"use strict";

/**
 * Wout Bazik.
 *
 * OTANTIFIKASYON: idantite a soti nan JETON SESYON an, jamè nan yon header.
 *
 * Anvan, wout sa yo t ap fè konfyans yon header `x-dev-uid`. Sa vle di nenpòt
 * moun ki konnen yon uid te ka li yon sòld — oswa VOYE LAJAN depi wallet la —
 * san okenn jeton. Se te twou ki pi grav nan API a.
 */

const express = require("express");
const { getBazikService } = require("../bazik_service");
const {
  requireAuth,
  requireRole,
  requireEnterprise,
} = require("../auth/middleware");
const { money, DomainError, BazikError } = require("../../../bazik/index.js");
const { applyPendingCommissions } = require("../commission/engine");

/**
 * Apre yon operasyon ki ka fè yon tranzaksyon pase `delivered` (settleTransfer),
 * nou aplike komisyon an reta yo. Idempotan e limite: san danje pou rele l
 * souvan. Nou pa bloke repons lan si li echwe — pwochen pasaj la ap rattrape.
 */
async function settleCommissions(enterpriseId) {
  try {
    await applyPendingCommissions({ enterpriseId, limit: 25 });
  } catch (err) {
    console.error("[commission] rattrapage echwe:", err.message);
  }
}

const router = express.Router();

/** Yon sèl kote pou tradui erè domèn yo an repons HTTP. */
function send(res, err) {
  const status =
    err.httpStatus ||
    (err instanceof DomainError ? 400 : err instanceof BazikError ? err.status || 502 : 500);

  if (status >= 500) console.error("[bazik]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "internal_error",
    message: err.message,
  });
}

/**
 * Resous la dwe nan antrepriz moun k ap rele a.
 *
 * Nou reponn 404 (pa 403) espre: yon 403 ta konfime ID a egziste nan yon lòt
 * antrepriz.
 */
function ownedOr404(res, resource, req) {
  if (!resource || resource.enterpriseId !== req.user.enterpriseId) {
    res.status(404).json({ ok: false, code: "not_found" });
    return false;
  }
  return true;
}

/** Montan yo rive an inite prensipal (10.50), nou travay an santim. */
function amountMinorFrom(body) {
  return money.toMinor(body.amount);
}

// --- Eta pasrèl la ---

/**
 * Yon sèl kote ki di: nan ki mòd nou ye, epi èske float Bazik la gen pwovizyon.
 *
 * Se wout sa a ki reponn kesyon an "poukisa mwen pa wè anyen sou dashboard
 * Bazik la?": si `mode` se `fake`, anyen pa janm pati; si `gatewayFunded` se
 * `false`, Bazik refize tout transfè anvan li kreye yo.
 */
router.get("/status", requireAuth, async (req, res) => {
  const service = getBazikService();

  const status = {
    mode: service.config.mode,
    /** `true` sèlman lè transfè yo rive vre sou Bazik. */
    reachesBazik: service.config.mode !== "fake",
  };

  try {
    const wallet = await service.gatewayWallet();

    status.gatewayWallet = {
      available: money.fromMinor(wallet.availableMinor),
      reserved: money.fromMinor(wallet.reservedMinor),
      currency: wallet.currency,
      environment: wallet.environment,
    };
    status.gatewayFunded = wallet.availableMinor > 0;

    if (!status.gatewayFunded) {
      status.warning =
        "Wallet Bazik la vid: chak transfè ap refize ak `insufficient_balance`, " +
        "e anyen p ap parèt sou dashboard Bazik la.";
    }
  } catch (err) {
    status.gatewayWallet = null;
    status.gatewayError = err.code || "unknown";
  }

  return res.json({ ok: true, ...status });
});

/** Sld wallet Bazik la (se li ki finanse transfè yo). */
router.get("/gateway/wallet", requireAuth, requireRole("owner", "admin"), async (req, res) => {
  try {
    const service = getBazikService();
    return res.json({ ok: true, mode: service.config.mode, wallet: await service.gatewayWallet() });
  } catch (err) {
    return send(res, err);
  }
});

/**
 * Lis transfè yo ak ID Bazik yo — pou rekonsilye ak dashboard Bazik la.
 * `gatewayId` se nimewo a ou ap chèche sou kote Bazik.
 */
