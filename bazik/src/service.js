"use strict";

/**
 * Fasad la: li kole yon store, yon kliyan ak yon konfigirasyon ansanm.
 *
 * Tout rès aplikasyon an (serveur Express, Cloud Functions, tès) pase isit
 * sèlman — yo pa janm rele `client.js` ni `store/*` dirèkteman.
 */

const { loadConfig } = require("./config");
const { createBazikClient } = require("./client");
const { createFakeBazikClient } = require("./fake_client");
const { createTransferUseCases } = require("./transfer");
const { createTopupUseCases } = require("./topup");
const { createWebhookHandler } = require("./webhook");
const { assertStore } = require("./store/port");
const { createRateBook } = require("./rates");

/**
 * @param {object} options
 * @param {object} options.store yon store ki respekte `store/port.js`
 * @param {object} [options.client] si nou pa bay youn, nou chwazi selon mòd la
 * @param {object} [options.config]
 */
/**
 * @param {object} [options.ratesPolicy] `{ requireFresh, maxAgeMs }` — serveur a
 *   mande to fre an pwodiksyon (gade `rates.js`).
 */
function createBazikService({ store, client, config, env, ratesPolicy = {} } = {}) {
  assertStore(store);
  const rates = createRateBook({ store, ...ratesPolicy });

  const resolvedConfig = config || loadConfig(env);
  const resolvedClient =
    client || (resolvedConfig.isFake ? createFakeBazikClient() : createBazikClient(resolvedConfig));

  const transfers = createTransferUseCases({ store, client: resolvedClient, config: resolvedConfig, rates });
  const topups = createTopupUseCases({ store, client: resolvedClient, config: resolvedConfig, rates });
  const webhooks = createWebhookHandler({
    store,
    client: resolvedClient,
    config: resolvedConfig,
    transfers,
    topups,
  });

  return {
    config: resolvedConfig,
    store,
    /** Liv to echanj la: rechaj minit yo (Reloadly) sèvi ak MENM nan. */
    rates,
    client: resolvedClient,
    transfers,
    topups,
    webhooks,

    /** Sld Bazik la — se li ki finanse transfè yo. */
    async gatewayWallet() {
      return resolvedClient.wallet();
    },

    async close() {
      await store.close();
    },
  };
}

module.exports = { createBazikService };
