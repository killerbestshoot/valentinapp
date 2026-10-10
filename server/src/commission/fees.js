"use strict";

/**
 * Frè platfòm nan — sa ki fè platfòm nan viv.
 *
 * RÈG BIZNIS:
 *   - owner a fikse yon % pa sèvis (`services.fee_pct`) ak yon minimòm an HTG
 *     (`services.fee_min_htg_minor`). Frè a OBLIGATWA: ajan an pa ka retire l.
 *   - Kliyan an chwazi kiyès ki peye l:
 *       'sender'   → 5% sou 2000 MXN = 100 MXN; kliyan an peye 2100,
 *                    benefisyè a resevwa 2000.
 *       'deducted' → 5% sou 2000 MXN = 100 MXN; kliyan an peye 2000,
 *                    benefisyè a resevwa 1900.
 *   - Se NAN frè sa a komisyon yo soti: ajan an pran `agent_share_pct` nan
 *     frè a, owner a pran rès la, e se sou pati pa l frè pasrèl la (Bazik,
 *     PSL) tonbe (`commission/engine.js`).
 *
 * Tout montan yo an santim, nan deviz tranzaksyon an.
 */

const { getDb } = require("../db/db");
const { getBazikService } = require("../bazik_service");

const FEE_MODES = ["sender", "deducted"];

/** Si sèvis la pa nan katalòg la. */
const DEFAULT_FEE_PCT = 10;
const DEFAULT_AGENT_SHARE_PCT = 40;

/** Limit yon owner ka mete. Yon frè 0 ta touye platfòm nan; > 50% se yon erè frap. */
const MIN_FEE_PCT = 0.5;
const MAX_FEE_PCT = 50;

/**
 * Konbyen pasrèl la pran, an % montan an — pou montre owner a maj li ANVAN
 * li valide yon to. Se estimasyon: chif egzak la soti nan devi Bazik la.
 */
const GATEWAY_COST_PCT = { moncash: 5, natcash: 5, psl: 7 };

function feeError(code, message) {
  return Object.assign(new Error(message), { code });
}

/** Règ frè yon sèvis (pa non, san konsidere majiskil). */
function resolveFeePolicy(serviceName) {
  const row = getDb()
    .prepare(
      `SELECT fee_pct, fee_min_htg_minor, agent_share_pct, network FROM services
        WHERE LOWER(name) = LOWER(?) AND is_active = 1 LIMIT 1`
    )
    .get(String(serviceName || "").trim());

  return {
    feePct: row ? Number(row.fee_pct) : DEFAULT_FEE_PCT,
    feeMinHtgMinor: row ? Number(row.fee_min_htg_minor) : 0,
    agentSharePct: row ? Number(row.agent_share_pct) : DEFAULT_AGENT_SHARE_PCT,
    network: row?.network || "",
  };
}

/**
 * Kalkile frè a ak separasyon li.
 *
 * @param {object} p
 * @param {number} p.inputMinor sa ajan an tape: montan pou VOYE ('sender') oswa
 *   sa kliyan an BAY an tou ('deducted')
 * @param {string} p.currency deviz montan an
 * @param {'sender'|'deducted'} p.mode
 * @param {string} p.serviceName
 */
async function computeFee({ inputMinor, currency, mode, serviceName }) {
  if (!FEE_MODES.includes(mode)) {
    throw feeError("invalid_fee_mode", "Chwazi kiyès ki peye frè a: anvwayè a oswa dedwi sou montan an.");
  }
  if (!Number.isInteger(inputMinor) || inputMinor <= 0) {
    throw feeError("invalid_amount", "Mete yon montan ki valid.");
  }

  const policy = resolveFeePolicy(serviceName);
  const cur = String(currency || "").toUpperCase();

  // Minimòm nan fikse an HTG, nou konvèti l nan deviz tranzaksyon an.
  let minMinor = 0;
  if (policy.feeMinHtgMinor > 0) {
    minMinor = (await getBazikService().rates.convert(policy.feeMinHtgMinor, "HTG", cur)).amountMinor;
  }

  const pctFeeMinor = Math.round((inputMinor * policy.feePct) / 100);
  const feeMinor = Math.max(pctFeeMinor, minMinor);
  const netMinor = mode === "sender" ? inputMinor : inputMinor - feeMinor;

  if (netMinor <= 0) {
    throw feeError(
      "amount_below_fee",
      "Montan an pi piti pase frè minimòm nan: benefisyè a pa t ap resevwa anyen."
    );
  }

  // Ajan an pran pati pa l; owner a pran RÈS la, konsa de pati yo toujou fè
  // frè a egzakteman (pa gen santim ki disparèt nan awondi).
  const agentMinor = Math.round((feeMinor * policy.agentSharePct) / 100);
  const ownerMinor = feeMinor - agentMinor;

  return {
    mode,
    currency: cur,
    feePct: policy.feePct,
    agentSharePct: policy.agentSharePct,
    /** Minimòm nan te pi wo pase %: se li ki aplike. */
    minApplied: minMinor > pctFeeMinor,
    feeMinor,
    /** Sa benefisyè a resevwa. */
    netMinor,
    /** Sa kliyan an peye an tou. */
    totalMinor: netMinor + feeMinor,
    agentMinor,
    ownerMinor,
  };
}

/** Valide sa owner a voye pou chanje règ frè yon sèvis. */
function validateFeePolicy({ feePct, feeMinHtg, agentSharePct }, current) {
  const out = { ...current };

  if (feePct !== undefined) {
    const n = Number(feePct);
    if (!Number.isFinite(n) || n < MIN_FEE_PCT || n > MAX_FEE_PCT) {
      throw feeError("invalid_fee_pct", `Frè a dwe ant ${MIN_FEE_PCT}% ak ${MAX_FEE_PCT}%.`);
    }
    out.feePct = n;
  }

  if (feeMinHtg !== undefined) {
    const n = Number(feeMinHtg);
    if (!Number.isFinite(n) || n < 0 || n > 100000) {
      throw feeError("invalid_fee_min", "Frè minimòm nan dwe ant 0 ak 100 000 HTG.");
    }
    out.feeMinHtgMinor = Math.round(n * 100);
  }

  if (agentSharePct !== undefined) {
    const n = Number(agentSharePct);
    if (!Number.isFinite(n) || n < 0 || n > 100) {
      throw feeError("invalid_agent_share", "Pati ajan an dwe ant 0% ak 100% frè a.");
    }
    out.agentSharePct = n;
  }

  return out;
}

/**
 * Maj owner a an % montan an, apre pati ajan an ak frè pasrèl la.
 * Negatif = owner a pèdi lajan sou chak transfè.
 */
function ownerMarginPct({ feePct, agentSharePct, network }) {
  const ownerPct = (feePct * (100 - agentSharePct)) / 100;
  return Math.round((ownerPct - (GATEWAY_COST_PCT[network] || 0)) * 100) / 100;
}

module.exports = {
  FEE_MODES,
  DEFAULT_FEE_PCT,
  DEFAULT_AGENT_SHARE_PCT,
  GATEWAY_COST_PCT,
  MIN_FEE_PCT,
  MAX_FEE_PCT,
  resolveFeePolicy,
  computeFee,
  validateFeePolicy,
  ownerMarginPct,
};
