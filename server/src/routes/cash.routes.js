"use strict";

/**
 * Fèmti kès — kontwòl kach ajan yo, chak jou, pa deviz.
 *
 *   GET  /api/cash/expected?date=&uid=     kès atann: fon + lavant (sèvè a kalkile)
 *   POST /api/cash/closings                ajan an voye fèmti li: { date, lines, note }
 *   GET  /api/cash/closings?from=&to=&uid=&status=
 *   GET  /api/cash/closings.csv?from=&to=  owner/admin: ekspòtasyon pou kontab la
 *   POST /api/cash/closings/:id/validate   owner/admin: fèmen jounen an
 *   POST /api/cash/closings/:id/reject     owner/admin: voye l tounen bay ajan an
 *
 * KALKIL: kès atann = fon kès + lavant − depo bay pwopriyetè a.
 *   - lavant = sa kliyan yo peye an kach (montan + frè), nan deviz tranzaksyon
 *     an, pou tranzaksyon ajan an kreye jou sa a (lè Ayiti)
 *   - tranzaksyon `failed` / `canceled` pa konte: kliyan an te ranbouse
 *   - lavant yo PA janm soti nan kò demann lan: sèvè a rekalkile yo chak fwa
 *
 * Yon ekar (kach konte − kès atann) mande yon nòt. Yon fèmti `validated`
 * fèmen nèt; yon fèmti `rejected` ajan an ka refè l.
 */

const express = require("express");

const { getDb, now } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money } = require("../../../bazik/index.js");
const AppIds = require("../../../bazik/src/ids");

const router = express.Router();

const TZ = process.env.ANALYTICS_TZ || "America/Port-au-Prince";
const DAY = 86400000;
/** Tranzaksyon kote kliyan an kenbe kòb li: pa nan kès la. */
const REFUNDED = new Set(["failed", "canceled"]);
const MAX_RANGE_DAYS = 92;

const dateFmt = new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" });
const localDate = (ms) => dateFmt.format(new Date(ms));

function send(res, err) {
  const status = err.status || (err instanceof Error ? 500 : 400);
  if (status >= 500) console.error("[cash]", err);
  return res.status(status).json({ ok: false, code: err.code || "error", message: err.message });
}

const isManager = (user) => user.role === "owner" || user.role === "admin" || user.role === "administrator";

function parseDate(raw, fallback) {
  const value = String(raw || fallback || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(`${value}T12:00:00Z`))) {
    throw { code: "invalid_date", message: "Dat la dwe nan fòma AAAA-MM-JJ." };
  }
  return value;
}

/** Ajan an wè pa l sèlman; owner/admin ka gade nenpòt staff antrepriz la. */
function targetUid(req, raw) {
  const uid = String(raw || "").trim();
  if (!uid || uid === req.user.uid) return req.user.uid;
  if (!isManager(req.user)) throw { status: 403, code: "forbidden", message: "Ou ka wè sèlman kès pa w." };
  const member = getDb()
    .prepare("SELECT 1 FROM enterprise_users WHERE uid = ? AND enterprise_id = ?")
    .get(uid, req.user.enterpriseId);
  if (!member) throw { status: 404, code: "staff_not_found", message: "Staff sa a pa nan antrepriz ou a." };
  return uid;
}

/** Lavant kach yon staff pou yon jou lokal, pa deviz. */
function salesFor(enterpriseId, uid, date) {
  const mid = Date.parse(`${date}T12:00:00Z`);
  // Yon fenèt laj, epi nou filtre pa dat LOKAL la: pa gen kalkil desalaj.
  const rows = getDb()
    .prepare(
      `SELECT currency, status, amount_minor, sender_fee_minor, created_at FROM transactions
        WHERE enterprise_id = ? AND staff_uid = ? AND created_at BETWEEN ? AND ?`
    )
    .all(enterpriseId, uid, mid - 1.5 * DAY, mid + 1.5 * DAY);

  const by = {};
  for (const row of rows) {
    if (localDate(row.created_at) !== date) continue;
    const cur = String(row.currency || "").toUpperCase();
    by[cur] ??= { currency: cur, salesMinor: 0, txCount: 0, refundedCount: 0, pendingCount: 0 };
    if (REFUNDED.has(row.status)) {
      by[cur].refundedCount += 1;
      continue;
    }
    by[cur].salesMinor += Number(row.amount_minor || 0) + Number(row.sender_fee_minor || 0);
    by[cur].txCount += 1;
    if (row.status !== "delivered") by[cur].pendingCount += 1;
  }
  return by;
}

