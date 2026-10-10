"use strict";

/**
 * Komisyon ak katalòg sèvis.
 *
 *   GET   /api/commissions              jounal komisyon antrepriz la
 *   GET   /api/commissions/summary      total pa staff
 *   GET   /api/commissions/live         komisyon tout ajan yo an dirèk (owner/admin)
 *   POST  /api/commissions/run          aplike komisyon an reta yo
 *   GET   /api/services                 katalòg la (ak to yo)
 *   PATCH /api/services/:id             chanje frè / pati ajan / aktive (owner)
 */

const express = require("express");

const { getDb, now } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { applyPendingCommissions } = require("../commission/engine");
const { validateFeePolicy, ownerMarginPct, GATEWAY_COST_PCT } = require("../commission/fees");
const { getBazikService } = require("../bazik_service");
const { money } = require("../../../bazik/index.js");

const commissions = express.Router();
const services = express.Router();

function send(res, err) {
  const status = err.status || 400;
  if (status >= 500) console.error("[commissions]", err);
  return res.status(status).json({ ok: false, code: err.code || "error", message: err.message });
}

// --- Komisyon ---

commissions.get("/", requireAuth, requireEnterprise, (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 200);

    const filters = ["c.enterprise_id = ?"];
    const params = [req.user.enterpriseId];

    // Yon ajan wè pwòp komisyon li sèlman.
    if (req.user.role === "agent" || req.user.role === "client") {
      filters.push("c.staff_uid = ?");
      params.push(req.user.uid);
    }

    const rows = getDb()
      .prepare(
        `SELECT c.*, u.display_name AS staff_name
           FROM commission_logs c
           LEFT JOIN users u ON u.uid = c.staff_uid
          WHERE ${filters.join(" AND ")}
          ORDER BY c.created_at DESC LIMIT ?`
      )
      .all(...params, limit);

    return res.json({
      ok: true,
      commissions: rows.map((row) => ({
        txId: row.tx_id,
        staffUid: row.staff_uid,
        staffName: row.staff_name || "",
        service: row.service,
        txAmount: money.fromMinor(row.tx_amount_minor),
        txCurrency: row.tx_currency,
        agentPct: row.agent_pct,
        ownerPct: row.owner_pct,
        agentCommission: money.fromMinor(row.agent_minor),
        ownerCommission: money.fromMinor(row.owner_minor),
        createdAt: row.created_at,
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

/** Total komisyon ajan pa staff, pa deviz tranzaksyon. */
commissions.get("/summary", requireAuth, requireEnterprise, requireRole("owner", "admin"), (req, res) => {
  try {
    const rows = getDb()
      .prepare(
        `SELECT c.staff_uid, u.display_name, c.tx_currency,
                COUNT(*) AS count,
                SUM(c.agent_minor) AS agent_total,
                SUM(c.owner_minor) AS owner_total
           FROM commission_logs c
           LEFT JOIN users u ON u.uid = c.staff_uid
          WHERE c.enterprise_id = ?
          GROUP BY c.staff_uid, c.tx_currency
          ORDER BY agent_total DESC`
      )
      .all(req.user.enterpriseId);

    return res.json({
      ok: true,
      summary: rows.map((row) => ({
        staffUid: row.staff_uid,
        staffName: row.display_name || "",
        currency: row.tx_currency,
        count: row.count,
        agentTotal: money.fromMinor(row.agent_total || 0),
        ownerTotal: money.fromMinor(row.owner_total || 0),
      })),
    });
  } catch (err) {
    return send(res, err);
  }
});

/**
 * Komisyon tout ajan yo, an dirèk — ekran owner a rele sa chak kèk segonn.
 *
 *   ?days=1|7|30   peryòd la (1 = jodi a depi minwi)
 *   ?currency=HTG  deviz pou total yo (chak liy konvèti ak to jounen an)
 *
 * `earned` = tranzaksyon livre (komisyon deja nan wallet yo).
 * `pending` = tranzaksyon an chemen: komisyon pwomèt, ap peye lè yo livre.
 */
commissions.get("/live", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const db = getDb();
    const ent = req.user.enterpriseId;
    const days = [1, 7, 30].includes(Number(req.query.days)) ? Number(req.query.days) : 1;
    const display = String(req.query.currency || "HTG").toUpperCase();
    const rates = getBazikService().rates;

    const start = new Date();
    start.setHours(0, 0, 0, 0);
    start.setDate(start.getDate() - (days - 1));
    const since = start.getTime();

    const conv = async (minor, from) =>
      !minor || from === display ? minor || 0 : (await rates.convert(minor, from, display)).amountMinor;

    const earnedRows = db
      .prepare(
        `SELECT c.staff_uid, c.tx_currency AS currency, COUNT(*) AS count,
                SUM(c.tx_amount_minor) AS volume, SUM(c.fee_minor) AS fee,
                SUM(c.agent_minor) AS agent, SUM(c.owner_minor) AS owner_gross,
                SUM(c.gateway_cost_minor) AS gateway, SUM(c.owner_net_minor) AS owner_net,
                MAX(c.created_at) AS last_at
           FROM commission_logs c
          WHERE c.enterprise_id = ? AND c.created_at >= ?
          GROUP BY c.staff_uid, c.tx_currency`
      )
      .all(ent, since);

    const pendingRows = db
      .prepare(
        `SELECT staff_uid, currency, COUNT(*) AS count,
                SUM(commission_agent_minor) AS agent, SUM(commission_owner_minor) AS owner_gross
           FROM transactions
          WHERE enterprise_id = ? AND fee_mode != '' AND commission_applied = 0
            AND status IN ('pending', 'sending') AND created_at >= ?
          GROUP BY staff_uid, currency`
      )
      .all(ent, since);

    const staff = new Map();
    const names = db
      .prepare(
        `SELECT eu.uid, COALESCE(NULLIF(u.display_name, ''), eu.display_name, eu.email) AS name, eu.role
           FROM enterprise_users eu LEFT JOIN users u ON u.uid = eu.uid
          WHERE eu.enterprise_id = ? AND eu.is_active = 1 AND eu.role != 'owner'`
      )
      .all(ent);
    const blank = (uid, name = "", role = "agent") => ({
      staffUid: uid, staffName: name, role, count: 0, volume: 0, fee: 0, agent: 0,
      ownerGross: 0, gatewayCost: 0, ownerNet: 0, pendingCount: 0, pendingAgent: 0,
      pendingOwner: 0, lastAt: null,
    });
    for (const n of names) staff.set(n.uid, blank(n.uid, n.name, n.role));

    for (const r of earnedRows) {
      const s = staff.get(r.staff_uid) || blank(r.staff_uid);
      s.count += r.count;
      s.volume += await conv(r.volume, r.currency);
      s.fee += await conv(r.fee, r.currency);
      s.agent += await conv(r.agent, r.currency);
      s.ownerGross += await conv(r.owner_gross, r.currency);
      s.gatewayCost += await conv(r.gateway, r.currency);
      s.ownerNet += await conv(r.owner_net, r.currency);
      s.lastAt = Math.max(s.lastAt || 0, r.last_at);
      staff.set(r.staff_uid, s);
    }
    for (const r of pendingRows) {
      const s = staff.get(r.staff_uid) || blank(r.staff_uid);
      s.pendingCount += r.count;
      s.pendingAgent += await conv(r.agent, r.currency);
      s.pendingOwner += await conv(r.owner_gross, r.currency);
      staff.set(r.staff_uid, s);
    }

    const fromMinor = (m) => money.fromMinor(Math.round(m || 0));
    const agents = [...staff.values()]
      .sort((a, b) => b.agent - a.agent || b.count - a.count)
      .map((s) => ({
        staffUid: s.staffUid,
        staffName: s.staffName,
        role: s.role,
        count: s.count,
        volume: fromMinor(s.volume),
        fee: fromMinor(s.fee),
        agentCommission: fromMinor(s.agent),
        ownerGross: fromMinor(s.ownerGross),
        gatewayCost: fromMinor(s.gatewayCost),
        ownerNet: fromMinor(s.ownerNet),
        pendingCount: s.pendingCount,
        pendingAgent: fromMinor(s.pendingAgent),
        pendingOwner: fromMinor(s.pendingOwner),
        lastAt: s.lastAt,
      }));

    const sum = (k) => fromMinor([...staff.values()].reduce((t, s) => t + s[k], 0));

    const recent = db
      .prepare(
        `SELECT c.tx_id, c.staff_uid, c.service, c.tx_currency, c.fee_minor, c.agent_minor,
                c.owner_net_minor, c.created_at,
                COALESCE(NULLIF(u.display_name, ''), '') AS staff_name
           FROM commission_logs c LEFT JOIN users u ON u.uid = c.staff_uid
          WHERE c.enterprise_id = ?
          ORDER BY c.created_at DESC LIMIT 15`
      )
      .all(ent)
      .map((r) => ({
        txId: r.tx_id,
        staffUid: r.staff_uid,
        staffName: r.staff_name,
        service: r.service,
        currency: r.tx_currency,
        fee: money.fromMinor(r.fee_minor),
        agentCommission: money.fromMinor(r.agent_minor),
        ownerNet: money.fromMinor(r.owner_net_minor),
        createdAt: r.created_at,
      }));

    return res.json({
      ok: true,
      days,
      currency: display,
      since,
      serverTime: Date.now(),
      totals: {
        count: [...staff.values()].reduce((t, s) => t + s.count, 0),
        volume: sum("volume"),
        fee: sum("fee"),
        agentCommission: sum("agent"),
        ownerGross: sum("ownerGross"),
        gatewayCost: sum("gatewayCost"),
        ownerNet: sum("ownerNet"),
        pendingAgent: sum("pendingAgent"),
        pendingOwner: sum("pendingOwner"),
      },
      agents,
      recent,
    });
  } catch (err) {
    return send(res, err);
  }
});

commissions.post("/run", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    // Limite sou antrepriz moun nan: ansyen `runCommissionNow` te lanse pou
    // TOUT antrepriz yo, e li te retounen txId tout antrepriz yo nan erè yo.
    const results = await applyPendingCommissions({
      enterpriseId: req.user.enterpriseId,
      limit: 200,
    });

    return res.json({
      ok: true,
      applied: results.filter((r) => r.status === "applied").length,
      skipped: results.filter((r) => r.status === "skipped").length,
      errors: results.filter((r) => r.status === "error").length,
      results,
    });
  } catch (err) {
    return send(res, err);
  }
});

// --- Sèvis ---

function serviceJson(row) {
  return {
    serviceId: row.service_id,
    name: row.name,
    code: row.code,
    network: row.network,
    gatewayBacked: Boolean(row.network),
    isActive: row.is_active === 1,
    agentCommissionPct: row.commission_agent_pct,
    ownerCommissionPct: row.commission_owner_pct,
    /** Frè platfòm nan, an % montan an. */
    feePct: row.fee_pct,
    /** Frè minimòm, an HTG (konvèti nan deviz tranzaksyon an). */
    feeMinHtg: money.fromMinor(row.fee_min_htg_minor || 0),
    /** Pati ajan an NAN FRÈ A. Owner a pran rès la. */
    agentSharePct: row.agent_share_pct,
    /** Estimasyon frè pasrèl la, an % montan an. */
    gatewayCostPct: GATEWAY_COST_PCT[row.network] || 0,
    /** Sa owner a kenbe an % montan an apre ajan an ak pasrèl la. */
    ownerMarginPct: ownerMarginPct({ feePct: row.fee_pct, agentSharePct: row.agent_share_pct, network: row.network }),
  };
}

services.get("/", requireAuth, (req, res) => {
  try {
    const rows = getDb().prepare("SELECT * FROM services ORDER BY name").all();
    return res.json({ ok: true, services: rows.map(serviceJson) });
  } catch (err) {
    return send(res, err);
  }
});

services.patch("/:id", requireAuth, requireRole("owner"), (req, res) => {
  try {
    const body = req.body || {};
    const row = getDb().prepare("SELECT * FROM services WHERE service_id = ?").get(req.params.id);
    if (!row) return res.status(404).json({ ok: false, code: "not_found" });

    const pct = (value, fallback) => {
      if (value === undefined) return fallback;
      const n = Number(value);
      // Yon to negatif oswa > 100% pa gen sans, e li ta kreye oswa detwi lajan.
      if (!Number.isFinite(n) || n < 0 || n > 100) {
        throw Object.assign(new Error("To a dwe ant 0 ak 100."), { code: "invalid_pct" });
      }
      return n;
    };

    const agentPct = pct(body.agentCommissionPct, row.commission_agent_pct);
    const ownerPct = pct(body.ownerCommissionPct, row.commission_owner_pct);
    const isActive = body.isActive === undefined ? row.is_active : body.isActive ? 1 : 0;
    const policy = validateFeePolicy(
      { feePct: body.feePct, feeMinHtg: body.feeMinHtg, agentSharePct: body.agentSharePct },
      { feePct: row.fee_pct, feeMinHtgMinor: row.fee_min_htg_minor, agentSharePct: row.agent_share_pct }
    );

    getDb()
      .prepare(
        `UPDATE services SET commission_agent_pct = ?, commission_owner_pct = ?,
           fee_pct = ?, fee_min_htg_minor = ?, agent_share_pct = ?,
           is_active = ?, updated_at = ? WHERE service_id = ?`
      )
      .run(agentPct, ownerPct, policy.feePct, policy.feeMinHtgMinor, policy.agentSharePct,
        isActive, now(), req.params.id);

    const updated = getDb().prepare("SELECT * FROM services WHERE service_id = ?").get(req.params.id);
    return res.json({ ok: true, service: serviceJson(updated) });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = { commissions, services };
