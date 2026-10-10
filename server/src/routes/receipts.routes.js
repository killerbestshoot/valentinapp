"use strict";

/**
 * Verifikasyon resi.
 *
 *   GET /api/receipts/verify?tx=…&s=…   PIBLIK: QR kòd resi a mennen la
 *
 * Yon resi pataje an imaj ka fabrike nan nenpòt editè foto. Siyati a (HMAC
 * referans + montan + deviz) se sèl bagay yon fo resi pa ka kopye: sèvè a
 * konfime l, epi li montre jis sa ki ekri sou resi a — pa non, pa nimewo konplè.
 */

const express = require("express");
const { createHmac, timingSafeEqual } = require("node:crypto");

const { getDb } = require("../db/db");
const { money } = require("../../../bazik/index.js");

const router = express.Router();

function secret() {
  return process.env.RECEIPT_SECRET || process.env.OTP_SECRET || "voupvapcash-dev-receipt";
}

/** 16 karaktè hex: ase pou yon QR ki rete lizib, enposib pou devine. */
function signReceipt(row) {
  return createHmac("sha256", secret())
    .update(`${row.tx_id}|${row.amount_minor}|${row.currency}|${row.sender_fee_minor || 0}`)
    .digest("hex")
    .slice(0, 16);
}

function publicBaseUrl(req) {
  const configured = String(process.env.PUBLIC_APP_URL || "").replace(/\/+$/, "");
  if (configured) return configured;
  const proto = req.get("x-forwarded-proto") || req.protocol || "https";
  return `${proto}://${req.get("host")}`;
}

/** Sa resi a bezwen pou QR kòd la. */
function receiptInfo(req, row) {
  const signature = signReceipt(row);
  return {
    reference: row.tx_id,
    signature,
    verifyUrl: `${publicBaseUrl(req)}/api/receipts/verify?tx=${encodeURIComponent(row.tx_id)}&s=${signature}`,
  };
}

router.get("/verify", (req, res) => {
  const txId = String(req.query.tx || "").trim();
  const given = String(req.query.s || "").trim().toLowerCase();

  const row = txId
    ? getDb().prepare("SELECT tx_id, amount_minor, currency, sender_fee_minor, status, service, created_at FROM transactions WHERE tx_id = ?").get(txId)
    : null;

  const expected = row ? signReceipt(row) : "";
  const valid =
    Boolean(row) &&
    given.length === expected.length &&
    timingSafeEqual(Buffer.from(given), Buffer.from(expected));

  if (!valid) {
    return res.status(404).json({
      ok: false,
      valid: false,
      message: "Resi sa a pa soti nan VOUPVAPCASH, oswa li te modifye.",
    });
  }

  return res.json({
    ok: true,
    valid: true,
    reference: row.tx_id,
    service: row.service,
    status: row.status,
    amount: money.fromMinor(row.amount_minor),
    fee: money.fromMinor(row.sender_fee_minor || 0),
    currency: row.currency,
    createdAt: row.created_at,
  });
});

module.exports = { router, signReceipt, receiptInfo };
