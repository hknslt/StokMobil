// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

/** -------------------------------
 *  Müşteri adını farklı şemalardan çöz
 * -------------------------------- */
async function resolveMusteriAdi(after) {
  const flatKeys = [
    "musteriAdi", "musteriAdı", "musteri_adi",
    "musteriIsmi", "musteriName",
    "customerName", "firmaAdi", "firmaAdı", "unvan", "title", "name",
  ];
  for (const k of flatKeys) if (after[k]) return String(after[k]);

  if (after.musteri && typeof after.musteri === "object") {
    const m = after.musteri;
    const nested = m.adi || m.ad || m.name || m.title || m.firmaAdi || m.firmaAdı;
    if (nested) return String(nested);
  }

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
  return "";
}

/** Olay -> ayar anahtarı (flat) */
const olayKeyMap = {
  olusturuldu: "siparisOlusturuldu",
  stok_eksik: "stokYetersiz",
  sevkiyat: "sevkiyataGitti",
  tamamlandi: "siparisTamamlandi",
  // NOT: uretimde için ayrı toggle istemezsen sevkiyat’a bağladık
  uretimde: "sevkiyataGitti",
};
/** Olay -> ayar anahtarı (nested: ayarlar.bildirimler) */
const nestedKeyMap = {
  olusturuldu: "siparis",
  stok_eksik: "stok",
  sevkiyat: "sevkiyat",
  tamamlandi: "tamamlandi",
  uretimde: "sevkiyat",
};

// İzinli mi? (flat+nested; explicit false varsa kapalı)
function isAllowedForUser(u, olay) {
  const flat = (u && u.notificationSettings) || {};
  const nested = (u && u.ayarlar && u.ayarlar.bildirimler) || {};
  const hasFlatKey = Object.prototype.hasOwnProperty.call(olayKeyMap, olay);
  const hasNestedKey = Object.prototype.hasOwnProperty.call(nestedKeyMap, olay);

  const flatAllowed = hasFlatKey ? flat[olayKeyMap[olay]] !== false : true;
  const nestedAllowed = hasNestedKey ? nested[nestedKeyMap[olay]] !== false : true;

  return flatAllowed && nestedAllowed;
}

exports.siparisDurumBildirim = functions
  // Bölgeyi Firestore’unla aynı yap (diğer fonksiyonların europe-west1)
  .region("europe-west1")
  .firestore.document("siparisler/{siparisId}")
  .onWrite(async (change, ctx) => {
    const after = change.after.data();
    const before = change.before.data();
    if (!after) return null;

    // Gereksiz tetikleri erken kes
    if (before) {
      const beforeStr = JSON.stringify({ durum: before.durum, stokUyarisi: before.stokUyarisi });
      const afterStr = JSON.stringify({ durum: after.durum, stokUyarisi: after.stokUyarisi });
      if (beforeStr === afterStr) return null;
    }

    // --- Olayı belirle + mesajı hazırla ---
    let title = "", body = "", olay = "";
    if (!before) {
      title = "Sipariş oluşturuldu";
      const musteriAdi = await resolveMusteriAdi(after);
      body = `Müşteri: ${musteriAdi || "-"}`;
      olay = "olusturuldu";
    } else if (before.durum !== after.durum) {
      const map = {
        uretimde: ["Sipariş üretimde", "Sipariş üretime alındı.", "uretimde"],
        sevkiyat: ["Sipariş sevkiyata gitti", "Sipariş sevkiyat aşamasında.", "sevkiyat"],
        tamamlandi: ["Sipariş tamamlandı", "Sipariş teslim edildi.", "tamamlandi"],
        reddedildi: ["Sipariş reddedildi", "Sipariş onaylanmadı.", "reddedildi"],
      };
      if (map[after.durum]) {
        [title, body, olay] = map[after.durum];
        const musteriAdi = await resolveMusteriAdi(after);
        if (musteriAdi) body = `${body} (Müşteri: ${musteriAdi})`;
      }
    }

    if (after.stokUyarisi === true && (!before || before.stokUyarisi !== true)) {
      title ||= "Stok yetersizliği";
      body ||= "Sipariş sonrası stok eksik.";
      olay ||= "stok_eksik";
    }

    // reddedildi için toggle tanımlamadık: herkes görsün istiyorsan kalsın,
    // aksi halde olayKeyMap/nestedKeyMap’e anahtar ekle.
    if (!title) return null;

    // --- İzinli kullanıcıları bul ---
    const usersSnap = await db.collection("users").get();
    const izinliUid = new Set(
      usersSnap.docs
        .filter((doc) => isAllowedForUser(doc.data(), olay))
        .map((doc) => doc.id)
    );
    if (!izinliUid.size) return null;

    // --- Cihaz tokenlarını topla (sadece izinliler) ---
    const cihazSnap = await db.collectionGroup("cihazlar").get();
    const tokenSet = new Set();
    cihazSnap.docs.forEach((doc) => {
      const token = doc.get("token");
      if (!token) return;
      const uid = doc.ref.parent.parent.id; // users/{uid}/cihazlar
      if (izinliUid.has(uid)) tokenSet.add(token);
    });
    const tokens = Array.from(tokenSet);

    // --- In-app feed'e yaz (izinlilere) ---
    const feedPayload = {
      type: olay,
      title,
      body,
      siparisId: ctx.params.siparisId || "",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await Promise.all(
      Array.from(izinliUid).map((uid) =>
        db.collection("users").doc(uid).collection("inapp_notifications").add(feedPayload)
      )
    );

    // --- Push bildirimi gönder (varsa) ---
    if (tokens.length) {
      try {
        const res = await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: { olay, siparisId: ctx.params.siparisId || "" },
        });
        console.log("FCM OK:", res.successCount, "FAIL:", res.failureCount);
        res.responses.forEach((r, i) => {
          if (!r.success) console.error("FCM ERR", i, r.error?.code, r.error?.message);
        });
      } catch (e) {
        console.error("FCM send error:", e);
      }
    } else {
      console.warn("Gönderilecek token yok.");
    }

    return null;
  });