function closingRow(enterpriseId, uid, date) {
  return getDb()
    .prepare("SELECT * FROM cash_closings WHERE enterprise_id = ? AND staff_uid = ? AND business_date = ?")
    .get(enterpriseId, uid, date);
}

/** Fon kès pwopoze a = kach ki te konte nan dènye fèmti anvan dat sa a. */
function suggestedOpening(enterpriseId, uid, date) {
  const prev = getDb()
    .prepare(
      `SELECT lines FROM cash_closings WHERE enterprise_id = ? AND staff_uid = ? AND business_date < ?
        ORDER BY business_date DESC LIMIT 1`
    )
    .get(enterpriseId, uid, date);
  const out = {};
  for (const line of prev ? JSON.parse(prev.lines) : []) out[line.currency] = line.countedMinor;
  return out;
}

function lineJson(line) {
  return {
    currency: line.currency,
    opening: money.fromMinor(line.openingMinor),
    sales: money.fromMinor(line.salesMinor),
    txCount: line.txCount,
    deposit: money.fromMinor(line.depositMinor),
    expected: money.fromMinor(line.expectedMinor),
    counted: money.fromMinor(line.countedMinor),
    variance: money.fromMinor(line.varianceMinor),
  };
}

function toJson(row) {
  const lines = JSON.parse(row.lines);
  return {
    closingId: row.closing_id,
    staffUid: row.staff_uid,
    staffName: row.staff_name,
    date: row.business_date,
    status: row.status,
    note: row.note,
    lines: lines.map(lineJson),
    balanced: lines.every((l) => l.varianceMinor === 0),
    submittedAt: row.submitted_at,
    decidedByName: row.decided_by_name,
    decidedAt: row.decided_at,
    decisionNote: row.decision_note,
  };
}

/** Montan an santim; 0 aksepte (yon kès ka vid), negatif refize. */
function minorOrZero(value, label) {
  if (value === undefined || value === null || value === "") return 0;
  const n = Number(String(value).replace(",", "."));
  if (!Number.isFinite(n) || n < 0) throw { code: "invalid_amount", message: `${label}: montan an pa valid.` };
  return Math.round(n * 100);
}

// --- Kès atann ------------------------------------------------------------------

router.get("/expected", requireAuth, requireEnterprise, (req, res) => {
  try {
    const date = parseDate(req.query.date, localDate(now()));
    const uid = targetUid(req, req.query.uid);
    const { enterpriseId } = req.user;

    const sales = salesFor(enterpriseId, uid, date);
    const opening = suggestedOpening(enterpriseId, uid, date);
    const existing = closingRow(enterpriseId, uid, date);

    const currencies = [...new Set([...Object.keys(sales), ...Object.keys(opening)])].sort();
    return res.json({
      ok: true,
      date,
      today: localDate(now()),
      currencies: currencies.map((cur) => ({
        currency: cur,
        sales: money.fromMinor(sales[cur]?.salesMinor || 0),
        txCount: sales[cur]?.txCount || 0,
        pendingCount: sales[cur]?.pendingCount || 0,
        refundedCount: sales[cur]?.refundedCount || 0,
        suggestedOpening: money.fromMinor(opening[cur] || 0),
      })),
      closing: existing ? toJson(existing) : null,
    });
  } catch (err) {
    return send(res, err);
  }
});

// --- Voye fèmti a ------------------------------------------------------------------

