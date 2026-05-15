const express = require("express");
const router = express.Router();

const { saveOtp, verifyOtp } = require("../otp_store");
const { sendOtpEmail } = require("../mailer");

function genOtp6() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

router.post("/send", async (req, res) => {
  try {
    const email = String(req.body?.email || "").trim().toLowerCase();
    if (!email || !email.includes("@")) {
      return res.status(400).json({ ok: false, message: "Email pa valid." });
    }

    const otp = genOtp6();
    const ttl = Number(process.env.OTP_TTL_SECONDS || 300);

    saveOtp(email, otp, ttl);
    await sendOtpEmail(email, otp);

    return res.json({ ok: true, message: "OTP voye sou email la." });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ ok: false, message: "Erè pandan voye OTP." });
  }
});

router.post("/verify", (req, res) => {
  const email = String(req.body?.email || "").trim().toLowerCase();
  const otp = String(req.body?.otp || "").trim();

  if (!email || !otp) {
    return res.status(400).json({ ok: false, message: "Email + OTP obligatwa." });
  }

  const ok = verifyOtp(email, otp);
  if (!ok) {
    return res.status(401).json({ ok: false, message: "OTP pa bon oswa ekspire." });
  }

  return res.json({ ok: true, message: "OTP verifye." });
});

module.exports = router;