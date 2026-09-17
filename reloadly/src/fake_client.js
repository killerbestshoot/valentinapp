"use strict";

/**
 * Similatè Reloadly Airtime — menm entèfas ak `client.js`, zewo rezo.
 *
 * Fòm yo swiv SDK ofisyèl la ak repons sandbox la (`docs/contract.md`). Chif
 * operatè yo (limit, to, remiz) se sa sandbox la te bay le 17/09/2026: vre
 * valè yo soti nan `GET /operators/auto-detect/...` sou kont lan, e yo chanje.
 *
 * Li egziste pou:
 *  1. devlope ak teste san kle ni kont Reloadly ki gen kòb;
 *  2. jwe ka ki prèske enposib pou pwovoke sou sandbox la (rechaj ki rete
 *     PROCESSING, refi apre debi, repons ki pèdi).
 */

const { ReloadlyError } = require("./errors");
const mapper = require("./mapper");

/** Operatè similasyon, nan fòm JSON API a (`Operator`). */
const DEFAULT_OPERATORS = [
  {
    id: 173,
    operatorId: 173,
    name: "Digicel Haiti",
    bundle: false,
    data: false,
    pin: false,
    supportsLocalAmounts: false,
    denominationType: "RANGE",
    senderCurrencyCode: "USD",
    destinationCurrencyCode: "HTG",
    minAmount: 4,
    maxAmount: 100,
    localMinAmount: null,
    localMaxAmount: null,
    fixedAmounts: [],
    localFixedAmounts: [],
    suggestedAmounts: [4, 5, 10, 15, 20],
    country: { isoName: "HT", name: "Haiti" },
    fx: { rate: 121.4599991, currencyCode: "HTG" },
    internationalDiscount: 2,
    localDiscount: 0,
    status: "ACTIVE",
  },
  {
    id: 174,
    operatorId: 174,
    name: "Natcom Haiti",
    bundle: false,
    data: false,
    pin: false,
    supportsLocalAmounts: true,
    denominationType: "RANGE",
    senderCurrencyCode: "USD",
    destinationCurrencyCode: "HTG",
    minAmount: 0.5,
    maxAmount: 99.24,
    localMinAmount: 65,
    localMaxAmount: 13000,
    fixedAmounts: [],
    localFixedAmounts: [],
    suggestedAmounts: [1, 2, 5, 10, 20],
    country: { isoName: "HT", name: "Haiti" },
    fx: { rate: 131, currencyCode: "HTG" },
    internationalDiscount: 5,
    localDiscount: 0,
    status: "ACTIVE",
  },
];

/** Prefiks Natcom yo; tout lòt nimewo mobil (3x, 4x, 5x) tonbe sou Digicel. */
const NATCOM_PREFIXES = ["32", "33", "35", "40", "41", "42", "43", "44", "55"];

