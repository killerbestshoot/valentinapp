"use strict";

/**
 * Konfigirasyon Reloadly Airtime.
 *
 * Mòd yo, menm lojik ak Bazik:
 *  - "fake"    : similatè lokal, okenn rezo. Default la lè pa gen kle.
 *  - "sandbox" : vre API Reloadly, kle sandbox, pa gen vre minit ki pati.
 *  - "live"    : pwodiksyon.
 *
 * URL yo soti nan SDK Java ofisyèl la (`ServiceURLs`, `AuthenticationAPI`),
 * pa nan dok piblik la — gade `docs/contract.md`.
 */

const AUTH_URL = "https://auth.reloadly.com";

const SERVICE_URLS = {
  sandbox: "https://topups-sandbox.reloadly.com",
  live: "https://topups.reloadly.com",
};

/** Peyi Minit Haiti sèvi a. Nou pa vann minit pou lòt peyi. */
const COUNTRY_CODE = "HT";

function readEnv(env, key) {
  const value = env[key];
  return typeof value === "string" ? value.trim() : "";
}

function loadReloadlyConfig(env = process.env) {
  const clientId = readEnv(env, "RELOADLY_CLIENT_ID");
  const clientSecret = readEnv(env, "RELOADLY_CLIENT_SECRET");
  const explicitMode = readEnv(env, "RELOADLY_MODE").toLowerCase();

  const hasCredentials = clientId.length > 0 && clientSecret.length > 0;
  const mode = explicitMode || (hasCredentials ? "sandbox" : "fake");

  if (!["fake", "sandbox", "live"].includes(mode)) {
    throw new Error(`RELOADLY_MODE pa valid: ${mode}`);
  }

  if (mode !== "fake" && !hasCredentials) {
    throw new Error(
      `RELOADLY_MODE=${mode} mande RELOADLY_CLIENT_ID ak RELOADLY_CLIENT_SECRET.`
    );
  }

  const serviceUrl = SERVICE_URLS[mode] || SERVICE_URLS.sandbox;

  return {
    mode,
    isFake: mode === "fake",
    isLive: mode === "live",
    authUrl: readEnv(env, "RELOADLY_AUTH_URL") || AUTH_URL,
    baseUrl: readEnv(env, "RELOADLY_BASE_URL") || serviceUrl,
    // SDK a mete URL sèvis la kòm `audience` (`service.getServiceUrl()`). Yon
    // jeton sandbox pa mache sou live, ni lekontrè.
    audience: serviceUrl,
    clientId,
    clientSecret,
    countryCode: COUNTRY_CODE,
    maxRetries: Number(readEnv(env, "RELOADLY_MAX_RETRIES") || 2),
    // Anba 25 s kliyan Flutter la, pou yon rechaj ki lan pa kite ajan an
    // san repons pandan serveur a toujou ap tann.
    requestTimeoutMs: Number(readEnv(env, "RELOADLY_TIMEOUT_MS") || 20000),
  };
}

module.exports = { loadReloadlyConfig, AUTH_URL, SERVICE_URLS, COUNTRY_CODE };
