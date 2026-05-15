const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.applyCommissionWeekly = functions.pubsub
  .schedule("every sunday 23:59")
  .timeZone("America/Mexico_City")
  .onRun(async (context) => {

    const db = admin.firestore();

    const snapshot = await db
      .collection("transactions")
      .where("status", "==", "delivered")
      .where("commissionApplied", "==", false)
      .get();

    console.log("Transactions to process:", snapshot.size);

    for (const doc of snapshot.docs) {
      const tx = doc.data();

      const enterpriseId = tx.enterpriseId;
      const staffUid = tx.staffUid;

      const commissionAgent = Number(tx.commissionAgent || 0);
      const commissionOwner = Number(tx.commissionOwner || 0);

      if (commissionAgent <= 0 && commissionOwner <= 0) continue;

      const agentRef = db.doc(`balances/${enterpriseId}_${staffUid}`);
      const ownerRef = db.doc(`balances/${enterpriseId}_OWNER`);

      await db.runTransaction(async (t) => {
        const agentSnap = await t.get(agentRef);
        const ownerSnap = await t.get(ownerRef);

        const agentBal = Number(agentSnap.data()?.balance || 0);
        const ownerBal = Number(ownerSnap.data()?.balance || 0);

        t.set(agentRef, {
          balance: agentBal + commissionAgent,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        t.set(ownerRef, {
          balance: ownerBal + commissionOwner,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        t.update(doc.ref, {
          commissionApplied: true,
          commissionAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log("Processed:", doc.id);
    }

    return null;
  });
