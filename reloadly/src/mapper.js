"use strict";

/**
 * SÈL KOTE NAN PWOJÈ A KI KONNEN FÒM PAYLOAD RELOADLY YO.
 *
 * Fòm yo soti nan SDK Java ofisyèl la (DTO + fiksti tès yo), pa nan dok
 * piblik la — dok la se yon aplikasyon JavaScript ki pa lizib san navigatè, e
 * leson Bazik la montre yon dok ka pa koresponn ak API a. Gade
 * `docs/contract.md`. Sa ki poko verifye sou sandbox la make TODO(contract).
 *
 * Nou ekri ak non egzak SDK a itilize, men nou *li* ak tolerans.
 */

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

/** Desimal API a (15, 1089.31) -> santim antye. */
function toMinor(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.round(number * 100) : 0;
}

/** Santim antye -> desimal pou voye bay API a. */
function fromMinor(minor) {
  return Math.round(Number(minor)) / 100;
}

/** Estati domèn nou yo — menm vokabilè ak transfè Bazik yo. */
const Status = {
  PROCESSING: "processing",
  COMPLETED: "completed",
  FAILED: "failed",
};

/**
 * `AirtimeTransactionStatus` SDK a: PROCESSING, SUCCESSFUL, REFUNDED, FAILED.
 * `REFUNDED` = Reloadly remèt lajan an sou kont nou: pou ajan an se yon echèk.
 * Yon valè nou pa konnen retounen "" — se moun k ap rele a ki deside.
 */
function normalizeStatus(raw) {
  const value = String(raw || "").trim().toUpperCase();
  if (value === "SUCCESSFUL" || value === "SUCCESS" || value === "COMPLETED") return Status.COMPLETED;
  if (value === "FAILED" || value === "REFUNDED") return Status.FAILED;
  if (value === "PROCESSING" || value === "PENDING") return Status.PROCESSING;
  return "";
}

/**
 * Nimewo Ayiti: 8 chif lokal. Reloadly mande fòma entènasyonal la,
 * `+50936377111` (fiksti tès SDK a), ak `countryCode: "HT"` apa.
 */
function normalizeHaitiPhone(phone) {
  const digits = String(phone || "").replace(/\D/g, "");
  const local = digits.length === 11 && digits.startsWith("509") ? digits.slice(3) : digits;

  if (local.length !== 8) {
    throw new DomainError(
      "invalid_phone",
      `Nimewo a pa valid: ${phone || "(vid)"}. Nou tann yon nimewo Ayiti ak 8 chif.`
    );
  }

  return { local, international: `+509${local}` };
}

// ---------------------------------------------------------------------------
// Demann (nou -> Reloadly)
// ---------------------------------------------------------------------------

/** POST https://auth.reloadly.com/oauth/token (`OAuth2ClientCredentialsOperation`). */
function buildTokenRequest({ clientId, clientSecret, audience }) {
  return {
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: "client_credentials",
    audience,
  };
}

/**
 * POST /topups (`PhoneTopupRequest`).
 *
 * `customIdentifier` = ID rechaj NOU AN. Se li ki pèmèt nou jwenn rechaj la
 * ankò si repons lan pèdi (timeout), paske nan ka sa a nou pa gen
 * `transactionId` Reloadly a.
 */
function buildTopupRequest({ operatorId, amountMinor, useLocalAmount, customIdentifier, phone }) {
  return {
    operatorId: Number(operatorId),
    amount: fromMinor(amountMinor),
    useLocalAmount: Boolean(useLocalAmount),
    customIdentifier,
    recipientPhone: {
      countryCode: "HT",
      number: normalizeHaitiPhone(phone).international,
    },
  };
}

// ---------------------------------------------------------------------------
// Repons (Reloadly -> nou)
// ---------------------------------------------------------------------------

/** `TokenHolder`: { access_token, token_type, expires_in (segond) }. */
function readTokenResponse(body, now = Date.now()) {
  const token = pick(body, ["access_token", "accessToken", "token"], "");
  const expiresIn = Number(pick(body, ["expires_in", "expiresIn"], 0));

  return {
    token: String(token),
    expiresAt: expiresIn > 0 ? now + expiresIn * 1000 : 0,
    /**
     * Pèmisyon kont lan (obsève 17/09/2026): send-topups, read-operators,
     * read-promotions, read-topups-history, read-prepaid-balance,
     * read-prepaid-commissions. Pa gen okenn pèmisyon pou FINANSE kont lan.
     */
    scopes: String(pick(body, ["scope"], "")).split(/\s+/).filter(Boolean),
    raw: body,
  };
}

