"use strict";

/**
 * Wallet, rejis ak demann rechaj — ranplase `balances`, `wallet_ledger`,
 * `wallet_topup_requests` ak `payout_requests`.
 *
 *   GET  /api/wallets/me                sòld mwen
 *   GET  /api/wallets/:uid              sòld yon staff (owner/admin)
 *   GET  /api/wallets/:uid/ledger       istorik mouvman yo
 *   POST /api/wallets/topups            mande yon rechaj (owner/admin)
 *   GET  /api/wallets/topups            lis demann yo
 *   POST /api/wallets/topups/:id/approve  kredite wallet la
 *   POST /api/wallets/topups/:id/reject
 *
 * Kredite yon wallet pa janm yon senp `UPDATE`: li pase pa `creditWallet` nan
 * Bazik la, ki ekri sòld la ak liy rejis la nan MENM tranzaksyon.
 */

const express = require("express");

const { getRatesRefresher } = require("../rates/rates_refresher");

const { getDb, now } = require("../db/db");
const { getBazikService } = require("../bazik_service");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money } = require("../../../bazik/index.js");
const AppIds = require("../../../bazik/src/ids");
const { getExchangeMargin, applyMargin } = require("../settings/settings");
const { checkCreditCapacity, withCreditLock } = require("../solvency");

const router = express.Router();

/**
 * Kredite yon demann rechaj SÈLMAN si pwovizyon Bazik la ka kouvri l (wè
 * `checkCreditCapacity`). Verifikasyon + kredi pase anba yon kadna pa
 * antrepriz: de apwobasyon paralèl pa ka tou de konte sou menm kòb la.
 */
function settleIfCovered({ row, gatewayStatus }) {
  return withCreditLock(row.enterprise_id, async () => {
    const capacity = await checkCreditCapacity({
      enterpriseId: row.enterprise_id,
      creditMinor: row.amount_minor,
      currency: row.currency,
      targetRole: row.target_role,
    });

    if (!capacity.allowed) {
      throw Object.assign(new Error(capacity.message), {
        status: capacity.status,
        code: capacity.code,
        maxCreditHtg: capacity.maxCreditHtg,
      });
    }

    return getBazikService().store.settleTopup({
      topupId: row.request_id,
      status: "completed",
      gatewayStatus,
    });
  });
}

function send(res, err) {
  const status = err.status || 400;
  if (status >= 500) console.error("[wallets]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "error",
    message: err.message,
    ...(err.maxCreditHtg !== undefined ? { maxCreditHtg: err.maxCreditHtg } : {}),
  });
}

async function walletOf(uid, enterpriseId) {
  const wallet = await getBazikService().store.getWallet({ uid, enterpriseId });

  if (!wallet) {
    return { uid, enterpriseId, balance: 0, currency: "USD", exists: false };
  }

  return {
    uid: wallet.uid,
    enterpriseId: wallet.enterpriseId,
    enterpriseName: wallet.enterpriseName,
    role: wallet.role,
    balance: money.fromMinor(wallet.balanceMinor),
    currency: wallet.currency,
    exists: true,
  };
}

router.get("/me", requireAuth, requireEnterprise, async (req, res) => {
  try {
    return res.json({
      ok: true,
      wallet: await walletOf(req.user.uid, req.user.enterpriseId),
    });
  } catch (err) {
    return send(res, err);
  }
});

/** To echanj yo — UI a sèvi ak sa pou montre konvèsyon an anvan validasyon.
 *  Nou aplike majin owner an isit la tou pou UI a montre menm valè ak sa
 *  serveur a pral itilize nan konvèsyon aktyèl la. */
