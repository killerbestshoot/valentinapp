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
const { getDb } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money, DomainError } = require("../../../bazik/index.js");
const { ReloadlyError } = require("../../../reloadly/index.js");
const { applyPendingCommissions } = require("../commission/engine");

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

module.exports = router;
