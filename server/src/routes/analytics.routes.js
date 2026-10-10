"use strict";

/**
 * Tablo owner a — analiz antrepriz la.
 *
 *   GET /api/analytics/owner
 *       ?days=7|30|90          peryòd la (jou kalandriye, jodi a ladan)
 *       ?currency=HTG|USD|MXN  deviz pou tout montan yo
 *       ?groupBy=agent|network|currency|week|status
 *       ?networks=moncash,natcash,psl,minit,manual   filtre (vid = tout)
 *
 * Tout chif yo kalkile sou tranzaksyon antrepriz moun k ap rele a, pa sou yon
 * paj. "Volim" = sa benefisyè yo resevwa sou tranzaksyon LIVRE. Jou ak lè yo
 * nan lè Ayiti (`ANALYTICS_TZ`), pa nan lè sèvè a.
 */

const express = require("express");

const { getDb } = require("../db/db");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { getBazikService } = require("../bazik_service");

const router = express.Router();

const DAY = 86400000;
const TZ = process.env.ANALYTICS_TZ || "America/Port-au-Prince";
const NETWORKS = ["moncash", "natcash", "psl", "minit", "manual"];
const NETWORK_LABEL = {
  moncash: "MonCash",
  natcash: "NatCash",
  psl: "PSL (repli MonCash)",
  minit: "Minit Haiti",
  manual: "Livrezon manyèl",
};
const GROUPS = ["agent", "network", "currency", "week", "status"];
/** Yon transfè ki rete `processing` plis pase sa a bezwen yon moun gade l. */
const STUCK_AFTER_MS = 15 * 60000;

function send(res, err) {
  const status = err.status || 400;
  if (status >= 500) console.error("[analytics]", err);
  return res.status(status).json({ ok: false, code: err.code || "error", message: err.message });
}

const partsFmt = new Intl.DateTimeFormat("en-CA", {
  timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit",
  hour: "2-digit", hourCycle: "h23", weekday: "short",
});
const DOW = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };

