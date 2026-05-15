const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(process.cwd(), "serviceAccountKey.json"));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

const ownerEmail = "staffexcelsior3@gmail.com";
const enterpriseId = "ENT-001";
const enterpriseName = "VOUPVAPCASH";

async function main() {
  const user = await admin.auth().getUserByEmail(ownerEmail);
  const uid = user.uid;

  console.log("=======================================");
  console.log("AUTH OWNER");
  console.log("uid:", uid);
  console.log("email:", user.email);
  console.log("=======================================");

  await db.collection("users").doc(uid).set({
    uid,
    email: ownerEmail,
    displayName: user.displayName || "Owner",
    role: "owner",
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await db.collection("enterprise_users").doc(uid).set({
    uid,
    email: ownerEmail,
    displayName: user.displayName || "Owner",
    role: "owner",
    enterpriseId,
    enterpriseName,
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await db.collection("balances").doc(`${enterpriseId}_OWNER`).set({
    uid: "OWNER",
    role: "owner",
    enterpriseId,
    enterpriseName,
    balance: 19,
    currency: "USD",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const userDoc = await db.collection("users").doc(uid).get();
  const entDoc = await db.collection("enterprise_users").doc(uid).get();
  const balDoc = await db.collection("balances").doc(`${enterpriseId}_OWNER`).get();

  console.log("USERS DOC =>", userDoc.exists ? userDoc.data() : "MISSING");
  console.log("ENTERPRISE_USERS DOC =>", entDoc.exists ? entDoc.data() : "MISSING");
  console.log("OWNER BALANCE DOC =>", balDoc.exists ? balDoc.data() : "MISSING");

  console.log("=======================================");
  console.log("DONE");
  console.log("KOUNYE A:");
  console.log("1) Fè logout nan app la");
  console.log("2) Login ankò ak staffexcelsior3@gmail.com");
  console.log("3) Kouri: flutter run -d chrome");
  console.log("=======================================");
}

main().catch((e) => {
  console.error("RUN ERROR:", e);
  process.exit(1);
});