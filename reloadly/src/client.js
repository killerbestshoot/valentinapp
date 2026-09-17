"use strict";

/**
 * Kliyan HTTP Reloadly Airtime.
 *
 * Responsabilite:
 *  - jere jeton OAuth2 la (`client_credentials`) ak yon cache ki respekte
 *    `expires_in`
 *  - voye header vèsyon an (`application/com.reloadly.topups-v1+json`)
 *  - re-eseye SÈLMAN sa ki san danje (gade `call`)
 *  - pa janm kite `clientSecret` la soti nan modil sa a
 */

const { ReloadlyError } = require("./errors");
const mapper = require("./mapper");

/** `Version.AIRTIME_V1` nan SDK a. San li, API a ka reponn ak yon lòt vèsyon. */
const ACCEPT_AIRTIME_V1 = "application/com.reloadly.topups-v1+json";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createReloadlyClient(config, { fetchImpl = globalThis.fetch, now = () => Date.now() } = {}) {
  /** { token, expiresAt } */
  let cachedToken = null;

  async function rawRequest(url, { method = "GET", body, headers = {} } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.requestTimeoutMs);

    let response;
    try {
      response = await fetchImpl(url, {
        method,
        headers: {
          ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
          ...headers,
        },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
        signal: controller.signal,
      });
    } catch (err) {
      throw new ReloadlyError("network_error", `Reloadly pa reponn: ${err.message}`, { retryable: true });
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

      throw new ReloadlyError(code, error.message || `Reloadly reponn ${response.status}`, {
        status: response.status,
        body: parsed,
        retryable: response.status === 429 || response.status >= 500,
      });
    }

    return parsed || {};
  }

  /** Jeton an kenbe jiska 1 min anvan li ekspire. */
  async function getToken({ force = false } = {}) {
    if (!force && cachedToken && cachedToken.expiresAt > now() + 60000) {
      return cachedToken.token;
    }

    const body = await rawRequest(`${config.authUrl}/oauth/token`, {
      method: "POST",
      body: mapper.buildTokenRequest(config),
      headers: { Accept: "application/json" },
    });

    const parsed = mapper.readTokenResponse(body, now());
    if (!parsed.token) {
      throw new ReloadlyError("no_token", "Reloadly pa retounen yon jeton.", { body });
    }

    cachedToken = {
      token: parsed.token,
      // San `expires_in`, nou pran 1 èdtan: pi bon pase kenbe yon jeton mouri.
      expiresAt: parsed.expiresAt > 0 ? parsed.expiresAt : now() + 3600000,
    };

    return cachedToken.token;
  }

  /**
   * Apèl otantifye.
   *
   * `idempotent: false` pou `POST /topups`. Pou li, nou re-eseye SÈLMAN lè
   * Reloadly refize demann lan ANVAN li trete l (401, 429). JAMÈ sou yon
   * timeout oswa yon 5xx: rechaj la ka te pati anvan koneksyon an mouri, e
   * yon dezyèm POST ta bay kliyan an minit de fwa.
   */
  async function call(path, { method = "GET", body, idempotent = method === "GET" } = {}) {
    let lastError = null;

    for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        const token = await getToken({
          force: attempt > 0 && lastError?.code === "unauthorized",
        });

        return await rawRequest(`${config.baseUrl}${path}`, {
          method,
          body,
          headers: { Accept: ACCEPT_AIRTIME_V1, Authorization: `Bearer ${token}` },
        });
      } catch (err) {
        lastError = err;

        const rejectedBeforeProcessing =
          err instanceof ReloadlyError && (err.code === "unauthorized" || err.code === "rate_limited");

        const canRetry =
          err instanceof ReloadlyError &&
          attempt < config.maxRetries &&
          (rejectedBeforeProcessing || (idempotent && err.retryable));

        if (!canRetry) throw err;

        await sleep(400 * 2 ** attempt);
      }
    }

    throw lastError;
  }

  return {
    mode: config.mode,

    /**
     * Jwenn jeton an AVAN nou debite ajan an.
     *
     * San sa, yon pàn sou `auth.reloadly.com` pandan `POST /topups` ta sanble
     * ak yon timeout sou rechaj la li menm: nou ta kite l an verifikasyon alòske
     * anyen pa t janm pati. Jeton an valab omwen 1 min apre apèl sa a.
     */
    async prepare() {
      await getToken();
    },

    /** GET /accounts/balance — kont Reloadly a finanse tout rechaj yo. */
    async balance() {
      return mapper.readBalanceResponse(await call("/accounts/balance"));
    },

    /**
     * GET /operators/auto-detect/phone/{phone}/countries/{iso}
     *
     * Nou eskli done, pakè ak PIN: Minit Haiti vann kredi dirèk sou liy lan.
     * TODO(contract): verifye sou sandbox ke filt sa yo respekte sou auto-detect.
     */
    async detectOperator(phone) {
      const { international } = mapper.normalizeHaitiPhone(phone);
      const query = new URLSearchParams({
        suggestedAmounts: "true",
        includeData: "false",
        includeBundles: "false",
        includePin: "false",
      });

      return mapper.readOperator(
        await call(
          `/operators/auto-detect/phone/${encodeURIComponent(international)}` +
            `/countries/${config.countryCode}?${query}`
        )
      );
    },

    /** GET /operators/{operatorId} */
    async operator(operatorId) {
      return mapper.readOperator(
        await call(`/operators/${encodeURIComponent(operatorId)}?suggestedAmounts=true`)
      );
    },

    /** POST /topups — deplase lajan: `idempotent: false`. */
    async topup(params) {
      return mapper.readTopup(
        await call("/topups", { method: "POST", body: mapper.buildTopupRequest(params), idempotent: false })
      );
    },

    /** GET /topups/{transactionId}/status */
    async topupStatus(transactionId) {
      return mapper.readStatusResponse(
        await call(`/topups/${encodeURIComponent(transactionId)}/status`)
      );
    },

    /**
     * GET /topups/reports/transactions?customIdentifier=...
     *
     * Sèl fason pou jwenn yon rechaj lè repons POST la pèdi: nou pa gen
     * `transactionId` li, men nou te voye pwòp ID pa nou kòm `customIdentifier`.
     */
    async findTopupByCustomIdentifier(customIdentifier) {
      // Pa gen `page`/`size`: nou pa konnen si paj yo kòmanse a 0 oswa 1, e
      // yon filt sou yon ID inik pa ka bay plis pase yon paj.
      const query = new URLSearchParams({ customIdentifier });
      const matches = mapper
        .readTopupPage(await call(`/topups/reports/transactions?${query}`))
        .filter((topup) => topup.customIdentifier === customIdentifier);

      return matches[0] || null;
    },

    /** Ekspoze pou tès sèlman. */
    _resetToken() {
      cachedToken = null;
    },
  };
}

module.exports = { createReloadlyClient, ACCEPT_AIRTIME_V1 };
