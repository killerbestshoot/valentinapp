"use strict";

/** Minimal PSL Payout API client. Secrets stay on the server. */
class PslError extends Error {
  constructor(code, message, { status = 0, body = null } = {}) {
    super(message);
    this.name = "PslError";
    this.code = code;
    this.status = status;
    this.body = body;
  }
}

/** Rezo PSL voye yo, ak frè PSL la (an % montan an, anplis montan an). */
const PSL_PROVIDERS = ["moncash", "natcash"];
const PSL_FEE_PCT = { moncash: 7, natcash: 6 };

function createPslClient(config, { fetchImpl = globalThis.fetch } = {}) {
  async function request(path, { method = "GET", body } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.requestTimeoutMs || 20000);
    let response;
    try {
      response = await fetchImpl(`${config.baseUrl}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${config.apiKey}`,
          Accept: "application/json",
          ...(body ? { "Content-Type": "application/json" } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: controller.signal,
      });
    } catch (err) {
      throw new PslError("network_error", `PSL Wallet pa reponn: ${err.message}`);
    } finally {
      clearTimeout(timer);
    }

    let data;
    try {
      data = await response.json();
    } catch {
      data = {};
    }
    if (!response.ok) {
      const detail = data.error || data;
      throw new PslError(
        String(detail.code || `http_${response.status}`).toLowerCase(),
        detail.message || `PSL Wallet reponn ${response.status}`,
        { status: response.status, body: data }
      );
    }
    return data;
  }

  return {
    /**
     * `provider` OBLIGATWA depi PSL mete NatCash: san li, PSL reponn
     * `422 provider_required`. "moncash" = otomatik (≈ 1 min), "natcash" =
     * voye alamen pa ekip PSL la (rete `pending` jiskaske yo voye l).
     */
    async createPayout({ provider, amountHtgMinor, phone, reference, description }) {
      if (!PSL_PROVIDERS.includes(provider)) {
        throw new PslError("invalid_provider", `Rezo PSL pa valid: ${provider || "(vid)"}.`);
      }
      const data = await request("/v1/payouts", {
        method: "POST",
        body: {
          provider,
          amount: (amountHtgMinor / 100).toFixed(2),
          phone: `509${String(phone).replace(/\D/g, "").replace(/^509/, "")}`,
          reference,
          description,
        },
      });
      return readPayout(data);
    },

    /** GET /v1/balance — `{ balance: "25400.00", currency: "HTG", account_status }`. */
    async balance() {
      const data = await request("/v1/balance");
      return {
        availableMinor: Math.round(Number(data.balance || 0) * 100),
        currency: String(data.currency || "HTG").toUpperCase(),
        accountStatus: String(data.account_status || ""),
      };
    },

    async payoutStatus(id) {
      return readPayout(await request(`/v1/payouts/${encodeURIComponent(id)}`));
    },
  };
}

function readPayout(data) {
  const status = String(data.status || "pending").toLowerCase();
  return {
    gatewayId: String(data.id || data.reference || ""),
    status: status === "completed" ? "completed" : ["failed", "cancelled"].includes(status) ? "failed" : "processing",
    rawStatus: status,
    failureReason: String(data.failure_reason || ""),
  };
}

module.exports = { createPslClient, PslError, readPayout, PSL_PROVIDERS, PSL_FEE_PCT };
