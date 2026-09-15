"use strict";

/**
 * Store SQLite — devlopman ak tès.
 *
 * `node:sqlite` se yon modil entegre (Node >= 22), donk zewo depandans.
 * API a sinkwòn: nou sèvi ak BEGIN IMMEDIATE pou operasyon konpoze yo,
 * epi nou ekspoze metòd yo kòm `async` pou yo ka echanje ak Firestore.
 */

const fs = require("node:fs");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const { DomainError } = require("../errors");
const AppIds = require("../ids");

const SCHEMA_PATH = path.join(__dirname, "schema.sql");

/** Menm fòma ak `BalanceService.staffDocId` nan Dart la. */
function walletId(enterpriseId, uid) {
  return `${enterpriseId}_${uid}`;
}

function now() {
  return Date.now();
}

function bool(value) {
  return value ? 1 : 0;
}

// --- Mapping snake_case (DB) -> camelCase (domèn) ---

function mapWallet(row) {
  if (!row) return null;
  return {
    id: row.id,
    uid: row.uid,
    enterpriseId: row.enterprise_id,
    enterpriseName: row.enterprise_name,
    role: row.role,
    currency: row.currency,
    balanceMinor: row.balance_minor,
    updatedAt: row.updated_at,
  };
}

function mapTopup(row) {
  if (!row) return null;
  return {
    requestId: row.request_id,
    type: row.type,
    status: row.status,
    processed: row.processed === 1,
    gateway: row.gateway,
    network: row.network,
    gatewayOrderId: row.gateway_order_id,
    gatewayId: row.gateway_id,
    gatewayStatus: row.gateway_status,
    paymentUrl: row.payment_url,
    amountMinor: row.amount_minor,
    currency: row.currency,
    amountHtgMinor: row.amount_htg_minor,
    rateToHtg: row.rate_to_htg,
    targetUid: row.target_uid,
    targetEmail: row.target_email,
    targetName: row.target_name,
    targetRole: row.target_role,
    enterpriseId: row.enterprise_id,
    enterpriseName: row.enterprise_name,
    phone: row.phone,
    requestedBy: row.requested_by,
    requestedByName: row.requested_by_name,
    requestedByRole: row.requested_by_role,
    note: row.note,
    failureReason: row.failure_reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    creditedAt: row.credited_at,
  };
}

