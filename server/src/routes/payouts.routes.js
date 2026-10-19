"use strict";

/**
 * Payout — peye yon staff sòld li sou MonCash/NatCash.
 *
 *   GET  /api/payouts                lis (ajan: pa li sèlman)
 *   POST /api/payouts                mande yon payout
 *   POST /api/payouts/:id/approve    owner/admin — voye lajan an via Bazik
 *   POST /api/payouts/:id/reject     owner/admin
 *
 * PRENSIP: demann lan PA debite anyen. Se apwobasyon an ki rele motè transfè
 * a (`transfers.send`), ki debite wallet la ak voye lajan an ann atomik, ak
 * tout pwoteksyon li deja genyen (deviz wallet, idempotans, echèk ambigi).
 *
 * Kle idempotans lan se `payout:{requestId}`: de klik sou "Apwouve" pa ka peye
 * menm demann lan de fwa.
 *
 * PAYOUT BANK (`network = 'bank'`): Bazik pa ka fè virement bancaire. Apwobasyon
 * an debite wallet la (menm kle idempotans), epi admin nan fè virement an li
 * menm APRE — konsa si sòld la pa ase, okenn kòb poko pati.
 */

const express = require("express");

const { getDb, now } = require("../db/db");
const { getBazikService } = require("../bazik_service");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money, DomainError, BazikError } = require("../../../bazik/index.js");
const AppIds = require("../../../bazik/src/ids");
const { commissionUid } = require("../../../bazik/src/commission_wallet");

const router = express.Router();

function send(res, err) {
  const status =
    err.status ||
    (err instanceof DomainError ? 400 : err instanceof BazikError ? 502 : err instanceof Error ? 500 : 400);
  if (status >= 500) console.error("[payouts]", err);
  return res.status(status).json({ ok: false, code: err.code || "error", message: err.message });
}

function toJson(row) {
  return {
    requestId: row.request_id,
    staffUid: row.staff_uid.endsWith("#commission") ? row.staff_uid.slice(0, -"#commission".length) : row.staff_uid,
    wallet: row.staff_uid.endsWith("#commission") ? "commission" : "main",
    staffName: row.staff_name,
    amount: money.fromMinor(row.amount_minor),
    currency: row.currency,
    network: row.network,
    phone: row.phone,
    bankName: row.bank_name || "",
    bankAccountName: row.bank_account_name || "",
    bankAccountNumber: row.bank_account_number || "",
    receiverName: row.receiver_name,
    note: row.note,
    status: row.status,
    transferId: row.transfer_id,
    failureReason: row.failure_reason,
    createdAt: row.created_at,
    decidedAt: row.decided_at,
  };
}

