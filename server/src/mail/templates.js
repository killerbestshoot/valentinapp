"use strict";

/**
 * Tèks imel yo.
 *
 * Règ pou yon imel OTP:
 *  - kòd la nan SIJÈ a tou: kèk kliyan imel montre sijè a nan notifikasyon an,
 *    donk itilizatè a li kòd la san li menm louvri mesaj la;
 *  - di klèman konbyen tan li valab;
 *  - di sa pou fè si se pa ou ki mande l;
 *  - PA gen lyen ladan: yon imel OTP san lyen pi difisil pou imite (phishing).
 */

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function otpEmail({ code, ttlSeconds, appName = "VOUPVAPCASH" }) {
  const minutes = Math.max(1, Math.round(ttlSeconds / 60));
  const safeCode = escapeHtml(code);

  return {
    subject: `${code} — kòd ${appName} ou`,

    text: [
      `Kòd ${appName} ou se: ${code}`,
      ``,
      `Li valab pou ${minutes} minit.`,
      `Pa bay pèsonn kòd sa a — menm si yo di ou yo se ${appName}.`,
      ``,
      `Si se pa ou ki mande l, inyore mesaj sa a.`,
    ].join("\n"),

    html: `
<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1a1a1a">
  <h1 style="font-size:18px;margin:0 0 16px">${escapeHtml(appName)}</h1>
  <p style="margin:0 0 8px">Kòd ou:</p>
  <div style="font-size:32px;font-weight:bold;letter-spacing:6px;padding:16px 0">${safeCode}</div>
  <p style="margin:0 0 16px;color:#555">Li valab pou <strong>${minutes} minit</strong>.</p>
  <p style="margin:0 0 16px;color:#b00020">
    Pa bay pèsonn kòd sa a — menm si yo di ou yo se ${escapeHtml(appName)}.
  </p>
  <hr style="border:none;border-top:1px solid #e5e5e5;margin:24px 0">
  <p style="margin:0;color:#888;font-size:12px">
    Si se pa ou ki mande kòd sa a, ou pa bezwen fè anyen.
  </p>
</div>`.trim(),
  };
}

function resetPasswordEmail({ code, ttlSeconds, appName = "VOUPVAPCASH" }) {
  const minutes = Math.max(1, Math.round(ttlSeconds / 60));
  const safeCode = escapeHtml(code);

  return {
    subject: `${code} — reinisyalize modpas ${appName} ou`,

    text: [
      `Reinisyalizasyon modpas ${appName}`,
      ``,
      `Kòd konfirmasyon ou se: ${code}`,
      ``,
      `Li valab pou ${minutes} minit.`,
      `Pa bay pèsonn kòd sa a — menm si yo di ou yo se ${appName}.`,
      ``,
      `Si se pa ou ki mande reinisyalizasyon an, inyore mesaj sa a — kont ou an sekirite.`,
    ].join("\n"),

    html: `
<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1a1a1a">
  <h1 style="font-size:18px;margin:0 0 4px">${escapeHtml(appName)}</h1>
  <p style="margin:0 0 20px;color:#555;font-size:14px">Reinisyalizasyon modpas</p>
  <p style="margin:0 0 8px">Kòd konfirmasyon ou:</p>
  <div style="font-size:36px;font-weight:bold;letter-spacing:8px;padding:20px 0;color:#1a1a1a">${safeCode}</div>
  <p style="margin:0 0 16px;color:#555">Li valab pou <strong>${minutes} minit</strong>.</p>
  <p style="margin:0 0 16px;color:#b00020">
    Pa bay pèsonn kòd sa a — menm si yo di ou yo se ${escapeHtml(appName)}.
  </p>
  <hr style="border:none;border-top:1px solid #e5e5e5;margin:24px 0">
  <p style="margin:0;color:#888;font-size:12px">
    Si se pa ou ki mande reinisyalizasyon sa a, inyore mesaj sa a — kont ou an sekirite.
    Pa gen lyen pou klike nan mesaj sa a.
  </p>
</div>`.trim(),
  };
}

module.exports = { otpEmail, resetPasswordEmail, escapeHtml };
