"use strict";

/**
 * Similatè Bazik — menm entèfas ak `client.js`, zewo rezo.
 *
 * Li kopye konpòtman REYÈL la (gade `docs/contract.md`):
 *   - frè 5%, `total_cost = montan + frè`
 *   - minimòm 100 HTG (MonCash) / 3998 HTG (NatCash), maksimòm 75000 HTG
 *   - menm kòd erè: insufficient_balance, amount_too_low, amount_too_high
 *   - wallet Bazik la dwe gen pwovizyon
 *
 * Li egziste pou 2 rezon:
 *  1. devlope ak teste san depann de rezo a ni de yon wallet ki finanse;
 *  2. jwe ka echèk yo (transfè ki echwe, webhook an doub) ki prèske enposib
 *     pou pwovoke sou yon vre sandbox.
 */

const { BazikError } = require("./errors");
const mapper = require("./mapper");
const { Status } = mapper;
const {
  fromMinor,
  feeMinor,
  totalCostMinor,
  NETWORK_LIMITS,
  DEFAULT_FEE_PERCENT,
} = require("./money");

function createFakeBazikClient({
  autoComplete = false,
  availableMinor = 10000000, // 100 000 HTG pou tès yo pa bloke
  failWallets = ["37000000"],
  allowCashIn = false, // kont `transfer` la pa gen dwa ankese
} = {}) {
  /** referans -> dosye */
  const records = new Map();
  let balanceMinor = availableMinor;
  let counter = 0;

  function nextId(prefix) {
    counter += 1;
    return `${prefix}_fake_${String(counter).padStart(6, "0")}`;
  }

  function mustFind(key) {
    const record = records.get(key);
    if (!record) {
      throw new BazikError("Transfer not found", `No transfer found with transaction ID: ${key}`, {
        status: 404,
      });
    }
    return record;
  }

  function normalizedWallet(phone) {
    return String(phone || "").replace(/\D/g, "").slice(-8);
  }

  return {
    mode: "fake",

    async wallet() {
      return {
        availableMinor: balanceMinor,
        reservedMinor: 0,
        currency: "HTG",
        environment: "fake",
        raw: { fake: true },
      };
    },

    async quote({ amountHtgMinor, network }) {
      return {
        deliveryMinor: amountHtgMinor,
        feeMinor: feeMinor(amountHtgMinor),
        totalCostMinor: totalCostMinor(amountHtgMinor),
        feePercent: DEFAULT_FEE_PERCENT,
        currency: "HTG",
        raw: { fake: true },
      };
    },

    async createTransfer(network, params) {
      const { reference, amountHtgMinor, phone, receiverName } = params;
      const limits = NETWORK_LIMITS[network];
      const htg = fromMinor(amountHtgMinor);

      if (htg < limits.minHtg) {
        throw new BazikError(
          "amount_too_low",
          `Minimum ${network} transfer amount is ${limits.minHtg} HTG. You requested ${htg} HTG.`,
          { status: 400 }
        );
      }

      if (htg > limits.maxHtg) {
        throw new BazikError(
          "amount_too_high",
          `Maximum ${network} transfer amount is ${limits.maxHtg} HTG per transaction. You requested ${htg} HTG.`,
          { status: 400 }
        );
      }

      // Nou pase pa MENM konstriktè demann ak vrè kliyan an, konsa fo a refize
      // egzakteman sa pwodiksyon refize. Anvan, li te teste sèlman si non an
      // vid: yon non ak yon sèl mo te pase isit la men li te kraze an
      // pwodiksyon (NatCash mande non AK siyati), e okenn tès pa t wè l.
      if (network === "natcash") {
        mapper.buildNatcashTransferRequest(params);
      } else {
        mapper.buildMoncashTransferRequest(params);
      }

      const cost = totalCostMinor(amountHtgMinor);
      if (cost > balanceMinor) {
        throw new BazikError(
          "insufficient_balance",
          `Your available balance (${fromMinor(balanceMinor)} HTG) is insufficient for this transfer (${fromMinor(cost)} HTG required including fees)`,
          { status: 400 }
        );
      }

      // Bazik debite tout kòb la (montan + frè) lè transfè a aksepte.
      balanceMinor -= cost;

      const failed = failWallets.includes(normalizedWallet(phone));
      const gatewayId = nextId("trf");
      const status = failed ? Status.FAILED : autoComplete ? Status.COMPLETED : Status.PROCESSING;

      const record = {
        kind: "transfer",
        network,
        gatewayId,
        reference,
        amountHtgMinor,
        costMinor: cost,
        phone,
        receiverName,
        status,
      };

      records.set(reference, record);
      records.set(gatewayId, record);

      return {
        gatewayId,
        status,
        message: failed ? "Nimewo a pa ka resevwa lajan (similasyon)." : "",
        raw: { fake: true },
      };
    },

    async transferStatus(transactionId) {
      const record = mustFind(transactionId);
      return {
        gatewayId: record.gatewayId,
        status: record.status,
        message: "",
        raw: { fake: true },
      };
    },

    async customerStatus({ phone }) {
      return { wallet: normalizedWallet(phone), status: "active", fake: true };
    },

    async createPayment({ orderId, amountHtgMinor, phone }) {
      if (!allowCashIn) {
        throw new BazikError(
          "endpoint_not_authorized",
          "Your account type (transfer) is not authorized to access this endpoint. This endpoint is available for: online, instore.",
          { status: 403 }
        );
      }

      const gatewayId = nextId("pay");
      const record = {
        kind: "payment",
        gatewayId,
        reference: orderId,
        amountHtgMinor,
        phone,
        status: autoComplete ? Status.COMPLETED : Status.PENDING,
      };

      records.set(orderId, record);
      records.set(gatewayId, record);

      return {
        gatewayId,
        paymentUrl: `https://fake-moncash.local/pay/${gatewayId}?order=${encodeURIComponent(orderId)}`,
        status: record.status,
        raw: { fake: true },
      };
    },

    async paymentStatus(referenceId) {
      const record = mustFind(referenceId);
      return {
        gatewayId: record.gatewayId,
        status: record.status,
        amountHtg: fromMinor(record.amountHtgMinor),
        payer: record.phone || "",
        raw: { fake: true },
      };
    },

    // ---- Kontwòl tès (pa egziste sou vre kliyan an) ----

    /** Fòse yon peman/transfè pase nan yon estati. */
    _setStatus(reference, status) {
      const record = mustFind(reference);
      record.status = status;
      return this;
    },

    _markCompleted(reference) {
      return this._setStatus(reference, Status.COMPLETED);
    },

    _markFailed(reference) {
      return this._setStatus(reference, Status.FAILED);
    },

    /** Konstwi yon kopi webhook jan Bazik ta voye l. */
    _webhookBody(reference, { eventId } = {}) {
      const record = mustFind(reference);
      return {
        eventId: eventId || `evt_fake_${record.gatewayId}_${record.status}`,
        event: record.kind === "payment" ? "payment.updated" : "transfer.updated",
        data: {
          referenceId: reference,
          transactionId: record.gatewayId,
          status: record.status,
          gdes: fromMinor(record.amountHtgMinor),
        },
      };
    },

    _balanceMinor() {
      return balanceMinor;
    },

    _get(reference) {
      return records.get(reference) || null;
    },
  };
}

module.exports = { createFakeBazikClient };
