"use strict";

/**
 * Wout Minit Haiti (Reloadly Airtime).
 *
 *   GET  /api/airtime/status               mòd, kont Reloadly la
 *   GET  /api/airtime/operators/detect     operatè yon nimewo (?phone=)
 *   POST /api/airtime/quote                devi: { phone, amount, currency?, operatorId? }
 *   POST /api/airtime/topups               livre yon tranzaksyon Minit: { txId, operatorId? }
 *   GET  /api/airtime/topups               owner/admin: rekonsilye ak dashboard Reloadly
 *   GET  /api/airtime/topups/:id
 *   POST /api/airtime/topups/:id/refresh   mande Reloadly kote l ye
 *   POST /api/airtime/topups/poll          owner/admin: tout sa ki an verifikasyon
 */

const express = require("express");

const { getAirtimeService } = require("../airtime_service");
const { getDb, now } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money, DomainError } = require("../../../bazik/index.js");
const { ReloadlyError } = require("../../../reloadly/index.js");
const { applyPendingCommissions } = require("../commission/engine");
const AppIds = require("../../../bazik/src/ids");
const { getBazikService } = require("../bazik_service");
const { checkCreditCapacity, withCreditLock } = require("../solvency");

const router = express.Router();

/** Menm wòl ak `settleCommissions` nan bazik.routes.js. */
async function settleCommissions(enterpriseId) {
  try {
    await applyPendingCommissions({ enterpriseId, limit: 25 });
  } catch (err) {
    console.error("[commission] rattrapage echwe:", err.message);
  }
}

function send(res, err) {
  // Yon erè Reloadly se yon pàn AMONT: 502, jamè estati Reloadly a tel kel.
  // Yon 401 Reloadly (move kle) ki pase tel kel ta fè app la efase sesyon
  // ajan an — li ta dekonekte pou yon pwoblèm konfigirasyon serveur.
  //
  // Yon refi metye (DomainError, oswa yon objè `{ code, message }` wout la
  // bati li menm) = 400. Sèlman yon erè JavaScript enkoni = 500.
  const status =
    err.httpStatus ||
    (err instanceof ReloadlyError ? 502 : err instanceof DomainError || !(err instanceof Error) ? 400 : 500);

  if (status >= 500) console.error("[airtime]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "internal_error",
    message: err.message,
    ...(err.topup ? { topup: err.topup } : {}),
    ...(err.allowedAmounts ? { allowedAmounts: err.allowedAmounts } : {}),
  });
}

/** An pwodiksyon san kle: pa gen similasyon, pa gen debi. */
function requireAvailable(req, res, next) {
  if (getAirtimeService().disabled) {
    return res.status(503).json({
      ok: false,
      code: "airtime_unavailable",
      message: "Minit Haiti poko aktive: kle Reloadly yo pa konfigire sou serveur a.",
    });
  }
  return next();
}

function ownedOr404(res, topup, req) {
  if (!topup || topup.enterpriseId !== req.user.enterpriseId) {
    res.status(404).json({ ok: false, code: "not_found" });
    return false;
  }
  return true;
}

/** Sèvis ki livre pa Reloadly: katalòg la rele l "Minit Haiti". */
function isAirtimeService(serviceName) {
  return /minit/i.test(String(serviceName || ""));
}

/** Fòm JSON yon rechaj pou UI a (montan an desimal, pa an santim). */
function toJson(topup) {
  if (!topup) return null;
  return {
    ...topup,
    amount: money.fromMinor(topup.amountMinor),
    sendAmount: money.fromMinor(topup.sendAmountMinor),
    debit: money.fromMinor(topup.debitMinor),
    estimatedDelivered: money.fromMinor(topup.estimatedDeliveredMinor),
    delivered: money.fromMinor(topup.deliveredMinor),
    discount: money.fromMinor(topup.discountMinor),
  };
}

// --- Eta -----------------------------------------------------------------------