/** Lis montan yon operatè bay (`fixedAmounts`, `suggestedAmounts`...) an santim. */
function minorList(value) {
  if (!Array.isArray(value)) return [];
  return value.map(toMinor).filter((minor) => minor > 0).sort((a, b) => a - b);
}

/** `Operator`: limit, deviz, to, tip denominasyon. */
function readOperator(body) {
  const country = pick(body, ["country"], {}) || {};
  const fx = pick(body, ["fx"], {}) || {};

  return {
    operatorId: Number(pick(body, ["operatorId", "id"], 0)),
    name: String(pick(body, ["name"], "")),
    countryCode: String(pick(country, ["isoName", "iso", "code"], pick(body, ["countryCode"], ""))).toUpperCase(),
    /** "RANGE" (nenpòt montan ant min/max) oswa "FIXED" (lis montan). */
    denominationType: String(pick(body, ["denominationType"], "RANGE")).toUpperCase(),
    isData: pick(body, ["data"], false) === true,
    isBundle: pick(body, ["bundle"], false) === true,
    isPin: pick(body, ["pin"], false) === true,
    /** "ACTIVE" sou sandbox la (17/09/2026). Vid si API a pa voye l. */
    status: String(pick(body, ["status"], "")).toUpperCase(),
    supportsLocalAmounts: pick(body, ["supportsLocalAmounts"], false) === true,
    senderCurrency: String(pick(body, ["senderCurrencyCode"], "")).toUpperCase(),
    destinationCurrency: String(pick(body, ["destinationCurrencyCode"], "")).toUpperCase(),
    /** Konbyen inite deviz destinasyon (HTG) pou 1 inite deviz voye (USD). */
    fxRate: Number(pick(fx, ["rate"], 0)),
    minMinor: toMinor(pick(body, ["minAmount"], 0)),
    maxMinor: toMinor(pick(body, ["maxAmount"], 0)),
    localMinMinor: toMinor(pick(body, ["localMinAmount"], 0)),
    localMaxMinor: toMinor(pick(body, ["localMaxAmount"], 0)),
    fixedMinor: minorList(pick(body, ["fixedAmounts"], [])),
    localFixedMinor: minorList(pick(body, ["localFixedAmounts"], [])),
    suggestedMinor: minorList(pick(body, ["suggestedAmounts"], [])),
    raw: body,
  };
}

/** `TopupTransaction`. */
function readTopup(body) {
  const balance = pick(body, ["balanceInfo"], {}) || {};
  const gatewayId = String(pick(body, ["transactionId", "id"], ""));
  const explicit = normalizeStatus(pick(body, ["status"], ""));

  return {
    gatewayId,
    // TODO(contract): fiksti 2021 `phone_topup_transaction.json` la pa gen chan
    // `status`. `POST /topups` (sinkwòn) reponn 200 sèlman lè rechaj la trete —
    // echèk yo tounen 4xx. Donk yon repons ak `transactionId` san estati =
    // reyisi. Si Reloadly voye yon estati, se li ki genyen.
    status: explicit || (gatewayId ? Status.COMPLETED : ""),
    rawStatus: String(pick(body, ["status"], "")),
    customIdentifier: String(pick(body, ["customIdentifier"], "")),
    operatorTransactionId: String(pick(body, ["operatorTransactionId"], "")),
    operatorId: Number(pick(body, ["operatorId"], 0)),
    operatorName: String(pick(body, ["operatorName"], "")),
    requestedMinor: toMinor(pick(body, ["requestedAmount"], 0)),
    requestedCurrency: String(pick(body, ["requestedAmountCurrencyCode"], "")),
    deliveredMinor: toMinor(pick(body, ["deliveredAmount"], 0)),
    deliveredCurrency: String(pick(body, ["deliveredAmountCurrencyCode"], "")),
    /** Remiz Reloadly bay: se maj antrepriz la sou rechaj la. */
    discountMinor: toMinor(pick(body, ["discount"], 0)),
    discountCurrency: String(pick(body, ["discountCurrencyCode"], "")),
    balanceAfterMinor: toMinor(pick(balance, ["newBalance"], 0)),
    raw: body,
  };
}

