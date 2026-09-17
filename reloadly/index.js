"use strict";

/**
 * Pwen antre pakè `reloadly` la (Minit Haiti).
 *
 *   const { getBazikService } = require("../server/src/bazik_service");
 *   const airtime = createAirtimeService({ ledgerStore: getBazikService().store });
 *   await airtime.topups.send({ ... });
 *
 * `ledgerStore` OBLIGATWA: rechaj yo debite MENM wallet ak transfè Bazik yo.
 */

const { loadReloadlyConfig } = require("./src/config");
const { createReloadlyClient } = require("./src/client");
const { createFakeReloadlyClient } = require("./src/fake_client");
const { createAirtimeStore } = require("./src/store/sqlite_store");
const { createAirtimeUseCases } = require("./src/airtime");
const { createAccountInsights, PERMISSIONS } = require("./src/insights");
const { ReloadlyError, DomainError } = require("./src/errors");
const { createRateBook } = require("../bazik/src/rates");
const mapper = require("./src/mapper");

/**
 * @param {object} [options.rates] liv to echanj Bazik la (`bazikService.rates`):
 *   MENM politik fraîcheur pou transfè ak rechaj.
 */
function createAirtimeService({ ledgerStore, client, config, env, rates } = {}) {
  if (!ledgerStore || !ledgerStore._ledger) {
    throw new Error("createAirtimeService mande store Bazik la (`ledgerStore`).");
  }

  const resolvedConfig = config || loadReloadlyConfig(env);
  const resolvedClient =
    client || (resolvedConfig.isFake ? createFakeReloadlyClient() : createReloadlyClient(resolvedConfig));

  const store = createAirtimeStore({ ledger: ledgerStore._ledger });
  const resolvedRates = rates || createRateBook({ store: ledgerStore });
  const topups = createAirtimeUseCases({
    store,
    wallets: ledgerStore,
    client: resolvedClient,
    config: resolvedConfig,
    rates: resolvedRates,
  });

  const insights = createAccountInsights({ client: resolvedClient, config: resolvedConfig });

  return { config: resolvedConfig, client: resolvedClient, store, topups, insights, rates: resolvedRates };
}

module.exports = {
  createAirtimeService,
  createReloadlyClient,
  createFakeReloadlyClient,
  loadReloadlyConfig,
  ReloadlyError,
  DomainError,
  mapper,
  PERMISSIONS,
};
