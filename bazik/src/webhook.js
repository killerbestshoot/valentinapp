"use strict";

/**
 * Resepsyon webhook Bazik.
 *
 * De règ ki pa negosyab:
 *  1. VERIFYE SIYATI A anvan nou fè anyen — sinon nenpòt moun ka kredite yon
 *     wallet ak yon POST.
 *  2. IDEMPOTANS — Bazik ka voye menm evènman an plizyè fwa (retry). Nou
 *     anrejistre `eventId` an premye; si li deja la, nou pa retrete l.
 *
 * TODO(contract): fòm siyati a poko obsève (wallet Bazik la vid, donk okenn
 * transfè reyèl pa ka pati pou deklanche yon webhook). Nou aplike HMAC-SHA256
 * sou kò a, ki se sa `whsec_` prefiks la sijere, ak tolerans sou non header a.
 * Lè premye vre webhook la rive, konpare ak sa epi ajiste isit sèlman.
 */

const { createHmac, timingSafeEqual } = require("node:crypto");
const { DomainError } = require("./errors");
const mapper = require("./mapper");

const SIGNATURE_HEADERS = [
  "x-bazik-signature",
  "x-webhook-signature",
  "x-signature",
  "bazik-signature",
];

/** Konpare 2 siyati san bay enfòmasyon sou tan konparezon an. */
function safeEqual(a, b) {
  const bufferA = Buffer.from(String(a));
  const bufferB = Buffer.from(String(b));
  if (bufferA.length !== bufferB.length) return false;
  return timingSafeEqual(bufferA, bufferB);
}

function createWebhookHandler({ store, client, config, transfers, topups }) {
  /**
   * @param {string} rawBody kò a TEL KEL li rive (pa JSON.parse -> stringify:
   *        sa chanje lòd kle yo e siyati a p ap matche ankò)
   */
  function verifySignature(rawBody, headers = {}) {
    if (!config.webhookSecret) {
      // San sekrè, nou aksepte SÈLMAN an mòd similasyon.
      //
      // Anvan, sa te valab pou tout mòd ki pa `live` — sandbox enkli. Yon POST
      // anonim `{status: "completed"}` te ka kredite yon wallet atravè
      // `settleTopup`, e rechaj manyèl yo te adrese pa menm referans lan.
      if (!config.isFake) {
        throw new DomainError(
          "webhook_secret_missing",
          "BAZIK_WEBHOOK_SECRET pa konfigire: webhook yo refize."
        );
      }
      return { verified: false, reason: "no_secret_configured" };
    }

    const normalized = {};
    for (const [key, value] of Object.entries(headers)) {
      normalized[key.toLowerCase()] = value;
    }

    const header = SIGNATURE_HEADERS.map((name) => normalized[name]).find(Boolean);
    if (!header) {
      throw new DomainError("webhook_signature_missing", "Pa gen header siyati nan webhook la.");
    }

    // Kèk pasrèl voye "t=...,v1=...". Nou pran dènye pati a si gen yon "=".
    const provided = String(header).includes("=")
      ? String(header).split(",").pop().split("=").pop().trim()
      : String(header).trim();

    const expected = createHmac("sha256", config.webhookSecret).update(rawBody).digest("hex");

    if (!safeEqual(provided, expected)) {
      throw new DomainError("webhook_signature_invalid", "Siyati webhook la pa bon.");
    }

    return { verified: true };
  }

  /**
   * Trete yon webhook.
   * @returns {Promise<{status: string, [key: string]: any}>}
   */
  async function handle({ rawBody, headers = {}, skipSignature = false }) {
    if (!skipSignature) verifySignature(rawBody, headers);

    let body;
    try {
      body = typeof rawBody === "string" ? JSON.parse(rawBody) : rawBody;
    } catch {
      throw new DomainError("webhook_invalid_json", "Kò webhook la pa JSON valid.");
    }

    const event = mapper.readWebhookEvent(body);

    // Idempotans: premye bagay nou fè, anvan nou touche lajan.
    const isNew = await store.recordEvent({
      eventId: event.eventId,
      type: event.type,
      reference: event.reference,
      status: event.status,
      payload: body,
    });

    if (!isNew) {
      return { status: "duplicate", eventId: event.eventId };
    }

    if (!event.reference) {
      await store.markEventProcessed(event.eventId, { skipped: "no_reference" });
      return { status: "ignored", reason: "no_reference", eventId: event.eventId };
    }

    // Referans lan ka vize yon transfè soti oswa yon rechaj.
    const transfer = await store.findTransferByReference(event.reference);

    if (transfer) {
      if (event.status !== "completed" && event.status !== "failed") {
        await store.markEventProcessed(event.eventId, { status: event.status, noop: true });
        return { status: "acknowledged", eventId: event.eventId, transferId: transfer.transferId };
      }

      const settled = await store.settleTransfer({
        transferId: transfer.transferId,
        status: event.status,
        gatewayId: event.gatewayId,
        gatewayStatus: event.status,
        failureReason: event.status === "failed" ? "webhook: transfè echwe" : "",
      });

      await store.markEventProcessed(event.eventId, {
        transferId: transfer.transferId,
        status: event.status,
        refunded: settled.refund !== null,
      });

      return {
        status: settled.duplicate ? "already_settled" : "settled",
        eventId: event.eventId,
        transferId: transfer.transferId,
        refunded: settled.refund !== null,
      };
    }

    const topup = await store.findTopupByReference(event.reference);

    if (topup) {
      if (event.status !== "completed" && event.status !== "failed") {
        await store.markEventProcessed(event.eventId, { status: event.status, noop: true });
        return { status: "acknowledged", eventId: event.eventId, topupId: topup.requestId };
      }

      const settled = await store.settleTopup({
        topupId: topup.requestId,
        status: event.status,
        gatewayId: event.gatewayId,
        gatewayStatus: event.status,
        failureReason: event.status === "failed" ? "webhook: peman echwe" : "",
      });

      await store.markEventProcessed(event.eventId, {
        topupId: topup.requestId,
        status: event.status,
        credited: settled.credit !== null,
      });

      return {
        status: settled.duplicate ? "already_settled" : "settled",
        eventId: event.eventId,
        topupId: topup.requestId,
        credited: settled.credit !== null,
      };
    }

    await store.markEventProcessed(event.eventId, { skipped: "unknown_reference" });
    return { status: "ignored", reason: "unknown_reference", eventId: event.eventId };
  }

  /** Itil pou tès ak pou zouti dev: siyen yon kò menm jan Bazik ta fè l. */
  function sign(rawBody) {
    return createHmac("sha256", config.webhookSecret || "").update(rawBody).digest("hex");
  }

  return { handle, verifySignature, sign };
}

module.exports = { createWebhookHandler, SIGNATURE_HEADERS };
