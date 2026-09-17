"use strict";

/**
 * Minit Haiti: rechaj kredi telefòn atravè Reloadly Airtime.
 *
 * MENM LÒD OPERASYON AK TRANSFÈ BAZIK YO (`bazik/src/transfer.js`):
 *   1. valide tout sa nou ka valide lokalman (nimewo, operatè, montan, kont)
 *   2. debite wallet la ANVAN nou rele Reloadly, nan menm tranzaksyon ak liy lan
 *   3. rele Reloadly
 *   4. refi klè -> ranbouse; repons ambigi -> PA ranbouse, verifye pita
 *
 * MONTAN: nan deviz TRANZAKSYON AN (sa kliyan an peye), NENPÒT deviz.
 *   - deviz = deviz operatè a (USD)          -> voye tel kel
 *   - deviz = HTG e operatè a aksepte lokal  -> `useLocalAmount: true`
 *   - nenpòt lòt deviz (MXN, CLP, HTG pou Digicel...) -> KONVÈTI an USD ak to
 *     jounen an (`rates`), awondi an BA: nou pa janm voye plis pase valè a.
 * DEBI: montan an konvèti nan deviz WALLET ajan an — toujou nan inite wallet la.
 */

const AppIds = require("../../bazik/src/ids");
const { createRateBook } = require("../../bazik/src/rates");
const { ReloadlyError, DomainError, domainError } = require("./errors");
const { normalizeHaitiPhone, fromMinor } = require("./mapper");

/** Operatè yo pa chanje chak minit; nou pa rele auto-detect sou chak lèt. */
const OPERATOR_TTL_MS = 5 * 60 * 1000;
const BALANCE_TTL_MS = 30 * 1000;

const Final = new Set(["completed", "failed"]);

function formatMinor(minor) {
  return fromMinor(minor).toFixed(2);
}

