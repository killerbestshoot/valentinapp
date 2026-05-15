const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(process.cwd(), "serviceAccountKey.json"));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

const ownerEmail = process.argv[2];
const enterpriseId = process.argv[3];
const enterpriseName = process.argv[4];
const role = process.argv[5] || "owner";

async function main() {
  if (!ownerEmail) throw new Error("ownerEmail manke");

  const userRecord = await admin.auth().getUserByEmail(ownerEmail);
  const uid = userRecord.uid;

  console.log("AUTH USER FOUND");
  console.log("uid:", uid);
  console.log("email:", userRecord.email);

  await db.collection("users").doc(uid).set({
    uid,
    email: ownerEmail,
    displayName: userRecord.displayName || "Owner",
    role,
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const entRef = db.collection("enterprise_users").doc(uid);
  await entRef.set({
    uid,
    email: ownerEmail,
    displayName: userRecord.displayName || "Owner",
    role,
    enterpriseId,
    enterpriseName,
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const ownerBalanceRef = db.collection("balances").doc(`${enterpriseId}_OWNER`);
  const ownerBalanceSnap = await ownerBalanceRef.get();

  if (!ownerBalanceSnap.exists) {
    await ownerBalanceRef.set({
      uid: "OWNER",
      role: "owner",
      enterpriseId,
      enterpriseName,
      balance: 0,
      currency: "USD",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log("CREATED owner balance doc:", `${enterpriseId}_OWNER`);
  } else {
    console.log("OWNER balance doc already exists:", `${enterpriseId}_OWNER`);
  }

  console.log("=======================================");
  console.log("OWNER PROFILE FIXED");
  console.log("users/" + uid);
  console.log("enterprise_users/" + uid);
  console.log("balances/" + enterpriseId + "_OWNER");
  console.log("=======================================");
}

main().catch((e) => {
  console.error("RUN ERROR:", e.message || e);
  process.exit(1);
});