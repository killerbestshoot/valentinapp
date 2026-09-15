"use strict";

/**
 * Konfigirasyon voye imel.
 *
 * Kat founisè:
 *  - `hostinger_smtp` : smtp.hostinger.com:465 (SSL) — default la
 *  - `hostinger_api`  : https://api.mail.hostinger.com (Bearer token)
 *  - `gmail`          : ansyen konfigirasyon an, nou kenbe l pou tranzisyon
 *  - `console`        : dev — nou ekri kòd la nan log la, nou pa voye anyen
 *
 * Poukisa de chemen Hostinger? SMTP mande pò 465/587 soti. Anpil anviwònman
 * serverless bloke pò sa yo; nan ka sa a se API HTTP la ki travay. Menm kòd,
 * yon sèl varyab anviwònman ki chanje.
 */

/** Valè Hostinger yo (hPanel > Emails > Connect apps & devices). */
const HOSTINGER_SMTP = {
  host: "smtp.hostinger.com",
  port: 465,
  secure: true, // 465 = TLS dirèk. Si rezo a bloke l, sèvi ak 587 + secure=false.
};

const HOSTINGER_API_BASE = "https://api.mail.hostinger.com";

const PROVIDERS = ["hostinger_smtp", "hostinger_api", "gmail", "console"];

function read(env, key, fallback = "") {
  const value = env[key];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : fallback;
}

function readBool(env, key, fallback) {
  const value = read(env, key, "");
  if (value === "") return fallback;
  return value.toLowerCase() === "true" || value === "1";
}

function readNumber(env, key, fallback) {
  const value = Number(read(env, key, ""));
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

/**
 * Chwazi founisè a.
 *
 * Nou pa janm tonbe sou `console` an silans nan pwodiksyon: si yon moun bliye
 * konfigire mailbox la, nou vle yon erè klè, pa yon OTP ki disparèt.
 */
function resolveProvider(env) {
  const explicit = read(env, "MAIL_PROVIDER").toLowerCase();

  if (explicit) {
    if (!PROVIDERS.includes(explicit)) {
      throw new Error(`MAIL_PROVIDER pa valid: ${explicit}. Chwazi nan: ${PROVIDERS.join(", ")}`);
    }
    return explicit;
  }

  if (read(env, "HOSTINGER_MAIL_TOKEN")) return "hostinger_api";
  if (read(env, "SMTP_USER") && read(env, "SMTP_PASS")) {
    // Ansyen `.env` la te vize Gmail. Nou detekte l pou nou pa kase anyen.
    return read(env, "SMTP_USER").endsWith("@gmail.com") ? "gmail" : "hostinger_smtp";
  }

  return "console";
}

function loadMailConfig(env = process.env) {
  const provider = resolveProvider(env);
  const isProduction = read(env, "NODE_ENV") === "production";

  if (provider === "console" && isProduction) {
    throw new Error(
      "MAIL_PROVIDER=console entèdi an pwodiksyon: OTP yo t ap ekri nan log la olye yo pati."
    );
  }

  const config = {
    provider,
    isProduction,
    fromName: read(env, "MAIL_FROM_NAME", "VOUPVAPCASH"),
    /** Konbyen fwa nou re-eseye lè sèvè a bay yon erè tanporè. */
    maxRetries: readNumber(env, "MAIL_MAX_RETRIES", 2),
    timeoutMs: readNumber(env, "MAIL_TIMEOUT_MS", 15000),
  };

  if (provider === "hostinger_smtp" || provider === "gmail") {
    const user = read(env, "SMTP_USER");
    const pass = read(env, "SMTP_PASS");

    if (!user || !pass) {
      throw new Error(`MAIL_PROVIDER=${provider} mande SMTP_USER ak SMTP_PASS.`);
    }

    config.smtp =
      provider === "gmail"
        ? { service: "gmail", auth: { user, pass } }
        : {
            host: read(env, "SMTP_HOST", HOSTINGER_SMTP.host),
            port: readNumber(env, "SMTP_PORT", HOSTINGER_SMTP.port),
            secure: readBool(env, "SMTP_SECURE", HOSTINGER_SMTP.secure),
            auth: { user, pass },
            // Yon sèl koneksyon ki rete louvri: OTP yo pati pi vit, e nou pa
            // refè yon handshake TLS pou chak imel.
            pool: true,
            maxConnections: readNumber(env, "SMTP_MAX_CONNECTIONS", 3),
          };

    config.from = read(env, "MAIL_FROM", user);
  }

  if (provider === "hostinger_api") {
    const token = read(env, "HOSTINGER_MAIL_TOKEN");
    const mailboxId = read(env, "HOSTINGER_MAILBOX_ID");

    if (!token || !mailboxId) {
      throw new Error(
        "MAIL_PROVIDER=hostinger_api mande HOSTINGER_MAIL_TOKEN ak HOSTINGER_MAILBOX_ID " +
          "(hPanel > Emails > API tokens)."
      );
    }

    config.api = {
      baseUrl: read(env, "HOSTINGER_MAIL_BASE_URL", HOSTINGER_API_BASE),
      token,
      mailboxId,
    };

    // Ak API a, adrès la se mailbox token an otorize a — nou pa chwazi l.
    config.from = read(env, "MAIL_FROM", "");
  }

  return config;
}

module.exports = { loadMailConfig, PROVIDERS, HOSTINGER_SMTP, HOSTINGER_API_BASE };
