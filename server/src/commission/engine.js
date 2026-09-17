"use strict";

/**
 * Motè komisyon — pòt SQLite `commission/index.js` (Firebase).
 *
 * RÈG BIZNIS (menm ak ansyen sistèm nan):
 *   - komisyon ajan = montan × to ajan sèvis la (10% pa default)
 *   - komisyon owner = montan × to owner sèvis la (20% pa default)
 *   - aplike SÈLMAN sou tranzaksyon `delivered`, yon SÈL fwa
 *
 * DE DEFO ANSYEN VÈSYON AN KI KORIJE ISIT LA:
 *
 * 1. Wallet owner FANTOM. Ansyen motè a te kredite `balances/{ent}_OWNER` —
 *    yon uid literal "OWNER" ke pèsonn pa janm li. Komisyon owner yo te
 *    akimile nan yon wallet envizib. Isit la nou kredite wallet VRE owner an
 *    (`enterprises.owner_uid`).
 *
 * 2. Pa gen tras nan rejis la. Ansyen motè a te modifye `balance` dirèkteman,
 *    san liy nan `wallet_ledger`: sòld la pa t ka eksplike. Isit la chak kredi
 *    pase pa `creditWallet`, ki ekri sòld la ak liy rejis la ansanm.
 *
 * IDEMPOTANS: chak kredi gen yon kle stab (`commission:{txId}:agent`). Si pwosesis
 * la mouri ant de kredi, yon lòt pasaj rejwe l san janm double yon komisyon —
 * kontrent UNIQUE sou `wallet_ledger.idempotency_key` garanti sa.
 */

const { getDb, now } = require("../db/db");
const { getBazikService } = require("../bazik_service");
const { money } = require("../../../bazik/index.js");

/** To legacy yo, si sèvis la pa nan katalòg la. */
const DEFAULT_AGENT_PCT = 10;
const DEFAULT_OWNER_PCT = 20;

/** To komisyon yon sèvis (pa non, san konsidere majiskil). */
function resolveRates(serviceName) {
  const row = getDb()
    .prepare(
      `SELECT commission_agent_pct, commission_owner_pct FROM services
        WHERE LOWER(name) = LOWER(?) AND is_active = 1 LIMIT 1`
    )
    .get(String(serviceName || "").trim());

  return {
    agentPct: row ? Number(row.commission_agent_pct) : DEFAULT_AGENT_PCT,
    ownerPct: row ? Number(row.commission_owner_pct) : DEFAULT_OWNER_PCT,
  };
}

/**
 * Kalkile komisyon yo nan deviz tranzaksyon an.
 * Nou rele sa lè tranzaksyon an KREYE: to a fikse sou li, konsa yon chanjman
 * to pita pa modifye retwoaktivman sa ajan an te wè.
 */
function computeCommission({ amountMinor, serviceName }) {
  const { agentPct, ownerPct } = resolveRates(serviceName);

  return {
    agentPct,
    ownerPct,
    agentMinor: Math.round((amountMinor * agentPct) / 100),
    ownerMinor: Math.round((amountMinor * ownerPct) / 100),
  };
}

/**
 * Konvèti santim yon deviz vè yon lòt, ak liv to echanj la (to jounen an).
 * Si to yo pa fre an pwodiksyon, sa voye `rates_stale`: komisyon an rete an
 * reta, e pwochen pasaj `applyPendingCommissions` ap aplike l.
 */
async function convertMinor(amountMinor, fromCurrency, toCurrency) {
  if (fromCurrency === toCurrency || amountMinor === 0) return amountMinor;
  return (await getBazikService().rates.convert(amountMinor, fromCurrency, toCurrency)).amountMinor;
}

/**
 * Aplike komisyon yon tranzaksyon.
 * @returns {Promise<{status: string, [key: string]: any}>}
 */
