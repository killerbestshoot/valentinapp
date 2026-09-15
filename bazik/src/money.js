"use strict";

/**
 * Tout kalkil lajan nan modil sa a fèt an "minor units" (santim), kòm antye.
 * Rezon an: `balance` nan Firestore se yon `double`, e double ap pèdi presizyon
 * apre plizyè operasyon. Nou konvèti sèlman nan fwontyè a (store la / API a).
 *
 * Règ yo soti nan `docs/contract.md` — yo verifye sou sandbox la, se pa ipotèz.
 */

const { DomainError } = require("./errors");

/** Deviz pasrèl la. Bazik pa aksepte lòt bagay. */
const GATEWAY_CURRENCY = "HTG";

/** Frè Bazik (fee_percentage nan /transfers/quote). */
const DEFAULT_FEE_PERCENT = 5;

/**
 * Limit chak rezo, an HTG. Sa yo soti dirèkteman nan erè API a:
 *   "Minimum MonCash transfer amount is 100 HTG"
 *   "Minimum Natcash transfer amount is 3998 HTG"
 *   "Maximum MonCash transfer amount is 75000 HTG per transaction"
 */
const NETWORK_LIMITS = {
  moncash: { minHtg: 100, maxHtg: 75000 },
  natcash: { minHtg: 3998, maxHtg: 75000 },
};

/** Konvèti yon montan (nonm/string) an santim antye. */
function toMinor(amount) {
  const value = typeof amount === "string" ? Number(amount.trim()) : Number(amount);
  if (!Number.isFinite(value)) {
    throw new DomainError("invalid_amount", `Montan an pa valid: ${amount}`);
  }
  if (value <= 0) {
    throw new DomainError("invalid_amount", "Montan an dwe pi gran pase 0.");
  }
  return Math.round(value * 100);
}

/** Retounen yon nonm ak 2 desimal (pou JSON / voye bay Bazik). */
function fromMinor(minor) {
  return Math.round(Number(minor)) / 100;
}

/**
 * Konvèti santim yon deviz vè santim HTG.
 * @param {number} minor santim nan deviz sous la
 * @param {number} rateToHTG konbyen HTG 1 inite deviz la vo
 */
function convertToHtgMinor(minor, rateToHTG) {
  const rate = Number(rateToHTG);
  if (!Number.isFinite(rate) || rate <= 0) {
    throw new DomainError("invalid_rate", `To echanj la pa valid: ${rateToHTG}`);
  }
  return Math.round(minor * rate);
}

/** Konvèti santim HTG tounen nan deviz wallet la. */
function convertFromHtgMinor(htgMinor, rateToHTG) {
  const rate = Number(rateToHTG);
  if (!Number.isFinite(rate) || rate <= 0) {
    throw new DomainError("invalid_rate", `To echanj la pa valid: ${rateToHTG}`);
  }
  return Math.round(htgMinor / rate);
}

/** Frè Bazik sou yon montan HTG (an santim). */
function feeMinor(htgMinor, feePercent = DEFAULT_FEE_PERCENT) {
  return Math.round((htgMinor * feePercent) / 100);
}

/** Sa transfè a ap koute nan wallet Bazik la: montan + frè. */
function totalCostMinor(htgMinor, feePercent = DEFAULT_FEE_PERCENT) {
  return htgMinor + feeMinor(htgMinor, feePercent);
}

/**
 * Verifye limit rezo a AVAN nou rele API a.
 * Sa evite yon aller-retour rezo pou yon erè nou te ka wè lokalman,
 * e sitou sa bay yon mesaj ann Kreyòl bay ajan an.
 */
function assertNetworkAmount(network, htgMinor) {
  const limits = NETWORK_LIMITS[network];
  if (!limits) {
    throw new DomainError("unknown_network", `Rezo a pa rekonèt: ${network}`);
  }

  const htg = fromMinor(htgMinor);

  if (htg < limits.minHtg) {
    throw new DomainError(
      "amount_too_low",
      `Minimòm pou ${network} se ${limits.minHtg} HTG. Ou mande ${htg} HTG.`
    );
  }

  if (htg > limits.maxHtg) {
    throw new DomainError(
      "amount_too_high",
      `Maksimòm pou ${network} se ${limits.maxHtg} HTG pa tranzaksyon. Ou mande ${htg} HTG.`
    );
  }

  return true;
}

module.exports = {
  GATEWAY_CURRENCY,
  DEFAULT_FEE_PERCENT,
  NETWORK_LIMITS,
  toMinor,
  fromMinor,
  convertToHtgMinor,
  convertFromHtgMinor,
  feeMinor,
  totalCostMinor,
  assertNetworkAmount,
};
