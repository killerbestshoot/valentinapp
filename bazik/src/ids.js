"use strict";

/**
 * Pòt JS egzak de `lib/services/shared/app_ids.dart`.
 *
 * Menm namespace + menm algorithm => menm seed bay menm ID nan Dart ak nan Node.
 * Sa se sa ki pèmèt nou sèvi ak ID yo kòm kle idempotans sou Bazik.
 */

const { createHash, randomBytes } = require("node:crypto");

const NAMESPACE = "6f5dd6b4-5ed6-5d16-8d58-voupvapcash";

const UUID5_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PREFIXED_UUID5_PATTERN =
  /^[A-Z]{2,5}_[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function uuid5(name) {
  const hash = createHash("sha1")
    .update(Buffer.concat([Buffer.from(NAMESPACE, "utf8"), Buffer.from(name, "utf8")]))
    .digest();

  const bytes = Buffer.from(hash.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  const hex = bytes.toString("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join("-");
}

function uniqueSeed() {
  return `${Date.now() * 1000}:${randomBytes(8).toString("hex")}`;
}

function generate(prefix, seed) {
  const normalizedPrefix = String(prefix || "").trim().toUpperCase();
  if (!normalizedPrefix) throw new Error("Prefix is required.");

  const trimmed = typeof seed === "string" ? seed.trim() : "";
  const name = trimmed.length > 0 ? trimmed : uniqueSeed();
  return `${normalizedPrefix}_${uuid5(`${normalizedPrefix}:${name}`)}`;
}

const AppIds = {
  uuid5,
  generate,
  transaction: (seed) => generate("TX", seed),
  agent: (seed) => generate("AG", seed),
  admin: (seed) => generate("AD", seed),
  owner: (seed) => generate("OW", seed),
  client: (seed) => generate("CL", seed),
  enterprise: (seed) => generate("ENT", seed),
  enterpriseUser: (seed) => generate("EU", seed),
  service: (seed) => generate("SVC", seed),

  /** Menm switch ak `AppIds.userForRole` nan Dart la. */
  userForRole: (role, seed) => {
    switch (String(role || "").trim().toLowerCase()) {
      case "agent":
        return generate("AG", seed);
      case "admin":
      case "administrator":
        return generate("AD", seed);
      case "owner":
        return generate("OW", seed);
      default:
        return generate("CL", seed);
    }
  },
  topupRequest: (seed) => generate("TU", seed),
  payoutRequest: (seed) => generate("PO", seed),
  withdrawRequest: (seed) => generate("WD", seed),
  transfer: (seed) => generate("TRF", seed),
  /** Rechaj minit (Reloadly). Se ID sa a ki voye kòm `customIdentifier`. */
  airtime: (seed) => generate("AIR", seed),
  ledger: (seed) => generate("LG", seed),
  history: (seed) => generate("HIS", seed),
  walletLog: (seed) => generate("WL", seed),
  notification: (seed) => generate("NTF", seed),
  isUuid5: (value) => UUID5_PATTERN.test(String(value).trim()),
  isPrefixedUuid5: (value) => PREFIXED_UUID5_PATTERN.test(String(value).trim()),
};

module.exports = AppIds;
