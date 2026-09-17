"use strict";

/**
 * Sante sistèm ak notifikasyon.
 *
 *   GET /api/system/health          eta baz la + pasrèl yo (owner/admin)
 *   GET /api/system/reloadly        pèmisyon ak done kont Reloadly (owner/admin)
 *   GET /api/system/notifications   sa ki bezwen atansyon kounye a
 *
 * DONE LAJAN = OWNER SÈLMAN: sòld pasrèl yo, komisyon (maj) Reloadly yo,
 * istorik rechaj yo ak solvabilite a. Filt la fèt sou serveur a; kache yo nan
 * UI a sèlman pa t ap pwoteje anyen.
 *
 * Notifikasyon yo DERIVE depi done yo, pa estoke apa. Ansyen koleksyon
 * `notifications` la te dwe mete ajou pa chak ekran — epi li te tonbe an
 * dezakò ak reyalite a dèske yon ekran bliye. Isit la, si yon demann
 * `pending`, li parèt; si li trete, li disparèt. Pa gen sinkronizasyon.
 */

const express = require("express");

const { getDb, getDbFile } = require("../db/db");
const { getBazikService } = require("../bazik_service");
const { getAirtimeService } = require("../airtime_service");
const { checkSolvency, solvencyNotification } = require("../solvency");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money } = require("../../../bazik/index.js");

const router = express.Router();

router.get("/health", requireAuth, requireRole("owner", "admin"), async (req, res) => {
  const db = getDb();
  const checks = {};

  try {
    db.prepare("SELECT 1").get();
    checks.database = { ok: true, file: getDbFile() };
  } catch (err) {
    checks.database = { ok: false, error: err.message };
  }

  const count = (sql, ...params) => db.prepare(sql).get(...params).n;
  const ent = req.user.enterpriseId;

  checks.data = {
    users: count("SELECT COUNT(*) AS n FROM enterprise_users WHERE enterprise_id = ?", ent),
    transactions: count("SELECT COUNT(*) AS n FROM transactions WHERE enterprise_id = ?", ent),
    stuckTransfers: count(
      `SELECT COUNT(*) AS n FROM bazik_transfers
        WHERE enterprise_id = ? AND status = 'processing' AND created_at < ?`,
      ent,
      Date.now() - 60 * 60 * 1000
    ),
    pendingCommissions: count(
      `SELECT COUNT(*) AS n FROM transactions
        WHERE enterprise_id = ? AND status = 'delivered' AND commission_applied = 0`,
      ent
    ),
  };

  try {
    const service = getBazikService();
    const wallet = await service.gatewayWallet();
    checks.gateway = {
      ok: true,
      mode: service.config.mode,
      available: money.fromMinor(wallet.availableMinor),
      currency: wallet.currency,
      funded: wallet.availableMinor > 0,
    };
  } catch (err) {
    checks.gateway = { ok: false, error: err.code || err.message };
  }

  // Solvabilite: se yon done lajan, donk owner sèlman.
  if (req.user.role === "owner") {
    try {
      checks.solvency = await checkSolvency({ enterpriseId: ent });
    } catch (err) {
      checks.solvency = { ok: false, status: "unknown", reasons: [err.code || err.message] };
    }
  } else {
    checks.solvency = { restricted: true };
  }

  const healthy =
    checks.database.ok && checks.gateway.ok && checks.data.stuckTransfers === 0;

  return res.json({ ok: true, healthy, checks });
});

/**
 * Pèmisyon kont Reloadly la ak sa chak pèmisyon bay.
 *
 * `read-prepaid-balance`, `read-prepaid-commissions` ak `read-topups-history`
 * se done lajan: yo REZÈVE pou owner. Pou yon admin, nou pa menm rele Reloadly.
 */
router.get("/reloadly", requireAuth, requireRole("owner", "admin"), async (req, res) => {
  try {
    const service = getAirtimeService();

    if (service.disabled) {
      return res.json({
        ok: true,
        enabled: false,
        mode: service.config.mode,
        warning: "Minit Haiti poko aktive: kle Reloadly yo pa konfigire sou serveur a.",
      });
    }

    const overview = await service.insights.overview({
      isOwner: req.user.role === "owner",
      historyLimit: Math.min(Number(req.query.limit) || 10, 25),
    });

    return res.json({ ok: true, enabled: true, ...overview });
  } catch (err) {
    console.error("[system] reloadly:", err);
    return res.status(502).json({ ok: false, code: err.code || "error", message: err.message });
  }
});

router.get("/notifications", requireAuth, requireEnterprise, async (req, res) => {
  const db = getDb();
  const ent = req.user.enterpriseId;
  const isManager = ["owner", "admin", "administrator"].includes(req.user.role);
  const items = [];

  const push = (type, severity, title, count) => {
    if (count > 0) items.push({ type, severity, title, count });
  };

  const n = (sql, ...params) => db.prepare(sql).get(...params).n;

  if (isManager) {
    push(
      "topup_pending",
      "info",
      "Demann rechaj ki ap tann apwobasyon",
      n("SELECT COUNT(*) AS n FROM wallet_topup_requests WHERE enterprise_id = ? AND processed = 0", ent)
    );
    push(
      "payout_pending",
      "info",
      "Demann payout ki ap tann apwobasyon",
      n("SELECT COUNT(*) AS n FROM payout_requests WHERE enterprise_id = ? AND status = 'pending'", ent)
    );
    push(
      "transfer_verifying",
      "warning",
      "Transfè an verifikasyon ak Bazik",
      n(
        `SELECT COUNT(*) AS n FROM bazik_transfers
          WHERE enterprise_id = ? AND status = 'processing' AND gateway_status = 'unknown'`,
        ent
      )
    );
    push(
      "transfer_failed",
      "warning",
      "Transfè ki echwe jodi a",
      n(
        `SELECT COUNT(*) AS n FROM bazik_transfers
          WHERE enterprise_id = ? AND status = 'failed' AND created_at > ?`,
        ent,
        Date.now() - 24 * 60 * 60 * 1000
      )
    );
    push(
      "commission_pending",
      "info",
      "Komisyon ki poko aplike",
      n(
        `SELECT COUNT(*) AS n FROM transactions
          WHERE enterprise_id = ? AND status = 'delivered' AND commission_applied = 0`,
        ent
      )
    );
  } else {
    push(
      "my_payout_pending",
      "info",
      "Payout ou ki ap tann apwobasyon",
      n(
        "SELECT COUNT(*) AS n FROM payout_requests WHERE enterprise_id = ? AND staff_uid = ? AND status = 'pending'",
        ent,
        req.user.uid
      )
    );
    push(
      "my_tx_pending",
      "info",
      "Tranzaksyon ou ki poko livre",
      n(
        "SELECT COUNT(*) AS n FROM transactions WHERE enterprise_id = ? AND staff_uid = ? AND status = 'pending'",
        ent,
        req.user.uid
      )
    );
  }

  // Alèt solvabilite: owner sèlman (li gen chif pasrèl yo ladan).
  if (req.user.role === "owner") {
    try {
      const alert = solvencyNotification(await checkSolvency({ enterpriseId: ent }));
      if (alert) items.push(alert);
    } catch (err) {
      items.push({
        type: "solvency_unknown",
        severity: "warning",
        title: `Nou pa ka verifye solvabilite a: ${err.code || err.message}`,
        count: 1,
      });
    }
  }

  return res.json({ ok: true, notifications: items, total: items.reduce((s, i) => s + i.count, 0) });
});

module.exports = router;
