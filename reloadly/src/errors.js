"use strict";

/**
 * `DomainError` se MENM klas ak Bazik la: wout serveur yo teste
 * `instanceof DomainError` pou deside kòd HTTP a. De klas ak menm non ta bay
 * 500 sou yon erè ajan an ka korije.
 */
const { DomainError } = require("../../bazik/src/errors");

/** Erè ki soti nan Reloadly oswa nan rezo a. */
class ReloadlyError extends Error {
  constructor(code, message, { status = 0, body = null, retryable = false } = {}) {
    super(message);
    this.name = "ReloadlyError";
    this.code = code;
    this.status = status;
    this.body = body;
    this.retryable = retryable;
  }
}

/** Yon `DomainError` ki pote plis kontèks (eg. rechaj la) pou repons HTTP a. */
function domainError(code, message, extra = {}) {
  return Object.assign(new DomainError(code, message), extra);
}

module.exports = { ReloadlyError, DomainError, domainError };