router.get("/", requireAuth, requireEnterprise, (req, res) => {
  try {
    const filters = ["enterprise_id = ?"];
    const params = [req.user.enterpriseId];

    if (req.user.role === "agent" || req.user.role === "client") {
      filters.push("(staff_uid = ? OR staff_uid = ?)");
      params.push(req.user.uid, commissionUid(req.user.uid));
    } else if (req.user.role === "owner") {
      filters.push("(staff_uid = ? OR staff_uid = ?)");
      params.push(req.user.uid, commissionUid(req.user.uid));
    }

    const status = String(req.query.status || "").trim();
    if (status) {
      filters.push("status = ?");
      params.push(status);
    }

    const rows = getDb()
      .prepare(
        `SELECT * FROM payout_requests WHERE ${filters.join(" AND ")}
          ORDER BY created_at DESC LIMIT 100`
      )
      .all(...params);

    return res.json({ ok: true, payouts: rows.map(toJson) });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const body = req.body || {};
    const network = ["natcash", "bank"].includes(body.network) ? body.network : "moncash";

    let amountMinor;
    try {
      amountMinor = money.toMinor(body.amount);
    } catch (err) {
      return send(res, { code: "invalid_amount", message: err.message });
    }

    const phone = network === "bank" ? "" : String(body.phone || "").trim();
    if (network !== "bank" && !phone) {
      return send(res, { code: "missing_phone", message: "Nimewo MonCash/NatCash la obligatwa." });
    }

    if (body.wallet === "commission" && !["agent", "owner"].includes(req.user.role)) {
      return send(res, { code: "invalid_wallet", message: "Wallet komisyon sa a pa disponib pou wòl ou." });
    }

    if (body.wallet === "commission" && !["agent", "owner"].includes(req.user.role)) {
      return send(res, { code: "invalid_wallet", message: "Wallet komisyon sa a pa disponib pou wòl ou." });
    }

    const bank = { name: "", accountName: "", accountNumber: "" };
    if (network === "bank") {
      bank.name = String(body.bankName || "").trim().slice(0, 80);
      bank.accountName = String(body.bankAccountName || "").trim().slice(0, 120);
      bank.accountNumber = String(body.bankAccountNumber || "").trim().slice(0, 60);
      if (!bank.name || !bank.accountName || !bank.accountNumber) {
        return send(res, {
          code: "missing_bank_details",
          message: "Non bank lan, non sou kont lan ak nimewo kont lan obligatwa.",
        });
      }
    }

    // Deviz la se sa wallet la — pa sa kliyan an voye (menm leson ak vòl pa deviz la).
    const requestedCommission = body.wallet === "commission";
    const sourceUid = requestedCommission ? commissionUid(req.user.uid) : req.user.uid;
    const wallet = await getBazikService().store.getWallet({
      uid: sourceUid,
      enterpriseId: req.user.enterpriseId,
    });

    if (!wallet) return send(res, { code: "wallet_not_found", message: "Ou pa gen wallet." });

    // Nou verifye sòld la tou swit pou yon mesaj klè, men se apwobasyon an ki
    // debite: sòld la ka chanje ant de moman yo.
    if (wallet.balanceMinor < amountMinor) {
      return send(res, {
        code: "insufficient_funds",
        message: `Sòld ${requestedCommission ? "komisyon" : "prensipal"} ou (${money.fromMinor(wallet.balanceMinor)} ${wallet.currency}) pa ase.`,
      });
    }

    const requestId = AppIds.payoutRequest(`${req.user.enterpriseId}:${req.user.uid}:${Date.now()}`);

    getDb()
      .prepare(
        `INSERT INTO payout_requests
          (request_id, enterprise_id, staff_uid, staff_name, amount_minor, currency, network,
           phone, receiver_name, note, bank_name, bank_account_name, bank_account_number,
           status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`
      )
      .run(
        requestId, req.user.enterpriseId, sourceUid, req.user.displayName, amountMinor,
        wallet.currency, network, phone,
        network === "bank" ? bank.accountName : String(body.receiverName || req.user.displayName || ""),
        String(body.note || ""), bank.name, bank.accountName, bank.accountNumber, now(), now()
      );

    const row = getDb().prepare("SELECT * FROM payout_requests WHERE request_id = ?").get(requestId);
    return res.json({ ok: true, payout: toJson(row) });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/:id/approve", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  const db = getDb();

  try {
    const row = db
      .prepare("SELECT * FROM payout_requests WHERE request_id = ? AND enterprise_id = ?")
      .get(req.params.id, req.user.enterpriseId);

    if (!row) return res.status(404).json({ ok: false, code: "not_found" });

    if (row.status !== "pending") {
      return send(res, { code: "already_processed", message: `Demann sa a deja ${row.status}.` });
    }

    // Yon moun pa apwouve pwòp payout li.
    if (row.staff_uid === req.user.uid) {
      return send(res, {
        status: 403,
        code: "cannot_approve_self",
        message: "Ou pa ka apwouve pwòp demann payout ou.",
      });
    }

    // Rezève demann lan AVAN nou voye lajan: si de admin klike ansanm, sèl
    // youn pase kondisyon `status = 'pending'` la.
    const claimed = db
      .prepare(
        `UPDATE payout_requests SET status = 'verifying', decided_by = ?, updated_at = ?
          WHERE request_id = ? AND status = 'pending'`
      )
      .run(req.user.uid, now(), row.request_id);

    if (claimed.changes === 0) {
      return send(res, { code: "already_processed", message: "Yon lòt moun deja trete demann sa a." });
    }

    if (row.network === "bank") {
      try {
        await getBazikService().store.debitWallet({
          uid: row.staff_uid,
          enterpriseId: row.enterprise_id,
          enterpriseName: req.user.enterpriseName,
          amountMinor: row.amount_minor,
          currency: row.currency,
          type: "payout_bank",
          note: `Payout bank: ${row.bank_name} · ${row.bank_account_number}`,
          sourceCollection: "payout_requests",
          sourceId: row.request_id,
          serviceName: "bank",
          createdBy: req.user.uid,
          createdByRole: req.user.role,
          idempotencyKey: `payout:${row.request_id}`,
        });
      } catch (err) {
        // Debi a atomik: si l echwe, anyen pa t debite e okenn kòb pa t pati.
        db.prepare(
          `UPDATE payout_requests SET status = 'failed', failure_reason = ?, decided_at = ?, updated_at = ?
            WHERE request_id = ?`
        ).run(`${err.code || "error"}: ${err.message}`, now(), now(), row.request_id);
        throw err;
      }

      db.prepare(
        `UPDATE payout_requests SET status = 'approved', transfer_id = ?, decided_at = ?, updated_at = ?
          WHERE request_id = ?`
      ).run(String(req.body?.reference || "").trim().slice(0, 80), now(), now(), row.request_id);

      const updated = db.prepare("SELECT * FROM payout_requests WHERE request_id = ?").get(row.request_id);
      return res.json({ ok: true, payout: toJson(updated) });
    }

    try {
      const result = await getBazikService().transfers.send({
        kind: "payout",
        network: row.network,
        amountMinor: row.amount_minor,
        currency: row.currency,
        uid: row.staff_uid,
        enterpriseId: row.enterprise_id,
        enterpriseName: req.user.enterpriseName,
        phone: row.phone,
        receiverName: row.receiver_name,
        note: row.note || "Payout",
        createdBy: req.user.uid,
        idempotencySeed: `payout:${row.request_id}`,
        bypassLock: String(row.staff_uid).endsWith("#commission"),
      });

      const transfer = result.transfer;
      const final = transfer.status === "failed" ? "failed" : "approved";

      db.prepare(
        `UPDATE payout_requests SET status = ?, transfer_id = ?, decided_at = ?,
           failure_reason = ?, updated_at = ? WHERE request_id = ?`
      ).run(final, transfer.transferId, now(), transfer.failureReason || "", now(), row.request_id);
    } catch (err) {
      // Echèk ambigi: lajan an ka te pati. Demann lan rete `verifying`, jamè
      // `pending` — sinon yon lòt klik ta ka peye l yon dezyèm fwa.
      const verifying = err.code === "transfer_pending_verification";

      db.prepare(
        `UPDATE payout_requests SET status = ?, failure_reason = ?, decided_at = ?, updated_at = ?
          WHERE request_id = ?`
      ).run(verifying ? "verifying" : "failed", `${err.code}: ${err.message}`, now(), now(), row.request_id);

      throw err;
    }

    const updated = db.prepare("SELECT * FROM payout_requests WHERE request_id = ?").get(row.request_id);
    return res.json({ ok: true, payout: toJson(updated) });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/:id/reject", requireAuth, requireEnterprise, requireRole("owner", "admin"), (req, res) => {
  try {
    const result = getDb()
      .prepare(
        `UPDATE payout_requests SET status = 'rejected', decided_by = ?, decided_at = ?,
           failure_reason = ?, updated_at = ?
         WHERE request_id = ? AND enterprise_id = ? AND status = 'pending'`
      )
      .run(req.user.uid, now(), String(req.body?.note || ""), now(), req.params.id, req.user.enterpriseId);

    if (result.changes === 0) {
      return send(res, { code: "not_found_or_processed", message: "Demann lan pa egziste oswa li deja trete." });
    }

    return res.json({ ok: true });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = router;