router.get("/rates", requireAuth, (req, res) => {
  try {
    const rows = getDb()
      .prepare("SELECT currency, rate_to_htg FROM exchange_rates ORDER BY currency")
      .all();

    const margin = getExchangeMargin();
    const rates = {};
    for (const row of rows) {
      rates[row.currency] =
        row.currency === "HTG" ? row.rate_to_htg : applyMargin(row.rate_to_htg, margin);
    }

    // `meta`: sous ak dat to yo. UI a ka montre "to jounen an" oswa avèti si
    // yo pa ajou. Kle API a pa janm la. Nou ajoute majin aktyèl la pou UI a
    // ka siyale konbyen soustrè sou chak to.
    return res.json({
      ok: true,
      rates,
      margin,
      meta: getRatesRefresher().status(),
    });
  } catch (err) {
    return send(res, err);
  }
});

// --- Demann rechaj ---
// (Deklare AVAN `/:uid` sinon "topups" ta pase pou yon uid.)

router.get("/topups", requireAuth, requireEnterprise, (req, res) => {
  try {
    const status = String(req.query.status || "").trim();

    const filters = ["enterprise_id = ?"];
    const params = [req.user.enterpriseId];

    if (status) {
      filters.push("status = ?");
      params.push(status);
    }

    // Yon ajan wè sèlman demann ki vize l.
    if (req.user.role === "agent") {
      filters.push("target_uid = ?");
      params.push(req.user.uid);
    }

    const rows = getDb()
      .prepare(
        `SELECT * FROM wallet_topup_requests WHERE ${filters.join(" AND ")}
          ORDER BY created_at DESC LIMIT 100`
      )
      .all(...params);

    return res.json({
      ok: true,
      topups: rows.map((row) => ({
        requestId: row.request_id,
        status: row.status,
        processed: row.processed === 1,
        amount: money.fromMinor(row.amount_minor),
        currency: row.currency,
        targetUid: row.target_uid,
        targetName: row.target_name,
        targetEmail: row.target_email,
        note: row.note,
        requestedByName: row.requested_by_name,
        createdAt: row.created_at,
        creditedAt: row.credited_at,
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

router.post(
  "/topups",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  async (req, res) => {
    try {
      const body = req.body || {};
      const targetUid = String(body.targetUid || "").trim();

      if (!targetUid) {
        return send(res, { code: "missing_target", message: "Chwazi yon staff." });
      }

      let amountMinor;
      try {
        amountMinor = money.toMinor(body.amount);
      } catch (err) {
        return send(res, { code: "invalid_amount", message: err.message });
      }

      const target = getDb()
        .prepare(
          `SELECT u.display_name, u.email, u.role FROM enterprise_users eu
             JOIN users u ON u.uid = eu.uid
            WHERE eu.uid = ? AND eu.enterprise_id = ? AND eu.is_active = 1`
        )
        .get(targetUid, req.user.enterpriseId);

      if (!target) {
        return send(res, {
          code: "target_not_found",
          message: "Staff sa a pa nan antrepriz ou a.",
        });
      }

      const requestId = AppIds.topupRequest(
        `${req.user.enterpriseId}:${targetUid}:${Date.now()}`
      );

      // Yon wallet gen YON SÈL deviz. Si admin nan tape nan yon lòt deviz,
      // nou konvèti — nou pa melanje inite nan menm sòld la.
      const inputCurrency = String(body.currency || "USD").toUpperCase();

      const wallet = await getBazikService().store.getWallet({
        uid: targetUid,
        enterpriseId: req.user.enterpriseId,
      });
      const currency = wallet?.currency || "USD";

      let creditMinor = amountMinor;
      let rateNote = "";

      if (inputCurrency !== currency) {
        // To jounen an (liv to echanj la), pa yon kalkil apa.
        const converted = await getBazikService().rates.convert(amountMinor, inputCurrency, currency);
        creditMinor = converted.amountMinor;

        rateNote =
          ` (${money.fromMinor(amountMinor)} ${inputCurrency} ` +
          `@ ${converted.rate.toFixed(4)})`;
      }

      getDb()
        .prepare(
          `INSERT INTO wallet_topup_requests
            (request_id, type, status, processed, gateway, network, gateway_order_id,
             amount_minor, currency, amount_htg_minor, rate_to_htg, target_uid,
             target_email, target_name, target_role, enterprise_id, enterprise_name,
             requested_by, requested_by_name, requested_by_role, note,
             created_at, updated_at)
           VALUES (?, 'wallet_topup', 'pending', 0, 'manual', 'manual', ?, ?, ?, 0, 0,
                   ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        )
        .run(
          requestId, requestId, creditMinor, currency, targetUid,
          target.email, target.display_name, target.role,
          req.user.enterpriseId, req.user.enterpriseName,
          req.user.uid, req.user.displayName, req.user.role,
          String(body.note || "") + rateNote, now(), now()
        );

      // `autoApprove` = owner/admin ap mete kòb dirèkteman, san de etap.
      // Nou pase pa MENM chemen an (`settleTopup`), donk rejis la ekri menm
      // jan an: pa gen "rakousi" ki sote tras la.
      if (body.autoApprove === true) {
        let settled;
        try {
          settled = await settleIfCovered({
            row: {
              request_id: requestId,
              enterprise_id: req.user.enterpriseId,
              amount_minor: creditMinor,
              currency,
              target_role: target.role,
            },
            gatewayStatus: "direct_credit",
          });
        } catch (err) {
          // Pa kite yon demann "pending" ki pa t janm ka pase.
          getDb()
            .prepare(
              `UPDATE wallet_topup_requests
                  SET status = 'rejected', processed = 1, failure_reason = ?, updated_at = ?
                WHERE request_id = ? AND processed = 0`
            )
            .run(err.code || "error", now(), requestId);
          throw err;
        }

        return res.json({
          ok: true,
          requestId,
          credited: settled.credit !== null,
          creditedAmount: money.fromMinor(creditMinor),
          currency,
        });
      }

      return res.json({ ok: true, requestId });
    } catch (err) {
      return send(res, err);
    }
  }
);

router.post(
  "/topups/:id/approve",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  async (req, res) => {
    try {
      const row = getDb()
        .prepare(
          "SELECT * FROM wallet_topup_requests WHERE request_id = ? AND enterprise_id = ?"
        )
        .get(req.params.id, req.user.enterpriseId);

      if (!row) return res.status(404).json({ ok: false, code: "not_found" });

      if (row.processed === 1) {
        return send(res, {
          code: "already_processed",
          message: "Demann sa a deja trete.",
        });
      }

      // `settleTopup` kredite wallet la ak ekri rejis la ann ATOMIK, epi li
      // pwoteje kont doub kredi gras ak yon kle idempotans.
      const settled = await settleIfCovered({ row, gatewayStatus: "manual_approval" });

      return res.json({
        ok: true,
        duplicate: settled.duplicate,
        credited: settled.credit !== null,
      });
    } catch (err) {
      return send(res, err);
    }
  }
);

router.post(
  "/topups/:id/reject",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  (req, res) => {
    try {
      const result = getDb()
        .prepare(
          `UPDATE wallet_topup_requests
              SET status = 'rejected', processed = 1, failure_reason = ?, updated_at = ?
            WHERE request_id = ? AND enterprise_id = ? AND processed = 0`
        )
        .run(String(req.body?.note || ""), now(), req.params.id, req.user.enterpriseId);

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

// --- Sòld yon staff + rejis ---

/**
 * Owner a mete sòld yon wallet sou yon montan egzak (korije yon erè, aliyen ak
 * Bazik...). Se pa yon UPDATE: diferans lan pase nan rejis la kòm yon liy
 * `adjustment`, ak non owner a ak rezon an.
 *
 * Yon ogmantasyon sou wallet yon staff se yon nouvo dèt: li pase menm kontwòl
 * solvabilite ak yon rechaj.
 */
router.post("/:uid/adjust", requireAuth, requireEnterprise, requireRole("owner"), async (req, res) => {
  try {
    const body = req.body || {};
    const note = String(body.note || "").trim();
    if (note.length < 5) {
      return send(res, { code: "note_required", message: "Ekri poukisa (omwen 5 karaktè): se tras ajisteman an." });
    }

    let targetMinor;
    try {
      targetMinor = money.toMinor(body.balance);
    } catch (err) {
      return send(res, { code: "invalid_amount", message: err.message });
    }
    if (targetMinor < 0) return send(res, { code: "invalid_amount", message: "Sòld la pa ka negatif." });

    const enterpriseId = req.user.enterpriseId;
    const target = getDb()
      .prepare("SELECT uid, role, display_name FROM users WHERE uid = ?")
      .get(req.params.uid);
    const member = getDb()
      .prepare("SELECT 1 FROM enterprise_users WHERE uid = ? AND enterprise_id = ?")
      .get(req.params.uid, enterpriseId);
    if (!target || !member) return res.status(404).json({ ok: false, code: "staff_not_found" });

    const store = getBazikService().store;
    const result = await withCreditLock(enterpriseId, async () => {
      const wallet = await store.getWallet({ uid: target.uid, enterpriseId });
      if (!wallet) throw Object.assign(new Error("Wallet sa a pa egziste."), { status: 404, code: "wallet_not_found" });

      const diff = targetMinor - wallet.balanceMinor;
      if (diff === 0) return { wallet, diff };

      if (diff > 0) {
        const capacity = await checkCreditCapacity({
          enterpriseId, creditMinor: diff, currency: wallet.currency, targetRole: target.role,
        });
        if (!capacity.allowed) {
          throw Object.assign(new Error(capacity.message), { status: capacity.status, code: capacity.code });
        }
      }

      const move = {
        uid: target.uid,
        enterpriseId,
        enterpriseName: req.user.enterpriseName,
        role: target.role,
        amountMinor: Math.abs(diff),
        currency: wallet.currency,
        type: "adjustment",
        note: `Ajisteman owner: ${note}`,
        sourceCollection: "wallet_adjustments",
        sourceId: `${target.uid}:${now()}`,
        createdBy: req.user.uid,
        createdByRole: req.user.role,
        idempotencyKey: `adjust:${target.uid}:${wallet.balanceMinor}:${targetMinor}:${now()}`,
      };
      if (diff > 0) await store.creditWallet(move);
      else await store.debitWallet(move);

      return { wallet: await store.getWallet({ uid: target.uid, enterpriseId }), diff };
    });

    return res.json({
      ok: true,
      wallet: { ...result.wallet, balance: money.fromMinor(result.wallet.balanceMinor) },
      adjustment: money.fromMinor(result.diff),
    });
  } catch (err) {
    return send(res, err);
  }
});

router.get("/:uid", requireAuth, requireEnterprise, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid && req.user.role === "agent") {
      return res.status(403).json({ ok: false, code: "forbidden" });
    }

    return res.json({
      ok: true,
      wallet: await walletOf(req.params.uid, req.user.enterpriseId),
    });
  } catch (err) {
    return send(res, err);
  }
});

router.get("/:uid/ledger", requireAuth, requireEnterprise, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid && req.user.role === "agent") {
      return res.status(403).json({ ok: false, code: "forbidden" });
    }

    const rows = await getBazikService().store.listLedger({
      uid: req.params.uid,
      enterpriseId: req.user.enterpriseId,
      limit: Math.min(Number(req.query.limit) || 50, 200),
    });

    return res.json({
      ok: true,
      entries: rows.map((row) => ({
        ledgerId: row.ledger_id,
        type: row.type,
        direction: row.direction,
        amount: money.fromMinor(row.amount_minor),
        currency: row.currency,
        balanceBefore: money.fromMinor(row.before_minor),
        balanceAfter: money.fromMinor(row.after_minor),
        note: row.note,
        serviceName: row.service_name,
        createdAt: row.created_at,
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = router;
