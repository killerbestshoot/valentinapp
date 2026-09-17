"use strict";

/**
 * Kliyan exchangerate-api.com (v6).
 *
 *   GET https://v6.exchangerate-api.com/v6/{KLE}/latest/USD
 *
 * Repons (verifye le 17/09/2026, fiksti `test/fixtures/exchangerate_api_latest_usd_*.json`):
 *   { result: "success", base_code: "USD",
 *     time_last_update_unix, time_next_update_unix,   // chak jou a 00:00 UTC
 *     conversion_rates: { USD: 1, HTG: 130.6979, MXN: 17.1932, ... } }   // 166 deviz
 * Erè: HTTP 403 { result: "error", "error-type": "invalid-key" }
 *
 * KLE A NAN CHEMEN URL LA: li pa janm parèt nan yon log ni nan yon mesaj erè.
 * Se poutèt sa nou pa janm mete `err.message` fetch la (ki ka pote URL la).
 */

const DEFAULT_BASE_URL = "https://v6.exchangerate-api.com/v6";

/** Erè ke re-eseye jodi a p ap regle: sa t ap sèlman boule kota a. */
const PERMANENT_ERRORS = new Set([
  "missing_key",
  "invalid-key",
  "inactive-account",
  "quota-reached",
  "unsupported-code",
  "malformed-request",
]);

class RateProviderError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "RateProviderError";
    this.code = code;
    this.permanent = PERMANENT_ERRORS.has(code);
  }
}

/**
 * Tradui repons lan an "HTG pou 1 inite" — fòm `exchange_rates` la.
 * API a bay "X pou 1 USD": to(X -> HTG) = HTG pou 1 USD / X pou 1 USD.
 */
function parseLatest(body) {
  if (body?.base_code !== "USD") {
    throw new RateProviderError("bad_response", `Baz la dwe USD, li se ${body?.base_code}.`);
  }

  const perUsd = body.conversion_rates;
  const htgPerUsd = Number(perUsd?.HTG);
  if (!Number.isFinite(htgPerUsd) || htgPerUsd <= 0) {
    throw new RateProviderError("bad_response", "To HTG a manke oswa li pa valid nan repons lan.");
  }

  const rateToHtg = {};
  for (const [code, value] of Object.entries(perUsd)) {
    const number = Number(value);
    if (/^[A-Z]{3}$/.test(code) && Number.isFinite(number) && number > 0) {
      rateToHtg[code] = htgPerUsd / number;
    }
  }
  rateToHtg.HTG = 1;

  const providerUpdatedAt = Number(body.time_last_update_unix) * 1000;
  if (!Number.isFinite(providerUpdatedAt) || providerUpdatedAt <= 0) {
    throw new RateProviderError("bad_response", "`time_last_update_unix` manke.");
  }

  return {
    providerUpdatedAt,
    nextUpdateAt: Number(body.time_next_update_unix) * 1000 || 0,
    rateToHtg,
  };
}

async function fetchLatestUsdRates({
  apiKey,
  baseUrl = DEFAULT_BASE_URL,
  fetchImpl = globalThis.fetch,
  timeoutMs = 15000,
} = {}) {
  if (!apiKey) {
    throw new RateProviderError("missing_key", "EXCHANGE_RATE_API_KEY pa konfigire.");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  let response;
  try {
    response = await fetchImpl(`${baseUrl}/${encodeURIComponent(apiKey)}/latest/USD`, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
  } catch (err) {
    throw new RateProviderError(
      "network_error",
      `exchangerate-api pa reponn (${err.name === "AbortError" ? "timeout" : "rezo"}).`
    );
  } finally {
    clearTimeout(timer);
  }

  let body;
  try {
    body = await response.json();
  } catch {
    throw new RateProviderError("bad_response", `Repons exchangerate-api a pa JSON (HTTP ${response.status}).`);
  }

  if (body?.result !== "success") {
    const type = String(body?.["error-type"] || `http_${response.status}`);
    throw new RateProviderError(type, `exchangerate-api refize demann lan: ${type}.`);
  }

  return parseLatest(body);
}

module.exports = { fetchLatestUsdRates, parseLatest, RateProviderError, DEFAULT_BASE_URL };
