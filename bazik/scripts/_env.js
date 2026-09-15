"use strict";

/**
 * Ti chajè .env san depandans.
 *
 * Sous inik la se `server/.env` — menm fichye ak serveur a. De fichye .env ta
 * vle di de verite sou menm kle yo.
 */
const fs = require("node:fs");
const path = require("node:path");

function loadEnvFile(file = path.join(__dirname, "..", "..", "server", ".env")) {
  if (!fs.existsSync(file)) return process.env;

  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const index = trimmed.indexOf("=");
    if (index === -1) continue;

    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim();
    if (!(key in process.env)) process.env[key] = value;
  }

  return process.env;
}

/** Kache sekrè yo anvan nou ekri/afiche yon bagay. */
function redact(value) {
  const text = typeof value === "string" ? value : JSON.stringify(value, null, 2);
  return text
    .replace(/sk_[A-Za-z0-9_]+/g, "sk_***REDACTED***")
    .replace(/(bzk_token_|eyJ)[A-Za-z0-9._-]{10,}/g, "$1***REDACTED***");
}

module.exports = { loadEnvFile, redact };
