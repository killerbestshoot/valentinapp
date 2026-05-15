const admin = require("firebase-admin");
const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function ensureUser(email, password) {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    return existing;
  } catch (_) {
    return await admin.auth().createUser({
      email,
      password,
    });
  }
}

async function run() {
  try {
    console.log("Creating users...");

    const adminUser = await ensureUser("admin@test.com", "123456");
    const agentUser = await ensureUser("agent@test.com", "123456");

    console.log("ADMIN UID:", adminUser.uid);
    console.log("AGENT UID:", agentUser.uid);

    const enterpriseId = "ENT-001";
    const enterpriseName = "VOUPVAPCASH";

    await db.collection("users").doc(adminUser.uid).set({
      uid: adminUser.uid,
      email: "admin@test.com",
      role: "administrator",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection("users").doc(agentUser.uid).set({
      uid: agentUser.uid,
      email: "agent@test.com",
      role: "agent",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const entUsers = await db.collection("enterprise_users")
      .where("uid", "in", [adminUser.uid, agentUser.uid])
      .where("enterpriseId", "==", enterpriseId)
      .get();

    const seen = new Set();
    for (const d of entUsers.docs) {
      const data = d.data() || {};
      seen.add(`${data.uid}_${data.role}`);
    }

    if (!seen.has(`${adminUser.uid}_administrator`)) {
      await db.collection("enterprise_users").add({
        uid: adminUser.uid,
        enterpriseId,
        enterpriseName,
        role: "administrator",
        isActive: true,
      });
    }

    if (!seen.has(`${agentUser.uid}_agent`)) {
      await db.collection("enterprise_users").add({
        uid: agentUser.uid,
        enterpriseId,
        enterpriseName,
        role: "agent",
        isActive: true,
      });
    }

    await db.collection("balances").doc(`${enterpriseId}_${adminUser.uid}`).set({
      uid: adminUser.uid,
      enterpriseId,
      role: "administrator",
      balance: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection("balances").doc(`${enterpriseId}_${agentUser.uid}`).set({
      uid: agentUser.uid,
      enterpriseId,
      role: "agent",
      balance: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log("DONE: USERS + FIRESTORE CREATED");
    process.exit(0);
  } catch (e) {
    console.error("ERROR:", e);
    process.exit(1);
  }
}

run();
