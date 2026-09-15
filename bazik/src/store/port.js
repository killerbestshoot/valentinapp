"use strict";

/**
 * KONTRA STOKAJ.
 *
 * Aplikasyon: `sqlite_store.js` (serveur a ak tès yo).
 *
 * Prensip: pòt la pa ekspoze "transaksyon" — li ekspoze operasyon konpoze ki
 * ATOMIK pou kont yo. Konsa nou pa ka gen yon store ki kredite yon wallet san
 * make topup la, oswa ki make topup la san kredite.
 *
 * @typedef {Object} MoneyMove
 * @property {string} uid
 * @property {string} enterpriseId
 * @property {number} amountMinor  santim, antye, toujou pozitif
 * @property {string} currency
 * @property {string} type         eg 'wallet_topup_moncash'
 * @property {string} note
 * @property {string} [idempotencyKey] de apèl ak menm kle = yon sèl mouvman
 *
 * @typedef {Object} BazikStore
 * @property {() => Promise<void>} close
 * @property {(currency: string) => Promise<number>} getRateToHtg
 * @property {(w: object) => Promise<object>} ensureWallet
 * @property {(k: {uid: string, enterpriseId: string}) => Promise<object|null>} getWallet
 * @property {(m: MoneyMove) => Promise<object>} creditWallet
 * @property {(m: MoneyMove) => Promise<object>} debitWallet
 * @property {(r: object) => Promise<object>} createTopup
 * @property {(id: string) => Promise<object|null>} getTopup
 * @property {(ref: string) => Promise<object|null>} findTopupByReference
 * @property {(id: string, patch: object) => Promise<object>} updateTopup
 * @property {(args: object) => Promise<object>} settleTopup  ATOMIK: kredite + make
 * @property {(r: object) => Promise<object>} createTransfer
 * @property {(r: object, m: MoneyMove) => Promise<object>} openTransfer ATOMIK: liy + debi
 * @property {(id: string) => Promise<object|null>} getTransfer
 * @property {(ref: string) => Promise<object|null>} findTransferByReference
 * @property {(id: string, patch: object) => Promise<object>} updateTransfer
 * @property {(args: object) => Promise<object>} settleTransfer ATOMIK: make + ranbouse si echk
 * @property {(limit?: number) => Promise<object[]>} listPendingTransfers
 * @property {(e: object) => Promise<boolean>} recordEvent  false = deja wè (rejwe)
 * @property {(id: string, result: object) => Promise<void>} markEventProcessed
 * @property {(id: string) => Promise<object|null>} getTransaction
 * @property {(id: string, patch: object) => Promise<object>} updateTransaction
 */

const REQUIRED_METHODS = [
  "close",
  "getRateToHtg",
  "ensureWallet",
  "getWallet",
  "creditWallet",
  "debitWallet",
  "createTopup",
  "getTopup",
  "findTopupByReference",
  "updateTopup",
  "settleTopup",
  "createTransfer",
  "openTransfer",
  "getTransfer",
  "findTransferByReference",
  "updateTransfer",
  "settleTransfer",
  "listPendingTransfers",
  "recordEvent",
  "markEventProcessed",
  "getTransaction",
  "updateTransaction",
];

/** Verifye yon store respekte kontra a (nou rele sa nan tès yo). */
function assertStore(store) {
  const missing = REQUIRED_METHODS.filter((name) => typeof store?.[name] !== "function");
  if (missing.length > 0) {
    throw new Error(`Store la pa konplè. Metòd ki manke: ${missing.join(", ")}`);
  }
  return store;
}

module.exports = { assertStore, REQUIRED_METHODS };
