"use strict";

/**
 * Ankesman (cash-in): chaje wallet yon ajan ak MonCash.
 *
 * ATANSYON — gade `docs/contract.md`:
 * kont sandbox la se yon kont tip `transfer`, e Bazik refize `/moncash/token`
 * pou tip sa a (403 endpoint_not_authorized). Kòd la konplè e teste kont
 * similatè a, men li p ap mache an reyèl toutotan yo pa louvri yon kont
 * `online` oswa `instore`.
 *
 * Nou kenbe l paske: (1) se sa plan an mande, (2) jou kont lan louvri, se
 * sèlman konfigirasyon ki chanje, pa kòd la.
 */

const AppIds = require("./ids");
const { DomainError, BazikError } = require("./errors");
const { convertToHtgMinor, assertNetworkAmount, fromMinor } = require("./money");

function createTopupUseCases({ store, client, config }) {
  /**
   * Kreye yon demand rechaj epi mande Bazik yon lyen peman.
   * Wallet la PA kredite isit la — se sèlman lè peman an konfime.
   */
  async function create({
    targetUid,
    targetEmail = "",
    targetName = "",
    targetRole = "agent",
    enterpriseId,
    enterpriseName = "",
    amountMinor,
    currency = config.walletCurrency,
    phone = "",
    note = "",
    network = "moncash",
    requestedBy = "",
    requestedByName = "",
    requestedByRole = "",
    idempotencySeed = "",
  }) {
    if (!targetUid || !enterpriseId) {
      throw new DomainError("missing_target", "targetUid ak enterpriseId obligatwa.");
    }

    const rateToHtg = await store.getRateToHtg(currency);
    const amountHtgMinor = convertToHtgMinor(amountMinor, rateToHtg);

    assertNetworkAmount(network, amountHtgMinor);

    const seed = idempotencySeed || `${enterpriseId}:${targetUid}:${amountMinor}:${Date.now()}`;
    const requestId = AppIds.topupRequest(seed);

    const existing = await store.getTopup(requestId);
    if (existing) return { topup: existing, duplicate: true };

    let topup = await store.createTopup({
      requestId,
      gatewayOrderId: requestId,
      status: "pending",
      network,
      amountMinor,
      currency,
      amountHtgMinor,
      rateToHtg,
      targetUid,
      targetEmail,
      targetName,
      targetRole,
      enterpriseId,
      enterpriseName,
      phone,
      requestedBy,
      requestedByName,
      requestedByRole,
      note,
    });

    try {
      const payment = await client.createPayment({
        orderId: requestId,
        amountHtgMinor,
        phone,
        description: note || `Rechaj wallet ${targetName || targetUid}`,
      });

      topup = await store.updateTopup(requestId, {
        gatewayId: payment.gatewayId,
        gatewayStatus: payment.status,
        paymentUrl: payment.paymentUrl,
        status: "awaiting_payment",
      });

      return { topup, duplicate: false, paymentUrl: payment.paymentUrl };
    } catch (err) {
      const reason = err instanceof BazikError ? `${err.code}: ${err.message}` : err.message;

      topup = await store.updateTopup(requestId, {
        status: "failed",
        processed: true,
        failureReason: reason,
      });

      if (err instanceof BazikError && err.code === "endpoint_not_authorized") {
        throw new DomainError(
          "cash_in_unavailable",
          "Kont Bazik la se yon kont `transfer`: li pa ka ankese. Fòk yo louvri yon kont `online` pou rechaj MonCash mache."
        );
      }

      throw new DomainError("topup_failed", `Rechaj la pa kreye: ${reason}`);
    }
  }

  /**
   * Mande Bazik si peman an fèt, epi kredite wallet la si wi.
   * `settleTopup` ann atomik: menm si nou rele sa 10 fwa, yon sèl kredi.
   */
  async function verify(requestId) {
    const topup = await store.getTopup(requestId);
    if (!topup) throw new DomainError("topup_not_found", `Rechaj ${requestId} pa egziste.`);

    if (topup.processed) return { topup, changed: false };

    const payment = await client.paymentStatus(topup.gatewayOrderId || requestId);

    if (payment.status !== "completed" && payment.status !== "failed") {
      return { topup, changed: false, gatewayStatus: payment.status };
    }

    const settled = await store.settleTopup({
      topupId: requestId,
      status: payment.status,
      gatewayId: payment.gatewayId,
      gatewayStatus: payment.status,
      failureReason: payment.status === "failed" ? "peman an echwe" : "",
    });

    return { topup: settled.topup, changed: !settled.duplicate, credit: settled.credit };
  }

  /** Estimasyon pou UI a. */
  async function preview({ amountMinor, currency = config.walletCurrency }) {
    const rateToHtg = await store.getRateToHtg(currency);
    const amountHtgMinor = convertToHtgMinor(amountMinor, rateToHtg);

    return {
      amountMinor,
      currency,
      amountHtg: fromMinor(amountHtgMinor),
      rateToHtg,
    };
  }

  return { create, verify, preview };
}

module.exports = { createTopupUseCases };
