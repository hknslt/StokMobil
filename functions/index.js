const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

/* ---------- Müşteri adı ---------- */
async function resolveMusteriAdi(after) {
  if (after.musteri && typeof after.musteri === "object") {
    const m = after.musteri;
    const name = m.firmaAdi || m.yetkili;
    if (name) return String(name);

    const mid = m.id || m.musteriId || m.musteriID;
    if (mid) {
      try {
        const doc = await db.collection("musteriler").doc(String(mid)).get();
        if (doc.exists) {
          const d = doc.data() || {};
          return String(d.firmaAdi || d.yetkili || "");
        }
      } catch (e) {
        console.warn("Musteri adı (nested id) çekilemedi:", mid, e.message);
      }
    }
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
        return String(d.firmaAdi || d.yetkili || "");
      }
    } catch (e) {
      console.warn("Musteri adı çekilemedi:", id, e.message);
    }
  }

  if (after.firmaAdi || after.yetkili) return String(after.firmaAdi || after.yetkili);
  return "";
}

/* ---------- Toggle haritaları ---------- */
const olayKeyMap = {
  olusturuldu: "siparisOlusturuldu",
  uretimde: "uretimde",
  sevkiyat: "sevkiyataGitti",
  tamamlandi: "siparisTamamlandi",
  siparis_guncellendi: "siparisGuncellendi",
};
const nestedKeyMap = {
  olusturuldu: "siparis",
  uretimde: "uretimde",
  sevkiyat: "sevkiyat",
  tamamlandi: "tamamlandi",
  siparis_guncellendi: "guncelleme",
};

/* ---------- Rol -> izinli olaylar ---------- */
const roleEventMap = {
  // Yönetici her olayı alır
  admin: new Set(["olusturuldu", "stok_eksik", "sevkiyat", "tamamlandi", "uretimde", "siparis_guncellendi"]),
  pazarlamaci: new Set(["olusturuldu", "stok_eksik", "sevkiyat", "tamamlandi", "uretimde", "siparis_guncellendi"]),

  uretim: new Set(["uretimde", "stok_eksik", "siparis_guncellendi"]),
  sevkiyat: new Set(["sevkiyat", "uretimde", "siparis_guncellendi"]),
};


function normRole(r) {
  return (r || "")
    .toString()
    .toLowerCase()
    .replace(/ü/g, "u")
    .replace(/ı/g, "i")
    .replace(/ş/g, "s")
    .replace(/ğ/g, "g")
    .replace(/ç/g, "c")
    .replace(/ö/g, "o")
    .trim();
}

function roleAllows(u, olay) {
  const r = normRole(u?.role); // ← normalize ederek kullan
  const set = roleEventMap[r];
  if (!set) return false;
  return set.has(olay);
}

function isGloballyEnabled(u) {
  const flat = u?.notificationSettings || {};
  const nested = u?.ayarlar?.bildirimler || {};
  return (flat.enabled !== false) && (nested.enabled !== false);
}
function perTypeAllowed(u, olay) {
  const flat = u?.notificationSettings || {};
  const nested = u?.ayarlar?.bildirimler || {};
  const flatKey = olayKeyMap[olay];
  const nestedKey = nestedKeyMap[olay];
  const flatAllowed = flatKey ? flat[flatKey] !== false : true;
  const nestedAllowed = nestedKey ? nested[nestedKey] !== false : true;
  return flatAllowed && nestedAllowed;
}

