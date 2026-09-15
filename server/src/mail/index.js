"use strict";

/**
 * Pwen antre voye imel.
 *
 *   const { getMailer } = require("./mail");
 *   await getMailer().sendOtp("moun@example.com", "123456", 300);
 *
 * Founisè a chwazi nan `MAIL_PROVIDER` (gade `config.js`). Rès kòd la pa
 * konnen si se SMTP oswa HTTP ki dèyè.
 */

const { loadMailConfig } = require("./config");
const { createSmtpTransport } = require("./smtp_transport");
const { createApiTransport, MailError } = require("./api_transport");
const { otpEmail } = require("./templates");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Transpò `console`: dev sèlman, li ekri kòd la nan log la. */
function createConsoleTransport(config) {
  return {
    provider: "console",
    sent: [],

    async send({ to, subject, text }) {
      this.sent.push({ to, subject, text });
      console.log(`\n[mail:console] -> ${to}\n[mail:console] ${subject}\n`);
      return { ok: true, console: true };
    },

    async verify() {
      return { ok: true, provider: "console" };
    },

    async close() {},
  };
}

function createTransport(config, options = {}) {
  switch (config.provider) {
    case "hostinger_api":
      return createApiTransport(config, options);
    case "hostinger_smtp":
    case "gmail":
      return createSmtpTransport(config, options);
    default:
      return createConsoleTransport(config, options);
  }
}

function createMailer({ env, transport, config } = {}) {
  const resolvedConfig = config || loadMailConfig(env);
  const resolvedTransport = transport || createTransport(resolvedConfig);

  /** Voye ak retry sou erè tanporè sèlman. */
  async function send(message) {
    let lastError = null;

    for (let attempt = 0; attempt <= resolvedConfig.maxRetries; attempt++) {
      try {
        return await resolvedTransport.send(message);
      } catch (err) {
        lastError = err;

        const canRetry =
          err instanceof MailError && err.retryable && attempt < resolvedConfig.maxRetries;

        if (!canRetry) throw err;

        await sleep(300 * 2 ** attempt);
      }
    }

    throw lastError;
  }

  return {
    provider: resolvedConfig.provider,
    config: resolvedConfig,
    transport: resolvedTransport,

    send,

    /** Voye yon kòd OTP. */
    async sendOtp(to, code, ttlSeconds) {
      const message = otpEmail({
        code,
        ttlSeconds,
        appName: resolvedConfig.fromName,
      });

      return send({ to, ...message });
    },

    /** Teste konfigirasyon an (koneksyon + otantifikasyon) san voye anyen. */
    async verify() {
      return resolvedTransport.verify();
    },

    async close() {
      return resolvedTransport.close();
    },
  };
}

/** Yon sèl enstans pou tout serveur a (koneksyon SMTP la rete louvri). */
let singleton = null;

function getMailer() {
  return (singleton ??= createMailer());
}

function resetMailer() {
  singleton = null;
}

module.exports = { createMailer, getMailer, resetMailer, MailError, otpEmail };
