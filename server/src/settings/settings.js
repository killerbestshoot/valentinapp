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
 * Kont bank antrepriz la — sa ajan yo wè lè yo rechaje pa virement.
 * Yon lis (egz. yon kont HTG, yon kont USD), estoke an JSON pa antrepriz.
 */
const BANK_ACCOUNTS_KEY = "bank_accounts";
const MAX_BANK_ACCOUNTS = 5;
const BANK_CURRENCIES = ["HTG", "USD"];

function bankKey(enterpriseId) {
  return `${BANK_ACCOUNTS_KEY}:${enterpriseId}`;
}

function getBankAccounts(enterpriseId) {
  const row = getDb().prepare("SELECT value FROM app_settings WHERE key = ?").get(bankKey(enterpriseId));
  if (!row) return [];
  try {
    const list = JSON.parse(row.value);
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

function setBankAccounts(enterpriseId, accounts, updatedBy = "") {
  const invalid = (message) => Object.assign(new Error(message), { code: "invalid_bank_accounts", status: 400 });

  if (!Array.isArray(accounts)) throw invalid("Lis kont bank yo pa valid.");
  if (accounts.length > MAX_BANK_ACCOUNTS) throw invalid(`${MAX_BANK_ACCOUNTS} kont maksimòm.`);

  const text = (v, max) => String(v ?? "").trim().slice(0, max);
  const clean = accounts.map((a, i) => {
    const account = {
      id: text(a?.id, 40) || `bank_${Date.now()}_${i}`,
      bankName: text(a?.bankName, 80),
      accountName: text(a?.accountName, 120),
      accountNumber: text(a?.accountNumber, 60),
      currency: BANK_CURRENCIES.includes(String(a?.currency).toUpperCase())
        ? String(a.currency).toUpperCase()
        : "HTG",
      instructions: text(a?.instructions, 300),
    };
    if (!account.bankName || !account.accountName || !account.accountNumber) {
      throw invalid(`Kont #${i + 1}: non bank lan, non kont lan ak nimewo a obligatwa.`);
    }
    return account;
  });

  getDb()
    .prepare(
      `INSERT INTO app_settings (key, value, updated_at, updated_by)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value,
         updated_at = excluded.updated_at, updated_by = excluded.updated_by`
    )
    .run(bankKey(enterpriseId), JSON.stringify(clean), now(), updatedBy);

  return clean;
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
  MAX_BANK_ACCOUNTS,
  getBankAccounts,
  setBankAccounts,
  getExchangeMargin,
  getPslFallbackEnabled,
  setExchangeMargin,
  setPslFallbackEnabled,
  applyMargin,
};