/** Dat lokal (YYYY-MM-DD), lè (0–23) ak jou semèn (0 = lendi). */
function localParts(ms) {
  const p = Object.fromEntries(partsFmt.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  return { date: `${p.year}-${p.month}-${p.day}`, hour: Number(p.hour) % 24, dow: DOW[p.weekday] ?? 0 };
}

/** Lendi semèn yon dat lokal, an YYYY-MM-DD. */
function weekOf(date) {
  const d = new Date(`${date}T12:00:00Z`);
  const dow = (d.getUTCDay() + 6) % 7;
  return new Date(d.getTime() - dow * DAY).toISOString().slice(0, 10);
}

function networkOf(row) {
  const name = String(row.service || "").toLowerCase();
  if (name.includes("natcash")) return "natcash";
  if (name.includes("moncash")) return row.provider === "psl" ? "psl" : "moncash";
  if (name.includes("minit")) return "minit";
  return "manual";
}

function statusOf(row, now) {
  if (row.status === "delivered") return "delivered";
  if (row.status === "failed" || row.status === "canceled") return "failed";
  if (row.transfer_status === "processing" && now - row.transfer_created_at > STUCK_AFTER_MS) return "verifying";
  return "pending";
}

const STATUS_LABEL = { delivered: "Livre", failed: "Echwe", pending: "An kou", verifying: "Pou verifye" };

function maskPhone(phone) {
  const d = String(phone || "").replace(/\D/g, "").slice(-8);
  if (d.length < 8) return phone || "";
  return `+509 ${d.slice(0, 2)} •• •• ${d.slice(6)}`;
}

function emptyAgg() {
  return { count: 0, delivered: 0, failed: 0, pending: 0, verifying: 0, volume: 0, fee: 0, agent: 0, ownerNet: 0 };
}

function add(agg, t) {
  agg.count += 1;
  agg[t.state] += 1;
  if (t.state === "delivered") {
    agg.volume += t.amount;
    agg.fee += t.fee;
    agg.agent += t.agent;
    agg.ownerNet += t.ownerNet;
  }
}

function finish(agg) {
  const done = agg.delivered + agg.failed;
  const r2 = (v) => Math.round(v * 100) / 100;
  return {
    count: agg.count,
    delivered: agg.delivered,
    failed: agg.failed,
    pending: agg.pending + agg.verifying,
    volume: r2(agg.volume),
    fee: r2(agg.fee),
    agentCommission: r2(agg.agent),
    ownerNet: r2(agg.ownerNet),
    successRate: done ? Math.round((agg.delivered / done) * 10000) / 10000 : null,
    averageTicket: agg.delivered ? r2(agg.volume / agg.delivered) : 0,
  };
}

router.get("/owner", requireAuth, requireEnterprise, requireRole("owner", "admin"), async (req, res) => {
  try {
    const db = getDb();
    const ent = req.user.enterpriseId;
    const days = [7, 30, 90].includes(Number(req.query.days)) ? Number(req.query.days) : 30;
    const display = String(req.query.currency || "HTG").toUpperCase();
    const groupBy = GROUPS.includes(req.query.groupBy) ? req.query.groupBy : "agent";
    const wanted = String(req.query.networks || "")
      .split(",").map((s) => s.trim()).filter((s) => NETWORKS.includes(s));
    const networks = new Set(wanted.length ? wanted : NETWORKS);
    const now = Date.now();

    // Jou lokal peryòd la (pi ansyen → jodi a) ak peryòd anvan an.
    const dates = [];
    for (let i = 0; dates.length < 2 * days && i < 2 * days + 3; i += 1) {
      const d = localParts(now - i * DAY).date;
      if (!dates.includes(d)) dates.push(d);
    }
    const current = dates.slice(0, days).reverse();
    const previous = new Set(dates.slice(days, 2 * days));
    const currentSet = new Set(current);

    // Faktè konvèsyon pa deviz (to jounen an). Analiz la pa bloke si to yo
    // vye: se pa yon mouvman lajan.
    const rates = getBazikService().rates;
    const target = await rates.info(display);
    const factors = new Map();
    const factor = async (cur) => {
      if (!factors.has(cur)) {
        try {
          factors.set(cur, (await rates.info(cur)).rateToHtg / target.rateToHtg);
        } catch {
          factors.set(cur, null);
        }
      }
      return factors.get(cur);
    };

    const rows = db
      .prepare(
        `SELECT t.tx_id, t.created_at, t.status, t.service, t.currency, t.amount_minor,
                t.sender_fee_minor, t.commission_agent_minor, t.commission_owner_minor,
                t.staff_uid, t.staff_name, t.phone,
                c.owner_net_minor, c.agent_minor AS log_agent_minor,
                b.provider, b.status AS transfer_status, b.created_at AS transfer_created_at,
                CASE WHEN b.status = 'completed' THEN b.settled_at - b.created_at END AS latency_ms
           FROM transactions t
           LEFT JOIN commission_logs c ON c.tx_id = t.tx_id
           LEFT JOIN bazik_transfers b ON b.transfer_id = (
             SELECT transfer_id FROM bazik_transfers
              WHERE tx_id = t.tx_id ORDER BY created_at DESC LIMIT 1)
          WHERE t.enterprise_id = ? AND t.created_at >= ?
          ORDER BY t.created_at ASC`
      )
      .all(ent, now - (2 * days + 2) * DAY);

    const skippedCurrencies = new Set();
    const cur = [];
    const prev = [];
    for (const row of rows) {
      const network = networkOf(row);
      if (!networks.has(network)) continue;
      const lp = localParts(row.created_at);
      const inCurrent = currentSet.has(lp.date);
      if (!inCurrent && !previous.has(lp.date)) continue;

      const f = await factor(row.currency);
      if (f === null) {
        skippedCurrencies.add(row.currency);
        continue;
      }
      const conv = (minor) => ((minor || 0) * f) / 100;
      const state = statusOf(row, now);
      const t = {
        txId: row.tx_id,
        createdAt: row.created_at,
        ...lp,
        network,
        state,
        staffUid: row.staff_uid,
        staffName: row.staff_name || "",
        currency: row.currency,
        rawAmount: (row.amount_minor || 0) / 100,
        phone: row.phone,
        amount: conv(row.amount_minor),
        fee: conv(row.sender_fee_minor),
        agent: conv(row.log_agent_minor ?? row.commission_agent_minor),
        ownerNet: conv(row.owner_net_minor ?? row.commission_owner_minor),
        latencyMs: row.latency_ms,
      };
      (inCurrent ? cur : prev).push(t);
    }

    // --- KPI ---
    const kCur = emptyAgg();
    const kPrev = emptyAgg();
    cur.forEach((t) => add(kCur, t));
    prev.forEach((t) => add(kPrev, t));

    // --- Seri pa jou (volim livre pa rezo + kantite) ---
    const byDate = new Map(current.map((d) => [d, { date: d, count: 0, delivered: 0, failed: 0, fee: 0, ownerNet: 0, volume: Object.fromEntries(NETWORKS.map((n) => [n, 0])) }]));
    for (const t of cur) {
      const d = byDate.get(t.date);
      d.count += 1;
      if (t.state === "failed") d.failed += 1;
      if (t.state === "delivered") {
        d.delivered += 1;
        d.volume[t.network] += t.amount;
        d.fee += t.fee;
        d.ownerNet += t.ownerNet;
      }
    }
    const round = (v) => Math.round(v * 100) / 100;
    const series = [...byDate.values()].map((d) => ({
      ...d,
      fee: round(d.fee),
      ownerNet: round(d.ownerNet),
      volume: Object.fromEntries(Object.entries(d.volume).map(([k, v]) => [k, round(v)])),
    }));

    // --- Gwoupman ---
    const trendBuckets = Math.min(days, 12);
    const bucketOf = (date) => Math.min(trendBuckets - 1, Math.floor((current.indexOf(date) * trendBuckets) / days));
    const keyOf = {
      agent: (t) => [t.staffUid, t.staffName || "—", ""],
      network: (t) => [t.network, NETWORK_LABEL[t.network], ""],
      currency: (t) => [t.currency, t.currency, ""],
      week: (t) => { const w = weekOf(t.date); return [w, `Semèn ${w}`, ""]; },
      status: (t) => [t.state, STATUS_LABEL[t.state], ""],
    }[groupBy];
    const groups = new Map();
    for (const t of cur) {
      const [key, label, sub] = keyOf(t);
      if (!groups.has(key)) groups.set(key, { key, label, sub, agg: emptyAgg(), trend: new Array(trendBuckets).fill(0) });
      const g = groups.get(key);
      add(g.agg, t);
      if (t.state === "delivered") g.trend[bucketOf(t.date)] += t.amount;
    }
    const totalVolume = kCur.volume;
    const groupRows = [...groups.values()]
      .map((g) => ({
        key: g.key,
        label: g.label,
        sub: g.sub,
        ...finish(g.agg),
        share: totalVolume ? Math.round((g.agg.volume / totalVolume) * 10000) / 10000 : 0,
        trend: g.trend.map(round),
      }))
      .sort((a, b) => (groupBy === "week" ? String(b.key).localeCompare(String(a.key)) : b.volume - a.volume));

    // --- Lè chaje (lendi → dimanch × 0–23 h) ---
    const heatmap = Array.from({ length: 7 }, () => new Array(24).fill(0));
    for (const t of cur) heatmap[t.dow][t.hour] += 1;

    // --- Rezo ---
    const networkRows = NETWORKS.filter((n) => networks.has(n))
      .map((n) => {
        const items = cur.filter((t) => t.network === n);
        const agg = emptyAgg();
        items.forEach((t) => add(agg, t));
        const lat = items.map((t) => t.latencyMs).filter((v) => Number.isFinite(v) && v >= 0).sort((a, b) => a - b);
        return {
          network: n,
          label: NETWORK_LABEL[n],
          ...finish(agg),
          share: totalVolume ? Math.round((agg.volume / totalVolume) * 10000) / 10000 : 0,
          medianSeconds: lat.length ? Math.round(lat[Math.floor(lat.length / 2)] / 1000) : null,
        };
      })
      .filter((n) => n.count > 0);

    // --- Alèt ---
    const alerts = [];
    const stuck = cur.filter((t) => t.state === "verifying");
    if (stuck.length) {
      alerts.push({
        level: "critical",
        code: "transfers_stuck",
        title: `${stuck.length} transfè pou verifye`,
        detail: `${round(stuck.reduce((s, t) => s + t.amount, 0))} ${display} san repons pasrèl la depi plis pase 15 minit.`,
      });
    }
    const overall = finish(kCur).successRate;
    if (overall !== null) {
      const byAgent = new Map();
      for (const t of cur) {
        if (!byAgent.has(t.staffUid)) byAgent.set(t.staffUid, { name: t.staffName, agg: emptyAgg() });
        add(byAgent.get(t.staffUid).agg, t);
      }
      for (const { name, agg } of byAgent.values()) {
        const f = finish(agg);
        if (agg.delivered + agg.failed >= 10 && f.successRate !== null && f.successRate < overall - 0.03) {
          alerts.push({
            level: "warning",
            code: "agent_failures",
            title: `${name || "Yon ajan"}: ${round((1 - f.successRate) * 100)} % echèk`,
            detail: `Mwayèn antrepriz la: ${round((1 - overall) * 100)} %. ${agg.failed} echèk sou peryòd la.`,
          });
        }
      }
    }
    const loss = cur.filter((t) => t.state === "delivered" && t.ownerNet < 0);
    if (loss.length) {
      alerts.push({
        level: "warning",
        code: "owner_loss",
        title: `${loss.length} transfè kote pasrèl la koute plis pase pati ou`,
        detail: "Monte frè a oswa bese pati ajan an nan Sèvis.",
      });
    }
    const pslCount = cur.filter((t) => t.network === "psl").length;
    if (pslCount && networks.has("psl")) {
      alerts.push({
        level: "info",
        code: "psl_fallback",
        title: `Repli PSL: ${round((pslCount / (cur.length || 1)) * 100)} % envwa yo`,
        detail: "MonCash dirèk pa t disponib sou tranzaksyon sa yo, PSL pran relè a (frè 7 %).",
      });
    }
    if (skippedCurrencies.size) {
      alerts.push({
        level: "info",
        code: "rates_missing",
        title: "Kèk deviz pa konte",
        detail: `Pa gen to pou ${[...skippedCurrencies].join(", ")}.`,
      });
    }

    const recent = cur
      .slice(-8)
      .reverse()
      .map((t) => ({
        txId: t.txId,
        createdAt: t.createdAt,
        staffName: t.staffName,
        phone: maskPhone(t.phone),
        network: t.network,
        amount: t.rawAmount,
        currency: t.currency,
        status: t.state,
      }));

    return res.json({
      ok: true,
      days,
      currency: display,
      groupBy,
      timeZone: TZ,
      generatedAt: now,
      networks: [...networks],
      kpis: { current: finish(kCur), previous: finish(kPrev) },
      series,
      groups: groupRows,
      heatmap,
      networkStats: networkRows,
      alerts,
      recent,
    });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = router;
module.exports._internals = { localParts, weekOf, networkOf, maskPhone };
