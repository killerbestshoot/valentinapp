"use strict";

/**
 * Konfigirasyon antrepriz la (kle/valè).
 *
 * `exchange_margin_htg`: majin owner an soustrè de chak to echanj (HTG pa
 * inite deviz etranjè). Egzanp: to MXN se 7.60, majin 0.80 → to efektif 6.80.
 * Owner an kenbe diferans la nan chak konvèsyon.
 */

const { getDb, now } = require("../db/db");

const EXCHANGE_MARGIN_KEY = "exchange_margin_htg";
const PSL_FALLBACK_KEY = "psl_moncash_fallback_enabled";
const MAX_EXCHANGE_MARGIN = 0.8;

function getPslFallbackEnabled(defaultEnabled = false) {
  const row = getDb().prepare("SELECT value FROM app_settings WHERE key = ?").get(PSL_FALLBACK_KEY);
  if (!row) return Boolean(defaultEnabled);
  return row.value === "true";
}

function setPslFallbackEnabled(enabled, updatedBy = "") {
  if (typeof enabled !== "boolean") {
    const err = new Error("Valè fallback PSL la dwe vre oswa fo.");
    err.code = "invalid_psl_fallback";
    err.status = 400;
    throw err;
  }
  getDb()
    .prepare(
      `INSERT INTO app_settings (key, value, updated_at, updated_by)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value,
         updated_at = excluded.updated_at, updated_by = excluded.updated_by`
    )
    .run(PSL_FALLBACK_KEY, String(enabled), now(), updatedBy);
  return enabled;
}

function getExchangeMargin() {
  const row = getDb()
    .prepare("SELECT value FROM app_settings WHERE key = ?")
    .get(EXCHANGE_MARGIN_KEY);
  if (!row) return 0;

  const value = Number(row.value);
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.min(value, MAX_EXCHANGE_MARGIN);
}

function setExchangeMargin(margin, updatedBy = "") {
  const value = Number(margin);
  if (!Number.isFinite(value) || value < 0 || value > MAX_EXCHANGE_MARGIN) {
    const err = new Error(
      `Majin an dwe ant 0 ak ${MAX_EXCHANGE_MARGIN.toFixed(2)} HTG.`
    );
    err.code = "invalid_margin";
    err.status = 400;
    throw err;
  }

  getDb()
    .prepare(
      `INSERT INTO app_settings (key, value, updated_at, updated_by)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value,
         updated_at = excluded.updated_at, updated_by = excluded.updated_by`
    )
    .run(EXCHANGE_MARGIN_KEY, String(value), now(), updatedBy);

  return value;
}

/**
 * Aplike majin lan sou yon to brit (HTG pa inite). Si to a vin ≤ 0 apre, nou
 * kenbe li yon ti kras pozitif pou konvèsyon pa echwe — admin dwe korije
 * majin lan.
 */
function applyMargin(rate, margin = getExchangeMargin()) {
  const base = Number(rate);
  if (!Number.isFinite(base) || base <= 0) return base;

  const adjusted = base - Number(margin || 0);
  return adjusted > 0.0001 ? adjusted : 0.0001;
}

module.exports = {
  EXCHANGE_MARGIN_KEY,
  PSL_FALLBACK_KEY,
  MAX_EXCHANGE_MARGIN,
  getExchangeMargin,
  getPslFallbackEnabled,
  setExchangeMargin,
  setPslFallbackEnabled,
  applyMargin,
};
