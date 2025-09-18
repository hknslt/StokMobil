// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

/* ---------- Müşteri adı çöz --------- */
async function resolveMusteriAdi(after) {
  const flatKeys = ["musteriAdi", "musteriAdı", "musteri_adi", "musteriIsmi", "musteriName", "customerName", "firmaAdi", "firmaAdı", "unvan", "title", "name"];
  for (const k of flatKeys) if (after[k]) return String(after[k]);
  if (after.musteri && typeof after.musteri === "object") {
    const m = after.musteri;
    const nested = m.adi || m.ad || m.name || m.title || m.firmaAdi || m.firmaAdı;
    if (nested) return String(nested);
  }
  const id = after.musteriId || after.musteriID || (after.musteriRef && after.musteriRef.id) || (after.musteri && after.musteri.id);
  if (id) {
    try {
      const doc = await db.collection("musteriler").doc(String(id)).get();
      if (doc.exists) {
        const d = doc.data() || {};
        return (d.adi || d.ad || d.name || d.unvan || d.title || d.firmaAdi || d.firmaAdı || "").toString();
      }
    } catch (e) { console.warn("Musteri adı çekilemedi:", id, e.message); }
  }
  return "";
}

/* ---------- Olay-key eşlemesi --------- */
const olayKeyMap = {
  olusturuldu: "siparisOlusturuldu",
  stok_eksik: "stokYetersiz",
  sevkiyat: "sevkiyataGitti",
  tamamlandi: "siparisTamamlandi",
  uretimde: "sevkiyataGitti", // ayrı toggle istersen yeni key açarız
};
const nestedKeyMap = {
  olusturuldu: "siparis",
  stok_eksik: "stok",
  sevkiyat: "sevkiyat",
  tamamlandi: "tamamlandi",
  uretimde: "sevkiyat",
};

/* ---------- Rol -> izinli olaylar --------- */
const roleEventMap = {
  admin: new Set(["olusturuldu", "tamamlandi"]),
  uretim: new Set(["stok_eksik"]),
  sevkiyat: new Set(["sevkiyat"]),
  pazarlamaci: new Set(["olusturuldu"]), // istersen genişlet
};

function normRole(r) {
  return (r || "").toString().toLowerCase()
    .replace("ü", "u").replace("ı", "i").replace("ş", "s").replace("ğ", "g").replace("ç", "c").replace("ö", "o");
}

function roleAllows(u, olay) {
  const r = normRole(u?.role);
  const set = roleEventMap[r];
  if (!set) return false;
  return set.has(olay);
}

function isGloballyEnabled(u) {
  // flat: notificationSettings.enabled === false ise kapalı
  const flat = u?.notificationSettings || {};
  const nested = u?.ayarlar?.bildirimler || {};
  const flatEnabled = (flat.enabled !== false);
  const nestedEnabled = (nested.enabled !== false);
  return flatEnabled && nestedEnabled;
}

function perTypeAllowed(u, olay) {
  const flat = u?.notificationSettings || {};
  const nested = u?.ayarlar?.bildirimler || {};
  const flatAllowed = olayKeyMap[olay] ? flat[olayKeyMap[olay]] !== false : true;
  const nestedAllowed = nestedKeyMap[olay] ? nested[nestedKeyMap[olay]] !== false : true;
  return flatAllowed && nestedAllowed;
}

exports.siparisDurumBildirim = functions
  .region("europe-west1")
  .firestore.document("siparisler/{siparisId}")
  .onWrite(async (change, ctx) => {
    const after = change.after.data();
    const before = change.before.data();
    if (!after) return null;

    if (before) {
      const beforeStr = JSON.stringify({ durum: before.durum, stokUyarisi: before.stokUyarisi });
      const afterStr = JSON.stringify({ durum: after.durum, stokUyarisi: after.stokUyarisi });
      if (beforeStr === afterStr) return null;
    }

    // Olay + mesaj
    let title = "", body = "", olay = "";
    if (!before) {
      title = "Sipariş oluşturuldu";
      const musteriAdi = await resolveMusteriAdi(after);
      body = `Müşteri: ${musterriAdi || "-"}`;
      olay = "olusturuldu";
    } else if (before.durum !== after.durum) {
      const map = {
        uretimde: ["Sipariş üretimde", "Sipariş üretime alındı.", "uretimde"],
        sevkiyat: ["Sipariş sevkiyata gitti", "Sipariş sevkiyat aşamasında.", "sevkiyat"],
        tamamlandi: ["Sipariş tamamlandı", "Sipariş teslim edildi.", "tamamlandi"],
        reddedildi: ["Sipariş reddedildi", "Sipariş onaylanmadı.", "reddedildi"], // toggle'a bağlı değil
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
    if (!title) return null;

    // İzinli kullanıcılar (rol + genel + per-type)
    const usersSnap = await db.collection("users").get();
    const izinliUid = new Set(
      usersSnap.docs
        .filter(doc => {
          const u = doc.data() || {};
          if (!roleAllows(u, olay)) return false;
          if (!isGloballyEnabled(u)) return false;
          if (!perTypeAllowed(u, olay)) return false;
          return true;
        })
        .map(doc => doc.id)
    );
    if (!izinliUid.size) return null;

    // Tokenlar (sadece izinliler)
    const cihazSnap = await db.collectionGroup("cihazlar").get();
    const tokens = [];
    cihazSnap.docs.forEach(d => {
      const t = d.get("token");
      if (!t) return;
      const uid = d.ref.parent.parent.id;
      if (izinliUid.has(uid)) tokens.push(t);
    });

    // In-app feed
    const feed = {
      type: olay,
      title, body,
      siparisId: ctx.params.siparisId || "",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await Promise.all([...izinliUid].map(uid =>
      db.collection("users").doc(uid).collection("inapp_notifications").add(feed)
    ));

    // Push
    if (tokens.length) {
      try {
        const res = await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: { olay, siparisId: ctx.params.siparisId || "" },
        });
        console.log("FCM OK:", res.successCount, "FAIL:", res.failureCount);
      } catch (e) {
        console.error("FCM send error:", e);
      }
    }
    return null;
  });
