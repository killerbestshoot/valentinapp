"use strict";

/**
 * SÈL KOTE NAN PWOJÈ A KI KONNEN FÒM PAYLOAD BAZIK YO.
 *
 * Chak fòm isit la verifye sou sandbox la (gade `docs/contract.md`).
 * Sa ki ret ann ipotèz make ak TODO(contract).
 *
 * Nou ekri ak non egzak Bazik mande, men nou *li* ak tolerans (plizyè alyas),
 * konsa yon ti chanjman non pa kraze entegrasyon an.
 */

const { fromMinor } = require("./money");
const { DomainError } = require("./errors");

/** Li premye kle ki egziste nan yon objè. */
function pick(source, keys, fallback = undefined) {
  if (!source || typeof source !== "object") return fallback;
  for (const key of keys) {
    const value = source[key];
    if (value !== undefined && value !== null && value !== "") return value;
  }
  return fallback;
}

/** Estati domèn nou yo. Tout estati Bazik ap tonbe nan youn nan sa yo. */
const Status = {
  PENDING: "pending",
  PROCESSING: "processing",
  COMPLETED: "completed",
  FAILED: "failed",
  CANCELED: "canceled",
};

/** Nòmalize nenpòt estati Bazik vè estati domèn nou an. */
function normalizeStatus(raw) {
  const value = String(raw || "").trim().toLowerCase();

  if (["completed", "complete", "success", "successful", "paid", "delivered", "settled", "sent"].includes(value)) {
    return Status.COMPLETED;
  }
  if (["failed", "failure", "error", "declined", "rejected", "reversed"].includes(value)) {
    return Status.FAILED;
  }
  if (["canceled", "cancelled", "expired", "timeout", "aborted"].includes(value)) {
    return Status.CANCELED;
  }
  if (["processing", "in_progress", "sending", "submitted", "accepted"].includes(value)) {
    return Status.PROCESSING;
  }
  return Status.PENDING;
}

/**
 * Nimewo telefòn Ayiti: 8 chif, san +509.
 * Bazik rele chan sa a `wallet`.
 */
function normalizeWallet(phone) {
  const digits = String(phone || "").replace(/\D/g, "");
  const local = digits.startsWith("509") ? digits.slice(3) : digits;
  if (local.length !== 8) {
    throw new DomainError("invalid_wallet", `Nimewo telefòn pa valid: ${phone} (nou tann 8 chif).`);
  }
  return local;
}

/**
 * Separe yon non konplè an prenon + siyati (NatCash mande yo apa).
 *
 * Yon sèl mo PA bay siyati. Anvan, "Jean" te bay `Jean Jean`: nou t ap envante
 * yon siyati, e gad "non obligatwa" a pa t janm deklanche. NatCash sèvi ak non
 * an pou verifikasyon KYC — yon fo siyati ka fè yo rejte transfè a.
 */
