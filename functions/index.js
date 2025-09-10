const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

/** -------------------------------
 *  Müşteri adını farklı şemalardan çöz
 * -------------------------------- */
async function resolveMusteriAdi(after) {
  // 1) Düz alan adları
  const flatKeys = [
    "musteriAdi", "musteriAdı", "musteri_adi",
    "musteriIsmi", "musteriName",
    "customerName", "firmaAdi", "firmaAdı", "unvan", "title", "name",
  ];
  for (const k of flatKeys) {
    if (after[k]) return String(after[k]);
  }

  // 2) Nesne içinde (musteri: { adi, ad, name, title })
  if (after.musteri && typeof after.musteri === "object") {
    const m = after.musteri;
    const nested = m.adi || m.ad || m.name || m.title || m.firmaAdi || m.firmaAdı;
    if (nested) return String(nested);
  }

  // 3) ID veya Ref var ise /musteriler'den çek
  const id =
    after.musteriId ||
    after.musteriID ||
    (after.musteriRef && after.musteriRef.id) ||
    (after.musteri && after.musteri.id);
  if (id) {
    try {
      const doc = await db.collection("musteriler").doc(String(id)).get();
      if (doc.exists) {
        const d = doc.data() || {};
        return (
          d.adi || d.ad || d.name || d.unvan || d.title || d.firmaAdi || d.firmaAdı || ""
        ).toString();
      }
    } catch (e) {
      console.warn("Musteri adı çekilemedi:", id, e.message);
    }
  }

  return ""; // bulunamazsa boş dön
}

/** Olay -> ayar anahtarı (düz şema) */
const olayKeyMap = {
  olusturuldu: "siparisOlusturuldu",
  stok_eksik:  "stokYetersiz",
  sevkiyat:    "sevkiyataGitti",
  tamamlandi:  "siparisTamamlandi",
};
/** Olay -> ayar anahtarı (nested şema: ayarlar.bildirimler) */
const nestedKeyMap = {
  olusturuldu: "siparis",
  stok_eksik:  "stok",
  sevkiyat:    "sevkiyat",
  tamamlandi:  "tamamlandi",
};

exports.siparisDurumBildirim = functions
  .region("us-central1")
  .firestore.document("siparisler/{siparisId}")
  .onWrite(async (change, ctx) => {
    const after = change.after.data();
    const before = change.before.data();

    // Silinme ise çık
    if (!after) return null;

    // Hiç anlamlı değişiklik yoksa hızlı çıkış (opsiyonel ama maliyeti düşürür)
    if (before) {
      const beforeStr = JSON.stringify({
        durum: before.durum,
        stokUyarisi: before.stokUyarisi,
      });
      const afterStr = JSON.stringify({
        durum: after.durum,
        stokUyarisi: after.stokUyarisi,
      });
      if (beforeStr === afterStr) return null;
    }

    // --- Olayı/mesajı oluştur ---
    let title = "", body = "", olay = "";

    if (!before) {
      // Oluşturma
      title = "Sipariş oluşturuldu";
      const musteriAdi = await resolveMusteriAdi(after);
      body  = `Müşteri: ${musteriAdi || "-"}`;
      olay  = "olusturuldu";
    } else if (before.durum !== after.durum) {
      // Durum değişimi
      const map = {
        uretimde:   ["Sipariş üretimde", "Sipariş üretime alındı.", "uretimde"],
        sevkiyat:   ["Sipariş sevkiyata gitti", "Sipariş sevkiyat aşamasında.", "sevkiyat"],
        tamamlandi: ["Sipariş tamamlandı", "Sipariş teslim edildi.", "tamamlandi"],
        reddedildi: ["Sipariş reddedildi", "Sipariş onaylanmadı.", "reddedildi"],
      };
      if (map[after.durum]) {
        [title, body, olay] = map[after.durum];
        // İstersen müşteriyi ekle
        const musteriAdi = await resolveMusteriAdi(after);
        if (musteriAdi) body = `${body} (Müşteri: ${musteriAdi})`;
      }
    }

    // Stok uyarısı
    if (after.stokUyarisi === true && (!before || before.stokUyarisi !== true)) {
      title ||= "Stok yetersizliği";
      body  ||= "Sipariş sonrası stok eksik.";
      olay  ||= "stok_eksik";
    }

    if (!title) return null;

    // --- Kullanıcı ayarlarına göre filtre ---
    // Hem düz şema (notificationSettings.*) hem nested şema (ayarlar.bildirimler.*) desteklenir.
    const usersSnap = await db.collection("users").get();
    const acikUid = new Set(
      usersSnap.docs
        .filter((d) => {
          const u = d.data() || {};

          const flat = u.notificationSettings || {};
          const nested = (u.ayarlar && u.ayarlar.bildirimler) || {};

          // Varsayılan: true. Eğer anahtar explicit false ise kapalı say.
          const flatAllowed =
            olay in olayKeyMap
              ? flat[olayKeyMap[olay]] !== false
              : true;

          const nestedAllowed =
            olay in nestedKeyMap
              ? nested[nestedKeyMap[olay]] !== false
              : true;

          return flatAllowed && nestedAllowed;
        })
        .map((d) => d.id)
    );

    // --- Cihaz tokenlarını topla (users/{uid}/cihazlar alt koleksiyonu) ---
    const cihazSnap = await db.collectionGroup("cihazlar").get();
    const tokens = [];
    cihazSnap.docs.forEach((doc) => {
      const token = doc.get("token");
      if (!token) return;
      const uid = doc.ref.parent.parent.id; // users/{uid}/cihazlar
      if (acikUid.has(uid)) tokens.push(token);
    });

    console.log("BILDIRIM", {
      olay,
      siparisId: ctx.params.siparisId,
      tokenSayisi: tokens.length,
    });
    if (!tokens.length) {
      console.warn(
        "Hedef token bulunamadı. users/{uid}/cihazlar altındaki 'token' alanlarını kontrol et."
      );
      return null;
    }

    // --- Bildirim gönder ---
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { olay, siparisId: ctx.params.siparisId || "" },
    });

    console.log("FCM OK:", res.successCount, "FAIL:", res.failureCount);
    res.responses.forEach((r, i) => {
      if (!r.success) console.error("FCM ERR", i, r.error?.code, r.error?.message);
    });

    return null;
  });
