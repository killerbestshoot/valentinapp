"use strict";

/**
 * Konfigirasyon antrepriz la (majin to echanj, elatriye).
 *
 *   GET /api/settings/exchange-margin   (owner/admin ka wè)
 *   PUT /api/settings/exchange-margin   (owner sèlman mete ajou)
 */

const express = require("express");
const { getBazikService } = require("../bazik_service");

const { requireAuth, requireRole } = require("../auth/middleware");
const {
  getExchangeMargin,
  getPslFallbackEnabled,
  setExchangeMargin,
  setPslFallbackEnabled,
  MAX_EXCHANGE_MARGIN,
} = require("../settings/settings");

const router = express.Router();

function send(res, err) {
  const status = err.status || 500;
  if (status >= 500) console.error("[settings]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "internal_error",
    message: err.message,
  });
}

router.get(
  "/exchange-margin",
  requireAuth,
  requireRole("owner", "admin"),
  (req, res) => {
    try {
      return res.json({
        ok: true,
        margin: getExchangeMargin(),
        maxMargin: MAX_EXCHANGE_MARGIN,
      });
    } catch (err) {
      return send(res, err);
    }
  }
);

router.patch(
  "/exchange-margin",
  requireAuth,
  requireRole("owner"),
  (req, res) => {
    try {
      const margin = setExchangeMargin(req.body?.margin, req.user.uid);
      return res.json({ ok: true, margin, maxMargin: MAX_EXCHANGE_MARGIN });
    } catch (err) {
      return send(res, err);
    }
  }
);

router.get("/psl-fallback", requireAuth, requireRole("owner", "admin"), (req, res) => {
  try {
    const config = getBazikService().config;
    const configured = Boolean(config.psl?.enabled && !config.isFake);
    return res.json({
      ok: true,
      configured,
      enabled: configured && getPslFallbackEnabled(configured),
    });
  } catch (err) {
    return send(res, err);
  }
});

router.patch("/psl-fallback", requireAuth, requireRole("owner"), (req, res) => {
  try {
    const config = getBazikService().config;
    const configured = Boolean(config.psl?.enabled && !config.isFake);
    if (req.body?.enabled === true && !configured) {
      return res.status(409).json({
        ok: false,
        code: "psl_not_configured",
        message: "PSL API pa konfigire sou sèvè a.",
      });
    }
    const saved = setPslFallbackEnabled(req.body?.enabled, req.user.uid);
    return res.json({ ok: true, configured, enabled: configured && saved });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = router;
