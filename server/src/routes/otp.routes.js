"use strict";

/**
 * Wout OTP.
 *
 * Kòd la pati atravè `src/mail/` (Hostinger SMTP oswa Hostinger Mail API,
 * selon `MAIL_PROVIDER`). Wout sa a pa konnen ki transpò ki anba a.
 */

const express = require("express");
const { randomInt } = require("node:crypto");

const { saveOtp, verifyOtp, canSend } = require("../otp_store");
const { getMailer } = require("../mail");

const router = express.Router();

const DEFAULT_TTL_SECONDS = 300;

/**
 * `randomInt` sèvi ak yon sous aleyatwa kriptografik.
 * `Math.random()` pa dwe janm jenere yon OTP: li previzib.
 */
function generateOtp() {
  return String(randomInt(0, 1000000)).padStart(6, "0");
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

router.post("/send", async (req, res) => {
  const email = String(req.body?.email || "").trim().toLowerCase();

  if (!isValidEmail(email)) {
    return res.status(400).json({ ok: false, code: "invalid_email", message: "Email pa valid." });
  }

  // Anpeche yon moun sèvi ak fòm nan pou inonde yon adrès.
  const gate = canSend(email);
  if (!gate.allowed) {
    return res.status(429).json({
      ok: false,
      code: "too_soon",
      message: `Tann ${gate.retryAfterSeconds} segond anvan ou mande yon lòt kòd.`,
      retryAfterSeconds: gate.retryAfterSeconds,
    });
  }

  const otp = generateOtp();
  const ttl = Number(process.env.OTP_TTL_SECONDS || DEFAULT_TTL_SECONDS);

  try {
    // Nou voye imel la ANVAN nou anrejistre: si Hostinger refize, nou pa vle
    // yon kòd ki egziste nan baz la men ki pa janm rive nan men moun nan
    // (sa t ap bloke l pandan tout delè a pou granmesi).
    await getMailer().sendOtp(email, otp, ttl);
    saveOtp(email, otp, ttl);

    return res.json({ ok: true, message: "OTP voye sou email la.", expiresInSeconds: ttl });
  } catch (err) {
    console.error("[otp] voye echwe:", err.code || "", err.message);

    const unauthorized = err.code === "unauthorized" || err.code === "EAUTH";

    return res.status(502).json({
      ok: false,
      code: unauthorized ? "mail_auth_failed" : "mail_send_failed",
      message: unauthorized
        ? "Konfigirasyon imel la pa bon. Kontakte administratè a."
        : "Nou pa rive voye imel la. Eseye ankò.",
    });
  }
});

router.post("/verify", (req, res) => {
  const email = String(req.body?.email || "").trim().toLowerCase();
  const otp = String(req.body?.otp || "").trim();

  if (!email || !otp) {
    return res
      .status(400)
      .json({ ok: false, code: "missing_fields", message: "Email + OTP obligatwa." });
  }

  const result = verifyOtp(email, otp);

  if (result.ok) {
    return res.json({ ok: true, message: "OTP verifye." });
  }

  const messages = {
    not_found: "Pa gen kòd pou adrès sa a. Mande yon nouvo kòd.",
    expired: "Kòd la ekspire. Mande yon nouvo kòd.",
    too_many_attempts: "Twòp tantativ. Mande yon nouvo kòd.",
    invalid: "Kòd la pa bon.",
  };

  return res.status(401).json({
    ok: false,
    code: result.reason,
    message: messages[result.reason] || "Kòd la pa bon.",
    ...(result.attemptsLeft !== undefined ? { attemptsLeft: result.attemptsLeft } : {}),
  });
});

/** Tcheke konfigirasyon imel la san voye anyen (zouti dyagnostik). */
router.get("/health", async (req, res) => {
  try {
    const mailer = getMailer();
    const status = await mailer.verify();
    return res.json({ ok: true, provider: mailer.provider, ...status });
  } catch (err) {
    return res.status(502).json({ ok: false, code: err.code || "verify_failed", message: err.message });
  }
});

module.exports = router;
