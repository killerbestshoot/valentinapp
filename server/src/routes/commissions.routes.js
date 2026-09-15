"use strict";

/**
 * Komisyon ak katalòg sèvis.
 *
 *   GET   /api/commissions              jounal komisyon antrepriz la
 *   GET   /api/commissions/summary      total pa staff
 *   POST  /api/commissions/run          aplike komisyon an reta yo
 *   GET   /api/services                 katalòg la (ak to yo)
 *   PATCH /api/services/:id             chanje to / aktive (owner)
 */

const express = require("express");

const { getDb, now } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { applyPendingCommissions } = require("../commission/engine");
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

    getDb()
      .prepare(
        `UPDATE services SET commission_agent_pct = ?, commission_owner_pct = ?,
           is_active = ?, updated_at = ? WHERE service_id = ?`
      )
      .run(agentPct, ownerPct, isActive, now(), req.params.id);

    const updated = getDb().prepare("SELECT * FROM services WHERE service_id = ?").get(req.params.id);
    return res.json({ ok: true, service: serviceJson(updated) });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = { commissions, services };