function mapTransfer(row) {
  if (!row) return null;
  return {
    transferId: row.transfer_id,
    reference: row.reference,
    kind: row.kind,
    network: row.network,
    status: row.status,
    gatewayId: row.gateway_id,
    gatewayStatus: row.gateway_status,
    amountMinor: row.amount_minor,
    currency: row.currency,
    amountHtgMinor: row.amount_htg_minor,
    feeHtgMinor: row.fee_htg_minor,
    totalHtgMinor: row.total_htg_minor,
    debitMinor: row.debit_minor,
    rateToHtg: row.rate_to_htg,
    uid: row.uid,
    enterpriseId: row.enterprise_id,
    enterpriseName: row.enterprise_name,
    phone: row.phone,
    receiverName: row.receiver_name,
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

function mapTransaction(row) {
  if (!row) return null;
  return {
    txId: row.tx_id,
    enterpriseId: row.enterprise_id,
    staffUid: row.staff_uid,
    clientName: row.client_name,
    phone: row.phone,
    service: row.service,
    amountMinor: row.amount_minor,
    currency: row.currency,
    status: row.status,
    gatewayRef: row.gateway_ref,
    commissionApplied: row.commission_applied === 1,
  };
}

function createSqliteStore({ file = ":memory:", seedRates = true } = {}) {
  if (file !== ":memory:") {
    fs.mkdirSync(path.dirname(file), { recursive: true });
  }

  const db = new DatabaseSync(file);
  db.exec(fs.readFileSync(SCHEMA_PATH, "utf8"));

  if (seedRates) {
    // Menm valè ak `lib/services/rates/seed_exchange_rates.dart`.
    const rates = { HTG: 1, USD: 132, MXN: 7.25, DOP: 2.25, CLP: 0.14, BRL: 24 };
    const stmt = db.prepare(
      "INSERT INTO exchange_rates (currency, rate_to_htg, updated_at) VALUES (?, ?, ?) " +
        "ON CONFLICT(currency) DO NOTHING"
    );
    for (const [currency, rate] of Object.entries(rates)) stmt.run(currency, rate, now());
  }

  /** Operasyon konpoze: swa tout pase, swa anyen pa pase. `fn` dwe sinkwòn. */
  function tx(fn) {
    db.exec("BEGIN IMMEDIATE");
    try {
      const result = fn();
      db.exec("COMMIT");
      return result;
    } catch (err) {
      db.exec("ROLLBACK");
      throw err;
    }
  }

  function ensureWalletSync({ uid, enterpriseId, enterpriseName = "", role = "agent", currency = "USD" }) {
    const id = walletId(enterpriseId, uid);
    db.prepare(
      `INSERT INTO wallets (id, uid, enterprise_id, enterprise_name, role, currency, balance_minor, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)
       ON CONFLICT(id) DO NOTHING`
    ).run(id, uid, enterpriseId, enterpriseName, role, currency, now(), now());

    return mapWallet(db.prepare("SELECT * FROM wallets WHERE id = ?").get(id));
  }

  function moveSync(direction, move) {
    const {
      uid,
      enterpriseId,
      enterpriseName = "",
      role = "agent",
      amountMinor,
      currency = "USD",
      type,
      note = "",
      sourceCollection = "bazik",
      sourceId = "",
      txId = "",
      serviceName = "",
      status = "posted",
      createdBy = "system",
      createdByRole = "system",
      idempotencyKey = null,
    } = move;

    if (!Number.isInteger(amountMinor) || amountMinor <= 0) {
      throw new DomainError("invalid_amount", "amountMinor dwe yon antye pozitif.");
    }

    if (idempotencyKey) {
      const existing = db
        .prepare("SELECT * FROM wallet_ledger WHERE idempotency_key = ?")
        .get(idempotencyKey);
      if (existing) {
        return {
          duplicate: true,
          ledgerId: existing.ledger_id,
          beforeMinor: existing.before_minor,
          afterMinor: existing.after_minor,
        };
      }
    }

    const wallet = ensureWalletSync({ uid, enterpriseId, enterpriseName, role, currency });
    const before = wallet.balanceMinor;
    const after = direction === "credit" ? before + amountMinor : before - amountMinor;

    if (direction === "debit" && after < 0) {
      throw new DomainError(
        "insufficient_funds",
        `Sòld la pa ase: ${before / 100} ${currency} disponib, ${amountMinor / 100} mande.`
      );
    }

    db.prepare("UPDATE wallets SET balance_minor = ?, updated_at = ? WHERE id = ?").run(
      after,
      now(),
      wallet.id
    );

    const ledgerId = AppIds.ledger(`${direction}:${enterpriseId}:${uid}:${type}:${idempotencyKey || now()}`);

    db.prepare(
      `INSERT INTO wallet_ledger
        (ledger_id, idempotency_key, type, direction, uid, role, enterprise_id, enterprise_name,
         amount_minor, currency, before_minor, after_minor, source_collection, source_id, tx_id,
         service_name, status, note, created_by, created_by_role, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      ledgerId, idempotencyKey, type, direction, uid, role, enterpriseId, enterpriseName,
      amountMinor, currency, before, after, sourceCollection, sourceId, txId,
      serviceName, status, note, createdBy, createdByRole, now()
    );

    return { duplicate: false, ledgerId, beforeMinor: before, afterMinor: after };
  }

  function getTopupSync(id) {
    return mapTopup(db.prepare("SELECT * FROM wallet_topup_requests WHERE request_id = ?").get(id));
  }

  function insertTransferSync(record) {
      db.prepare(
      `INSERT INTO bazik_transfers
        (transfer_id, reference, kind, network, status, gateway_id, gateway_status,
         amount_minor, currency, amount_htg_minor, fee_htg_minor, total_htg_minor,
         debit_minor, rate_to_htg, uid, enterprise_id, enterprise_name, phone,
         receiver_name, tx_id, wallet_debited, refunded, failure_reason, note,
         created_by, created_at, updated_at, settled_at)
       VALUES (?, ?, ?, ?, ?, '', '', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, '', ?, ?, ?, ?, NULL)`
    ).run(
      record.transferId, record.reference, record.kind, record.network,
      record.status || "pending", record.amountMinor, record.currency,
      record.amountHtgMinor, record.feeHtgMinor || 0, record.totalHtgMinor || 0,
      record.debitMinor || 0, record.rateToHtg, record.uid || "", record.enterpriseId || "",
      record.enterpriseName || "", record.phone || "", record.receiverName || "",
      record.txId || "", bool(record.walletDebited), record.note || "",
      record.createdBy || "", now(), now()
    );

  }

  function getTransferSync(id) {
    return mapTransfer(db.prepare("SELECT * FROM bazik_transfers WHERE transfer_id = ?").get(id));
  }

  return {
    _db: db,

    async close() {
      db.close();
    },

    async getRateToHtg(currency) {
      const code = String(currency || "").toUpperCase().trim();
      if (code === "HTG") return 1;

      const row = db.prepare("SELECT rate_to_htg FROM exchange_rates WHERE currency = ?").get(code);
      const rate = Number(row?.rate_to_htg || 0);
      if (rate <= 0) {
        throw new DomainError("missing_rate", `Pa gen exchange rate pou ${code} -> HTG.`);
      }
      return rate;
    },

    async setRate(currency, rateToHtg) {
      db.prepare(
        `INSERT INTO exchange_rates (currency, rate_to_htg, updated_at) VALUES (?, ?, ?)
         ON CONFLICT(currency) DO UPDATE SET rate_to_htg = excluded.rate_to_htg, updated_at = excluded.updated_at`
      ).run(String(currency).toUpperCase(), Number(rateToHtg), now());
    },

    async ensureWallet(args) {
      return tx(() => ensureWalletSync(args));
    },

    async getWallet({ uid, enterpriseId }) {
      return mapWallet(
        db.prepare("SELECT * FROM wallets WHERE id = ?").get(walletId(enterpriseId, uid))
      );
    },

    async creditWallet(move) {
      return tx(() => moveSync("credit", move));
    },

    async debitWallet(move) {
      return tx(() => moveSync("debit", move));
    },

    async listLedger({ uid, enterpriseId, limit = 50 }) {
      return db
        .prepare(
          "SELECT * FROM wallet_ledger WHERE enterprise_id = ? AND uid = ? ORDER BY created_at DESC LIMIT ?"
        )
        .all(enterpriseId, uid, limit);
    },

    // ---------------- Topup (cash-in) ----------------

    async createTopup(record) {
      db.prepare(
        `INSERT INTO wallet_topup_requests
          (request_id, type, status, processed, gateway, network, gateway_order_id, gateway_id,
           gateway_status, payment_url, amount_minor, currency, amount_htg_minor, rate_to_htg,
           target_uid, target_email, target_name, target_role, enterprise_id, enterprise_name,
           phone, requested_by, requested_by_name, requested_by_role, note, failure_reason,
           created_at, updated_at, credited_at)
         VALUES (?, ?, ?, 0, ?, ?, ?, '', 'pending', '', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', ?, ?, NULL)`
      ).run(
        record.requestId, record.type || "wallet_topup", record.status || "pending",
        record.gateway || "bazik", record.network || "moncash", record.gatewayOrderId || record.requestId,
        record.amountMinor, record.currency, record.amountHtgMinor, record.rateToHtg,
        record.targetUid, record.targetEmail || "", record.targetName || "", record.targetRole || "agent",
        record.enterpriseId, record.enterpriseName || "", record.phone || "",
        record.requestedBy || "", record.requestedByName || "", record.requestedByRole || "",
        record.note || "", now(), now()
      );

      return getTopupSync(record.requestId);
    },

    async getTopup(id) {
      return getTopupSync(id);
    },

    async findTopupByReference(reference) {
      return mapTopup(
        db.prepare("SELECT * FROM wallet_topup_requests WHERE gateway_order_id = ?").get(reference)
      );
    },

    async updateTopup(id, patch) {
      const columns = {
        status: "status",
        processed: "processed",
        gatewayId: "gateway_id",
        gatewayStatus: "gateway_status",
        paymentUrl: "payment_url",
        failureReason: "failure_reason",
        note: "note",
      };

      const sets = [];
      const values = [];
      for (const [key, column] of Object.entries(columns)) {
        if (patch[key] !== undefined) {
          sets.push(`${column} = ?`);
          values.push(typeof patch[key] === "boolean" ? bool(patch[key]) : patch[key]);
        }
      }
      sets.push("updated_at = ?");
      values.push(now(), id);

      db.prepare(`UPDATE wallet_topup_requests SET ${sets.join(", ")} WHERE request_id = ?`).run(...values);
      return getTopupSync(id);
    },

    /**
     * ATOMIK. Fèmen yon topup:
     *  - `completed` => kredite wallet la (yon sèl fwa, gras ak idempotencyKey)
     *  - lòt estati   => make sa san touche lajan
     */
    async settleTopup({ topupId, status, gatewayId = "", gatewayStatus = "", failureReason = "" }) {
      return tx(() => {
        const topup = getTopupSync(topupId);
        if (!topup) throw new DomainError("topup_not_found", `Topup ${topupId} pa egziste.`);

        if (topup.processed) {
          return { duplicate: true, topup, credit: null };
        }

        let credit = null;

        if (status === "completed") {
          credit = moveSync("credit", {
            uid: topup.targetUid,
            enterpriseId: topup.enterpriseId,
            enterpriseName: topup.enterpriseName,
            role: topup.targetRole,
            amountMinor: topup.amountMinor,
            currency: topup.currency,
            type: `wallet_topup_${topup.network}`,
            note: topup.note || `Topup ${topup.network} via Bazik`,
            sourceCollection: "wallet_topup_requests",
            sourceId: topup.requestId,
            serviceName: topup.network,
            createdBy: "bazik",
            createdByRole: "system",
            idempotencyKey: `topup:${topup.requestId}`,
          });
        }

        db.prepare(
          `UPDATE wallet_topup_requests
             SET status = ?, processed = 1, gateway_id = ?, gateway_status = ?,
                 failure_reason = ?, updated_at = ?, credited_at = ?
           WHERE request_id = ?`
        ).run(
          status === "completed" ? "approved" : status,
          gatewayId || topup.gatewayId,
          gatewayStatus || status,
          failureReason,
          now(),
          status === "completed" ? now() : null,
          topupId
        );

        return { duplicate: false, topup: getTopupSync(topupId), credit };
      });
    },

    // ---------------- Transfè (cash-out / livrezon) ----------------

    async createTransfer(record) {
      insertTransferSync(record);
      return getTransferSync(record.transferId);
    },

    /**
     * ATOMIK. Louvri yon transfè: ekri liy lan EPI debite wallet la nan MENM
     * tranzaksyon, ak `wallet_debited = 1` depi okòmansman.
     *
     * Anvan, se te 3 ekriti separe (kreye → debite → make `walletDebited`).
     * Yon kras ant debi a ak make a te kite wallet la debite ak
     * `walletDebited = 0` — epi `settleTransfer` refize ranbouse sou flag sa a.
     * Kòb ajan an te disparèt san tras.
     *
     * Si debi a echwe (sòld pa ase), ROLLBACK la retire liy lan tou: pa gen
     * transfè `pending` òfelen.
     */
    async openTransfer(record, move) {
      return tx(() => {
        const existing = getTransferSync(record.transferId);
        if (existing) return { duplicate: true, transfer: existing };

        insertTransferSync({ ...record, walletDebited: true, status: "processing" });
        moveSync("debit", move);

        return { duplicate: false, transfer: getTransferSync(record.transferId) };
      });
    },

    async getTransfer(id) {
      return getTransferSync(id);
    },

    async findTransferByReference(reference) {
      return mapTransfer(db.prepare("SELECT * FROM bazik_transfers WHERE reference = ?").get(reference));
    },

    async updateTransfer(id, patch) {
      const columns = {
        status: "status",
        gatewayId: "gateway_id",
        gatewayStatus: "gateway_status",
        failureReason: "failure_reason",
        walletDebited: "wallet_debited",
        refunded: "refunded",
      };

      const sets = [];
      const values = [];
      for (const [key, column] of Object.entries(columns)) {
        if (patch[key] !== undefined) {
          sets.push(`${column} = ?`);
          values.push(typeof patch[key] === "boolean" ? bool(patch[key]) : patch[key]);
        }
      }
      sets.push("updated_at = ?");
      values.push(now(), id);

      db.prepare(`UPDATE bazik_transfers SET ${sets.join(", ")} WHERE transfer_id = ?`).run(...values);
      return getTransferSync(id);
    },

    /**
     * ATOMIK. Fèmen yon transfè:
     *  - `completed` => make l, epi si li lye ak yon tranzaksyon, pase l 'delivered'
     *  - `failed`    => make l, epi RANBOUSE wallet la si nou te deja debite l
     */
    async settleTransfer({ transferId, status, gatewayId = "", gatewayStatus = "", failureReason = "" }) {
      return tx(() => {
        const transfer = getTransferSync(transferId);
        if (!transfer) throw new DomainError("transfer_not_found", `Transfè ${transferId} pa egziste.`);

        const alreadyFinal = transfer.status === "completed" || transfer.status === "failed";
        if (alreadyFinal) {
          return { duplicate: true, transfer, refund: null };
        }

        let refund = null;

        if (status === "failed" && transfer.walletDebited && !transfer.refunded) {
          refund = moveSync("credit", {
            uid: transfer.uid,
            enterpriseId: transfer.enterpriseId,
            enterpriseName: transfer.enterpriseName,
            // Nou ranbouse EGZAKTEMAN sa nou te debite (montan + frè), pa sèlman
            // montan an — sinon ajan an ap pèdi frè a sou yon transfè ki echwe.
            amountMinor: transfer.debitMinor || transfer.amountMinor,
            currency: transfer.currency,
            type: `${transfer.kind}_refund`,
            note: `Ranbousman otomatik: ${failureReason || "transf echwe"}`,
            sourceCollection: "bazik_transfers",
            sourceId: transfer.transferId,
            txId: transfer.txId,
            serviceName: transfer.network,
            createdBy: "bazik",
            createdByRole: "system",
            idempotencyKey: `refund:${transfer.transferId}`,
          });
        }

        db.prepare(
          `UPDATE bazik_transfers
             SET status = ?, gateway_id = ?, gateway_status = ?, failure_reason = ?,
                 refunded = ?, updated_at = ?, settled_at = ?
           WHERE transfer_id = ?`
        ).run(
          status,
          gatewayId || transfer.gatewayId,
          gatewayStatus || status,
          failureReason,
          bool(transfer.refunded || refund !== null),
          now(),
          now(),
          transferId
        );

        if (transfer.txId) {
          const txStatus = status === "completed" ? "delivered" : "failed";
          // Filt `enterprise_id` OBLIGATWA: san li, yon transfè ki pote `txId`
          // yon lòt antrepriz te ka chanje estati tranzaksyon sa a.
          db.prepare(
            "UPDATE transactions SET status = ?, updated_at = ? WHERE tx_id = ? AND enterprise_id = ?"
          ).run(txStatus, now(), transfer.txId, transfer.enterpriseId);
        }

        return { duplicate: false, transfer: getTransferSync(transferId), refund };
      });
    },

    async listPendingTransfers(limit = 50) {
      return db
        .prepare(
          "SELECT * FROM bazik_transfers WHERE status IN ('pending','processing') ORDER BY created_at ASC LIMIT ?"
        )
        .all(limit)
        .map(mapTransfer);
    },

    // ---------------- Evènman webhook ----------------

    /** Retounen `false` si evènman an te deja anrejistre (rejwe). */
    async recordEvent({ eventId, type = "", reference = "", status = "", payload = {} }) {
      const result = db
        .prepare(
          `INSERT INTO bazik_events (event_id, type, reference, status, payload, received_at)
           VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(event_id) DO NOTHING`
        )
        .run(eventId, type, reference, status, JSON.stringify(payload), now());

      return result.changes === 1;
    },

    async markEventProcessed(eventId, result) {
      db.prepare(
        "UPDATE bazik_events SET processed = 1, processed_at = ?, result = ? WHERE event_id = ?"
      ).run(now(), JSON.stringify(result || {}), eventId);
    },

    async getEvent(eventId) {
      return db.prepare("SELECT * FROM bazik_events WHERE event_id = ?").get(eventId) || null;
    },

    // ---------------- Tranzaksyon app la ----------------

    async createTransaction(record) {
      db.prepare(
        `INSERT INTO transactions
          (tx_id, enterprise_id, staff_uid, client_name, phone, service, amount_minor, currency,
           status, gateway_ref, commission_applied, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '', 0, ?, ?)`
      ).run(
        record.txId, record.enterpriseId || "", record.staffUid || "", record.clientName || "",
        record.phone || "", record.service || "", record.amountMinor || 0, record.currency || "USD",
        record.status || "pending", now(), now()
      );
      return mapTransaction(db.prepare("SELECT * FROM transactions WHERE tx_id = ?").get(record.txId));
    },

    async getTransaction(txId) {
      return mapTransaction(db.prepare("SELECT * FROM transactions WHERE tx_id = ?").get(txId));
    },

    async updateTransaction(txId, patch) {
      const columns = { status: "status", gatewayRef: "gateway_ref" };
      const sets = [];
      const values = [];
      for (const [key, column] of Object.entries(columns)) {
        if (patch[key] !== undefined) {
          sets.push(`${column} = ?`);
          values.push(patch[key]);
        }
      }
      sets.push("updated_at = ?");
      values.push(now(), txId);

      db.prepare(`UPDATE transactions SET ${sets.join(", ")} WHERE tx_id = ?`).run(...values);
      return this.getTransaction(txId);
    },
  };
}

module.exports = { createSqliteStore, walletId };
