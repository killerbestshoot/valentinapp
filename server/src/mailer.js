const nodemailer = require("nodemailer");
require("dotenv").config();

function createTransporter() {
  if (process.env.NODE_ENV !== "production" && process.env.OTP_EMAIL_MODE !== "smtp") {
    return null;
  }

  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
    throw new Error("SMTP_USER/SMTP_PASS manke nan .env");
  }

  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

async function sendOtpEmail(toEmail, otp) {
  const transporter = createTransporter();
  if (!transporter) {
    console.log(`Dev OTP for ${toEmail}: ${otp}`);
    return;
  }

  const subject = "VOUPVAPCASH - Kòd OTP ou";
  const text = `Men kòd OTP ou: ${otp}\nLi valab pou 5 minit.`;
  const html = `
    <div style="font-family:Arial,sans-serif">
      <h2>VOUPVAPCASH</h2>
      <p>Men kòd OTP ou:</p>
      <div style="font-size:28px;font-weight:bold;letter-spacing:3px">${otp}</div>
      <p style="color:#666">Li valab pou 5 minit.</p>
    </div>
  `;

  await transporter.sendMail({
    from: `"VOUPVAPCASH" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject,
    text,
    html,
  });
}

module.exports = { sendOtpEmail };
