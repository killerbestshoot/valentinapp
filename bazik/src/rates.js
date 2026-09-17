"use strict";

/**
 * LIV TO ECHANJ: SÈL KOTE KI KONVÈTI LAJAN ANT DE DEVIZ.
 *
 * To yo estoke an "konbyen HTG pou 1 inite" (`exchange_rates.rate_to_htg`).
 * Konvèsyon X -> Y pase pa HTG: montan × to(X) / to(Y).
 *
 * Sous yon to:
 *   - "seed"             : valè fiks nan kòd la, pou premye demaraj. Yo te
 *                          jiska 5% lwen mache a le 17/09/2026 (MXN 7,25 vs 7,60).
 *   - "exchangerate-api" : serveur a mete yo ajou YON FWA PA JOU
 *                          (`server/src/rates/rates_refresher.js`).
 *
 * POLITIK `requireFresh` (serveur a aktive l an pwodiksyon): yon konvèsyon ANT
 * DE DEVIZ DIFERAN refize si youn nan to yo pa soti nan API a, oswa si li pi
 * vye pase `maxAgeMs`. Pi bon yon refi klè pase yon benefisyè ki resevwa 5%
 * mwens (oswa plis) san pèsonn pa wè l. HTG -> HTG pa janm bloke.
 */

const { DomainError } = require("./errors");

const API_SOURCE = "exchangerate-api";

/** API a mete ajou chak jou a 00:00 UTC: apre 36 h, nou rate yon jou. */
const STALE_AFTER_MS = 36 * 3600 * 1000;

/** Apre 7 jou san mizajou, konvèsyon yo bloke (si `requireFresh`). */
const DEFAULT_MAX_AGE_MS = 7 * 24 * 3600 * 1000;

function hours(ms) {
  return Math.round(ms / 3600000);
}

function createRateBook({
  store,
  requireFresh = false,
  maxAgeMs = DEFAULT_MAX_AGE_MS,
  now = () => Date.now(),
} = {}) {
  if (!store || typeof store.getRateToHtg !== "function") {
    throw new Error("createRateBook mande yon store ki gen `getRateToHtg`.");
  }

  /** { currency, rateToHtg, source, updatedAt } */
  async function info(currency) {
    const code = String(currency || "").toUpperCase().trim();
    if (code === "HTG") return { currency: "HTG", rateToHtg: 1, source: "identity", updatedAt: now() };

    if (typeof store.getRateInfo === "function") return store.getRateInfo(code);
    return { currency: code, rateToHtg: await store.getRateToHtg(code), source: "unknown", updatedAt: 0 };
  }

  function isStale(rate) {
    if (rate.source === "identity") return false;
    return rate.source !== API_SOURCE || now() - rate.updatedAt > STALE_AFTER_MS;
  }

  function assertUsable(rate) {
    if (!requireFresh || rate.source === "identity") return;

    if (rate.source !== API_SOURCE) {
      throw new DomainError(
        "rates_stale",
        `To ${rate.currency} la poko janm soti nan API to echanj lan (sous: ${rate.source}). ` +
          "Konvèsyon an bloke pou nou pa sèvi ak yon to ki fo. Administratè a dwe verifye " +
          "EXCHANGE_RATE_API_KEY sou serveur a."
      );
    }

    const age = now() - rate.updatedAt;
    if (age > maxAgeMs) {
      throw new DomainError(
        "rates_stale",
        `To ${rate.currency} la gen ${hours(age)} h, pi vye pase limit ${hours(maxAgeMs)} h la. ` +
          "Konvèsyon an bloke jiskaske to yo mete ajou. Kontakte administratè a."
      );
    }
  }

  /**
   * Konvèti `amountMinor` (santim `from`) an santim `to`.
   *
   * @param {object} [options]
   * @param {'nearest'|'down'} [options.rounding] `down` pou yon montan n ap
   *   VOYE deyò: nou pa janm voye plis pase valè nou debite.
   */
  async function convert(amountMinor, from, to, { rounding = "nearest" } = {}) {
    const source = await info(from);
    const target = await info(to);

    if (source.currency === target.currency) {
      return {
        amountMinor,
        rate: 1,
        fromRateToHtg: source.rateToHtg,
        toRateToHtg: target.rateToHtg,
        crossCurrency: false,
        stale: false,
        updatedAt: null,
      };
    }

    assertUsable(source);
    assertUsable(target);

    const exact = (amountMinor * source.rateToHtg) / target.rateToHtg;
    // `1e-9`: 580,9999999 se 581 — erè flotan pa dwe koute yon santim.
    const converted = rounding === "down" ? Math.floor(exact + 1e-9) : Math.round(exact);

    const dated = [source, target].filter((rate) => rate.source !== "identity");

    return {
      amountMinor: converted,
      /** Konbyen `to` pou 1 `from`. */
      rate: source.rateToHtg / target.rateToHtg,
      fromRateToHtg: source.rateToHtg,
      toRateToHtg: target.rateToHtg,
      crossCurrency: true,
      stale: dated.some(isStale),
      /** To ki pi vye nan de a: se li ki limite fyabilite konvèsyon an. */
      updatedAt: dated.length ? Math.min(...dated.map((rate) => rate.updatedAt)) : null,
    };
  }

  return { info, convert, isStale, assertUsable, requireFresh, maxAgeMs };
}

module.exports = { createRateBook, API_SOURCE, STALE_AFTER_MS, DEFAULT_MAX_AGE_MS };
