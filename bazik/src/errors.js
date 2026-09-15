"use strict";

/** Erè ki soti nan Bazik oswa nan rezo a. */
class BazikError extends Error {
  constructor(code, message, { status = 0, body = null, retryable = false } = {}) {
    super(message);
    this.name = "BazikError";
    this.code = code;
    this.status = status;
    this.body = body;
    this.retryable = retryable;
  }
}

/** Erè règ biznis nou (montan, wòl, otorizasyon...). Pa gen rapò ak rezo. */
class DomainError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "DomainError";
    this.code = code;
  }
}

module.exports = { BazikError, DomainError };
