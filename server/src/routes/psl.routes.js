"use strict";

const express = require("express");
const { createHash, createHmac, timingSafeEqual } = require("node:crypto");
const { getBazikService } = require("../bazik_service");
const { applyPendingCommissions } = require("../commission/engine");

const router = express.Router();
const MAX_SIGNATURE_AGE_SECONDS = 300;

function parseSignature(value) {
  const parts = Object.fromEntries(
    String(value || "")
      .split(",")
      .map((part) => part.trim().split("=", 2))
      .filter(([key, signature]) => key && signature)
  );
  return { timestamp: Number(parts.t), signature: parts.v1 || "" };
}

function verifySignature(rawBody, header, secret, nowSeconds = Math.floor(Date.now() / 1000)) {
  const { timestamp, signature } = parseSignature(header);
  if (!Number.isInteger(timestamp) || !signature) return false;
  if (Math.abs(nowSeconds - timestamp) > MAX_SIGNATURE_AGE_SECONDS) return false;

  const expected = createHmac("sha256", secret)
    .update(`${timestamp}.${rawBody}`)
    .digest("hex");
  const expectedBuffer = Buffer.from(expected, "hex");
  const providedBuffer = Buffer.from(signature, "hex");
  return (
    providedBuffer.length === expectedBuffer.length &&
    timingSafeEqual(expectedBuffer, providedBuffer)
  );
}

router.post("/webhook", async (req, res) => {
  const service = getBazikService();
  const secret = service.config.psl?.webhookSecret;
  if (!secret) {
    return res.status(503).json({ ok: false, code: "psl_webhook_secret_missing" });
  }

  const rawBody = req.rawBody;
  if (typeof rawBody !== "string" || !rawBody) {
    return res.status(400).json({ ok: false, code: "raw_body_missing" });
  }
  if (!verifySignature(rawBody, req.get("X-PSL-Signature"), secret)) {
    return res.status(400).json({ ok: false, code: "invalid_psl_signature" });
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return res.status(400).json({ ok: false, code: "invalid_json" });
  }

  const eventType = String(payload.event || "");
  const statusByEvent = {
    "payout.completed": "completed",
    "payout.failed": "failed",
    "payout.cancelled": "failed",
  };
  const status = statusByEvent[eventType];
  if (!status) return res.json({ ok: true, status: "ignored", reason: "unsupported_event" });

  try {
    const reference = String(payload.reference || payload.order_id || "");
    const eventId = createHash("sha256").update(rawBody).digest("hex");
    const isNew = await service.store.recordEvent({
      eventId: `psl_${eventId}`,
      type: eventType,
      reference,
      status,
      payload,
    });
    if (!reference) {
      await service.store.markEventProcessed(`psl_${eventId}`, { skipped: "no_reference" });
      return res.json({ ok: true, status: "ignored", reason: "no_reference" });
    }

    const transfer = await service.store.findTransferByReference(reference);
    if (!transfer || transfer.provider !== "psl" || transfer.network !== "moncash") {
      await service.store.markEventProcessed(`psl_${eventId}`, { skipped: "unknown_psl_reference" });
      return res.json({ ok: true, status: "ignored", reason: "unknown_reference" });
    }

    const settled = await service.store.settleTransfer({
      transferId: transfer.transferId,
      status,
      gatewayId: String(payload.id || transfer.gatewayId || ""),
      gatewayStatus: eventType,
      failureReason: status === "failed"
        ? String(payload.failure_reason || eventType)
        : "",
    });
    await service.store.markEventProcessed(`psl_${eventId}`, {
      transferId: transfer.transferId,
      status,
      refunded: settled.refund !== null,
    });

    try {
      await applyPendingCommissions({ enterpriseId: transfer.enterpriseId, limit: 25 });
    } catch (err) {
      console.error("[commission] PSL webhook rattrapage echwe:", err.message);
    }

    return res.json({
      ok: true,
      status: !isNew || settled.duplicate ? "already_settled" : "settled",
      transferId: transfer.transferId,
    });
  } catch (err) {
    console.error("[psl] webhook processing error:", err);
    return res.status(500).json({ ok: false, code: "psl_webhook_processing_failed" });
  }
});

module.exports = { router, verifySignature, parseSignature };
