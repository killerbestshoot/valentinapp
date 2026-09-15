"use strict";

/**
 * Transpò SMTP (Hostinger oswa Gmail), atravè nodemailer.
 *
 * Hostinger: smtp.hostinger.com, pò 465 ak SSL dirèk. Si rezo a bloke 465,
 * sèvi ak SMTP_PORT=587 ak SMTP_SECURE=false (STARTTLS).
 */

const nodemailer = require("nodemailer");
const { MailError } = require("./api_transport");

/** Kòd nodemailer/SMTP ki vle di "eseye ankò pita". */
const RETRYABLE_CODES = new Set([
  "ETIMEDOUT",
  "ECONNRESET",
  "ECONNECTION",
  "ESOCKET",
  "EDNS",
  "ETLS",
]);

function createSmtpTransport(config) {
  const transporter = nodemailer.createTransport({
    ...config.smtp,
    connectionTimeout: config.timeoutMs,
    greetingTimeout: config.timeoutMs,
  });

  return {
    provider: config.provider,

    async send({ to, subject, text, html }) {
      try {
        const info = await transporter.sendMail({
          from: `"${config.fromName}" <${config.from}>`,
          to: Array.isArray(to) ? to.join(", ") : to,
          subject,
          text,
          html,
        });

        return { ok: true, messageId: info.messageId };
      } catch (err) {
        // 5xx SMTP = refi definitif; 4xx = tanporè.
        const permanent = typeof err.responseCode === "number" && err.responseCode >= 500;
        const retryable = !permanent && (RETRYABLE_CODES.has(err.code) || err.responseCode >= 400);

        throw new MailError(err.code || "smtp_error", err.message, {
          status: err.responseCode || 0,
          retryable,
        });
      }
    },

    /** Teste koneksyon an + otantifikasyon an san voye imel. */
    async verify() {
      try {
        await transporter.verify();
        return { ok: true, provider: config.provider };
      } catch (err) {
        throw new MailError(err.code || "smtp_verify_failed", err.message, {
          status: err.responseCode || 0,
        });
      }
    },

    async close() {
      transporter.close();
    },
  };
}

module.exports = { createSmtpTransport };
