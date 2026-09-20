"use strict";

/**
 * Tranzaksyon yo — ranplase koleksyon Firestore `transactions`.
 *
 *   GET    /api/transactions            lis (limit, status)
 *   GET    /api/transactions/stats      total / pending / delivered / volim
 *   GET    /api/transactions/:id
 *   POST   /api/transactions            kreye
 *   PATCH  /api/transactions/:id        chanje estati
 *   DELETE /api/transactions/:id        owner sèlman
 *
 * Tout wout yo limite sou antrepriz moun k ap rele a. Yon admin pa ka wè
 * tranzaksyon yon lòt antrepriz, menm si li konnen ID a.
 *
 * YON TRANZAKSYON `delivered` FÈMEN: pèsonn pa ka efase l ni remèt li
 * `pending`. Lajan an deja pati (oswa yon moun deklare livrezon an), komisyon
 * yo aplike, e liy rejis yo pwente sou li. Sèl SISTÈM lan ka chanje l ankò:
 * rekonsilyasyon pasrèl la (`settleTransfer`, `settleTopup`) ki ekri dirèkteman
 * nan baz la lè Bazik oswa Reloadly di yon transfè echwe apre tou.
 */

const express = require("express");

const { getDb, now } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money } = require("../../../bazik/index.js");
const AppIds = require("../../../bazik/src/ids");
const { computeCommission, applyCommissionToTx } = require("../commission/engine");

const router = express.Router();

/** Estati yon tranzaksyon ka pran. */
const STATUSES = ["pending", "sending", "delivered", "failed", "canceled"];

/**
 * Yon tranzaksyon lye ak lajan k ap deplase (oswa ki deplase): efase l ta kite
 * transfè a oswa rechaj la san tranzaksyon, epi rejis la san esplikasyon.
 */
function linkedMoney(db, txId) {
  const transfer = db
    .prepare("SELECT status FROM bazik_transfers WHERE tx_id = ? AND status IN ('pending','processing','completed') LIMIT 1")
    .get(txId);
  if (transfer) return `yon transfè Bazik (${transfer.status})`;

  const topup = db
    .prepare("SELECT status FROM airtime_topups WHERE tx_id = ? AND status IN ('processing','completed') LIMIT 1")
    .get(txId);
  if (topup) return `yon rechaj minit (${topup.status})`;

  return null;
}

/**
 * Konvèsyon an pou resi a: to echanj lan ak sa benefisyè a resevwa an gouden.
 *
 * Tab `transactions` la kenbe montan an nan deviz kliyan an (MXN, USD...).
 * Benefisyè a, li menm, resevwa gouden: se liy `bazik_transfers` la ki gen to
 * jou a ak montan HTG la.
 *
 * To a soti nan liy lan, PA nan tab to jounen an: yon to ki chanje demen pa
 * dwe chanje yon resi ki deja enprime.
 *
 * NOU PA VOYE FRÈ PASRÈL LA. Se yon depans antrepriz la, kliyan an pa gen
 * anyen pou wè ladan l, e montre l sou yon resi ta fè l kwè se nan lajan pa l
 * li soti. Frè resi a montre se `sender_fee_minor`, sa anvwayè a peye vre.
 *
 * Retounen `null` pou yon tranzaksyon ki pa gen transfè (rechaj minit,
 * livrezon an lajan kach deklare alamen).
 */
function deliveryOf(db, txId) {
  const row = db
    .prepare(
      `SELECT * FROM bazik_transfers
        WHERE tx_id = ? AND status != 'failed'
        ORDER BY created_at DESC LIMIT 1`
    )
    .get(txId);

  if (!row) return null;

  return {
    network: row.network,
    /** Sa benefisyè a resevwa nan men l, an gouden. */
    amountHtg: money.fromMinor(row.amount_htg_minor),
    /** Konbyen HTG 1 inite deviz tranzaksyon an te vo lè transfè a fèt. */
    rateToHtg: row.rate_to_htg,
    rateCurrency: row.currency,
    ratesUpdatedAt: row.rates_updated_at,
  };
}

function send(res, err) {
  const status = err.status || 400;
  if (status >= 500) console.error("[transactions]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "error",
    message: err.message,
  });
}

