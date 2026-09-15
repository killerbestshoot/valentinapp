"use strict";

/**
 * Pwen antre pakè `bazik` la.
 *
 *   const { createSqliteService } = require("../bazik");
 *   const service = createSqliteService({ file: "server/data/bazik.db" });
 *   await service.transfers.send({ ... });
 */

const { createBazikService } = require("./src/service");
const { createSqliteStore } = require("./src/store/sqlite_store");
const { createFakeBazikClient } = require("./src/fake_client");
const { createBazikClient } = require("./src/client");
const { loadConfig } = require("./src/config");
const AppIds = require("./src/ids");
const money = require("./src/money");
const { BazikError, DomainError } = require("./src/errors");

/** Sèvis ki chita sou SQLite — devlopman ak tès. */
function createSqliteService({ file = ":memory:", client, config, env } = {}) {
  return createBazikService({
    store: createSqliteStore({ file }),
    client,
    config,
    env,
  });
}

module.exports = {
  createBazikService,
  createSqliteService,
  createSqliteStore,
  createBazikClient,
  createFakeBazikClient,
  loadConfig,
  AppIds,
  money,
  BazikError,
  DomainError,
};