router.get("/transfers", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const service = getBazikService();
    const limit = Math.min(Number(req.query.limit) || 25, 100);

    // Filtre antrepriz: anvan, yon owner te wè transfè TOUT antrepriz yo.
    const rows = service.store._db
      .prepare(
        `SELECT transfer_id, reference, gateway_id, status, network, amount_htg_minor,
                fee_htg_minor, failure_reason, created_at
           FROM bazik_transfers WHERE enterprise_id = ?
          ORDER BY created_at DESC LIMIT ?`
      )
      .all(req.user.enterpriseId, limit);

    return res.json({
      ok: true,
      mode: service.config.mode,
      transfers: rows.map((row) => ({
        transferId: row.transfer_id,
        reference: row.reference,
        gatewayId: row.gateway_id || null,
        status: row.status,
        network: row.network,
        amountHtg: money.fromMinor(row.amount_htg_minor),
        feeHtg: money.fromMinor(row.fee_htg_minor),
        failureReason: row.failure_reason || null,
        createdAt: row.created_at,
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

/** Sld wallet ajan an nan baz nou. */
router.get("/wallet", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const { uid, enterpriseId } = req.user;
    const service = getBazikService();
    const wallet = await service.store.getWallet({ uid, enterpriseId });

    return res.json({
      ok: true,
      wallet: wallet
        ? { ...wallet, balance: money.fromMinor(wallet.balanceMinor) }
        : null,
    });
  } catch (err) {
    return send(res, err);
  }
});

// --- Transfè soti ---

/** Estimasyon frè yo anvan ajan an konfime. */
router.post("/quote", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const service = getBazikService();
    const quote = await service.transfers.quote({
      amountMinor: amountMinorFrom(req.body || {}),
      currency: req.body?.currency,
      network: req.body?.network || "moncash",
      // Debi a kalkile nan deviz WALLET moun k ap rele a.
      uid: req.user.uid,
      enterpriseId: req.user.enterpriseId,
    });

    return res.json({ ok: true, quote: { ...quote, debit: money.fromMinor(quote.debitMinor) } });
  } catch (err) {
    return send(res, err);
  }
});

/** Voye lajan (payout oswa livrezon). */
router.post("/transfers", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const { uid, enterpriseId } = req.user;
    const service = getBazikService();
    const body = req.body || {};

    // Si demann lan pote yon `txId`, li dwe nan antrepriz moun nan. Anvan, yon
    // ajan te ka mete `txId` yon lòt antrepriz epi fè tranzaksyon sa a pase
    // `delivered` oswa `failed`.
    const txId = String(body.txId || "").trim();
    let tx = null;
    if (txId) {
      tx = service.store._db
        .prepare("SELECT * FROM transactions WHERE tx_id = ? AND enterprise_id = ?")
        .get(txId, enterpriseId);

      if (!tx) return res.status(404).json({ ok: false, code: "transaction_not_found" });
    }

    // Tranzaksyon ak frè platfòm: montan, deviz ak frè a soti nan TRANZAKSYON
    // AN, pa nan kò demann lan. Sinon yon ajan te ka voye plis pase sa li
    // anrejistre, oswa "bliye" frè a. Frè pasrèl la pa sou wallet ajan an: se
    // owner a ki peye l sou pati pa l nan frè a (`commission/engine.js`).
    const withPlatformFee = Boolean(tx?.fee_mode);

    const result = await service.transfers.send({
      kind: body.kind === "delivery" ? "delivery" : "payout",
      network: body.network === "natcash" ? "natcash" : "moncash",
      amountMinor: withPlatformFee ? tx.amount_minor : amountMinorFrom(body),
      currency: withPlatformFee ? tx.currency : body.currency,
      platformFeeMinor: withPlatformFee ? tx.sender_fee_minor : 0,
      chargeFeeToWallet: !withPlatformFee,
      uid,
      enterpriseId,
      // Soti nan sesyon an: anvan, yon kliyan te ka ekri "SPOOFED CORP" nan
      // rejis la.
      enterpriseName: req.user.enterpriseName,
      phone: body.phone,
      receiverName: body.receiverName || "",
      txId,
      note: body.note || "",
      createdBy: uid,
      idempotencySeed: body.idempotencySeed || "",
    });

    await settleCommissions(enterpriseId);
    return res.json({ ok: true, ...result });
  } catch (err) {
    return send(res, err);
  }
});

// --- Rekonsilyasyon manyèl ---

/** Yon transfè ki poko fini depi plis pase sa a parèt nan lis pou verifye a. */
const REVIEW_AFTER_MS = 15 * 60000;

/**
 * Transfè ki bloke (pending/processing depi plis pase 15 minit), ak sa owner
 * a bezwen pou jwenn yo sou dashboard Bazik la: dat, montan, nimewo, non.
 */