router.get("/status", requireAuth, async (req, res) => {
  const service = getAirtimeService();

  const status = {
    mode: service.config.mode,
    enabled: !service.disabled,
    /** `true` sèlman lè rechaj yo rive vre sou Reloadly. */
    reachesReloadly: !service.config.isFake,
  };

  if (service.disabled) {
    status.warning = "Minit Haiti poko aktive: kle Reloadly yo pa konfigire sou serveur a.";
    return res.json({ ok: true, ...status });
  }

  try {
    const account = await service.topups.accountBalance();

    // MONTAN an se yon done lajan: owner sèlman. Tout lòt moun jwenn `funded`,
    // ki se tou sa UI a bezwen pou avèti anvan yon vant.
    status.funded = account.balanceMinor > 0;
    status.account =
      req.user.role === "owner"
        ? { balance: money.fromMinor(account.balanceMinor), currency: account.currency }
        : { restricted: true, currency: account.currency };

    if (!status.funded) {
      status.warning = "Kont Reloadly la vid: tout rechaj minit ap refize.";
    }
  } catch (err) {
    status.account = null;
    status.accountError = err.code || "unknown";
  }

  return res.json({ ok: true, ...status });
});

// --- Operatè ak devi --------------------------------------------------------------

router.get("/operators/detect", requireAuth, requireEnterprise, requireAvailable, async (req, res) => {
  try {
    const service = getAirtimeService();
    const operator = await service.topups.detectOperator(String(req.query.phone || ""));
    return res.json({ ok: true, operator: service.topups.describeOperator(operator) });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/quote", requireAuth, requireEnterprise, requireAvailable, async (req, res) => {
  try {
    const body = req.body || {};
    const quote = await getAirtimeService().topups.quote({
      uid: req.user.uid,
      enterpriseId: req.user.enterpriseId,
      phone: body.phone,
      amountMinor: money.toMinor(body.amount),
      currency: body.currency,
      operatorId: body.operatorId,
    });

    return res.json({ ok: true, quote });
  } catch (err) {
    return send(res, err);
  }
});

// --- Livrezon -------------------------------------------------------------------

/**
 * Livre yon tranzaksyon Minit Haiti.
 *
 * Montan, deviz ak nimewo a soti nan TRANZAKSYON AN, pa nan kò demann lan.
 * Sinon yon tranzaksyon 1 USD (komisyon kalkile sou 1 USD) te ka livre
 * 50 USD minit, oswa sou yon lòt nimewo pase sa ki anrejistre a.
 */
router.post("/topups", requireAuth, requireEnterprise, requireAvailable, async (req, res) => {
  try {
    const { uid, enterpriseId } = req.user;
    const body = req.body || {};
    const txId = String(body.txId || "").trim();

    if (!txId) {
      return send(res, {
        code: "missing_transaction",
        message: "Yon rechaj minit dwe lye ak yon tranzaksyon Minit Haiti.",
      });
    }

    const tx = getDb()
      .prepare("SELECT * FROM transactions WHERE tx_id = ? AND enterprise_id = ?")
      .get(txId, enterpriseId);

    if (!tx) return res.status(404).json({ ok: false, code: "transaction_not_found" });

    if (!isAirtimeService(tx.service)) {
      return send(res, {
        code: "not_airtime_transaction",
        message: `Tranzaksyon sa a se ${tx.service}, pa Minit Haiti.`,
      });
    }

    if (tx.status === "delivered" || tx.status === "canceled") {
      return send(res, {
        httpStatus: 409,
        code: "transaction_closed",
        message: `Tranzaksyon sa a deja ${tx.status === "delivered" ? "livre" : "anile"}.`,
      });
    }

    const result = await getAirtimeService().topups.send({
      uid,
      enterpriseId,
      enterpriseName: req.user.enterpriseName,
      phone: tx.phone,
      amountMinor: tx.amount_minor,
      currency: tx.currency,
      platformFeeMinor: tx.fee_mode ? tx.sender_fee_minor : 0,
      operatorId: body.operatorId,
      txId,
      note: `Minit Haiti ${tx.client_name || ""}`.trim(),
      createdBy: uid,
    });

    await settleCommissions(enterpriseId);
    return res.json({ ok: true, ...result, topup: toJson(result.topup) });
  } catch (err) {
    if (err.topup) err.topup = toJson(err.topup);
    return send(res, err);
  }
});

router.get("/topups", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const service = getAirtimeService();
    const limit = Math.min(Number(req.query.limit) || 25, 100);
    const topups = await service.store.listTopups({ enterpriseId: req.user.enterpriseId, limit });

    return res.json({ ok: true, mode: service.config.mode, topups: topups.map(toJson) });
  } catch (err) {
    return send(res, err);
  }
});

