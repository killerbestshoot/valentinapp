const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const serviceAccountPath = fs.existsSync(path.join(__dirname, "../serviceAccountKey.json"))
  ? path.join(__dirname, "../serviceAccountKey.json")
  : path.join(__dirname, "../../tools/private/serviceAccountKey.json");
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function ensureUser(email, password) {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    return await admin.auth().updateUser(existing.uid, { password });
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

    const ownerUser = await ensureUser("owner@test.com", "123456");
    const adminUser = await ensureUser("admin@test.com", "123456");
    const agentUser = await ensureUser("agent@test.com", "123456");

    console.log("OWNER UID:", ownerUser.uid);
    console.log("ADMIN UID:", adminUser.uid);
    console.log("AGENT UID:", agentUser.uid);

    const enterpriseId = "ENT-001";
    const enterpriseName = "VOUPVAPCASH";

    await db.collection("users").doc(ownerUser.uid).set({
      uid: ownerUser.uid,
      email: "owner@test.com",
      role: "owner",
      enterpriseId,
      enterpriseName,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection("users").doc(adminUser.uid).set({
      uid: adminUser.uid,
      email: "admin@test.com",
      role: "administrator",
      enterpriseId,
      enterpriseName,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection("users").doc(agentUser.uid).set({
      uid: agentUser.uid,
      email: "agent@test.com",
      role: "agent",
      enterpriseId,
      enterpriseName,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const entUsers = await db.collection("enterprise_users")
      .where("uid", "in", [ownerUser.uid, adminUser.uid, agentUser.uid])
      .where("enterpriseId", "==", enterpriseId)
      .get();

    const seen = new Set();
    for (const d of entUsers.docs) {
      const data = d.data() || {};
      seen.add(`${data.uid}_${data.role}`);
    }

    if (!seen.has(`${ownerUser.uid}_owner`)) {
      await db.collection("enterprise_users").add({
        uid: ownerUser.uid,
        email: "owner@test.com",
        enterpriseId,
        enterpriseName,
        role: "owner",
        isActive: true,
      });
    }

    if (!seen.has(`${adminUser.uid}_administrator`)) {
      await db.collection("enterprise_users").add({
        uid: adminUser.uid,
        email: "admin@test.com",
        enterpriseId,
        enterpriseName,
        role: "administrator",
        isActive: true,
      });
    }

    if (!seen.has(`${agentUser.uid}_agent`)) {
      await db.collection("enterprise_users").add({
        uid: agentUser.uid,
        email: "agent@test.com",
        enterpriseId,
        enterpriseName,
        role: "agent",
        isActive: true,
      });
    }

    await db.collection("balances").doc(`${enterpriseId}_OWNER`).set({
      uid: ownerUser.uid,
      enterpriseId,
      enterpriseName,
      role: "owner",
      balance: 0,
      currency: "USD",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

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
