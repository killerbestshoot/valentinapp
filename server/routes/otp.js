const express = require("express");
const nodemailer = require("nodemailer");

const router = express.Router();

// In-memory store (dev). Pita n ap mete DB (Firestore/SQL).
// Map key: email, value: { code, expiresAt }
const otpStore = new Map();

function genOtp(length) {
  let otp = "";
  for (let i = 0; i < length; i++) otp += Math.floor(Math.random() * 10);
  return otp;
}

function minutesToMs(min) {
  return min * 60 * 1000;
}

function makeTransporter() {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 465);
  const secure = String(process.env.SMTP_SECURE || "true") === "true";
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    throw new Error("SMTP env missing. Check SMTP_HOST/SMTP_USER/SMTP_PASS in .env");
  }

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });
}

router.post("/send-otp", async (req, res) => {
  try {
    const { email } = req.body || {};
    if (!email || typeof email !== "string") {
      return res.status(400).json({ ok: false, error: "Email required" });
    }

    const ttlMin = Number(process.env.OTP_TTL_MINUTES || 5);
    const otpLen = Number(process.env.OTP_LENGTH || 5);

    const code = genOtp(otpLen);
    const expiresAt = Date.now() + minutesToMs(ttlMin);

    otpStore.set(email.toLowerCase().trim(), { code, expiresAt });

    const transporter = makeTransporter();

    const from = process.env.SMTP_USER;
    const subject = "Kòd OTP pou VOUPVAPCASH";
    const text = `Men kòd ou: ${code}\n\nLi valab pou ${ttlMin} minit. Si se pa ou, inyore mesaj sa.`;
    const html = `
      <div style="font-family: Arial, sans-serif;">
        <h2>VOUPVAPCASH - OTP</h2>
        <p>Men kòd ou:</p>
        <h1 style="letter-spacing: 4px;">${code}</h1>
        <p>Kòd la valab pou <b>${ttlMin} minit</b>.</p>
        <p>Si se pa ou, inyore mesaj sa.</p>
      </div>
    `;

    await transporter.sendMail({
      from,
      to: email,
      subject,
      text,
      html,
    });

    return res.json({ ok: true, message: "OTP sent" });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ ok: false, error: "Failed to send OTP" });
  }
});

router.post("/verify-otp", async (req, res) => {
  try {
    const { email, code } = req.body || {};
    if (!email || !code) {
      return res.status(400).json({ ok: false, error: "Email & code required" });
    }

    const key = email.toLowerCase().trim();
    const entry = otpStore.get(key);

    if (!entry) {
      return res.status(400).json({ ok: false, error: "No OTP found for this email" });
    }

    if (Date.now() > entry.expiresAt) {
      otpStore.delete(key);
      return res.status(400).json({ ok: false, error: "OTP expired" });
    }

    if (String(code).trim() !== entry.code) {
      return res.status(400).json({ ok: false, error: "Invalid OTP" });
    }

    otpStore.delete(key);
    return res.json({ ok: true, message: "OTP verified" });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ ok: false, error: "Failed to verify OTP" });
  }
});

module.exports = router;