router.get("/topups/:id", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const topup = await getAirtimeService().store.getTopup(req.params.id);
    if (!ownedOr404(res, topup, req)) return;
    return res.json({ ok: true, topup: toJson(topup) });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/topups/:id/refresh", requireAuth, requireEnterprise, requireAvailable, async (req, res) => {
  try {
    const service = getAirtimeService();
    const topup = await service.store.getTopup(req.params.id);

    // `refresh` ka deklanche yon ranbousman: pa sou rechaj yon lòt antrepriz.
    if (!ownedOr404(res, topup, req)) return;

    const refreshed = await service.topups.refresh(req.params.id);
    await settleCommissions(req.user.enterpriseId);
    return res.json({ ok: true, ...refreshed, topup: toJson(refreshed.topup) });
  } catch (err) {
    return send(res, err);
  }
});

router.post(
  "/topups/poll",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  requireAvailable,
  async (req, res) => {
    try {
      const updated = await getAirtimeService().topups.pollPending();
      await settleCommissions(null);
      return res.json({ ok: true, updated });
    } catch (err) {
      return send(res, err);
    }
  }
);

// ---- Rechaj airtime -------------------------------------------------------

/**
 * GET /api/airtime/recharge
 * Lis demann rechaj airtime yo.
 *   - Ajan: pa li sèlman
 *   - Owner/Admin: tout antrepriz la
 */