router.post("/closings", requireAuth, requireEnterprise, (req, res) => {
  try {
    const body = req.body || {};
    const date = parseDate(body.date, localDate(now()));
    if (date > localDate(now())) {
      return send(res, { code: "future_date", message: "Ou pa ka fèmen yon jou ki poko rive." });
    }
    const uid = targetUid(req, body.uid);
    const { enterpriseId } = req.user;

    const existing = closingRow(enterpriseId, uid, date);
    if (existing?.status === "validated") {
      return send(res, { status: 409, code: "closing_locked", message: "Jounen sa a deja valide: li fèmen." });
    }

    const sales = salesFor(enterpriseId, uid, date);
    const input = Array.isArray(body.lines) ? body.lines : [];
    const seen = new Set();
    const lines = [];

    for (const raw of input) {
      const cur = String(raw?.currency || "").trim().toUpperCase();
      if (!/^[A-Z]{3}$/.test(cur) || seen.has(cur)) continue;
      seen.add(cur);
      const openingMinor = minorOrZero(raw.opening, `Fon kès ${cur}`);
      const depositMinor = minorOrZero(raw.deposit, `Depo ${cur}`);
      if (raw.counted === undefined || raw.counted === null || raw.counted === "") {
        return send(res, { code: "missing_counted", message: `Antre kach ou konte an ${cur}.` });
      }
      const countedMinor = minorOrZero(raw.counted, `Kach konte ${cur}`);
      const salesMinor = sales[cur]?.salesMinor || 0;
      const expectedMinor = openingMinor + salesMinor - depositMinor;
      lines.push({
        currency: cur, openingMinor, salesMinor, txCount: sales[cur]?.txCount || 0,
        depositMinor, expectedMinor, countedMinor, varianceMinor: countedMinor - expectedMinor,
      });
    }

    // Chak deviz ki gen lavant dwe konte: pa gen kès ki "bliye".
    const missing = Object.keys(sales).filter((cur) => sales[cur].salesMinor > 0 && !seen.has(cur));
    if (missing.length) {
      return send(res, { code: "missing_currency", message: `Konte kès ${missing.join(", ")} tou: gen lavant nan deviz sa yo.` });
    }
    if (!lines.length) return send(res, { code: "empty_closing", message: "Antre omwen yon deviz." });

    const note = String(body.note || "").trim().slice(0, 500);
    if (lines.some((l) => l.varianceMinor !== 0) && note.length < 5) {
      return send(res, { code: "variance_note_required", message: "Gen yon ekar: eksplike l (omwen 5 karaktè)." });
    }

    const staff = getDb().prepare("SELECT display_name FROM users WHERE uid = ?").get(uid);
    const json = JSON.stringify(lines);

    if (existing) {
      getDb()
        .prepare(
          `UPDATE cash_closings SET lines = ?, note = ?, status = 'submitted', submitted_by = ?, submitted_at = ?,
             decided_by = '', decided_by_name = '', decided_at = NULL, decision_note = '', updated_at = ?
           WHERE closing_id = ? AND status != 'validated'`
        )
        .run(json, note, req.user.uid, now(), now(), existing.closing_id);
    } else {
      getDb()
        .prepare(
          `INSERT INTO cash_closings (closing_id, enterprise_id, staff_uid, staff_name, business_date, lines, note,
             status, submitted_by, submitted_at, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, 'submitted', ?, ?, ?, ?)`
        )
        .run(AppIds.cashClosing(`${enterpriseId}:${uid}:${date}`), enterpriseId, uid, staff?.display_name || "",
          date, json, note, req.user.uid, now(), now(), now());
    }

    return res.json({ ok: true, closing: toJson(closingRow(enterpriseId, uid, date)) });
  } catch (err) {
    return send(res, err);
  }
});

// --- Lis ak ekspòtasyon ------------------------------------------------------------

function listRows(req) {
  const today = localDate(now());
  const to = parseDate(req.query.to, today);
  const from = parseDate(req.query.from, localDate(Date.parse(`${to}T12:00:00Z`) - 6 * DAY));
  if (from > to) throw { code: "invalid_range", message: "Dat kòmansman an apre dat fen an." };
  if ((Date.parse(to) - Date.parse(from)) / DAY > MAX_RANGE_DAYS) {
    throw { code: "range_too_long", message: `${MAX_RANGE_DAYS} jou maksimòm.` };
  }

  const filters = ["enterprise_id = ?", "business_date BETWEEN ? AND ?"];
  const params = [req.user.enterpriseId, from, to];
  if (!isManager(req.user)) {
    filters.push("staff_uid = ?");
    params.push(req.user.uid);
  } else if (req.query.uid) {
    filters.push("staff_uid = ?");
    params.push(String(req.query.uid));
  }
  const status = String(req.query.status || "").trim();
  if (status) {
    filters.push("status = ?");
    params.push(status);
  }

  const rows = getDb()
    .prepare(`SELECT * FROM cash_closings WHERE ${filters.join(" AND ")} ORDER BY business_date DESC, staff_name`)
    .all(...params);
  return { from, to, rows };
}