async function applyCommissionToTx(txId) {
  const db = getDb();
  const store = getBazikService().store;

  const tx = db.prepare("SELECT * FROM transactions WHERE tx_id = ?").get(txId);

  if (!tx) return { status: "skipped", reason: "tx_not_found", txId };
  if (tx.status !== "delivered") return { status: "skipped", reason: "not_delivered", txId };
  if (tx.commission_applied === 1) return { status: "skipped", reason: "already_applied", txId };

  if (!tx.enterprise_id || !tx.staff_uid) {
    return { status: "skipped", reason: "missing_owner_fields", txId };
  }

  // To ki te fikse lè tranzaksyon an kreye. Si yo pa la (ansyen liy), nou
  // kalkile yo kounye a.
  let { agent_commission_pct: agentPct, owner_commission_pct: ownerPct } = tx;
  let agentMinor = tx.commission_agent_minor;
  let ownerMinor = tx.commission_owner_minor;

  if (!agentMinor && !ownerMinor) {
    const computed = computeCommission({ amountMinor: tx.amount_minor, serviceName: tx.service });
    ({ agentPct, ownerPct, agentMinor, ownerMinor } = computed);
  }

  if (agentMinor <= 0 && ownerMinor <= 0) {
    db.prepare(
      "UPDATE transactions SET commission_applied = 1, commission_applied_at = ? WHERE tx_id = ?"
    ).run(now(), txId);
    return { status: "skipped", reason: "zero_commission", txId };
  }

  const enterprise = db
    .prepare("SELECT owner_uid, name FROM enterprises WHERE enterprise_id = ?")
    .get(tx.enterprise_id);

  const ownerUid = enterprise?.owner_uid || "";

  // --- Kredi ajan ---
  const agentWallet = await store.getWallet({ uid: tx.staff_uid, enterpriseId: tx.enterprise_id });
  const agentCurrency = agentWallet?.currency || tx.currency;
  const agentCreditMinor = await convertMinor(agentMinor, tx.currency, agentCurrency);

  if (agentCreditMinor > 0) {
    await store.creditWallet({
      uid: tx.staff_uid,
      enterpriseId: tx.enterprise_id,
      enterpriseName: tx.enterprise_name || enterprise?.name || "",
      role: tx.staff_role || "agent",
      amountMinor: agentCreditMinor,
      currency: agentCurrency,
      type: "commission_agent",
      note: `Komisyon ${agentPct}% sou ${tx.service} (${money.fromMinor(tx.amount_minor)} ${tx.currency})`,
      sourceCollection: "transactions",
      sourceId: txId,
      txId,
      serviceName: tx.service,
      createdBy: "commission_engine",
      createdByRole: "system",
      idempotencyKey: `commission:${txId}:agent`,
    });
  }

  // --- Kredi owner ---
  let ownerCreditMinor = 0;

  if (ownerUid && ownerMinor > 0) {
    const ownerWallet = await store.getWallet({ uid: ownerUid, enterpriseId: tx.enterprise_id });
    const ownerCurrency = ownerWallet?.currency || tx.currency;
    ownerCreditMinor = await convertMinor(ownerMinor, tx.currency, ownerCurrency);

    if (ownerCreditMinor > 0) {
      await store.creditWallet({
        uid: ownerUid,
        enterpriseId: tx.enterprise_id,
        enterpriseName: tx.enterprise_name || enterprise?.name || "",
        role: "owner",
        amountMinor: ownerCreditMinor,
        currency: ownerCurrency,
        type: "commission_owner",
        note: `Komisyon owner ${ownerPct}% sou ${tx.service}`,
        sourceCollection: "transactions",
        sourceId: txId,
        txId,
        serviceName: tx.service,
        createdBy: "commission_engine",
        createdByRole: "system",
        idempotencyKey: `commission:${txId}:owner`,
      });
    }
  }

  // --- Make tranzaksyon an + jounal ---
  //
  // `AND commission_applied = 0`: si de pasaj konkiran rive isit, sèl youn
  // make l. Kredi yo pa ka double kanmenm (kle idempotans).
  const marked = db
    .prepare(
      `UPDATE transactions
          SET commission_applied = 1, commission_applied_at = ?,
              commission_agent_minor = ?, commission_owner_minor = ?,
              agent_commission_pct = ?, owner_commission_pct = ?
        WHERE tx_id = ? AND commission_applied = 0`
    )
    .run(now(), agentMinor, ownerMinor, agentPct, ownerPct, txId);

  db.prepare(
    `INSERT INTO commission_logs
      (tx_id, enterprise_id, staff_uid, owner_uid, service, tx_amount_minor, tx_currency,
       agent_pct, owner_pct, agent_minor, owner_minor, agent_credit_minor,
       owner_credit_minor, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(tx_id) DO NOTHING`
  ).run(
    txId, tx.enterprise_id, tx.staff_uid, ownerUid, tx.service, tx.amount_minor,
    tx.currency, agentPct, ownerPct, agentMinor, ownerMinor, agentCreditMinor,
    ownerCreditMinor, now()
  );

  return {
    status: marked.changes === 1 ? "applied" : "already_applied",
    txId,
    agentCredit: money.fromMinor(agentCreditMinor),
    ownerCredit: money.fromMinor(ownerCreditMinor),
    ownerMissing: !ownerUid,
  };
}

/**
 * Aplike tout komisyon ki an reta — ak yon LIMIT.
 *
 * Ansyen motè a te chaje TOUT koleksyon `transactions` la san filtre, epi li
 * te filtre apre. Ak kèk dizèn milye tranzaksyon, fonksyon an t ap mouri
 * (memwa) e komisyon yo t ap sispann peye san alèt.
 */
async function applyPendingCommissions({ enterpriseId = null, limit = 100 } = {}) {
  const db = getDb();

  const rows = enterpriseId
    ? db
        .prepare(
          `SELECT tx_id FROM transactions
            WHERE status = 'delivered' AND commission_applied = 0 AND enterprise_id = ?
            ORDER BY updated_at ASC LIMIT ?`
        )
        .all(enterpriseId, limit)
    : db
        .prepare(
          `SELECT tx_id FROM transactions
            WHERE status = 'delivered' AND commission_applied = 0
            ORDER BY updated_at ASC LIMIT ?`
        )
        .all(limit);

  const results = [];
  for (const row of rows) {
    try {
      results.push(await applyCommissionToTx(row.tx_id));
    } catch (err) {
      // Yon tranzaksyon ki echwe pa bloke lòt yo; li ap rejwe pwochen fwa.
      results.push({ status: "error", txId: row.tx_id, message: err.message });
    }
  }

  return results;
}

module.exports = {
  applyCommissionToTx,
  applyPendingCommissions,
  computeCommission,
  resolveRates,
  DEFAULT_AGENT_PCT,
  DEFAULT_OWNER_PCT,
};