/** GET /topups/{id}/status -> { code, message, status, transaction }. */
function readStatusResponse(body) {
  const transaction = pick(body, ["transaction"], null);
  const topup = transaction ? readTopup(transaction) : null;

  return {
    status: normalizeStatus(pick(body, ["status"], "")) || topup?.status || "",
    code: String(pick(body, ["code"], "")),
    message: String(pick(body, ["message"], "")),
    topup,
    raw: body,
  };
}

/** GET /topups/reports/transactions -> paj Spring (`content`). */
function readTopupPage(body) {
  const content = Array.isArray(body) ? body : pick(body, ["content"], []);
  return (Array.isArray(content) ? content : []).map(readTopup);
}

/**
 * GET /accounts/balance -> { balance, frozenBalance, currencyCode, updatedAt,
 * lowBalanceThreshold, maxLowBalanceThreshold } (sandbox 17/09/2026).
 */
function readBalanceResponse(body) {
  return {
    balanceMinor: toMinor(pick(body, ["balance"], 0)),
    currency: String(pick(body, ["currencyCode"], "")).toUpperCase(),
    /** Papòt alèt sòld ba, regle sou dashboard Reloadly a (0 = pa regle). */
    lowBalanceThresholdMinor: toMinor(pick(body, ["lowBalanceThreshold"], 0)),
    updatedAt: String(pick(body, ["updatedAt"], "")),
    raw: body,
  };
}

/** GET /promotions/countries/{iso} -> [Promotion] (`Promotion` SDK a). */
function readPromotion(body) {
  return {
    promotionId: Number(pick(body, ["id", "promotionId"], 0)),
    operatorId: Number(pick(body, ["operatorId"], 0)),
    title: String(pick(body, ["title"], "")),
    title2: String(pick(body, ["title2"], "")),
    description: String(pick(body, ["description"], "")),
    startDate: String(pick(body, ["startDate"], "")),
    endDate: String(pick(body, ["endDate"], "")),
    denominations: String(pick(body, ["denominations"], "")),
    localDenominations: String(pick(body, ["localDenominations"], "")),
  };
}

/**
 * GET /operators/{id}/commissions -> { percentage, internationalPercentage,
 * localPercentage, updatedAt, operator: { id, name, status } }.
 * Se REMIZ Reloadly bay la: tout maj antrepriz la sou yon rechaj.
 */
function readCommission(body) {
  const operator = pick(body, ["operator"], {}) || {};
  return {
    operatorId: Number(pick(operator, ["operatorId", "id"], 0)),
    operatorName: String(pick(operator, ["name"], "")),
    percentage: Number(pick(body, ["percentage"], 0)),
    internationalPercentage: Number(pick(body, ["internationalPercentage"], 0)),
    localPercentage: Number(pick(body, ["localPercentage"], 0)),
    updatedAt: String(pick(body, ["updatedAt"], "")),
  };
}

/** Enfòmasyon paj Spring yon lis (`totalElements`, `totalPages`). */
function readPageInfo(body) {
  return {
    totalElements: Number(pick(body, ["totalElements"], 0)),
    totalPages: Number(pick(body, ["totalPages"], 0)),
  };
}

/**
 * `APIError`: { timeStamp, message, path, errorCode, infoLink, details }.
 * Nou mete `errorCode` an miniskil pou li sanble ak kòd Bazik yo
 * (`INSUFFICIENT_BALANCE` -> `insufficient_balance`).
 */
function readErrorResponse(body) {
  const rawCode = String(pick(body, ["errorCode", "error", "code"], ""));

  return {
    code: rawCode ? rawCode.trim().toLowerCase() : "",
    rawCode,
    message: String(pick(body, ["message", "error_description", "details"], "")),
    infoLink: String(pick(body, ["infoLink"], "")),
    raw: body,
  };
}

module.exports = {
  Status,
  pick,
  toMinor,
  fromMinor,
  normalizeStatus,
  normalizeHaitiPhone,
  buildTokenRequest,
  buildTopupRequest,
  readTokenResponse,
  readOperator,
  readTopup,
  readStatusResponse,
  readTopupPage,
  readBalanceResponse,
  readPromotion,
  readCommission,
  readPageInfo,
  readErrorResponse,
};