/** Fòm JSON yon tranzaksyon — menm non chan ak sa app la te li nan Firestore. */
function toJson(row) {
  if (!row) return null;

  return {
    txId: row.tx_id,
    transactionId: row.tx_id,
    serviceName: row.service,
    serviceId: row.service_id || "",
    customerName: row.client_name || "",
    customerPhone: row.phone || "",
    country: row.country || "",
    /** Sa benefisyè a resevwa. */
    paymentAmount: money.fromMinor(row.amount_minor),
    paymentCurrency: row.currency,
    /** Frè anvwayè a peye anplis (0 = san frè). */
    senderFee: money.fromMinor(row.sender_fee_minor || 0),
    /** Sa anvwayè a soti nan pòch li an tou. */
    totalPaid: money.fromMinor(row.amount_minor + (row.sender_fee_minor || 0)),
    status: row.status,
    enterpriseId: row.enterprise_id,
    enterpriseName: row.enterprise_name || "",
    staffUid: row.staff_uid,
    staffName: row.staff_name || "",
    staffRole: row.staff_role || "",
    gatewayRef: row.gateway_ref || "",
    commissionApplied: row.commission_applied === 1,
    commissionAgent: money.fromMinor(row.commission_agent_minor || 0),
    commissionOwner: money.fromMinor(row.commission_owner_minor || 0),
    note: row.note || "",
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// --- Estatistik ---

/**
 * Estatistik sou TOUT antrepriz la, pa sèlman dènye paj la.
 *
 * (Ansyen dashboard la te kalkile sou 10 dènye tranzaksyon yo epi li te rele
 * sa "Transactions" — chif la pa t janm depase 10.)
 */
router.get("/stats", requireAuth, requireEnterprise, (req, res) => {
  try {
    const db = getDb();
    const enterpriseId = req.user.enterpriseId;

    const total = db
      .prepare("SELECT COUNT(*) AS n FROM transactions WHERE enterprise_id = ?")
      .get(enterpriseId).n;

    const delivered = db
      .prepare(
        "SELECT COUNT(*) AS n FROM transactions WHERE enterprise_id = ? AND status = 'delivered'"
      )
      .get(enterpriseId).n;

    const failed = db
      .prepare(
        "SELECT COUNT(*) AS n FROM transactions WHERE enterprise_id = ? AND status IN ('failed','canceled')"
      )
      .get(enterpriseId).n;

    // Volim pa deviz: adisyone USD ak HTG ansanm pa vle di anyen.
    const volumes = {};
    const rows = db
      .prepare(
        `SELECT currency, SUM(amount_minor) AS total
           FROM transactions WHERE enterprise_id = ? GROUP BY currency`
      )
      .all(enterpriseId);

    for (const row of rows) {
      if (row.total) volumes[row.currency] = money.fromMinor(row.total);
    }

    return res.json({
      ok: true,
      stats: {
        total,
        delivered,
        failed,
        pending: total - delivered - failed,
        volumes,
      },
    });
  } catch (err) {
    return send(res, err);
  }
});

// --- Lis ---

router.get("/", requireAuth, requireEnterprise, (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 25, 200);
    const status = String(req.query.status || "").trim();

    const filters = ["enterprise_id = ?"];
    const params = [req.user.enterpriseId];

    if (status && STATUSES.includes(status)) {
      filters.push("status = ?");
      params.push(status);
    }

    // Yon ajan wè pwòp tranzaksyon li sèlman.
    if (req.user.role === "agent") {
      filters.push("staff_uid = ?");
      params.push(req.user.uid);
    }

    const rows = getDb()
      .prepare(
        `SELECT * FROM transactions WHERE ${filters.join(" AND ")}
          ORDER BY created_at DESC LIMIT ?`
      )
      .all(...params, limit);

    return res.json({ ok: true, transactions: rows.map(toJson) });
  } catch (err) {
    return send(res, err);
  }
});

router.get("/:id", requireAuth, requireEnterprise, (req, res) => {
  try {
    const row = getDb()
      .prepare("SELECT * FROM transactions WHERE tx_id = ? AND enterprise_id = ?")
      .get(req.params.id, req.user.enterpriseId);

    if (!row) {
      return res.status(404).json({ ok: false, code: "not_found" });
    }

    return res.json({
      ok: true,
      transaction: toJson(row),
      delivery: deliveryOf(getDb(), row.tx_id),
    });
  } catch (err) {
    return send(res, err);
  }
});

// --- Kreye ---

