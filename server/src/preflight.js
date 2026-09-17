"use strict";

/**
 * Verifikasyon konfigirasyon anvan serveur a demare an pwodiksyon.
 *
 * San sa, yon kle ki manke pa bloke anyen: `loadConfig` Bazik la tonbe sou
 * mòd `fake` pou kont li lè pa gen kle, e ajan yo t ap "voye" kòb ki pa janm
 * pati — epi komisyon yo t ap kredite sou transfè ki pa egziste. Menm jan an,
 * yon `OTP_SECRET` ki manke fè premye OTP a kraze, pa demaraj la.
 *
 * Nou pito yon konteneur ki refize demare ak yon mesaj klè pase yon sèvis ki
 * sanble mache.
 */

const { loadConfig } = require("../../bazik/src/config");
const { loadMailConfig } = require("./mail/config");
const { loadReloadlyConfig } = require("../../reloadly/src/config");

const MIN_SECRET_LENGTH = 32;

function read(env, key) {
  const value = env[key];
  return typeof value === "string" ? value.trim() : "";
}

/**
 * @returns {{ errors: string[], warnings: string[] }}
 */
function checkProductionConfig(env = process.env) {
  const errors = [];
  const warnings = [];

  if (read(env, "NODE_ENV") !== "production") {
    return { errors, warnings };
  }

  if (read(env, "OTP_SECRET").length < MIN_SECRET_LENGTH) {
    errors.push(
      `OTP_SECRET manke oswa twò kout (min. ${MIN_SECRET_LENGTH} karaktè). ` +
        "Jenere youn: openssl rand -hex 32"
    );
  }

  try {
    const bazik = loadConfig(env);

    if (bazik.isFake && read(env, "ALLOW_FAKE_GATEWAY") !== "true") {
      errors.push(
        "Pasrèl Bazik la an mòd `fake`: okenn transfè p ap pati vre. " +
          "Mete BAZIK_MODE=live (oswa sandbox) ak kle yo, oswa " +
          "ALLOW_FAKE_GATEWAY=true pou yon demo."
      );
    }

    if (!bazik.isFake && !bazik.webhookSecret) {
      errors.push(
        `BAZIK_WEBHOOK_SECRET manke: webhook Bazik yo t ap refize, e transfè yo ` +
          "t ap rete an verifikasyon."
      );
    }

    if (bazik.mode === "sandbox") {
      warnings.push("Bazik an mòd sandbox: pa gen vre kòb k ap deplase.");
    }
  } catch (err) {
    errors.push(err.message);
  }

  try {
    loadMailConfig(env);
  } catch (err) {
    errors.push(err.message);
  }

  // Minit Haiti: yon kle ki manke DEZAKTIVE sèvis la (503), li pa bloke
  // demaraj la. MonCash ak NatCash pa dwe tonbe paske Reloadly poko pare.
  // Men yon mòd EKSPLISIT san kle (RELOADLY_MODE=live, kle bliye) se yon
  // move konfigirasyon: la, nou bloke.
  try {
    const reloadly = loadReloadlyConfig(env);

    if (reloadly.isFake && read(env, "ALLOW_FAKE_GATEWAY") !== "true") {
      warnings.push(
        "Reloadly pa konfigire: Minit Haiti dezaktive (wout /api/airtime reponn 503). " +
          "Mete RELOADLY_CLIENT_ID ak RELOADLY_CLIENT_SECRET pou aktive l."
      );
    }

    if (reloadly.mode === "sandbox") {
      warnings.push("Reloadly an mòd sandbox: okenn vre minit p ap pati.");
    }
  } catch (err) {
    errors.push(err.message);
  }

  // To echanj: an pwodiksyon, konvèsyon ant de deviz REFIZE to fiks `seed` yo
  // (jiska 5% lwen mache a). San kle, chak ajan ki pa travay an HTG ta bloke.
  if (!read(env, "EXCHANGE_RATE_API_KEY")) {
    errors.push(
      "EXCHANGE_RATE_API_KEY manke: to echanj yo pa ka mete ajou, e tout konvèsyon " +
        "deviz (USD, MXN, CLP... -> HTG) ta refize. Kle a: https://www.exchangerate-api.com"
    );
  }

  const maxAgeHours = read(env, "RATES_MAX_AGE_HOURS");
  if (maxAgeHours && !(Number(maxAgeHours) > 0)) {
    errors.push(`RATES_MAX_AGE_HOURS pa valid: ${maxAgeHours} (nonm èdtan pozitif).`);
  }

  const origins = read(env, "CORS_ORIGINS");
  if (!origins || origins === "*") {
    warnings.push("CORS_ORIGINS pa defini: API a aksepte demand depi nenpòt orijin.");
  }

  return { errors, warnings };
}

module.exports = { checkProductionConfig, MIN_SECRET_LENGTH };