router.get("/transfers/review", requireAuth, requireEnterprise, requireRole("owner", "admin"), (req, res) => {
  try {
    const db = getBazikService().store._db;
    const rows = db
      .prepare(
        `SELECT b.*, t.staff_name, t.status AS tx_status, t.client_name
           FROM bazik_transfers b
           LEFT JOIN transactions t ON t.tx_id = b.tx_id
          WHERE b.enterprise_id = ? AND b.status IN ('pending', 'processing') AND b.created_at <= ?
          ORDER BY b.created_at ASC`
      )
      .all(req.user.enterpriseId, Date.now() - REVIEW_AFTER_MS);

    return res.json({
      ok: true,
      transfers: rows.map((r) => ({
        transferId: r.transfer_id,
        reference: r.reference,
        gatewayId: r.gateway_id || null,
        provider: r.provider || "bazik",
        network: r.network,
        status: r.status,
        /** Pa gen ID Bazik ak Bazik pa jwenn li: sèlman yon moun ka deside. */
        manualReview: !r.gateway_id && r.gateway_status === "manual_review",
        amountHtg: money.fromMinor(r.amount_htg_minor),
        amount: money.fromMinor(r.amount_minor),
        currency: r.currency,
        debit: money.fromMinor(r.debit_minor),
        walletCurrency: r.wallet_currency,
        phone: r.phone,
        receiverName: r.receiver_name || r.client_name || "",
        staffName: r.staff_name || "",
        txId: r.tx_id || null,
        txStatus: r.tx_status || null,
        createdAt: r.created_at,
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

/**
 * Owner a deside sò yon transfè bloke.
 *
 *   { action: "completed", gatewayId: "…", note }  lajan an pati: ID Bazik la
 *       OBLIGATWA, e Bazik dwe konfime l `completed` — pa gen livrezon sou
 *       pawòl sèlman.
 *   { action: "failed", note }  lajan an pa janm pati: ajan an ranbouse
 *       (montan + frè). Refize si tranzaksyon an deja make livre.
 *
 * Yon sèl desizyon pa transfè (`transfer_resolutions`), ak non moun nan ak rezon an.
 */
router.post("/transfers/:id/resolve", requireAuth, requireEnterprise, requireRole("owner"), async (req, res) => {
  try {
    const service = getBazikService();
    const db = service.store._db;
    const body = req.body || {};
    const action = body.action === "completed" ? "completed" : body.action === "failed" ? "failed" : null;
    const note = String(body.note || "").trim();
    const gatewayId = String(body.gatewayId || "").trim();

    if (!action) return send(res, { code: "invalid_action", message: "Chwazi: livre oswa echwe." });
    if (note.length < 5) {
      return send(res, { code: "note_required", message: "Ekri poukisa (omwen 5 karaktè): se tras desizyon an." });
    }

    const transfer = await service.store.getTransfer(req.params.id);
    if (!transfer || transfer.enterpriseId !== req.user.enterpriseId) {
      return res.status(404).json({ ok: false, code: "transfer_not_found" });
    }
    if (transfer.status === "completed" || transfer.status === "failed") {
      return res.status(409).json({ ok: false, code: "transfer_closed", message: `Transfè sa a deja ${transfer.status}.` });
    }

    let bazikStatus = null;
    if (gatewayId) {
      const other = db
        .prepare("SELECT transfer_id FROM bazik_transfers WHERE gateway_id = ? AND transfer_id != ?")
        .get(gatewayId, transfer.transferId);
      if (other) {
        return res.status(409).json({
          ok: false,
          code: "gateway_id_taken",
          message: "ID Bazik sa a deja lye ak yon lòt transfè.",
        });
      }
      try {
        bazikStatus = (await service.client.transferStatus(gatewayId)).status;
      } catch (err) {
        if (err instanceof BazikError && err.status === 404) {
          return send(res, { code: "gateway_id_unknown", message: "Bazik pa konnen ID sa a. Verifye l sou dashboard la." });
        }
        throw err;
      }
    }

    if (action === "completed") {
      if (!gatewayId) {
        return send(res, { code: "gateway_id_required", message: "Mete ID transfè a jan li parèt sou dashboard Bazik la." });
      }
      if (bazikStatus !== "completed") {
        return res.status(409).json({
          ok: false,
          code: "bazik_not_completed",
          message: `Bazik di transfè sa a "${bazikStatus}", pa livre.`,
        });
      }
    } else {
      if (bazikStatus === "completed") {
        return res.status(409).json({
          ok: false,
          code: "bazik_completed",
          message: "Bazik di lajan sa a PATI: li pa ka make echwe ni ranbouse.",
        });
      }
      const tx = transfer.txId
        ? db.prepare("SELECT status FROM transactions WHERE tx_id = ?").get(transfer.txId)
        : null;
      if (tx?.status === "delivered") {
        return res.status(409).json({
          ok: false,
          code: "transaction_delivered",
          message: "Tranzaksyon an deja make livre (komisyon ka deja peye): konfime l ak ID Bazik la oswa kontakte sipò.",
        });
      }
    }

    const claimed = db
      .prepare(
        `INSERT INTO transfer_resolutions
          (transfer_id, enterprise_id, action, gateway_id, note, resolved_by, resolved_at)
         VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(transfer_id) DO NOTHING`
      )
      .run(transfer.transferId, req.user.enterpriseId, action, gatewayId, note, req.user.uid, Date.now());
    if (claimed.changes !== 1) {
      return res.status(409).json({ ok: false, code: "already_resolved", message: "Yon lòt moun deja deside pou transfè sa a." });
    }

    const settled = await service.store.settleTransfer({
      transferId: transfer.transferId,
      status: action,
      gatewayId,
      gatewayStatus: action === "completed" ? "manual_confirmed" : "manual_failed",
      failureReason: action === "failed" ? `Rekonsilye alamen: ${note}` : "",
    });

    await settleCommissions(req.user.enterpriseId);

    return res.json({
      ok: true,
      transfer: { transferId: settled.transfer.transferId, status: settled.transfer.status },
      refunded: settled.refund
        ? { amount: money.fromMinor(transfer.debitMinor), currency: transfer.walletCurrency }
        : null,
    });
  } catch (err) {
    return send(res, err);
  }
});

router.get("/transfers/:id", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const service = getBazikService();
    const transfer = await service.store.getTransfer(req.params.id);

    if (!ownedOr404(res, transfer, req)) return;
    return res.json({ ok: true, transfer });
  } catch (err) {
    return send(res, err);
  }
});

/** Mande Bazik kote transfè a ye (filè sekirite si webhook la pèdi). */
router.post("/transfers/:id/refresh", requireAuth, requireEnterprise, async (req, res) => {
  try {
    const service = getBazikService();
    const transfer = await service.store.getTransfer(req.params.id);

    // `refresh` ka deklanche yon ranbousman: pa sou transfè yon lòt antrepriz.
    if (!ownedOr404(res, transfer, req)) return;

    const refreshed = await service.transfers.refresh(req.params.id);
    await settleCommissions(req.user.enterpriseId);
    return res.json({ ok: true, ...refreshed });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/transfers/poll", requireAuth, requireRole("owner", "admin"), async (req, res) => {
  try {
    const service = getBazikService();
    const updated = await service.transfers.pollPending();
    await settleCommissions(null);
    return res.json({ ok: true, updated });
  } catch (err) {
    return send(res, err);
  }
});

// --- Rechaj (cash-in) ---

router.post("/topups", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const { uid, enterpriseId } = req.user;
    const service = getBazikService();
    const body = req.body || {};

    const result = await service.topups.create({
      targetUid: body.targetUid || uid,
      targetName: body.targetName || "",
      targetEmail: body.targetEmail || "",
      enterpriseId,
      amountMinor: amountMinorFrom(body),
      currency: body.currency,
      phone: body.phone || "",
      note: body.note || "",
      requestedBy: uid,
      idempotencySeed: body.idempotencySeed || "",
    });

    return res.json({ ok: true, ...result });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/topups/:id/verify", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const service = getBazikService();
    const topup = await service.store.getTopup(req.params.id);

    if (!ownedOr404(res, topup, req)) return;
    return res.json({ ok: true, ...(await service.topups.verify(req.params.id)) });
  } catch (err) {
    return send(res, err);
  }
});

// --- Webhook ---

/**
 * Bazik rele wout sa a. Siyati a verifye sou kò a TEL KEL li rive
 * (`req.rawBody`, mete la pa `express.json({ verify })` nan index.js).
 */
router.post("/webhook", async (req, res) => {
  try {
    const service = getBazikService();

    const result = await service.webhooks.handle({
      rawBody: req.rawBody || JSON.stringify(req.body || {}),
      headers: req.headers,
    });

    await settleCommissions(null);
    return res.json({ ok: true, ...result });
  } catch (err) {
    // Nou reponn 400 sou yon siyati ki pa bon: Bazik pa dwe re-eseye.
    if (err instanceof DomainError) {
      console.warn("[bazik] webhook refize:", err.code, err.message);
      return res.status(400).json({ ok: false, code: err.code, message: err.message });
    }
    return send(res, err);
  }
});

module.exports = router;
