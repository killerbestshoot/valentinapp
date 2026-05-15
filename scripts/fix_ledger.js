const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

function loadServiceAccount() {
  const candidates = [
    path.join(process.cwd(), "serviceAccountKey.json"),
    path.join(process.cwd(), "firebase-service-account.json"),
    path.join(process.cwd(), "service-account.json"),
  ];

  for (const p of candidates) {
    if (fs.existsSync(p)) {
      return require(p);
    }
  }

  throw new Error(
    "Pa jwenn service account file. Mete youn nan non sa yo nan root project la: serviceAccountKey.json | firebase-service-account.json | service-account.json"
  );
}

try {
  const serviceAccount = loadServiceAccount();

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
} catch (e) {
  console.error("INIT ERROR:", e.message);
  process.exit(1);
}

const db = admin.firestore();

function normalizeType(oldType) {
  const t = String(oldType || "").toLowerCase().trim();

  if (t.includes("topup")) return "topup";
  if (t.includes("payout")) return "payout";
  if (t.includes("commission")) return "commission";
  if (t.includes("withdraw")) return "withdraw";
  if (t.includes("transfer")) return "transfer";

  return t || "unknown";
}

function normalizeDirection(type, rawDirection) {
  const d = String(rawDirection || "").toLowerCase().trim();
  if (d === "credit" || d === "debit") return d;

  if (type === "payout" || type === "withdraw") return "debit";
  return "credit";
}

function toNumber(v, fallback = 0) {
  if (v === null || v === undefined) return fallback;
  if (typeof v === "number") return Number.isFinite(v) ? v : fallback;
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

async function main() {
  const snap = await db.collection("ledger").get();
  console.log("Total ledger docs:", snap.size);

  let updated = 0;

  for (const doc of snap.docs) {
    const d = doc.data() || {};

    const type = normalizeType(d.type);
    const direction = normalizeDirection(type, d.direction);

    const uid =
      d.uid ??
      d.staffUid ??
      d.actorUid ??
      d.targetUid ??
      d.ownerUid ??
      "UNKNOWN";

    const role =
      d.role ??
      d.staffRole ??
      d.actorRole ??
      d.targetRole ??
      d.ownerRole ??
      "unknown";

    const enterpriseId = d.enterpriseId ?? "";
    const enterpriseName = d.enterpriseName ?? "";
    const amount = toNumber(d.amount, 0);
    const currency = String(d.currency ?? "USD");

    const beforeBalance = toNumber(
      d.beforeBalance ?? d.balanceBefore,
      0
    );

    let afterBalance = toNumber(
      d.afterBalance ?? d.balanceAfter,
      Number.NaN
    );

    if (!Number.isFinite(afterBalance)) {
      afterBalance =
        direction === "debit"
          ? beforeBalance - amount
          : beforeBalance + amount;
    }

    const sourceCollection =
      d.sourceCollection ??
      (d.requestId ? "wallet_topup_requests" :
      d.transactionId || d.txId ? "transactions" :
      d.payoutRequestId ? "payout_requests" :
      "migration");

    const sourceId =
      d.sourceId ??
      d.requestId ??
      d.transactionId ??
      d.txId ??
      d.payoutRequestId ??
      doc.id;

    const txId =
      d.txId ??
      d.transactionId ??
      "";

    const note =
      d.note ??
      d.description ??
      "auto-migrated";

    const clean = {
      type,
      direction,
      uid: String(uid),
      role: String(role),
      enterpriseId: String(enterpriseId),
      enterpriseName: String(enterpriseName),
      amount,
      currency,
      beforeBalance,
      afterBalance,
      sourceCollection: String(sourceCollection),
      sourceId: String(sourceId),
      txId: String(txId),
      serviceName: String(d.serviceName ?? ""),
      status: String(d.status ?? "posted"),
      note: String(note),
      createdAt: d.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
      createdBy: String(d.createdBy ?? "system"),
      createdByRole: String(d.createdByRole ?? "system"),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await doc.ref.set(clean, { merge: true });
    updated++;

    if (updated % 20 === 0) {
      console.log("Updated:", updated);
    }
  }

  console.log("DONE. Updated docs:", updated);
}

main().catch((e) => {
  console.error("RUN ERROR:", e);
  process.exit(1);
});