function createFakeReloadlyClient({
  operators = DEFAULT_OPERATORS,
  balance = 1000, // USD
  failNumbers = ["37000000"], // Reloadly refize (4xx)
  processingNumbers = ["37111111"], // rete PROCESSING jiska yon `topupStatus`
  failOnStatusNumbers = ["37222222"], // PROCESSING, epi FAILED (REFUNDED) apre
  scopes = [
    "send-topups",
    "read-operators",
    "read-promotions",
    "read-topups-history",
    "read-prepaid-balance",
    "read-prepaid-commissions",
  ],
  promotions = [],
} = {}) {
  let balanceMinor = mapper.toMinor(balance);
  let counter = 0;

  /** transactionId -> tranzaksyon (fòm JSON API a) */
  const records = new Map();

  function operatorById(id) {
    const operator = operators.find((op) => Number(op.id) === Number(id));
    if (!operator) {
      throw new ReloadlyError("operator_not_found", `Operator not found: ${id}`, { status: 404 });
    }
    return operator;
  }

  function detect(local) {
    if (!/^[345]/.test(local)) {
      throw new ReloadlyError(
        "could_not_auto_detect_operator",
        "Could not auto detect operator for the given phone number",
        { status: 404 }
      );
    }

    const name = NATCOM_PREFIXES.includes(local.slice(0, 2)) ? "Natcom Haiti" : "Digicel Haiti";
    const operator = operators.find((op) => op.name === name) || operators[0];
    if (!operator) {
      throw new ReloadlyError("could_not_auto_detect_operator", "No operator", { status: 404 });
    }
    return operator;
  }

  function assertAmount(operator, amountMinor, useLocalAmount) {
    const parsed = mapper.readOperator(operator);

    if (useLocalAmount && !parsed.supportsLocalAmounts) {
      throw new ReloadlyError("local_amounts_not_supported", "Operator does not support local amounts", {
        status: 400,
      });
    }

    const fixed = useLocalAmount ? parsed.localFixedMinor : parsed.fixedMinor;
    const min = useLocalAmount ? parsed.localMinMinor : parsed.minMinor;
    const max = useLocalAmount ? parsed.localMaxMinor : parsed.maxMinor;

    const ok =
      parsed.denominationType === "FIXED"
        ? fixed.includes(amountMinor)
        : amountMinor >= min && amountMinor <= max;

    if (!ok) {
      throw new ReloadlyError("invalid_amount_for_operator", "Invalid amount for operator", { status: 400 });
    }

    return parsed;
  }

  return {
    mode: "fake",

    /** Pou tès yo. */
    records,

    async balance() {
      return mapper.readBalanceResponse({
        balance: balanceMinor / 100,
        currencyCode: "USD",
        lowBalanceThreshold: 0,
        updatedAt: new Date().toISOString(),
      });
    },

    /** Menm pèmisyon ak kont sandbox antrepriz la (17/09/2026). */
    async scopes() {
      return [...scopes];
    },

    async operatorsByCountry() {
      return operators.map(mapper.readOperator);
    },

    async promotionsByCountry() {
      return promotions.map(mapper.readPromotion);
    },

    async commission(operatorId) {
      const operator = operatorById(operatorId);
      return mapper.readCommission({
        percentage: operator.internationalDiscount || 0,
        internationalPercentage: operator.internationalDiscount || 0,
        localPercentage: operator.localDiscount || 0,
        updatedAt: "2026-09-17 00:00:00",
        operator: { id: operator.id, name: operator.name, status: true },
      });
    },

    async recentTopups(limit = 10) {
      return [...records.values()].map(mapper.readTopup).reverse().slice(0, limit);
    },

    async detectOperator(phone) {
      const { local } = mapper.normalizeHaitiPhone(phone);
      return mapper.readOperator(detect(local));
    },

    async operator(operatorId) {
      return mapper.readOperator(operatorById(operatorId));
    },

    async topup({ operatorId, amountMinor, useLocalAmount = false, customIdentifier, phone }) {
      const { local, international } = mapper.normalizeHaitiPhone(phone);
      const operator = operatorById(operatorId);
      const parsed = assertAmount(operator, amountMinor, useLocalAmount);

      if ([...records.values()].some((r) => r.customIdentifier === customIdentifier)) {
        // Obsève sou sandbox la le 17/09/2026.
        throw new ReloadlyError(
          "custom_identifier_already_used",
          "The custom identifier provided has already been used. Please provide a new, unique custom identifier",
          { status: 400 }
        );
      }

      if (failNumbers.includes(local)) {
        throw new ReloadlyError(
          "transaction_cannot_be_processed_at_the_moment",
          "Transaction cannot be processed at the moment",
          { status: 400 }
        );
      }

      // Sa kont lan peye an USD: montan an, mwens remiz operatè a. Sandbox la
      // bay `localDiscount: 0` pou montan lokal yo (pa gen maj).
      const senderMinor = useLocalAmount ? Math.round(amountMinor / parsed.fxRate) : amountMinor;
      const discountPercent = useLocalAmount ? operator.localDiscount : operator.internationalDiscount;
      const discountMinor = Math.round((senderMinor * Number(discountPercent || 0)) / 100);
      const costMinor = senderMinor - discountMinor;

      if (costMinor > balanceMinor) {
        throw new ReloadlyError("insufficient_balance", "Insufficient balance", { status: 400 });
      }

      balanceMinor -= costMinor;
      counter += 1;

      const pending = processingNumbers.includes(local) || failOnStatusNumbers.includes(local);

      const record = {
        transactionId: 10000 + counter,
        status: pending ? "PROCESSING" : "SUCCESSFUL",
        operatorTransactionId: pending ? null : `OP${counter}`,
        customIdentifier,
        recipientPhone: international.slice(1),
        countryCode: "HT",
        operatorId: parsed.operatorId,
        operatorName: parsed.name,
        discount: discountMinor / 100,
        discountCurrencyCode: "USD",
        requestedAmount: senderMinor / 100,
        requestedAmountCurrencyCode: "USD",
        deliveredAmount: useLocalAmount ? amountMinor / 100 : Math.round(amountMinor * parsed.fxRate) / 100,
        deliveredAmountCurrencyCode: parsed.destinationCurrency,
        transactionDate: new Date().toISOString(),
        balanceInfo: { newBalance: balanceMinor / 100, currencyCode: "USD" },
        _failOnStatus: failOnStatusNumbers.includes(local),
        _costMinor: costMinor,
      };

      records.set(record.transactionId, record);
      return mapper.readTopup(record);
    },

    async topupStatus(transactionId) {
      const record = records.get(Number(transactionId));
      if (!record) {
        throw new ReloadlyError("transaction_not_found", "Transaction not found", { status: 404 });
      }

      if (record.status === "PROCESSING") {
        record.status = record._failOnStatus ? "REFUNDED" : "SUCCESSFUL";
        if (record.status === "REFUNDED") balanceMinor += record._costMinor;
      }

      return mapper.readStatusResponse({ status: record.status, transaction: record });
    },

    async findTopupByCustomIdentifier(customIdentifier) {
      for (const record of records.values()) {
        if (record.customIdentifier === customIdentifier) return mapper.readTopup(record);
      }
      return null;
    },
  };
}

module.exports = { createFakeReloadlyClient, DEFAULT_OPERATORS };
