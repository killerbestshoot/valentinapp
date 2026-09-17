"use strict";

/**
 * Store rechaj minit yo.
 *
 * Li pa gen pwòp koneksyon ni pwòp rejis: li resevwa `_ledger` store Bazik la
 * (MENM fichye SQLite, MENM `wallets`, MENM `wallet_ledger`). Se sa ki fè yon
 * rechaj ak yon transfè MonCash debite yon sèl sòld, pa de kopi ki pa dakò.
 */

const fs = require("node:fs");
const path = require("node:path");

const { DomainError } = require("../errors");

const SCHEMA_PATH = path.join(__dirname, "schema.sql");

/** Kolòn konvèsyon deviz yo — ajoute sou yon baz ki te kreye anvan yo. */
const CONVERSION_COLUMNS = [
  ["send_amount_minor", "INTEGER NOT NULL DEFAULT 0"],
  ["send_currency", "TEXT NOT NULL DEFAULT ''"],
  ["conversion_rate", "REAL NOT NULL DEFAULT 1"],
  ["debit_minor", "INTEGER NOT NULL DEFAULT 0"],
  ["wallet_currency", "TEXT NOT NULL DEFAULT ''"],
  ["rates_updated_at", "INTEGER"],
];

function now() {
  return Date.now();
}

function mapTopup(row) {
  if (!row) return null;
  return {
    topupId: row.topup_id,
    status: row.status,
    gatewayId: row.gateway_id,
    gatewayStatus: row.gateway_status,
    operatorId: row.operator_id,
    operatorName: row.operator_name,
    countryCode: row.country_code,
    phone: row.phone,
    useLocalAmount: row.use_local_amount === 1,
    amountMinor: row.amount_minor,
    currency: row.currency,
    // Liy ki anvan konvèsyon yo: montan an, deviz la ak debi a te menm bagay.
    sendAmountMinor: row.send_amount_minor || row.amount_minor,
    sendCurrency: row.send_currency || row.currency,
    conversionRate: row.conversion_rate || 1,
    debitMinor: row.debit_minor || row.amount_minor,
    walletCurrency: row.wallet_currency || row.currency,
    ratesUpdatedAt: row.rates_updated_at,
    estimatedDeliveredMinor: row.estimated_delivered_minor,
    deliveredMinor: row.delivered_minor,
    deliveredCurrency: row.delivered_currency,
    discountMinor: row.discount_minor,
    discountCurrency: row.discount_currency,
    operatorTransactionId: row.operator_transaction_id,
    uid: row.uid,
    enterpriseId: row.enterprise_id,
    enterpriseName: row.enterprise_name,
    txId: row.tx_id,
    walletDebited: row.wallet_debited === 1,
    refunded: row.refunded === 1,
    failureReason: row.failure_reason,
    note: row.note,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    settledAt: row.settled_at,
  };
}

/**
 * @param {object} options
 * @param {{db: object, atomic: Function, debitSync: Function, creditSync: Function}} options.ledger
 *   `store._ledger` Bazik la.
 */