router.get("/recharge", requireAuth, requireEnterprise, (req, res) => {
  try {
    const isManager = req.user.role === "owner" || req.user.role === "admin";
    const filters = ["enterprise_id = ?"];
    const params = [req.user.enterpriseId];

    if (!isManager) {
      filters.push("agent_uid = ?");
      params.push(req.user.uid);
    }

    const status = String(req.query.status || "").trim();
    if (status) {
      filters.push("status = ?");
      params.push(status);
    }

    const rows = getDb()
      .prepare(
        `SELECT * FROM airtime_recharge_requests
          WHERE ${filters.join(" AND ")}
          ORDER BY created_at DESC LIMIT 100`
      )
      .all(...params);

    return res.json({
      ok: true,
      recharges: rows.map((r) => ({
        requestId: r.request_id,
        agentUid: r.agent_uid,
        agentName: r.agent_name,
        amount: money.fromMinor(r.amount_minor),
        currency: r.currency,
        note: r.note,
        status: r.status,
        decidedBy: r.decided_by,
        decidedAt: r.decided_at,
        createdAt: r.created_at,
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

/**
 * POST /api/airtime/recharge
 * Ajan kreye yon demann rechaj airtime.
 */
router.post("/recharge", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const body = req.body || {};

    let amountMinor;
    try {
      amountMinor = money.toMinor(body.amount);
    } catch (err) {
      return send(res, { code: "invalid_amount", message: err.message });
    }

    if (amountMinor <= 0) {
      return send(res, { code: "invalid_amount", message: "Montan an dwe pi gran pase 0." });
    }

    // Deviz la se sa wallet la pou evite konfizyon konvèsyon.
    const wallet = await getBazikService().store.getWallet({
      uid: req.user.uid,
      enterpriseId: req.user.enterpriseId,
    });

    const currency = wallet?.currency || "USD";
    const requestId = AppIds.generate("AR", `airtime_recharge:${req.user.enterpriseId}:${req.user.uid}:${Date.now()}`);

    getDb()
      .prepare(
        `INSERT INTO airtime_recharge_requests
          (request_id, enterprise_id, agent_uid, agent_name, amount_minor, currency, note, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`
      )
      .run(
        requestId, req.user.enterpriseId, req.user.uid,
        req.user.displayName || "", amountMinor, currency,
        String(body.note || ""), now(), now()
      );

    const row = getDb()
      .prepare("SELECT * FROM airtime_recharge_requests WHERE request_id = ?")
      .get(requestId);

    return res.json({
      ok: true,
      recharge: {
        requestId: row.request_id,
        agentUid: row.agent_uid,
        agentName: row.agent_name,
        amount: money.fromMinor(row.amount_minor),
        currency: row.currency,
        note: row.note,
        status: row.status,
        createdAt: row.created_at,
      },
    });
  } catch (err) {
    return send(res, err);
  }
});

/**
 * POST /api/airtime/recharge/:id/approve
 * Owner/Admin kredite wallet ajan an.
 */
router.post(
  "/recharge/:id/approve",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  async (req, res) => {
    const db = getDb();

    try {
      const row = db
        .prepare(
          "SELECT * FROM airtime_recharge_requests WHERE request_id = ? AND enterprise_id = ?"
        )
        .get(req.params.id, req.user.enterpriseId);

      if (!row) return res.status(404).json({ ok: false, code: "not_found" });

      if (row.status !== "pending") {
        return send(res, {
          code: "already_processed",
          message: `Demann sa a deja ${row.status}.`,
        });
      }

      // Klame an atomik: evite de admin apwouve menm demann lan.
      const claimed = db
        .prepare(
          `UPDATE airtime_recharge_requests
            SET status = 'approved', decided_by = ?, decided_at = ?, updated_at = ?
            WHERE request_id = ? AND status = 'pending'`
        )
        .run(req.user.uid, now(), now(), row.request_id);

      if (claimed.changes === 0) {
        return send(res, { code: "already_processed", message: "Yon lòt moun deja apwouve demann sa a." });
      }

      // Cherche nom antrepriz la pou ledger la.
      const enterprise = db
        .prepare("SELECT name FROM enterprises WHERE enterprise_id = ?")
        .get(row.enterprise_id);

      await withCreditLock(row.enterprise_id, async () => {
        const capacity = await checkCreditCapacity({
          enterpriseId: row.enterprise_id,
          creditMinor: row.amount_minor,
          currency: row.currency,
          targetRole: "agent",
        });

        if (!capacity.allowed) {
          // Annule apwobasyon an si solvabilite pa pèmèt la.
          db.prepare(
            `UPDATE airtime_recharge_requests
              SET status = 'pending', decided_by = '', decided_at = NULL, updated_at = ?
              WHERE request_id = ?`
          ).run(now(), row.request_id);

          throw Object.assign(new Error(capacity.message), {
            status: capacity.status,
            code: capacity.code,
          });
        }

        await getBazikService().store.creditWallet({
          uid: row.agent_uid,
          enterpriseId: row.enterprise_id,
          enterpriseName: enterprise?.name || "",
          role: "agent",
          amountMinor: row.amount_minor,
          currency: row.currency,
          type: "airtime_recharge",
          note: `Rechaj airtime${row.note ? `: ${row.note}` : ""}`,
          sourceCollection: "airtime_recharge_requests",
          sourceId: row.request_id,
          createdBy: req.user.uid,
          createdByRole: req.user.role,
          idempotencyKey: `airtime_recharge:${row.request_id}`,
        });
      });

      const updated = db
        .prepare("SELECT * FROM airtime_recharge_requests WHERE request_id = ?")
        .get(row.request_id);

      return res.json({
        ok: true,
        recharge: {
          requestId: updated.request_id,
          agentName: updated.agent_name,
          amount: money.fromMinor(updated.amount_minor),
          currency: updated.currency,
          status: updated.status,
          decidedAt: updated.decided_at,
        },
      });
    } catch (err) {
      return send(res, err);
    }
  }
);

/**
 * POST /api/airtime/recharge/:id/reject
 * Owner/Admin refize demann lan.
 */
router.post(
  "/recharge/:id/reject",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  (req, res) => {
    try {
      const result = getDb()
        .prepare(
          `UPDATE airtime_recharge_requests
            SET status = 'rejected', decided_by = ?, decided_at = ?, updated_at = ?
            WHERE request_id = ? AND enterprise_id = ? AND status = 'pending'`
        )
        .run(req.user.uid, now(), now(), req.params.id, req.user.enterpriseId);

      if (result.changes === 0) {
        return send(res, {
          code: "not_found_or_processed",
          message: "Demann lan pa egziste oswa li deja trete.",
        });
      }

      return res.json({ ok: true });
    } catch (err) {
      return send(res, err);
    }
  }
);

module.exports = router;
