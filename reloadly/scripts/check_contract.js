"use strict";

/**
 * Verifye ke vre API Reloadly a konpòte l jan `docs/contract.md` di.
 *
 * Se pa yon tès inite — li rele vre rezo a. Rele l:
 *  - lè ou fèk resevwa kle sandbox oswa live yo;
 *  - anvan ou aktive Minit Haiti an pwodiksyon;
 *  - si yon rechaj sispèk parèt.
 *
 *   node reloadly/scripts/check_contract.js
 *   node reloadly/scripts/check_contract.js 3xxxxxxx 4xxxxxxx   # nimewo pou auto-detect
 *
 * Li PA deplase okenn lajan: jeton, sòld, detekte operatè. Li pa janm rele
 * `POST /topups`.
 */

const { loadEnvFile } = require("../../bazik/scripts/_env");
loadEnvFile();

const { loadReloadlyConfig } = require("../src/config");
const { createReloadlyClient } = require("../src/client");
const { fromMinor } = require("../src/mapper");

const checks = [];

function record(name, ok, detail = "") {
  checks.push({ name, ok });
  console.log(`${ok ? "✅" : "❌"} ${name}${detail ? ` — ${detail}` : ""}`);
}

async function main() {
  const config = loadReloadlyConfig();

  if (config.isFake) {
    console.log("⚠️  Pa gen kle Reloadly (RELOADLY_MODE=fake). Anyen pou verifye.");
    return;
  }

  console.log(`Mòd: ${config.mode} | ${config.baseUrl}\n`);
  const client = createReloadlyClient(config);

  try {
    await client.prepare();
    record("jeton OAuth2 (`access_token` + `expires_in`)", true);
  } catch (err) {
    record("jeton OAuth2", false, `${err.code}: ${err.message}`);
    return;
  }

  try {
    const balance = await client.balance();
    record(
      "GET /accounts/balance",
      Boolean(balance.currency),
      `${fromMinor(balance.balanceMinor)} ${balance.currency}` +
        (balance.balanceMinor <= 0 ? " — ⚠️ kont lan vid: tout rechaj ap refize" : "")
    );
  } catch (err) {
    record("GET /accounts/balance", false, `${err.code}: ${err.message}`);
  }

  // Nimewo egzanp: prefiks Digicel (37) ak Natcom (33) — pa bezwen reyèl pou auto-detect.
  const phones = process.argv.slice(2);
  for (const phone of phones.length ? phones : ["37000001", "33000001"]) {
    try {
      const op = await client.detectOperator(phone);
      const range =
        op.denominationType === "FIXED"
          ? `FIXED [${op.fixedMinor.map(fromMinor).join(", ")}] ${op.senderCurrency}`
          : `RANGE ${fromMinor(op.minMinor)}–${fromMinor(op.maxMinor)} ${op.senderCurrency}`;

      record(
        `auto-detect ${phone}`,
        op.operatorId > 0 && op.countryCode === "HT" && !op.isPin && !op.isData && !op.isBundle,
        `#${op.operatorId} ${op.name} | ${range} | to ${op.fxRate} ${op.destinationCurrency}` +
          ` | lokal: ${op.supportsLocalAmounts ? `oui (${fromMinor(op.localMinMinor)}–${fromMinor(op.localMaxMinor)})` : "non"}` +
          ` | pin/data/bundle: ${op.isPin}/${op.isData}/${op.isBundle}`
      );
    } catch (err) {
      record(`auto-detect ${phone}`, false, `${err.code}: ${err.message}`);
    }
  }

  const failed = checks.filter((c) => !c.ok).length;
  console.log(`\n${checks.length - failed}/${checks.length} verifikasyon pase.`);
  if (failed > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error("❌", err.code || "", err.message);
  process.exit(1);
});
