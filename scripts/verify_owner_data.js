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

async function main() {
  if (!ownerEmail) throw new Error("ownerEmail manke");

  const user = await admin.auth().getUserByEmail(ownerEmail);
  const uid = user.uid;

  console.log("=======================================");
  console.log("AUTH USER");
  console.log("uid:", uid);
  console.log("email:", user.email);
  console.log("displayName:", user.displayName || "-");
  console.log("=======================================");

  const userRef = db.collection("users").doc(uid);
  const entRef = db.collection("enterprise_users").doc(uid);

  const userSnap = await userRef.get();
  const entSnap = await entRef.get();

  console.log("");
  console.log("USERS DOC:");
  if (userSnap.exists) {
    console.log(JSON.stringify(userSnap.data(), null, 2));
  } else {
    console.log("MISSING");
  }

  console.log("");
  console.log("ENTERPRISE_USERS DIRECT DOC:");
  if (entSnap.exists) {
    console.log(JSON.stringify(entSnap.data(), null, 2));
  } else {
    console.log("MISSING");
  }

  console.log("");
  console.log("ENTERPRISE_USERS QUERY where uid == auth uid:");
  const entQuery = await db
    .collection("enterprise_users")
    .where("uid", "==", uid)
    .get();

  if (entQuery.empty) {
    console.log("NO MATCH");
  } else {
    entQuery.docs.forEach((doc, i) => {
      console.log(`--- MATCH ${i + 1} / DOC ID: ${doc.id} ---`);
      console.log(JSON.stringify(doc.data(), null, 2));
    });
  }

  let enterpriseId = "";
  let enterpriseName = "";

  if (entSnap.exists) {
    const d = entSnap.data() || {};
    enterpriseId = String(d.enterpriseId || "");
    enterpriseName = String(d.enterpriseName || "");
  } else if (!entQuery.empty) {
    const d = entQuery.docs[0].data() || {};
    enterpriseId = String(d.enterpriseId || "");
    enterpriseName = String(d.enterpriseName || "");
  }

  console.log("");
  console.log("RESOLVED ENTERPRISE:");
  console.log("enterpriseId:", enterpriseId || "(empty)");
  console.log("enterpriseName:", enterpriseName || "(empty)");

  if (enterpriseId) {
    const ownerBalId = `${enterpriseId}_OWNER`;
    const ownerBalSnap = await db.collection("balances").doc(ownerBalId).get();

    console.log("");
    console.log(`OWNER BALANCE DOC: balances/${ownerBalId}`);
    if (ownerBalSnap.exists) {
      console.log(JSON.stringify(ownerBalSnap.data(), null, 2));
    } else {
      console.log("MISSING");
    }
  } else {
    console.log("");
    console.log("OWNER BALANCE DOC:");
    console.log("SKIPPED paske enterpriseId vid");
  }

  console.log("");
  console.log("BALANCES QUICK LIST:");
  const balSnap = await db.collection("balances").limit(20).get();
  balSnap.docs.forEach((doc) => {
    const d = doc.data() || {};
    console.log(
      `- ${doc.id} | role=${d.role || "-"} | uid=${d.uid || "-"} | enterpriseId=${d.enterpriseId || "-"} | balance=${d.balance ?? "-"}`
    );
  });

  console.log("");
  console.log("=======================================");
  console.log("VERIFY FINI");
  console.log("Si enterpriseId soti EMPTY, pwoblèm nan nan users/enterprise_users");
  console.log("Si enterpriseId bon men balance toujou 0.00 nan app la, pwoblèm nan nan kòd dashboard la");
  console.log("=======================================");
}

main().catch((e) => {
  console.error("RUN ERROR:", e);
  process.exit(1);
});