function createAirtimeUseCases({
  store,
  wallets,
  client,
  config,
  rates = createRateBook({ store: wallets }),
  now = () => Date.now(),
}) {
  const cache = new Map();

  async function cached(key, ttlMs, loader) {
    const hit = cache.get(key);
    if (hit && hit.at > now() - ttlMs) return hit.value;

    const value = await loader();
    cache.set(key, { at: now(), value });
    return value;
  }

  // --- Operatè ---------------------------------------------------------------

  /** Fòm JSON yon operatè pou UI a. */
  function describeOperator(operator) {
    return {
      operatorId: operator.operatorId,
      name: operator.name,
      denominationType: operator.denominationType,
      senderCurrency: operator.senderCurrency,
      destinationCurrency: operator.destinationCurrency,
      supportsLocalAmounts: operator.supportsLocalAmounts,
      fxRate: operator.fxRate,
      minAmount: fromMinor(operator.minMinor),
      maxAmount: fromMinor(operator.maxMinor),
      localMinAmount: fromMinor(operator.localMinMinor),
      localMaxAmount: fromMinor(operator.localMaxMinor),
      fixedAmounts: operator.fixedMinor.map(fromMinor),
      localFixedAmounts: operator.localFixedMinor.map(fromMinor),
      suggestedAmounts: operator.suggestedMinor.map(fromMinor),
    };
  }

  /** Minit Haiti vann kredi dirèk sou yon liy Ayiti — pa done, pa pakè, pa PIN. */
  function assertSellable(operator) {
    if (operator.countryCode && operator.countryCode !== config.countryCode) {
      throw new DomainError(
        "operator_not_supported",
        `${operator.name || "Operatè sa a"} pa yon operatè Ayiti.`
      );
    }

    if (operator.isPin || operator.isData || operator.isBundle) {
      throw new DomainError(
        "operator_not_supported",
        `${operator.name} vann done, pakè oswa kòd PIN, pa minit dirèk.`
      );
    }

    if (operator.status && operator.status !== "ACTIVE") {
      throw new DomainError(
        "operator_unavailable",
        `${operator.name} pa disponib kounye a sou Reloadly (${operator.status}). Eseye pita.`
      );
    }

    return operator;
  }

  async function detectOperator(phone) {
    const { international } = normalizeHaitiPhone(phone);

    try {
      const operator = await cached(`phone:${international}`, OPERATOR_TTL_MS, () =>
        client.detectOperator(international)
      );
      return assertSellable(operator);
    } catch (err) {
      if (err instanceof ReloadlyError && (err.status === 404 || err.code === "could_not_auto_detect_operator")) {
        throw new DomainError(
          "operator_not_found",
          `Nou pa jwenn operatè nimewo ${international} la. Verifye se yon nimewo Digicel oswa Natcom.`
        );
      }
      throw err;
    }
  }

  /**
   * Operatè a TOUJOU soti nan nimewo a (auto-detect). Yon `operatorId` ki
   * vini nan demann lan sèvi sèlman pou verifye UI a ak serveur a dakò.
   *
   * Sandbox la montre poukisa: "Natcom Haiti Special Bundle" (#1296) se yon
   * pakè ki PA make `bundle`. Si nou te fè konfyans `operatorId` kliyan an,
   * yon apèl fòje te ka vann pakè sa a kòm minit.
   */
  async function resolveOperator({ phone, operatorId }) {
    const operator = await detectOperator(phone);

    if (operatorId && Number(operatorId) !== operator.operatorId) {
      throw new DomainError(
        "operator_mismatch",
        `Nimewo sa a se ${operator.name} (#${operator.operatorId}), pa operatè #${operatorId}. Rechaje devi a.`
      );
    }

    return operator;
  }

  // --- Montan ----------------------------------------------------------------

  /**
   * Chwazi mòd montan an, konvèti si sa nesesè, epi verifye limit operatè a
   * AVAN nou rele Reloadly. Mesaj ann Kreyòl, san aller-retour rezo, san debi.
   *
   * @param {string} amountCurrency deviz montan an (tranzaksyon an)
   * @param {string} walletCurrency deviz wallet ki ap debite a
   */
  async function planAmount({ operator, amountMinor, amountCurrency, walletCurrency }) {
    if (!Number.isInteger(amountMinor) || amountMinor <= 0) {
      throw new DomainError("invalid_amount", "Montan an dwe pi gran pase 0.");
    }

    const currency = String(amountCurrency || walletCurrency || "").toUpperCase();
    const wallet = String(walletCurrency || currency).toUpperCase();

    let useLocalAmount = false;
    let sendAmountMinor = amountMinor;
    let sendCurrency = operator.senderCurrency;
    let conversion = null;

    if (currency === operator.senderCurrency) {
      // Voye tel kel.
    } else if (currency === operator.destinationCurrency && operator.supportsLocalAmounts) {
      useLocalAmount = true;
      sendCurrency = operator.destinationCurrency;
    } else {
      // Awondi an BA: 100 MXN = 5,8163 USD -> 5,81 USD voye. Yon santim anwo
      // ta vle di nou voye plis valè pase sa kliyan an peye.
      conversion = await rates.convert(amountMinor, currency, operator.senderCurrency, { rounding: "down" });
      sendAmountMinor = conversion.amountMinor;
    }

    // Limit yo nan deviz VOYE a; mesaj la montre tou deviz kliyan an si nou konvèti.
    const inSend = (minor) =>
      conversion
        ? `${formatMinor(minor)} ${sendCurrency} (≈ ${formatMinor(Math.ceil(minor / conversion.rate))} ${currency})`
        : `${formatMinor(minor)} ${sendCurrency}`;
    const asked = conversion
      ? `${formatMinor(amountMinor)} ${currency} (≈ ${formatMinor(sendAmountMinor)} ${sendCurrency})`
      : `${formatMinor(amountMinor)} ${currency}`;

    const fixed = useLocalAmount ? operator.localFixedMinor : operator.fixedMinor;
    const min = useLocalAmount ? operator.localMinMinor : operator.minMinor;
    const max = useLocalAmount ? operator.localMaxMinor : operator.maxMinor;

    if (operator.denominationType === "FIXED") {
      if (!fixed.includes(sendAmountMinor)) {
        throw domainError(
          "amount_not_offered",
          `${operator.name} vann sèlman montan sa yo: ${fixed.map(inSend).join(", ")}. Ou mande ${asked}.`,
          { allowedAmounts: fixed.map(fromMinor) }
        );
      }
    } else {
      if (min > 0 && sendAmountMinor < min) {
        throw new DomainError("amount_too_low", `Minimòm ${operator.name} se ${inSend(min)}. Ou mande ${asked}.`);
      }
      if (max > 0 && sendAmountMinor > max) {
        throw new DomainError("amount_too_high", `Maksimòm ${operator.name} se ${inSend(max)}. Ou mande ${asked}.`);
      }
    }

    const debit = await rates.convert(amountMinor, currency, wallet);
    const fx = operator.fxRate;

    return {
      useLocalAmount,
      currency,
      amountMinor,
      sendAmountMinor,
      sendCurrency,
      /** Konbyen `sendCurrency` pou 1 `currency` (1 si pa gen konvèsyon). */
      conversionRate: conversion ? conversion.rate : 1,
      debitMinor: debit.amountMinor,
      walletCurrency: wallet,
      ratesUpdatedAt: conversion?.updatedAt ?? debit.updatedAt ?? null,
      ratesStale: Boolean(conversion?.stale || debit.stale),
      /** Estimasyon sèlman: montan egzak la soti nan repons Reloadly a. */
      estimatedDeliveredMinor: useLocalAmount ? sendAmountMinor : fx > 0 ? Math.round(sendAmountMinor * fx) : 0,
      deliveredCurrency: operator.destinationCurrency,
      /** Sa kont Reloadly a peye, ANVAN remiz: nou verifye pwovizyon ak li. */
      senderCostMinor: useLocalAmount ? (fx > 0 ? Math.round(sendAmountMinor / fx) : 0) : sendAmountMinor,
      senderCurrency: operator.senderCurrency,
    };
  }

  // --- Kont Reloadly ---------------------------------------------------------

  async function accountBalance({ force = false } = {}) {
    if (force) cache.delete("balance");
    return cached("balance", BALANCE_TTL_MS, () => client.balance());
  }

  /**
   * Echwe FÈMEN sèlman lè nou KONNEN kont lan pa ase. Si tchèk la li menm
   * echwe, nou kontinye: se Reloadly ki otorite.
   */
  async function assertAccountFunded(plan) {
    if (!(plan.senderCostMinor > 0)) return { checked: false };

    let account;
    try {
      account = await accountBalance();
    } catch (err) {
      if (err instanceof ReloadlyError) return { checked: false, reason: err.code };
      throw err;
    }

    if (account.currency && plan.senderCurrency && account.currency !== plan.senderCurrency) {
      return { checked: false, reason: "currency" };
    }

    if (account.balanceMinor < plan.senderCostMinor) {
      throw new DomainError(
        "airtime_underfunded",
        `Kont Reloadly la pa gen ase kòb: ${formatMinor(account.balanceMinor)} ${account.currency} disponib, ` +
          `${formatMinor(plan.senderCostMinor)} ${plan.senderCurrency} nesesè. Kontakte administratè a.`
      );
    }

    return { checked: true };
  }

  // --- Wallet ajan an --------------------------------------------------------

  async function walletFor({ uid, enterpriseId }) {
    const wallet = await wallets.getWallet({ uid, enterpriseId });
    if (!wallet) throw new DomainError("wallet_not_found", "Wallet sa a pa egziste.");
    return wallet;
  }

  // --- Devi ------------------------------------------------------------------

  /** Sa ajan an ap peye ak sa benefisyè a ap resevwa, san anyen pa deplase. */
  async function quote({ uid, enterpriseId, phone, amountMinor, currency, operatorId }) {
    const wallet = await walletFor({ uid, enterpriseId });
    const { international } = normalizeHaitiPhone(phone);
    const operator = await resolveOperator({ phone: international, operatorId });
    const plan = await planAmount({
      operator,
      amountMinor,
      amountCurrency: currency || wallet.currency,
      walletCurrency: wallet.currency,
    });

    // Menm tchèk ak `send`: yon devi ki pase dwe vle di rechaj la ka pati. UI a
    // rele devi a ANVAN li kreye tranzaksyon an, konsa yon kont vid pa kite
    // yon tranzaksyon `pending` òfelen.
    await assertAccountFunded(plan);

    return {
      phone: international,
      operator: describeOperator(operator),
      currency: plan.currency,
      amount: fromMinor(plan.amountMinor),
      useLocalAmount: plan.useLocalAmount,
      sendAmount: fromMinor(plan.sendAmountMinor),
      sendCurrency: plan.sendCurrency,
      conversionRate: plan.conversionRate,
      estimatedDelivered: fromMinor(plan.estimatedDeliveredMinor),
      deliveredCurrency: plan.deliveredCurrency,
      debit: fromMinor(plan.debitMinor),
      debitCurrency: plan.walletCurrency,
      ratesUpdatedAt: plan.ratesUpdatedAt,
      ratesStale: plan.ratesStale,
      mode: client.mode,
    };
  }

  // --- Voye ------------------------------------------------------------------

  /**
   * Timeout, sokèt koupe, 5xx: Reloadly ka te trete rechaj la. Si nou ranbouse
   * epi minit yo te pase, antrepriz la pèdi 100% montan an.
   */
  function isAmbiguous(err) {
    if (!(err instanceof ReloadlyError)) return true;
    if (err.code === "network_error") return true;
    return err.status >= 500;
  }

  /** Aplike repons Reloadly a (POST, status oswa rapò) sou liy nou an. */
  async function applyResult(topupId, result) {
    const delivery = {
      deliveredMinor: result.deliveredMinor,
      deliveredCurrency: result.deliveredCurrency,
      discountMinor: result.discountMinor,
      discountCurrency: result.discountCurrency,
      operatorTransactionId: result.operatorTransactionId,
    };

    if (Final.has(result.status)) {
      const settled = await store.settleTopup({
        topupId,
        status: result.status,
        gatewayId: result.gatewayId,
        gatewayStatus: result.rawStatus || result.status,
        failureReason: result.status === "failed" ? `Reloadly: ${result.rawStatus || "FAILED"}` : "",
        delivery,
      });
      return { topup: settled.topup, changed: !settled.duplicate, refund: settled.refund };
    }

    // PROCESSING, oswa yon repons san estati ni ID: nou kite l an verifikasyon.
    const topup = await store.updateTopup(topupId, {
      status: "processing",
      gatewayId: result.gatewayId,
      gatewayStatus: result.rawStatus || "PROCESSING",
      delivery,
    });
    return { topup, changed: false };
  }

  /**
   * @param {object} params
   * @param {number} params.amountMinor santim nan deviz `currency`
   * @param {string} [params.currency] deviz montan an (default: deviz wallet la)
   * @param {string} params.phone nimewo Ayiti benefisyè a
   * @param {number} [params.operatorId] si UI a te deja detekte l
   * @param {string} [params.txId] tranzaksyon app la
   * @param {string} [params.idempotencySeed] OBLIGATWA si pa gen `txId`
   */
  async function send({
    uid,
    enterpriseId,
    enterpriseName = "",
    phone,
    amountMinor,
    currency,
    operatorId,
    txId = "",
    note = "",
    createdBy = "",
    idempotencySeed = "",
  }) {
    if (!uid || !enterpriseId) {
      throw new DomainError("missing_owner", "uid ak enterpriseId obligatwa.");
    }

    const seed = idempotencySeed || (txId ? `tx:${txId}` : "");
    if (!seed) {
      throw new DomainError(
        "missing_idempotency_key",
        "Yon kle idempotans obligatwa pou evite voye menm minit yo de fwa."
      );
    }

    const topupId = AppIds.airtime(`${enterpriseId}:${uid}:${seed}`);

    const existing = await store.getTopup(topupId);
    if (existing) return { topup: existing, duplicate: true, mode: client.mode };

    const wallet = await walletFor({ uid, enterpriseId });
    const { international } = normalizeHaitiPhone(phone);
    const operator = await resolveOperator({ phone: international, operatorId });
    const plan = await planAmount({
      operator,
      amountMinor,
      amountCurrency: currency || wallet.currency,
      walletCurrency: wallet.currency,
    });

    await assertAccountFunded(plan);
    if (typeof client.prepare === "function") await client.prepare();

    // --- 1) Liy + debi ann ATOMIK ---
    const opened = await store.openTopup(
      {
        topupId,
        operatorId: operator.operatorId,
        operatorName: operator.name,
        countryCode: config.countryCode,
        phone: international,
        useLocalAmount: plan.useLocalAmount,
        amountMinor,
        currency: plan.currency,
        sendAmountMinor: plan.sendAmountMinor,
        sendCurrency: plan.sendCurrency,
        conversionRate: plan.conversionRate,
        debitMinor: plan.debitMinor,
        walletCurrency: plan.walletCurrency,
        ratesUpdatedAt: plan.ratesUpdatedAt,
        estimatedDeliveredMinor: plan.estimatedDeliveredMinor,
        deliveredCurrency: plan.deliveredCurrency,
        uid,
        enterpriseId,
        enterpriseName,
        txId,
        note,
        createdBy,
      },
      {
        uid,
        enterpriseId,
        enterpriseName,
        // Debi a nan deviz WALLET la, pa nan deviz tranzaksyon an.
        amountMinor: plan.debitMinor,
        currency: plan.walletCurrency,
        type: "airtime_minit",
        note: note || `Minit ${operator.name} ${international}`,
        sourceCollection: "airtime_topups",
        sourceId: topupId,
        txId,
        serviceName: "minit_ht",
        createdBy: createdBy || "reloadly",
        createdByRole: "system",
        idempotencyKey: `airtime:${topupId}`,
      }
    );

    // Yon lòt apèl te louvri l anvan nou (doub-klik konkiran): pa gen dezyèm voye.
    if (opened.duplicate) return { topup: opened.topup, duplicate: true, mode: client.mode };

    // --- 2) Rele Reloadly ---
    let result;
    try {
      result = await client.topup({
        operatorId: operator.operatorId,
        amountMinor: plan.sendAmountMinor,
        useLocalAmount: plan.useLocalAmount,
        customIdentifier: topupId,
        phone: international,
      });
    } catch (err) {
      const reason = err instanceof ReloadlyError ? `${err.code}: ${err.message}` : err.message;

      // 400 `CUSTOM_IDENTIFIER_ALREADY_USED` (obsève sou sandbox la) PA vle
      // di "refize": sa vle di Reloadly TE DEJA trete yon rechaj ak ID sa a.
      // Sa rive si baz la retabli depi yon sovgad ki pa t konnen rechaj la.
      // Ranbouse la ta bay minit yo gratis: nou rekonsilye pito.
      if (err instanceof ReloadlyError && err.code === "custom_identifier_already_used") {
        const found = await client.findTopupByCustomIdentifier(topupId).catch(() => null);

        if (found) {
          const applied = await applyResult(topupId, found);
          return { topup: applied.topup, duplicate: true, refund: applied.refund || null, mode: client.mode };
        }

        const pending = await store.updateTopup(topupId, {
          status: "processing",
          gatewayStatus: "unknown",
          failureReason: `ambigu: ${reason}`,
        });
        throw domainError(
          "airtime_pending_verification",
          "Reloadly di rechaj sa a te deja voye, men nou pa jwenn li. Li an verifikasyon — pa voye l ankò.",
          { topup: pending }
        );
      }

      if (isAmbiguous(err)) {
        const pending = await store.updateTopup(topupId, {
          status: "processing",
          gatewayStatus: "unknown",
          failureReason: `ambigu: ${reason}`,
        });

        throw domainError(
          "airtime_pending_verification",
          "Nou pa rive konfime rechaj la ak Reloadly. Li an verifikasyon — pa voye l ankò.",
          { topup: pending }
        );
      }

      const settled = await store.settleTopup({ topupId, status: "failed", failureReason: reason });

      throw domainError(
        err instanceof ReloadlyError ? err.code : "airtime_failed",
        `Rechaj la pa pase, wallet la ranbouse. ${reason}`,
        { topup: settled.topup }
      );
    }

    // --- 3) Reloadly reponn ---
    const applied = await applyResult(topupId, result);
    return { topup: applied.topup, duplicate: false, refund: applied.refund || null, mode: client.mode };
  }

  // --- Rekonsilyasyon --------------------------------------------------------

  /**
   * Mande Reloadly ki kote yon rechaj ye, epi fèmen l si li final.
   *
   * - Ak `transactionId`: `GET /topups/{id}/status`.
   * - San li (POST la pa t janm reponn): rapò tranzaksyon yo filtre sou
   *   `customIdentifier`.
   *
   * "Pa jwenn" PA vle di "pa pati": nou pa ranbouse sou sa. Yon moun verifye
   * sou dashboard Reloadly a.
   */
  async function refresh(topupId) {
    const topup = await store.getTopup(topupId);
    if (!topup) throw new DomainError("airtime_topup_not_found", `Rechaj ${topupId} pa egziste.`);

    if (Final.has(topup.status)) return { topup, changed: false };

    if (topup.gatewayId) {
      let status;
      try {
        status = await client.topupStatus(topup.gatewayId);
      } catch (err) {
        if (err instanceof ReloadlyError && err.status === 404) {
          return { topup, changed: false, notFound: true };
        }
        throw err;
      }

      return applyResult(topupId, {
        ...(status.topup || {}),
        gatewayId: status.topup?.gatewayId || topup.gatewayId,
        status: status.status,
        rawStatus: String(status.raw?.status || status.topup?.rawStatus || ""),
      });
    }

    const found = await client.findTopupByCustomIdentifier(topupId);
    if (!found) return { topup, changed: false, notFound: true };

    return applyResult(topupId, found);
  }

  /** Pou yon tach pwograme: rekipere tout rechaj ki rete an verifikasyon. */
  async function pollPending(limit = 50) {
    const pending = await store.listPendingTopups(limit);
    const results = [];

    for (const topup of pending) {
      try {
        const result = await refresh(topup.topupId);
        if (result.changed) results.push(result.topup);
      } catch (err) {
        results.push({ topupId: topup.topupId, error: err.message });
      }
    }

    return results;
  }

  return {
    describeOperator,
    detectOperator,
    quote,
    send,
    refresh,
    pollPending,
    accountBalance,
    planAmount,
  };
}

module.exports = { createAirtimeUseCases };
