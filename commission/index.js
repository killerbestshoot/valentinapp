const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");

if (!admin.apps.length) admin.initializeApp();

async function createNotification({ enterpriseId, title, message, type = "system" }) {
  const db = admin.firestore();
  return db.collection("notifications").add({
    enterpriseId,
    title,
    message,
    type,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function applyCommissionToTx(txRef, txId) {
  const db = admin.firestore();

  return await db.runTransaction(async (t) => {
    const snap = await t.get(txRef);
    if (!snap.exists) return { ok: false, skipped: true, reason: "tx pa egziste" };

    const tx = snap.data();

    if (tx.status !== "delivered") return { ok: false, skipped: true, reason: "status pa delivered" };
    if (tx.commissionApplied === true) return { ok: false, skipped: true, reason: "deja aplike" };

    const enterpriseId = String(tx.enterpriseId || "").trim();
    const staffUid = String(tx.staffUid || "").trim();

    if (!enterpriseId || !staffUid) {
      return { ok: false, skipped: true, reason: "enterpriseId/staffUid manke" };
    }

    const commissionAgent = Number(tx.commissionAgent || 0);
    const commissionOwner = Number(tx.commissionOwner || 0);

    if (commissionAgent <= 0 && commissionOwner <= 0) {
      return { ok: false, skipped: true, reason: "commission = 0" };
    }

    const agentRef = db.doc(`balances/${enterpriseId}_${staffUid}`);
    const ownerRef = db.doc(`balances/${enterpriseId}_OWNER`);
    const logRef = db.collection("commission_logs").doc(txId);

    const agentSnap = await t.get(agentRef);
    const ownerSnap = await t.get(ownerRef);

    const agentBal = Number(agentSnap.data()?.balance || 0);
    const ownerBal = Number(ownerSnap.data()?.balance || 0);

    t.set(agentRef, {
      enterpriseId,
      uid: staffUid,
      role: "agent",
      balance: agentBal + commissionAgent,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    t.set(ownerRef, {
      enterpriseId,
      uid: "OWNER",
      role: "owner",
      balance: ownerBal + commissionOwner,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    t.update(txRef, {
      commissionApplied: true,
      commissionAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
      agentCommissionApplied: commissionAgent,
      ownerCommissionApplied: commissionOwner,
    });

    t.set(logRef, {
      txId,
      enterpriseId,
      staffUid,
      staffName: tx.staffName || "",
      serviceName: tx.serviceName || "",
      commissionAgent,
      commissionOwner,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "commission_engine",
    }, { merge: true });

    return { ok: true, txId, enterpriseId, commissionAgent, commissionOwner };
  });
}

async function processCommissions() {
  const db = admin.firestore();
  const snapshot = await db.collection("transactions").where("status", "==", "delivered").get();

  let success = 0;
  let skipped = 0;
  let failed = 0;
  const errors = [];

  for (const doc of snapshot.docs) {
    try {
      const result = await applyCommissionToTx(doc.ref, doc.id);

      if (result.ok) {
        success++;

        await createNotification({
          enterpriseId: result.enterpriseId,
          title: "Commission Applied",
          message: `Tx ${result.txId}: Agent ${result.commissionAgent} / Owner ${result.commissionOwner}`,
          type: "commission",
        });
      } else {
        skipped++;
        if (result.reason) errors.push(`${doc.id}: ${result.reason}`);
      }
    } catch (err) {
      failed++;
      errors.push(`${doc.id}: ${err.message || err}`);
      console.error("ERROR TX:", doc.id, err);
    }
  }

  return { ok: true, scanned: snapshot.size, success, skipped, failed, errors };
}

exports.autoApplyCommissionOnTransaction = onDocumentWritten(
  {
    document: "transactions/{txId}",
    region: "us-central1",
    memory: "256MiB",
  },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return null;

    const tx = after.data();
    if (tx.status !== "delivered") return null;
    if (tx.commissionApplied === true) return null;

    const result = await applyCommissionToTx(after.ref, event.params.txId);

    if (result.ok) {
      await createNotification({
        enterpriseId: result.enterpriseId,
        title: "Commission Applied",
        message: `Tx ${result.txId}: Agent ${result.commissionAgent} / Owner ${result.commissionOwner}`,
        type: "commission",
      });
    }

    console.log("AUTO COMMISSION RESULT:", result);
    return null;
  }
);

exports.runWeeklyCommissionV2 = onSchedule(
  {
    schedule: "every sunday 23:59",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    memory: "256MiB",
  },
  async () => processCommissions()
);

exports.runCommissionNow = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User pa konekte.");
    }

    try {
      return await processCommissions();
    } catch (err) {
      console.error("RUN COMMISSION NOW FAILED:", err);
      throw new HttpsError("internal", err.message || String(err));
    }
  }
);