"use strict";

/**
 * Kliyan HTTP Bazik.
 *
 * Responsabilite:
 *  - jere token an (/token) ak yon cache ki respekte `expires_at`
 *  - respekte limit 100 req/min
 *  - re-eseye SÈLMAN sou erè tanporè (429, 5xx, rezo) — jamè sou erè biznis
 *  - pa janm kite `secretKey` a soti nan modil sa a
 *
 * Fòm payload yo soti nan `mapper.js`, ki li menm soti nan `docs/contract.md`.
 */

const { BazikError } = require("./errors");
const mapper = require("./mapper");

/**
 * Erè biznis: Bazik reponn 4xx men pwoblèm nan se demand nou an.
 * Re-eseye yo pa gen sans — nou t ap jwenn menm repons lan.
 */
const NON_RETRYABLE_CODES = new Set([
  "amount_too_low",
  "amount_too_high",
  "insufficient_balance",
  "invalid_request",
  "endpoint_not_authorized",
  "Missing required fields",
  "Transfer not found",
]);

/** Ti "token bucket" senp pou nou pa depase limit la. */
function createRateLimiter(maxPerMinute) {
  const windowMs = 60000;
  let hits = [];

  return async function throttle() {
    const now = Date.now();
    hits = hits.filter((t) => now - t < windowMs);

    if (hits.length >= maxPerMinute) {
      const waitMs = windowMs - (now - hits[0]) + 5;
      await new Promise((resolve) => setTimeout(resolve, waitMs));
      return throttle();
    }

    hits.push(Date.now());
  };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createBazikClient(config, { fetchImpl = globalThis.fetch, now = () => Date.now() } = {}) {
  const throttle = createRateLimiter(config.maxRequestsPerMinute);

  /** { token, expiresAt } */
  let cachedToken = null;

  async function rawRequest(path, { method = "POST", body, token } = {}) {
    await throttle();

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.requestTimeoutMs);

    let response;
    try {
      response = await fetchImpl(`${config.baseUrl}${path}`, {
        method,
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
        signal: controller.signal,
      });
    } catch (err) {
      throw new BazikError("network_error", `Bazik pa reponn: ${err.message}`, { retryable: true });
    } finally {
      clearTimeout(timer);
    }

    const text = await response.text();
    let parsed = null;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = { raw: text };
    }

    if (!response.ok) {
      const error = mapper.readErrorResponse(parsed);

      const code =
        response.status === 401
          ? "unauthorized"
          : response.status === 429
            ? "rate_limited"
            : error.code || `http_${response.status}`;

      const retryable =
        !NON_RETRYABLE_CODES.has(error.code) &&
        (response.status === 429 || response.status >= 500);

      throw new BazikError(code, error.message || `Bazik reponn ${response.status}`, {
        status: response.status,
        body: parsed,
        retryable,
      });
    }

    return parsed || {};
  }

  /** Rele /token epi kenbe rezilta a jiska 1 min anvan li ekspire. */
  async function getToken({ force = false } = {}) {
    if (!force && cachedToken && cachedToken.expiresAt > now() + 60000) {
      return cachedToken.token;
    }

    const body = await rawRequest("/token", {
      body: { userID: config.userId, secretKey: config.secretKey },
    });

    const parsed = mapper.readTokenResponse(body);
    if (!parsed.token) {
      throw new BazikError("no_token", "Bazik pa retounen yon token.", { body });
    }

    cachedToken = {
      token: parsed.token,
      // Si Bazik pa bay dat ekspirasyon, nou pran 1 èdtan pou nou pa kenbe
      // yon token mouri pandan 24 èdtan.
      expiresAt: parsed.expiresAt > 0 ? parsed.expiresAt : now() + 3600000,
    };

    return cachedToken.token;
  }

  /**
   * Apèl otantifye, ak retry + rafrechi token sou 401.
   *
   * `idempotent: false` pou tout ekriti ki deplase lajan. Pou apèl sa yo, nou
   * re-eseye SÈLMAN lè Bazik te refize demann lan anvan li trete l (401, 429).
   * JAMÈ sou yon timeout oswa yon 5xx: Bazik ka te aksepte transfè a anvan
   * koneksyon an mouri. Anvan, `POST /moncash/transfers` te ka pati 4 fwa
   * ak menm `referenceId` — e `contract.md` di klèman nou pa konnen si Bazik
   * idempotan sou `referenceId`.
   */
  async function call(path, body, { method = "POST", idempotent = method === "GET" } = {}) {
    let lastError = null;

    for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        const token = await getToken({
          force: attempt > 0 && lastError?.code === "unauthorized",
        });
        return await rawRequest(path, { method, body, token });
      } catch (err) {
        lastError = err;

        // Refize anvan tretman: toujou san risk pou re-eseye.
        const rejectedBeforeProcessing =
          err instanceof BazikError &&
          (err.code === "unauthorized" || err.code === "rate_limited");

        const canRetry =
          err instanceof BazikError &&
          attempt < config.maxRetries &&
          (rejectedBeforeProcessing || (idempotent && err.retryable));

        if (!canRetry) throw err;

        // Backoff eksponansyèl: 400ms, 800ms, 1600ms...
        await sleep(400 * 2 ** attempt);
      }
    }

    throw lastError;
  }

  return {
    mode: config.mode,

    /** GET /wallet — sld Bazik la (se li ki finanse transfè yo). */
    async wallet() {
      return mapper.readWalletResponse(await call("/wallet", undefined, { method: "GET" }));
    },

    /** POST /transfers/quote — frè a anvan nou voye. */
    async quote(params) {
      // POST, men li pa ekri anyen: san risk pou re-eseye.
      return mapper.readQuoteResponse(
        await call("/transfers/quote", mapper.buildQuoteRequest(params), { idempotent: true })
      );
    },

    /** POST /moncash/transfers | /natcash/transfers */
    async createTransfer(network, params) {
      const path = network === "natcash" ? "/natcash/transfers" : "/moncash/transfers";
      const body =
        network === "natcash"
          ? mapper.buildNatcashTransferRequest(params)
          : mapper.buildMoncashTransferRequest(params);

      return mapper.readTransferResponse(await call(path, body));
    },

    /** GET /transfers/{transactionId} */
    async transferStatus(transactionId) {
      return mapper.readTransferResponse(
        await call(`/transfers/${encodeURIComponent(transactionId)}`, undefined, { method: "GET" })
      );
    },

    /** POST /moncash/customers/status — verifye si yon nimewo se yon kliyan MonCash. */
    async customerStatus(params) {
      return await call("/moncash/customers/status", mapper.buildCustomerStatusRequest(params), {
        idempotent: true,
      });
    },

    // --- Ankesman (cash-in): mande yon kont `online`/`instore` ---

    /** POST /moncash/token */
    async createPayment(params) {
      return mapper.readPaymentResponse(
        await call("/moncash/token", mapper.buildCreatePaymentRequest(params))
      );
    },

    /** GET /moncash/payments/{referenceId} */
    async paymentStatus(referenceId) {
      return mapper.readPaymentStatusResponse(
        await call(`/moncash/payments/${encodeURIComponent(referenceId)}`, undefined, { method: "GET" })
      );
    },

    /** Ekspoze pou tès sèlman. */
    _resetToken() {
      cachedToken = null;
    },
  };
}

module.exports = { createBazikClient, createRateLimiter, NON_RETRYABLE_CODES };
