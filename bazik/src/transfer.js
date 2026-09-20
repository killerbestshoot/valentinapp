"use strict";

/**
 * Transfè soti: payout (voye bay yon staff) ak livrezon (voye bay yon kliyan).
 *
 * Se flux prensipal la pou kont `transfer` la (gade `docs/contract.md`).
 *
 * LÒD OPERASYON YO ENPÒTAN:
 *   1. debite wallet la ANVAN nou rele Bazik
 *   2. rele Bazik
 *   3. si Bazik refize -> ranbouse otomatikman
 *
 * Si nou te rele Bazik anvan, yon pàn ant apèl la ak debi a t ap kite lajan
 * soti san okenn tras nan wallet la.
 */

const AppIds = require("./ids");
const { DomainError, BazikError } = require("./errors");
const { assertNetworkAmount, feeMinor, fromMinor, DEFAULT_FEE_PERCENT } = require("./money");
const { createRateBook } = require("./rates");

function createTransferUseCases({ store, client, config, rates = createRateBook({ store }) }) {
  /**
   * Sòld Bazik la chanje dousman; nou kenbe l yon ti moman pou nou pa boule
   * kota 100 req/min nan ak yon apèl anplis sou chak transfè.
   */
  const GATEWAY_BALANCE_TTL_MS = 30000;
  let cachedGatewayBalance = null;

  async function gatewayBalance({ force = false } = {}) {
    if (!force && cachedGatewayBalance && cachedGatewayBalance.at > Date.now() - GATEWAY_BALANCE_TTL_MS) {
      return cachedGatewayBalance.value;
    }

    const wallet = await client.wallet();
    cachedGatewayBalance = { at: Date.now(), value: wallet };
    return wallet;
  }

  /**
   * Verifye float Bazik la AVAN nou debite ajan an.
   *
   * San sa, yon wallet Bazik vid bay yon sekans absid: nou debite ajan an,
   * Bazik refize, nou ranbouse. Ajan an wè sòld li desann epi remonte san
   * okenn esplikasyon, e nou pèdi 2 apèl rezo.
   *
   * Nou echwe FÈMEN sèlman lè nou KONNEN float la pa ase. Si tchèk la li menm
   * echwe (rezo, endpoint bloke), nou kontinye: se Bazik ki otorite, pa nou.
   */
  async function assertGatewayFunded(totalHtgMinor) {
    let wallet;

    try {
      wallet = await gatewayBalance();
    } catch (err) {
      if (err instanceof BazikError) return { checked: false, reason: err.code };
      throw err;
    }

    if (wallet.availableMinor < totalHtgMinor) {
      throw new DomainError(
        "gateway_underfunded",
        `Kont Bazik la pa gen ase pwovizyon: ${fromMinor(wallet.availableMinor)} HTG disponib, ` +
          `${fromMinor(totalHtgMinor)} HTG nesesè (frè ladan). Kontakte administratè a.`
      );
    }

    return { checked: true, availableMinor: wallet.availableMinor };
  }

  /**
   * Prepare chif yo: konvèsyon deviz + frè Bazik.
   * Nou mande Bazik yon `quote` lè nou kapab, konsa si frè a chanje nou swiv.
   *
   * DE DEVIZ, DE ROL:
   *   - `currency`       : deviz MONTAN AN (sa kliyan an peye ajan an)
   *   - `walletCurrency` : deviz WALLET ajan an, kote debi a fèt
   * Tout konvèsyon pase pa `rates` (liv to echanj la), ki konnen dat ak sous
   * chak to. Montan an -> HTG pou benefisyè a; total HTG -> deviz wallet pou debi a.
   */
  async function prepareAmounts({ amountMinor, currency, walletCurrency = currency, network }) {
    const toHtg = await rates.convert(amountMinor, currency, "HTG");
    const amountHtgMinor = toHtg.amountMinor;

    assertNetworkAmount(network, amountHtgMinor);

    let feeHtgMinor = feeMinor(amountHtgMinor);
    let feePercent = DEFAULT_FEE_PERCENT;

    try {
      const quote = await client.quote({ amountHtgMinor, network });

      // Nou aksepte frè Bazik la SÈLMAN si li koyeran ak total la. Anvan, si
      // Bazik te chanje non chan `fee` la, `feeMinor` te tounen 0 pandan
      // `total_cost` rete pozitif — frè yo te tonbe a zewo, antrepriz la
      // t ap absòbe 5% sou chak transfè san okenn siyal.
      const coherent =
        quote.feeMinor > 0 &&
        quote.totalCostMinor === amountHtgMinor + quote.feeMinor;

      if (coherent) {
        feeHtgMinor = quote.feeMinor;
        feePercent = quote.feePercent || feePercent;
      }
    } catch (err) {
      // Quote a se yon konfò, se pa yon blokaj: si li echwe nou kontinye ak
      // to 5% la ki dokimante. Men nou make sa nan log la.
      if (!(err instanceof BazikError)) throw err;
    }

    const totalHtgMinor = amountHtgMinor + feeHtgMinor;
    const debit = await rates.convert(totalHtgMinor, "HTG", walletCurrency);

    // San frè: montan an konvèti DIREKTEMAN nan deviz wallet la (pa atravè
    // HTG awondi), konsa menm deviz = menm montan egzak.
    const amountInWallet = await rates.convert(amountMinor, currency, walletCurrency);

    return {
      rateToHtg: toHtg.fromRateToHtg,
      walletCurrency: String(walletCurrency).toUpperCase(),
      walletRateToHtg: debit.toRateToHtg,
      amountHtgMinor,
      feeHtgMinor,
      feePercent,
      totalHtgMinor,
      /** Sa nou retire nan wallet la, nan deviz WALLET la (frè ladan). */
      debitMinor: debit.amountMinor,
      /** Menm bagay san frè (`chargeFeeToWallet: false`). */
      amountWalletMinor: amountInWallet.amountMinor,
      ratesUpdatedAt: toHtg.updatedAt ?? debit.updatedAt ?? null,
      ratesStale: toHtg.stale || debit.stale,
    };
  }

  /**
   * Yon estimasyon pou UI a, san anyen pa deplase.
   * Ak `uid`/`enterpriseId`, debi a kalkile nan deviz WALLET ajan an.
   */
  async function quote({ amountMinor, currency, network = "moncash", uid, enterpriseId }) {
    const wallet = uid && enterpriseId ? await store.getWallet({ uid, enterpriseId }) : null;
    const walletCurrency = wallet?.currency || String(currency || config.walletCurrency).toUpperCase();
    const amountCurrency = String(currency || walletCurrency).toUpperCase();

    const amounts = await prepareAmounts({ amountMinor, currency: amountCurrency, walletCurrency, network });

    return {
      network,
      currency: amountCurrency,
      amountMinor,
      amountHtg: fromMinor(amounts.amountHtgMinor),
      feeHtg: fromMinor(amounts.feeHtgMinor),
      totalHtg: fromMinor(amounts.totalHtgMinor),
      feePercent: amounts.feePercent,
      debitMinor: amounts.debitMinor,
      walletCurrency: amounts.walletCurrency,
      rateToHtg: amounts.rateToHtg,
      ratesUpdatedAt: amounts.ratesUpdatedAt,
      ratesStale: amounts.ratesStale,
      mode: client.mode,
    };
  }

  /**
   * Voye lajan.
   *
   * @param {object} params
   * @param {'payout'|'delivery'} params.kind
   * @param {'moncash'|'natcash'} params.network
   * @param {number} params.amountMinor santim nan deviz wallet la
   * @param {string} params.phone nimewo benefisyè a
   * @param {string} [params.receiverName] OBLIGATWA pou NatCash
   * @param {string} [params.txId] tranzaksyon app la, si se yon livrezon
   * @param {string} [params.idempotencySeed] menm seed = menm transfè
   */
  /**
   * Èske yon erè Bazik AMBIGI — sa vle di nou pa konnen si transfè a pati?
   *
   * - `network_error` (timeout, sokèt koupe) ak 5xx: Bazik ka te aksepte l
   *   anvan koneksyon an mouri. NOU PA RANBOUSE: sinon, si lajan an te pati,
   *   benefisyè a resevwa l E ajan an ranbouse — antrepriz la pèdi 100%.
   *   Transfè a rete `processing`, `pollPending` ap rekonsilye l.
   * - 4xx metye (`insufficient_balance`, `amount_too_low`...) ak 429:
   *   Bazik refize demann lan klèman. Nou ka ranbouse san risk.
   */
  function isAmbiguous(err) {
    if (!(err instanceof BazikError)) return true;
    if (err.code === "network_error") return true;
    return err.status >= 500;
  }

  /**
   * Voye lajan.
   *
   * @param {object} params
   * @param {'payout'|'delivery'} params.kind
   * @param {'moncash'|'natcash'} params.network
   * @param {number} params.amountMinor santim nan deviz `currency`
   * @param {string} [params.currency] deviz montan an (default: deviz wallet la)
   * @param {string} params.phone nimewo benefisyè a
   * @param {string} [params.receiverName] OBLIGATWA pou NatCash
   * @param {string} [params.txId] tranzaksyon app la, si se yon livrezon
   * @param {string} [params.idempotencySeed] OBLIGATWA si pa gen `txId`
   */
  async function send({
    kind = "payout",
    network = "moncash",
    amountMinor,
    currency,
    uid,
    enterpriseId,
    enterpriseName = "",
    phone,
    receiverName = "",
    txId = "",
    note = "",
    createdBy = "",
    idempotencySeed = "",
    chargeFeeToWallet = true,
  }) {
    if (!uid || !enterpriseId) {
      throw new DomainError("missing_owner", "uid ak enterpriseId obligatwa.");
    }

    if (network === "natcash" && !String(receiverName).trim()) {
      throw new DomainError("missing_receiver_name", "NatCash mande non konplè benefisyè a.");
    }

    // --- Deviz montan an ≠ deviz wallet la: KONVÈSYON, pa konfizyon ---
    //
    // Ansyen twou: yon wallet HTG voye `currency: "USD"` → 100 USD = 13 200 HTG
    // pou benefisyè a, men 105 debite nan wallet HTG la (inite melanje). Li te
    // achte 13 200 HTG pou 105 HTG. Premye koreksyon an te REFIZE tout lòt
    // deviz. Kounye a nou konvèti: debi a toujou kalkile NAN DEVIZ WALLET LA
    // (13 860 HTG pou egzanp lan), ak to jounen an.
    const wallet = await store.getWallet({ uid, enterpriseId });
    if (!wallet) {
      throw new DomainError("wallet_not_found", "Wallet sa a pa egziste.");
    }

    const walletCurrency = wallet.currency;
    const amountCurrency = String(currency || walletCurrency).toUpperCase();

    // --- Idempotans: yon kle STAB, san lè ---
    //
    // Anvan: `${...}:${txId || Date.now()}`. `Date.now()` chanje chak
    // milisgond, donk yon doub-klik te bay DE transfè — e de debi.
    const seed = idempotencySeed || (txId ? `tx:${txId}` : "");
    if (!seed) {
      throw new DomainError(
        "missing_idempotency_key",
        "Yon kle idempotans obligatwa pou evite voye menm lajan an de fwa."
      );
    }

    const transferId = AppIds.transfer(`${enterpriseId}:${uid}:${seed}`);

    const existing = await store.getTransfer(transferId);
    if (existing) {
      return { transfer: existing, duplicate: true, mode: client.mode };
    }

    const amounts = await prepareAmounts({ amountMinor, currency: amountCurrency, walletCurrency, network });
    const debitMinor = chargeFeeToWallet ? amounts.debitMinor : amounts.amountWalletMinor;

    await assertGatewayFunded(amounts.totalHtgMinor);

    // --- 1) Liy + debi ann ATOMIK ---
    const opened = await store.openTransfer(
      {
        transferId,
        reference: transferId,
        kind,
        network,
        amountMinor,
        currency: amountCurrency,
        amountHtgMinor: amounts.amountHtgMinor,
        feeHtgMinor: amounts.feeHtgMinor,
        totalHtgMinor: amounts.totalHtgMinor,
        debitMinor,
        feeChargedToWallet: chargeFeeToWallet,
        rateToHtg: amounts.rateToHtg,
        walletCurrency,
        walletRateToHtg: amounts.walletRateToHtg,
        ratesUpdatedAt: amounts.ratesUpdatedAt,
        uid,
        enterpriseId,
        enterpriseName,
        phone,
        receiverName,
        txId,
        note,
        createdBy,
      },
      {
        uid,
        enterpriseId,
        enterpriseName,
        amountMinor: debitMinor,
        currency: walletCurrency,
        type: `${kind}_${network}`,
        note: note || `${kind} ${network} via Bazik`,
        sourceCollection: "bazik_transfers",
        sourceId: transferId,
        txId,
        serviceName: network,
        createdBy: createdBy || "bazik",
        createdByRole: "system",
        idempotencyKey: `transfer:${transferId}`,
      }
    );

    // Yon lòt apèl te louvri l anvan nou (kous konkiran): pa gen dezyèm voye.
    if (opened.duplicate) {
      return { transfer: opened.transfer, duplicate: true, mode: client.mode };
    }

    // --- 2) Rele Bazik ---
    let result;
    try {
      result = await client.createTransfer(network, {
        reference: transferId,
        amountHtgMinor: amounts.amountHtgMinor,
        phone,
        receiverName,
        description: note || `VOUPVAPCASH ${kind}`,
      });
    } catch (err) {
      const reason = err instanceof BazikError ? `${err.code}: ${err.message}` : err.message;

      if (isAmbiguous(err)) {
        // NOU PA KONNEN si lajan an pati. Pa ranbouse: `pollPending` ap mande
        // Bazik `GET /transfers/{reference}` epi fèmen l nan bon sans lan.
        const pending = await store.updateTransfer(transferId, {
          status: "processing",
          gatewayStatus: "unknown",
          failureReason: `ambigu: ${reason}`,
        });

        throw new DomainError(
          "transfer_pending_verification",
          "Nou pa rive konfime transfè a ak Bazik. Li an verifikasyon — pa voye l ankò.",
          { transfer: pending }
        );
      }

      // Refi klè: ranbousman san risk.
      const settled = await store.settleTransfer({
        transferId,
        status: "failed",
        failureReason: reason,
      });

      throw new DomainError(
        err instanceof BazikError ? err.code : "transfer_failed",
        `Transfè a pa pase, wallet la ranbouse. ${reason}`,
        { transfer: settled.transfer }
      );
    }

    // --- 3) Bazik aksepte ---
    if (result.status === "completed" || result.status === "failed") {
      const settled = await store.settleTransfer({
        transferId,
        status: result.status,
        gatewayId: result.gatewayId,
        gatewayStatus: result.status,
        failureReason: result.status === "failed" ? result.message : "",
      });
      return { transfer: settled.transfer, duplicate: false, refund: settled.refund, mode: client.mode };
    }

    const transfer = await store.updateTransfer(transferId, {
      status: "processing",
      gatewayId: result.gatewayId,
      gatewayStatus: result.status,
    });

    return { transfer, duplicate: false, mode: client.mode };
  }

  /**
   * Mande Bazik ki kote yon transfè ye, epi fèmen l si li final.
   * Se sa ki pwoteje nou kont yon webhook ki pèdi.
   */
  async function refresh(transferId) {
    const transfer = await store.getTransfer(transferId);
    if (!transfer) throw new DomainError("transfer_not_found", `Transfè ${transferId} pa egziste.`);

    if (transfer.status === "completed" || transfer.status === "failed") {
      return { transfer, changed: false };
    }

    const lookupId = transfer.gatewayId || transfer.reference;

    let result;
    try {
      result = await client.transferStatus(lookupId);
    } catch (err) {
      if (err instanceof BazikError && err.status === 404) {
        return { transfer, changed: false, notFound: true };
      }
      throw err;
    }

    if (result.status !== "completed" && result.status !== "failed") {
      return { transfer, changed: false };
    }

    const settled = await store.settleTransfer({
      transferId,
      status: result.status,
      gatewayId: result.gatewayId,
      gatewayStatus: result.status,
      failureReason: result.status === "failed" ? result.message : "",
    });

    return { transfer: settled.transfer, changed: !settled.duplicate, refund: settled.refund };
  }

  /** Pou yon tach pwograme: rekipere tout transfè ki rete kwoke. */
  async function pollPending(limit = 50) {
    const pending = await store.listPendingTransfers(limit);
    const results = [];

    for (const transfer of pending) {
      try {
        const result = await refresh(transfer.transferId);
        if (result.changed) results.push(result.transfer);
      } catch (err) {
        results.push({ transferId: transfer.transferId, error: err.message });
      }
    }

    return results;
  }

  return { quote, send, refresh, pollPending, prepareAmounts, gatewayBalance };
}

module.exports = { createTransferUseCases };