router.post("/", requireAuth, requireEnterprise, (req, res) => {
  try {
    const body = req.body || {};

    const serviceName = String(body.serviceName || "").trim();
    const customerPhone = String(body.customerPhone || "").trim();

    if (!serviceName) {
      return send(res, { code: "missing_service", message: "Sèvis la obligatwa." });
    }

    let amountMinor;
    try {
      amountMinor = money.toMinor(body.paymentAmount);
    } catch (err) {
      return send(res, { code: "invalid_amount", message: err.message });
    }

    const txId = AppIds.transaction(
      `${serviceName}:${customerPhone}:${req.user.uid}:${Date.now()}`
    );

    // Frè anvwayè a: opsyonèl, 0 pa defo.
    //
    // Li PA antre nan kalkil komisyon an: komisyon yo rete sou montan
    // benefisyè a resevwa a, jan yo te ye anvan.
    let senderFeeMinor = 0;
    if (body.senderFee !== undefined && body.senderFee !== null && `${body.senderFee}` !== "") {
      try {
        senderFeeMinor = money.toMinor(body.senderFee);
      } catch (err) {
        return send(res, { code: "invalid_fee", message: `Frè a pa valid: ${err.message}` });
      }
      if (senderFeeMinor < 0) {
        return send(res, { code: "invalid_fee", message: "Frè a pa ka negatif." });
      }
    }

    // To komisyon an fikse KOUNYE A: si yon admin chanje to sèvis la pita, sa
    // pa modifye retwoaktivman sa tranzaksyon sa a te pwomèt.
    const commission = computeCommission({ amountMinor, serviceName });

    // `enterprise_id` ak `staff_uid` toujou soti nan sesyon an, jamè nan kò a:
    // yon kliyan pa ka atribiye yon tranzaksyon bay yon lòt antrepriz.
    getDb()
      .prepare(
        `INSERT INTO transactions
          (tx_id, enterprise_id, enterprise_name, staff_uid, staff_name, staff_role,
           client_name, phone, service, service_id, country, amount_minor, currency,
           sender_fee_minor,
           status, gateway_ref, commission_applied, note, created_at, updated_at,
           commission_agent_minor, commission_owner_minor,
           agent_commission_pct, owner_commission_pct)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', '', 0, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        txId,
        req.user.enterpriseId,
        req.user.enterpriseName,
        req.user.uid,
        req.user.displayName,
        req.user.role,
        String(body.customerName || "").trim(),
        customerPhone,
        serviceName,
        String(body.serviceId || "").trim(),
        String(body.country || "").trim(),
        amountMinor,
        String(body.paymentCurrency || "USD").trim().toUpperCase(),
        senderFeeMinor,
        String(body.note || "").trim(),
        now(),
        now(),
        commission.agentMinor,
        commission.ownerMinor,
        commission.agentPct,
        commission.ownerPct
      );

    const row = getDb().prepare("SELECT * FROM transactions WHERE tx_id = ?").get(txId);
    return res.json({ ok: true, transaction: toJson(row) });
  } catch (err) {
    return send(res, err);
  }
});

// --- Chanje estati ---

/**
 * Chanje estati yon tranzaksyon — owner/admin sèlman.
 *
 * Yon ajan pa dwe ka make pwòp tranzaksyon li `delivered`: se sa ki deklanche
 * komisyon yo. Li ta vle di ajan an valide pwòp livrezon li epi li peye tèt li.
 *
 * Chemen nòmal ajan an se "Livre via Bazik": la, se konfimasyon Bazik ki fè
 * estati a chanje, sèvè-bò, pa yon klik.
 */
router.patch("/:id", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const status = String(req.body?.status || "").trim();

    if (!STATUSES.includes(status)) {
      return send(res, {
        code: "invalid_status",
        message: `Estati a dwe youn nan: ${STATUSES.join(", ")}.`,
      });
    }

    const row = getDb()
      .prepare("SELECT * FROM transactions WHERE tx_id = ? AND enterprise_id = ?")
      .get(req.params.id, req.user.enterpriseId);

    if (!row) return res.status(404).json({ ok: false, code: "not_found" });

    // Yon livrezon konfime pa retounen an `pending` sou yon klik: komisyon yo
    // deja peye, e yon dezyèm livrezon ta voye lajan an de fwa.
    if (row.status === "delivered") {
      return res.status(409).json({
        ok: false,
        code: "transaction_closed",
        message:
          "Tranzaksyon sa a livre: li pa ka chanje ankò. Sèl rekonsilyasyon " +
          "pasrèl la ka make l otreman.",
      });
    }

    getDb()
      .prepare("UPDATE transactions SET status = ?, note = ?, updated_at = ? WHERE tx_id = ?")
      .run(status, String(req.body?.note ?? row.note ?? ""), now(), req.params.id);

    // Livrezon konfime: komisyon an aplike tou swit (idempotan).
    let commission = null;
    if (status === "delivered") {
      commission = await applyCommissionToTx(req.params.id);
    }

    const updated = getDb()
      .prepare("SELECT * FROM transactions WHERE tx_id = ?")
      .get(req.params.id);

    return res.json({ ok: true, transaction: toJson(updated), commission });
  } catch (err) {
    return send(res, err);
  }
});

router.delete("/:id", requireAuth, requireEnterprise, requireRole("owner"), (req, res) => {
  try {
    const db = getDb();
    const row = db
      .prepare("SELECT status FROM transactions WHERE tx_id = ? AND enterprise_id = ?")
      .get(req.params.id, req.user.enterpriseId);

    if (!row) return res.status(404).json({ ok: false, code: "not_found" });

    if (row.status === "delivered") {
      return res.status(409).json({
        ok: false,
        code: "transaction_closed",
        message: "Tranzaksyon sa a livre: li pa ka efase. Se tras livrezon an ak komisyon yo.",
      });
    }

    const linked = linkedMoney(db, req.params.id);
    if (linked) {
      return res.status(409).json({
        ok: false,
        code: "transaction_has_money",
        message: `Tranzaksyon sa a lye ak ${linked}: li pa ka efase.`,
      });
    }

    db.prepare("DELETE FROM transactions WHERE tx_id = ? AND enterprise_id = ?")
      .run(req.params.id, req.user.enterpriseId);

    return res.json({ ok: true });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = router;