/* ---------- Yardımcı ---------- */
function chunk(arr, size = 500) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/* ---------- Trigger ---------- */
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

    // Mesaj
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
    else {
      const bUrun = before.urunler || [];
      const aUrun = after.urunler || [];

      const bAciklama = (before.aciklama || "").trim();
      const aAciklama = (after.aciklama || "").trim();
      const urunlerDegisti = JSON.stringify(before.urunler) !== JSON.stringify(after.urunler);
      const aciklamaDegisti = before.aciklama !== after.aciklama;

      if (urunlerDegisti || aciklamaDegisti) {
        console.log(`Değişiklik Algılandı! Sipariş ID: ${ctx.params.siparisId}`);
        console.log(`Ürün Değişti: ${urunlerDegisti}, Açıklama Değişti: ${aciklamaDegisti}`);

        title = "Sipariş Güncellendi";
        const musteriAdi = await resolveMusteriAdi(after);
        body = `Sipariş detayları güncellendi. (${musteriAdi || '-'})`;
        olay = "siparis_guncellendi";
      }
    }



    if (after.stokUyarisi === true && (!before || before.stokUyarisi !== true)) {
      title ||= "Stok yetersizliği";
      body ||= "Sipariş sonrası stok eksik.";
      olay ||= "stok_eksik";
    }
    if (!title) return null;

    // typo fix (yukarıda küçük yazım hatası)
    body = body.replace("mustereriAdi", "musteriAdi");

    // İzinli kullanıcılar
    const usersSnap = await db.collection("users").get();
    const izinliUid = new Set(
      usersSnap.docs
        .filter(doc => {
          const u = doc.data() || {};
          return roleAllows(u, olay) && isGloballyEnabled(u) && perTypeAllowed(u, olay);
        })
        .map(doc => doc.id)
    );
    if (!izinliUid.size) return null;

    // Token dedup
    const cihazSnap = await db.collectionGroup("cihazlar").get();
    const tokenMap = new Map();
    cihazSnap.docs.forEach((d) => {
      const t = d.get("token");
      if (!t) return;
      const uid = d.ref.parent.parent.id;
      if (!izinliUid.has(uid)) return;

      const ts = d.get("refreshedAt")?.toMillis?.() ?? d.get("createdAt")?.toMillis?.() ?? 0;
      const prev = tokenMap.get(t);
      if (!prev || ts > prev.ts) tokenMap.set(t, { uid, ts });
    });
    const tokens = [...tokenMap.keys()];
    if (!tokens.length) return null;

    // bildirim sayfası için bildirim kayıtları
    /*
    const feed = {
      type: olay, title, body,
      siparisId: ctx.params.siparisId || "",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await Promise.all(
      [...izinliUid].map(uid =>
        db.collection("users").doc(uid).collection("inapp_notifications").add(feed)
      )
    );
    */

    // Push: Android data-only, iOS APNs alert + data
    const collapseId = `siparis:${ctx.params.siparisId || ""}:${olay}`;
    try {
      const batches = chunk(tokens, 500);
      for (const part of batches) {
        const res = await admin.messaging().sendEachForMulticast({
          tokens: part,
          data: {
            olay,
            siparisId: ctx.params.siparisId || "",
            title,
            body,
          },
          android: { collapseKey: collapseId },
          apns: {
            headers: { "apns-collapse-id": collapseId },
            payload: {
              aps: {
                alert: { title, body }, // iOS görünür
                sound: "default",
                threadId: `siparis:${ctx.params.siparisId || ""}`,
              },
            },
          },
        });
        console.log("FCM OK:", res.successCount, "FAIL:", res.failureCount);
      }
    } catch (e) {
      console.error("FCM send error:", e);
    }

    return null;
  });

/* ---------- Token claim ---------- */
exports.claimDeviceToken = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    try {
      const uid = context.auth?.uid;
      if (!uid) throw new functions.https.HttpsError("unauthenticated", "Giriş gerekli.");

      const tokenRaw = (data?.token ?? "").toString().trim();
      if (!tokenRaw) throw new functions.https.HttpsError("invalid-argument", "Token boş.");
      if (tokenRaw.includes("/")) throw new functions.https.HttpsError("invalid-argument", "Geçersiz token.");
      const platform = (data?.platform ?? "android").toString();

      const idxRef = db.collection("device_tokens").doc(tokenRaw);
      const idxSnap = await idxRef.get();
      const prevOwnerUid = idxSnap.exists ? idxSnap.get("ownerUid") : null;

      const batch = db.batch();
      if (prevOwnerUid && prevOwnerUid !== uid) {
        const oldRef = db.collection("users").doc(prevOwnerUid).collection("cihazlar").doc(tokenRaw);
        batch.delete(oldRef);
      }

      const myRef = db.collection("users").doc(uid).collection("cihazlar").doc(tokenRaw);
      batch.set(myRef, {
        uid, token: tokenRaw, platform,
        refreshedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      batch.set(idxRef, {
        ownerUid: uid, platform,
        lastClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      await batch.commit();
      return { ok: true, prevOwnerUid: prevOwnerUid || null };
    } catch (err) {
      console.error("claimDeviceToken hata:", err);
      if (err instanceof functions.https.HttpsError) throw err;
      throw new functions.https.HttpsError(
        "internal",
        typeof err?.message === "string" ? err.message : "Bilinmeyen sunucu hatası"
      );
    }
  });