router.get("/closings", requireAuth, requireEnterprise, (req, res) => {
  try {
    const { from, to, rows } = listRows(req);
    const closings = rows.map(toJson);

    // Total ekar pa deviz + ki ajan ki poko fèmen jodi a (pou owner a).
    const variance = {};
    for (const c of closings) for (const l of c.lines) variance[l.currency] = Math.round(((variance[l.currency] || 0) + l.variance) * 100) / 100;

    let missingToday = [];
    if (isManager(req.user) && to >= localDate(now())) {
      const today = localDate(now());
      const closed = new Set(rows.filter((r) => r.business_date === today).map((r) => r.staff_uid));
      missingToday = getDb()
        .prepare(
          `SELECT DISTINCT t.staff_uid AS uid, t.staff_name AS name FROM transactions t
            WHERE t.enterprise_id = ? AND t.created_at > ?`
        )
        .all(req.user.enterpriseId, now() - 1.5 * DAY)
        .filter((r) => !closed.has(r.uid) && Object.keys(salesFor(req.user.enterpriseId, r.uid, today)).length > 0)
        .map((r) => ({ uid: r.uid, name: r.name }));
    }

    return res.json({
      ok: true, from, to, closings, variance,
      pending: closings.filter((c) => c.status === "submitted").length,
      missingToday,
    });
  } catch (err) {
    return send(res, err);
  }
});

const csvCell = (v) => {
  const s = String(v ?? "");
  return /[",;\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

router.get("/closings.csv", requireAuth, requireEnterprise, requireRole("owner", "admin"), (req, res) => {
  try {
    const { from, to, rows } = listRows(req);
    const head = ["Dat", "Ajan", "Deviz", "Fon kès", "Lavant", "Tranzaksyon", "Depo", "Kès atann", "Kach konte", "Ekar", "Estati", "Nòt ajan", "Valide pa", "Nòt validasyon"];
    const out = [head.join(",")];
    for (const row of rows) {
      const c = toJson(row);
      for (const l of c.lines) {
        out.push([c.date, c.staffName, l.currency, l.opening.toFixed(2), l.sales.toFixed(2), l.txCount, l.deposit.toFixed(2),
          l.expected.toFixed(2), l.counted.toFixed(2), l.variance.toFixed(2), c.status, c.note, c.decidedByName, c.decisionNote]
          .map(csvCell).join(","));
      }
    }
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="femti-kes-${from}-${to}.csv"`);
    // BOM: Excel li aksan yo kòrèkteman.
    return res.send(`﻿${out.join("\n")}\n`);
  } catch (err) {
    return send(res, err);
  }
});

// --- Desizyon owner/admin -----------------------------------------------------------

function decide(status) {
  return (req, res) => {
    try {
      const row = getDb()
        .prepare("SELECT * FROM cash_closings WHERE closing_id = ? AND enterprise_id = ?")
        .get(req.params.id, req.user.enterpriseId);
      if (!row) return res.status(404).json({ ok: false, code: "not_found" });
      if (row.status !== "submitted") {
        return send(res, { status: 409, code: "already_decided", message: `Fèmti sa a deja ${row.status === "validated" ? "valide" : "rejte"}.` });
      }
      if (row.staff_uid === req.user.uid) {
        return send(res, { status: 403, code: "cannot_decide_self", message: "Yon lòt moun dwe valide kès ou." });
      }
      const note = String(req.body?.note || "").trim().slice(0, 500);
      if (status === "rejected" && note.length < 5) {
        return send(res, { code: "note_required", message: "Di ajan an sa pou l korije (omwen 5 karaktè)." });
      }
      const result = getDb()
        .prepare(
          `UPDATE cash_closings SET status = ?, decided_by = ?, decided_by_name = ?, decided_at = ?, decision_note = ?, updated_at = ?
            WHERE closing_id = ? AND status = 'submitted'`
        )
        .run(status, req.user.uid, req.user.displayName || "", now(), note, now(), row.closing_id);
      if (result.changes === 0) return send(res, { status: 409, code: "already_decided", message: "Yon lòt moun deja trete l." });

      const updated = getDb().prepare("SELECT * FROM cash_closings WHERE closing_id = ?").get(row.closing_id);
      return res.json({ ok: true, closing: toJson(updated) });
    } catch (err) {
      return send(res, err);
    }
  };
}

router.post("/closings/:id/validate", requireAuth, requireEnterprise, requireRole("owner", "admin"), decide("validated"));
router.post("/closings/:id/reject", requireAuth, requireEnterprise, requireRole("owner", "admin"), decide("rejected"));

module.exports = router;
