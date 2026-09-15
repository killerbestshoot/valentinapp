"use strict";

/**
 * Konfigirasyon Bazik.
 *
 * Mode yo:
 *  - "fake"    : okenn rezo, yon similatè lokal. Se default la lè ke pa gen kle.
 *  - "sandbox" : vre API Bazik, kle sandbox.
 *  - "live"    : pwodiksyon.
 *
 * Sekrè yo pa janm nan kòd la. An lokal: varyab anviwònman.
 * Nan Cloud Functions: Secret Manager (defineSecret).
 */

const DEFAULT_BASE_URL = "https://api.bazik.io";

function readEnv(env, key) {
  const value = env[key];
  return typeof value === "string" ? value.trim() : "";
}

function loadConfig(env = process.env) {
  const userId = readEnv(env, "BAZIK_USER_ID");
  const secretKey = readEnv(env, "BAZIK_SECRET_KEY");
  const explicitMode = readEnv(env, "BAZIK_MODE").toLowerCase();

  const hasCredentials = userId.length > 0 && secretKey.length > 0;
  const mode = explicitMode || (hasCredentials ? "sandbox" : "fake");

  if (!["fake", "sandbox", "live"].includes(mode)) {
    throw new Error(`BAZIK_MODE pa valid: ${mode}`);
  }

  if (mode !== "fake" && !hasCredentials) {
    throw new Error(
      `BAZIK_MODE=${mode} mande BAZIK_USER_ID ak BAZIK_SECRET_KEY.`
    );
  }

  return {
    mode,
    isFake: mode === "fake",
    isLive: mode === "live",
    baseUrl: readEnv(env, "BAZIK_BASE_URL") || DEFAULT_BASE_URL,
    userId,
    secretKey,
    webhookSecret: readEnv(env, "BAZIK_WEBHOOK_SECRET"),
    /** Deviz wallet yo nan app la (WalletEngine ekri 'USD' pa default). */
    walletCurrency: readEnv(env, "WALLET_CURRENCY") || "USD",
    /** Konbyen fwa nou re-eseye yon apèl ki echwe pou yon rezon tanporè. */
    maxRetries: Number(readEnv(env, "BAZIK_MAX_RETRIES") || 3),
    /** Limit Bazik: 100 req/min. Nou rete anba pou nou pa pran 429. */
    maxRequestsPerMinute: Number(readEnv(env, "BAZIK_MAX_RPM") || 90),
    requestTimeoutMs: Number(readEnv(env, "BAZIK_TIMEOUT_MS") || 20000),
  };
}

module.exports = { loadConfig, DEFAULT_BASE_URL };