function splitName(fullName) {
  const parts = String(fullName || "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { firstName: "", lastName: "" };
  if (parts.length === 1) return { firstName: parts[0], lastName: "" };
  return { firstName: parts[0], lastName: parts.slice(1).join(" ") };
}

// ---------------------------------------------------------------------------
// Demand (nou -> Bazik)
// ---------------------------------------------------------------------------

/**
 * POST /transfers/quote
 * Verifye sou sandbox: { amount, provider } -> { delivery_amount, fee, total_cost, ... }
 */
function buildQuoteRequest({ amountHtgMinor, network }) {
  return { amount: fromMinor(amountHtgMinor), provider: network };
}

/**
 * POST /moncash/transfers
 * Chan obligatwa (mesaj erè API a): gdes, wallet, description, referenceId.
 */
function buildMoncashTransferRequest({ reference, amountHtgMinor, phone, description }) {
  return {
    gdes: fromMinor(amountHtgMinor),
    wallet: normalizeWallet(phone),
    description: description || `VOUPVAPCASH ${reference}`,
    referenceId: reference,
  };
}

/**
 * POST /natcash/transfers
 * Chan obligatwa: gdes, wallet, customerFirstName, customerLastName.
 * Diferans ak MonCash: non benefisyè a OBLIGATWA.
 */
function buildNatcashTransferRequest({ reference, amountHtgMinor, phone, receiverName, description }) {
  const { firstName, lastName } = splitName(receiverName);

  if (!firstName || !lastName) {
    throw new DomainError(
      "missing_receiver_name",
      "NatCash mande non ak siyati benefisyè a."
    );
  }

  return {
    gdes: fromMinor(amountHtgMinor),
    wallet: normalizeWallet(phone),
    customerFirstName: firstName,
    customerLastName: lastName,
    description: description || `VOUPVAPCASH ${reference}`,
    referenceId: reference,
  };
}

/** POST /moncash/customers/status */
function buildCustomerStatusRequest({ phone }) {
  return { wallet: normalizeWallet(phone) };
}

/**
 * POST /moncash/token — ankesman (cash-in).
 * TODO(contract): kont `transfer` la pa gen dwa sou endpoint sa a (403),
 * donk fòm sa a pa ankò verifye sou yon vre kont `online`.
 */
function buildCreatePaymentRequest({ orderId, amountHtgMinor, phone, description }) {
  return {
    amount: fromMinor(amountHtgMinor),
    orderId,
    currency: "HTG",
    ...(phone ? { wallet: normalizeWallet(phone) } : {}),
    ...(description ? { description } : {}),
  };
}

// ---------------------------------------------------------------------------
// Repons (Bazik -> nou)
// ---------------------------------------------------------------------------

/** POST /token -> { success, token, user_id, expires_at (epoch ms), message } */
function readTokenResponse(body) {
  const token = pick(body, ["token", "access_token", "accessToken"], "");

  // Bazik bay `expires_at` an milisgond absoli. Dok piblik la te di `expires_in`
  // (yon dire). Nou sipòte toude pou nou pa depann de youn.
  const expiresAt = Number(pick(body, ["expires_at", "expiresAt"], 0));
  const expiresIn = Number(pick(body, ["expires_in", "expiresIn"], 0));

  return {
    token: String(token),
    expiresAt: expiresAt > 0 ? expiresAt : expiresIn > 0 ? Date.now() + expiresIn * 1000 : 0,
    userId: String(pick(body, ["user_id", "userId"], "")),
    raw: body,
  };
}

/** GET /wallet -> { available, reserved, currency, environment, last_updated } */
function readWalletResponse(body) {
  return {
    availableMinor: Math.round(Number(pick(body, ["available", "balance", "amount"], 0)) * 100),
    reservedMinor: Math.round(Number(pick(body, ["reserved"], 0)) * 100),
    currency: String(pick(body, ["currency"], "HTG")),
    environment: String(pick(body, ["environment"], "")),
    raw: body,
  };
}

/** POST /transfers/quote -> { delivery_amount, fee, total_cost, fee_percentage } */
function readQuoteResponse(body) {
  return {
    deliveryMinor: Math.round(Number(pick(body, ["delivery_amount", "deliveryAmount", "amount"], 0)) * 100),
    feeMinor: Math.round(Number(pick(body, ["fee"], 0)) * 100),
    totalCostMinor: Math.round(Number(pick(body, ["total_cost", "totalCost"], 0)) * 100),
    feePercent: Number(pick(body, ["fee_percentage", "feePercentage"], 0)),
    currency: String(pick(body, ["currency"], "HTG")),
    raw: body,
  };
}

/**
 * Repons kreyasyon transfè (MonCash oswa NatCash), ak repons `GET /transfers/{id}`.
 *
 * `failureReason` se KOTE Bazik di poukisa. Egzanp reyèl, sou yon transfè ki
 * echwe an pwodiksyon:
 *
 *   { "status": "failed", "failureReason": "Failed to obtain MonCash OAuth token",
 *     "description": "Livrezon MonCash", ... }
 *
 * ATANSYON SOU `description`: se TÈKS PA NOU an, ke Bazik voye tounen jan nou
 * te ba li l. Anvan, `message` te li l lè `message` pa t la, donk nou te
 * anrejistre «Livrezon MonCash» kòm rezon echèk — sa pa di anyen, epi vrè
 * rezon an (`failureReason`) te jete. Nou pa li `description` ankò.
 */
function readTransferResponse(body) {
  const data = pick(body, ["transfer", "data", "transaction"], body);

  return {
    gatewayId: String(
      pick(data, ["transactionId", "transaction_id", "transferId", "transfer_id", "id", "reference", "referenceId"], "")
    ),
    status: normalizeStatus(pick(data, ["status", "state"], "processing")),
    failureReason: String(
      pick(data, ["failureReason", "failure_reason", "reason"], "")
    ),
    message: String(pick(data, ["message", "detail"], "")),
    raw: body,
  };
}

/** Repons erè Bazik: nou sove kòd la pou nou ka deside si nou ka re-eseye. */
function readErrorResponse(body) {
  return {
    code: String(pick(body, ["error", "code"], "unknown_error")),
    message: String(pick(body, ["message", "details"], "")),
    minimumHtg: Number(pick(body, ["minimum_amount"], 0)),
    maximumHtg: Number(pick(body, ["maximum_amount"], 0)),
    requiredHtg: Number(pick(body, ["required"], 0)),
    availableHtg: Number(pick(body, ["available"], 0)),
    raw: body,
  };
}

/** Repons ankesman (cash-in). TODO(contract): pa ankò verifye. */
function readPaymentResponse(body) {
  return {
    gatewayId: String(pick(body, ["transactionId", "transaction_id", "paymentId", "payment_id", "id", "token"], "")),
    paymentUrl: String(pick(body, ["payment_url", "paymentUrl", "redirect_url", "redirectUrl", "url"], "")),
    status: normalizeStatus(pick(body, ["status", "state"], "pending")),
    raw: body,
  };
}

/** GET /moncash/payments/{referenceId} — verifikasyon yon peman. */
function readPaymentStatusResponse(body) {
  const data = pick(body, ["payment", "data", "transaction"], body);
  return {
    gatewayId: String(pick(data, ["transactionId", "transaction_id", "paymentId", "id"], "")),
    status: normalizeStatus(pick(data, ["status", "state", "message"], "pending")),
    amountHtg: Number(pick(data, ["gdes", "amount", "cost", "value"], 0)),
    payer: String(pick(data, ["payer", "wallet", "phone", "customer"], "")),
    raw: body,
  };
}

/**
 * Yon evènman webhook.
 * `eventId` esansyèl: se li ki bay idempotans lè Bazik voye menm bagay la 2 fwa.
 * TODO(contract): fòm egzak la poko obsève (wallet Bazik la vid, okenn transfè
 * pa ka pati). Lektè a tolerant espre.
 */
function readWebhookEvent(body) {
  const data = pick(body, ["data", "payload", "transaction", "transfer"], body) || {};

  const reference = String(
    pick(data, ["referenceId", "reference", "orderId", "order_id", "externalId"], "")
  );
  const status = normalizeStatus(
    pick(data, ["status", "state"], pick(body, ["status", "event"], ""))
  );

  // Kle deduplikasyon an: yon ID EVÈNMAN eksplisit, oswa referans + estati.
  //
  // Nou PA pran `id` jenerik la. Anpil pasrèl mete ID TRANZAKSYON an ladan,
  // ki menm pou tout evènman yon transfè: `processing` ta anrejistre l, epi
  // `completed` ta tonbe kòm "duplicate" — transfè a bloke pou tout tan, e
  // komisyon an pa janm aplike.
  const explicitId = pick(body, ["eventId", "event_id", "webhookId", "webhook_id"], "");
  const eventId = String(explicitId || `${reference || "unknown"}:${status}`);

  return {
    eventId,
    type: String(pick(body, ["event", "type", "eventType"], "")),
    reference,
    gatewayId: String(pick(data, ["transactionId", "transaction_id", "transferId", "id"], "")),
    status,
    amountHtg: Number(pick(data, ["gdes", "amount", "value"], 0)),
    // Menm chan ak repons `GET /transfers/{id}` la: webhook la gen menm fòm
    // (`type: "transfer.failed"`). San li, yon echèk ki rive pa webhook te
    // anrejistre kòm «webhook: transfè echwe», ki pa di anyen bay ajan an.
    failureReason: String(
      pick(data, ["failureReason", "failure_reason", "reason"], "")
    ),
    raw: body,
  };
}

module.exports = {
  Status,
  pick,
  normalizeStatus,
  normalizeWallet,
  splitName,
  buildQuoteRequest,
  buildMoncashTransferRequest,
  buildNatcashTransferRequest,
  buildCustomerStatusRequest,
  buildCreatePaymentRequest,
  readTokenResponse,
  readWalletResponse,
  readQuoteResponse,
  readTransferResponse,
  readErrorResponse,
  readPaymentResponse,
  readPaymentStatusResponse,
  readWebhookEvent,
};
