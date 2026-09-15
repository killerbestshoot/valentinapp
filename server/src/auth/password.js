"use strict";

/**
 * Achaj modpas.
 *
 * `scrypt` (nan `node:crypto`) espre: li fèt pou li LAN ak pou li mande
 * memwa, konsa yon moun ki vòlè baz la pa ka teste dè milyon modpas alaminit.
 * Yon SHA-256 senp t ap kase nan kèk minit sou yon GPU.
 *
 * Nou stoke `salt` ak `hash` apa. Chak itilizatè gen pwòp salt li: de moun ki
 * gen menm modpas pa gen menm hash, donk yon atakè pa ka reyitilize travay li.
 */

const { randomBytes, scrypt, timingSafeEqual } = require("node:crypto");
const { promisify } = require("node:util");

const scryptAsync = promisify(scrypt);

/** Paramèt yo. `N=16384` se yon konpwomi rezonab pou yon sèvè modès. */
const KEY_LENGTH = 64;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

const MIN_LENGTH = 8;

/** Règ minimòm. Nou pa bloke sou konpleksite: longè a konte plis. */
function validatePassword(password) {
  const value = String(password ?? "");

  if (value.length < MIN_LENGTH) {
    return { ok: false, reason: `Modpas la dwe gen omwen ${MIN_LENGTH} karaktè.` };
  }

  if (value.length > 200) {
    return { ok: false, reason: "Modpas la twò long." };
  }

  // Modpas ki pi evidan yo: yo se premye sa yon atakè eseye.
  const common = ["password", "12345678", "motdepase", "voupvapcash", "qwertyui"];
  if (common.includes(value.toLowerCase())) {
    return { ok: false, reason: "Modpas sa a twò fasil pou devine." };
  }

  return { ok: true };
}

async function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const derived = await scryptAsync(password, salt, KEY_LENGTH, SCRYPT_OPTIONS);

  return { hash: derived.toString("hex"), salt };
}

/**
 * Konparezon an fèt an tan konstan: si nou te sèvi ak `===`, tan repons lan
 * t ap varye selon konbyen karaktè ki kòrèk, e sa bay enfòmasyon.
 */
async function verifyPassword(password, { hash, salt }) {
  if (!hash || !salt) return false;

  let derived;
  try {
    derived = await scryptAsync(password, salt, KEY_LENGTH, SCRYPT_OPTIONS);
  } catch {
    return false;
  }

  const stored = Buffer.from(hash, "hex");
  if (stored.length !== derived.length) return false;

  return timingSafeEqual(stored, derived);
}

module.exports = { hashPassword, verifyPassword, validatePassword, MIN_LENGTH };
