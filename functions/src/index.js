const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

admin.initializeApp();
const db = admin.firestore();

function toNumber(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === "number") return value;
  const parsed = Number(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

async function getUserRole(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  if (userDoc.exists) {
    const role = ((userDoc.data() || {}).role || "").toString().trim().toLowerCase();
    if (role) return role;
  }

  const q = await db
    .collection("enterprise_users")
    .where("uid", "==", uid)
    .where("isActive", "==", true)
    .limit(1)
    .get();

  if (!q.empty) {
    return ((q.docs[0].data() || {}).role || "").toString().trim().toLowerCase();
  }

  return "";
}

async function processPendingCommissions({onlyTxId = null} = {}) {
  let query = db
    .collection("transactions")
    .where("status", "==", "delivered")
    .where("paymentStatus", "==", "paid")
    .where("commissionApplied", "==", false);

  if (onlyTxId) {
    query = query.where("txId", "==", onlyTxId);
  }

  const txSnap = await query.get();

  let processed = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of txSnap.docs) {
    const data = doc.data() || {};

    const txId = (data.txId || doc.id || "").toString().trim();
    const enterpriseId = (data.enterpriseId || "").toString().trim();
    const enterpriseName = (data.enterpriseName || "").toString().trim();
    const staffUid = (data.staffUid || "").toString().trim();
    const staffName = (data.staffName || "").toString().trim();
    const staffRole = (data.staffRole || "agent").toString().trim();
    const serviceName = (data.serviceName || "MonCash").toString().trim();

    const commissionAgent = toNumber(data.commissionAgent);
    const commissionOwner = toNumber(data.commissionOwner);

    if (!enterpriseId || !staffUid) {
      console.log("SKIP missing enterpriseId/staffUid:", txId);
      skipped++;
      continue;
    }

    if (commissionAgent <= 0 && commissionOwner <= 0) {
      console.log("SKIP invalid commissions:", txId);
      skipped++;
      continue;
    }

    const txRef = db.collection("transactions").doc(doc.id);
    const agentBalanceRef = db.collection("balances").doc(`${enterpriseId}_${staffUid}`);
    const ownerBalanceRef = db.collection("balances").doc(`${enterpriseId}_OWNER`);

    try {
      await db.runTransaction(async (transaction) => {
        const freshTx = await transaction.get(txRef);
        if (!freshTx.exists) throw new Error("Transaction deleted");

        const freshData = freshTx.data() || {};
        if (freshData.commissionApplied === true) {
          throw new Error("Commission already applied");
        }

        const agentBalSnap = await transaction.get(agentBalanceRef);
        const ownerBalSnap = await transaction.get(ownerBalanceRef);

        const agentExists = agentBalSnap.exists;
        const ownerExists = ownerBalSnap.exists;

        if (!agentExists) {
          transaction.set(agentBalanceRef, {
            uid: staffUid,
            enterpriseId,
            role: staffRole || "agent",
            balance: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        if (!ownerExists) {
          transaction.set(ownerBalanceRef, {
            uid: "OWNER",
            enterpriseId,
            role: "owner",
            balance: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        const agentBefore = agentExists ? toNumber((agentBalSnap.data() || {}).balance) : 0;
        const ownerBefore = ownerExists ? toNumber((ownerBalSnap.data() || {}).balance) : 0;

        const agentAfter = agentBefore + commissionAgent;
        const ownerAfter = ownerBefore + commissionOwner;

        transaction.set(agentBalanceRef, {
          uid: staffUid,
          enterpriseId,
          role: staffRole || "agent",
          balance: agentAfter,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        transaction.set(ownerBalanceRef, {
          uid: "OWNER",
          enterpriseId,
          role: "owner",
          balance: ownerAfter,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        transaction.update(txRef, {
          commissionApplied: true,
          commissionAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
          agentBalanceBefore: agentBefore,
          agentBalanceAfter: agentAfter,
          ownerBalanceBefore: ownerBefore,
          ownerBalanceAfter: ownerAfter,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const ledgerAgentRef = db.collection("ledger").doc();
        const ledgerOwnerRef = db.collection("ledger").doc();

        transaction.set(ledgerAgentRef, {
          type: "commission_agent",
          txId,
          enterpriseId,
          enterpriseName,
          uid: staffUid,
          name: staffName || staffUid,
          role: staffRole || "agent",
          serviceName,
          amount: commissionAgent,
          balanceBefore: agentBefore,
          balanceAfter: agentAfter,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.set(ledgerOwnerRef, {
          type: "commission_owner",
          txId,
          enterpriseId,
          enterpriseName,
          uid: "OWNER",
          name: "OWNER",
          role: "owner",
          serviceName,
          amount: commissionOwner,
          balanceBefore: ownerBefore,
          balanceAfter: ownerAfter,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log("OK commission applied:", txId);
      processed++;
    } catch (e) {
      console.log("FAIL on tx:", txId, e.message);
      failed++;
    }
  }

  return {
    processed,
    skipped,
    failed,
    totalFound: txSnap.size,
    onlyTxId: onlyTxId || null,
  };
}

exports.runWeeklyCommissions = onSchedule(
  {
    schedule: "every sunday 23:59",
    timeZone: "America/Mexico_City",
    region: "us-central1",
  },
  async () => {
    console.log("=== WEEKLY COMMISSION JOB START ===");
    const result = await processPendingCommissions();
    console.log("=== WEEKLY COMMISSION JOB END ===", result);
  }
);

exports.runWeeklyCommissionsNow = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Ou dwe konekte.");
    }

    const uid = request.auth.uid;
    const role = await getUserRole(uid);

    if (role !== "owner" && role !== "administrator" && role !== "admin") {
      throw new HttpsError("permission-denied", "Se owner/admin sèlman ki ka lanse commission manyèlman.");
    }

    const txId = ((request.data || {}).txId || "").toString().trim();
    const result = await processPendingCommissions({
      onlyTxId: txId || null,
    });

    return {
      ok: true,
      launchedBy: uid,
      role,
      ...result,
    };
  }
);