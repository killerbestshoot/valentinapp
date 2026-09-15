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

  const origins = read(env, "CORS_ORIGINS");
  if (!origins || origins === "*") {
    warnings.push("CORS_ORIGINS pa defini: API a aksepte demand depi nenpòt orijin.");
  }

  return { errors, warnings };
}

module.exports = { checkProductionConfig, MIN_SECRET_LENGTH };