function createAirtimeStore({ ledger }) {
  if (!ledger || typeof ledger.atomic !== "function" || typeof ledger.debitSync !== "function") {
    throw new Error("createAirtimeStore mande `_ledger` store Bazik la.");
  }

  const { db, atomic } = ledger;
  db.exec(fs.readFileSync(SCHEMA_PATH, "utf8"));

  const existing = new Set(db.prepare("PRAGMA table_info(airtime_topups)").all().map((row) => row.name));
  for (const [name, definition] of CONVERSION_COLUMNS) {
    if (!existing.has(name)) db.exec(`ALTER TABLE airtime_topups ADD COLUMN ${name} ${definition}`);
  }

  function getSync(id) {
    return mapTopup(db.prepare("SELECT * FROM airtime_topups WHERE topup_id = ?").get(id));
  }

  /** Detay livrezon Reloadly a, si nou genyen yo. */
  function deliveryColumns(delivery = {}) {
    return {
      delivered_minor: delivery.deliveredMinor,
      delivered_currency: delivery.deliveredCurrency,
      discount_minor: delivery.discountMinor,
      discount_currency: delivery.discountCurrency,
      operator_transaction_id: delivery.operatorTransactionId,
    };
  }

  function patchSync(id, patch) {
    const columns = {
      status: patch.status,
      gateway_id: patch.gatewayId,
      gateway_status: patch.gatewayStatus,
      failure_reason: patch.failureReason,
      ...deliveryColumns(patch.delivery),
    };

    const sets = [];
    const values = [];
    for (const [column, value] of Object.entries(columns)) {
      // Yon chan vid pa efase yon valè nou te deja genyen (eg. `gateway_id`).
      if (value === undefined || value === "" || value === 0) continue;
      sets.push(`${column} = ?`);
      values.push(value);
    }

    sets.push("updated_at = ?");
    values.push(now(), id);

    db.prepare(`UPDATE airtime_topups SET ${sets.join(", ")} WHERE topup_id = ?`).run(...values);
  }

  return {
    async getTopup(id) {
      return getSync(id);
    },

    /**
     * ATOMIK. Ekri liy rechaj la EPI debite wallet la nan MENM tranzaksyon.
     * Si debi a echwe (sòld pa ase), ROLLBACK la retire liy lan tou.
     */
    async openTopup(record, move) {
      return atomic(() => {
        const existing = getSync(record.topupId);
        if (existing) return { duplicate: true, topup: existing };

        // Yon tranzaksyon = yon sèl livrezon, KIKÈLSWA moun ki klike. `topupId`
        // la gen uid moun k ap rele a ladan: si ajan an epi yon admin livre
        // menm tranzaksyon an, de ID diferan ta bay de rechaj. Tchèk la fèt
        // ANDAN tranzaksyon an pou de klik konkiran pa pase toude.
        if (record.txId) {
          const active = db
            .prepare(
              `SELECT * FROM airtime_topups
                WHERE tx_id = ? AND enterprise_id = ? AND status IN ('processing','completed')
                LIMIT 1`
            )
            .get(record.txId, record.enterpriseId);

          if (active) return { duplicate: true, topup: mapTopup(active) };
        }

        db.prepare(
          `INSERT INTO airtime_topups
            (topup_id, status, operator_id, operator_name, country_code, phone,
             use_local_amount, amount_minor, currency, send_amount_minor, send_currency,
             conversion_rate, debit_minor, wallet_currency, rates_updated_at,
             estimated_delivered_minor, delivered_currency, uid, enterprise_id,
             enterprise_name, tx_id, wallet_debited, note, created_by, created_at, updated_at)
           VALUES (?, 'processing', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)`
        ).run(
          record.topupId,
          record.operatorId,
          record.operatorName || "",
          record.countryCode || "HT",
          record.phone,
          record.useLocalAmount ? 1 : 0,
          record.amountMinor,
          record.currency,
          record.sendAmountMinor ?? record.amountMinor,
          record.sendCurrency || record.currency,
          record.conversionRate ?? 1,
          record.debitMinor ?? record.amountMinor,
          record.walletCurrency || record.currency,
          record.ratesUpdatedAt ?? null,
          record.estimatedDeliveredMinor || 0,
          record.deliveredCurrency || "",
          record.uid,
          record.enterpriseId,
          record.enterpriseName || "",
          record.txId || "",
          record.note || "",
          record.createdBy || "",
          now(),
          now()
        );

        ledger.debitSync(move);

        return { duplicate: false, topup: getSync(record.topupId) };
      });
    },

    async updateTopup(id, patch) {
      patchSync(id, patch);
      return getSync(id);
    },

    /**
     * ATOMIK. Fèmen yon rechaj:
     *  - `completed` => make l, epi pase tranzaksyon lye a `delivered`
     *  - `failed`    => make l, RANBOUSE wallet la, pase tranzaksyon an `failed`
     * Yon dezyèm apèl sou yon rechaj ki deja fèmen pa fè anyen.
     */
    async settleTopup({ topupId, status, gatewayId = "", gatewayStatus = "", failureReason = "", delivery }) {
      if (status !== "completed" && status !== "failed") {
        throw new DomainError("invalid_status", `Estati final pa valid: ${status}`);
      }

      return atomic(() => {
        const topup = getSync(topupId);
        if (!topup) throw new DomainError("airtime_topup_not_found", `Rechaj ${topupId} pa egziste.`);

        if (topup.status === "completed" || topup.status === "failed") {
          return { duplicate: true, topup, refund: null };
        }

        let refund = null;
        if (status === "failed" && topup.walletDebited && !topup.refunded) {
          refund = ledger.creditSync({
            uid: topup.uid,
            enterpriseId: topup.enterpriseId,
            enterpriseName: topup.enterpriseName,
            // EGZAKTEMAN sa nou te debite, nan deviz WALLET la.
            amountMinor: topup.debitMinor,
            currency: topup.walletCurrency,
            type: "airtime_refund",
            note: `Ranbousman otomatik minit: ${failureReason || "rechaj echwe"}`,
            sourceCollection: "airtime_topups",
            sourceId: topup.topupId,
            txId: topup.txId,
            serviceName: "minit_ht",
            createdBy: "reloadly",
            createdByRole: "system",
            idempotencyKey: `airtime_refund:${topup.topupId}`,
          });
        }

        patchSync(topupId, { status, gatewayId, gatewayStatus: gatewayStatus || status, failureReason, delivery });

        db.prepare(
          "UPDATE airtime_topups SET refunded = ?, settled_at = ?, updated_at = ? WHERE topup_id = ?"
        ).run(topup.refunded || refund !== null ? 1 : 0, now(), now(), topupId);

        if (topup.txId) {
          // Filt `enterprise_id` OBLIGATWA, menm rezon ak `settleTransfer`.
          db.prepare(
            "UPDATE transactions SET status = ?, gateway_ref = ?, updated_at = ? WHERE tx_id = ? AND enterprise_id = ?"
          ).run(
            status === "completed" ? "delivered" : "failed",
            topup.topupId,
            now(),
            topup.txId,
            topup.enterpriseId
          );
        }

        return { duplicate: false, topup: getSync(topupId), refund };
      });
    },

    async listPendingTopups(limit = 50) {
      return db
        .prepare("SELECT * FROM airtime_topups WHERE status = 'processing' ORDER BY created_at ASC LIMIT ?")
        .all(limit)
        .map(mapTopup);
    },

    async listTopups({ enterpriseId, limit = 25 }) {
      return db
        .prepare("SELECT * FROM airtime_topups WHERE enterprise_id = ? ORDER BY created_at DESC LIMIT ?")
        .all(enterpriseId, limit)
        .map(mapTopup);
    },
  };
}

module.exports = { createAirtimeStore, SCHEMA_PATH };
