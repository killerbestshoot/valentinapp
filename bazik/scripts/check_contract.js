"use strict";

/**
 * Verifye ke vre API Bazik la toujou konpòte l jan `docs/contract.md` di.
 *
 * Se pa yon tès inite — li rele vre rezo a. Rele l lè:
 *  - ou fèk resevwa nouvo kle;
 *  - yon bagay sispèk ap pase an pwodiksyon;
 *  - anvan yon liberasyon enpòtan.
 *
 *   node bazik/scripts/check_contract.js
 *
 * Li PA deplase okenn lajan: li rele sèlman /token, /wallet ak /transfers/quote,
 * epi li verifye ke erè validasyon yo toujou bay menm limit yo.
 */

const { loadEnvFile } = require("./_env");
loadEnvFile();

const { loadConfig } = require("../src/config");
const { createBazikClient } = require("../src/client");
const { NETWORK_LIMITS, DEFAULT_FEE_PERCENT, toMinor, fromMinor } = require("../src/money");
const { BazikError } = require("../src/errors");

const checks = [];

function record(name, ok, detail = "") {
  checks.push({ name, ok, detail });
  console.log(`${ok ? "✅" : "❌"} ${name}${detail ? ` — ${detail}` : ""}`);
}

async function main() {
  const config = loadConfig();

  if (config.isFake) {
    console.log("⚠️  Pa gen kle Bazik (BAZIK_MODE=fake). Anyen pou verifye.");
    return;
  }

  console.log(`Mòd: ${config.mode} | ${config.baseUrl}\n`);

  const client = createBazikClient(config);

  // 1. Otantifikasyon
  const wallet = await client.wallet();
  record("token + /wallet", wallet.currency === "HTG", `sòld ${fromMinor(wallet.availableMinor)} HTG`);

  if (wallet.availableMinor === 0) {
    console.log("   ℹ️  Wallet Bazik la vid: okenn transfè p ap ka pati.");
  }

  // 2. Frè yo
  const quote = await client.quote({ amountHtgMinor: toMinor(500), network: "moncash" });
  record(
    `frè ${DEFAULT_FEE_PERCENT}%`,
    quote.feePercent === DEFAULT_FEE_PERCENT,
    `API bay ${quote.feePercent}%`
  );
  record(
    "total = montan + frè",
    quote.totalCostMinor === quote.deliveryMinor + quote.feeMinor,
    `${fromMinor(quote.totalCostMinor)} HTG`
  );

  // 3. Limit yo — nou pwovoke erè validasyon an espre (anyen pa deplase).
  for (const [network, limits] of Object.entries(NETWORK_LIMITS)) {
    try {
      await client.createTransfer(network, {
        reference: `CHECK_${Date.now()}_${network}`,
        amountHtgMinor: toMinor(1),
        phone: "37123456",
        receiverName: "Check Check",
        description: "contract check",
      });
      record(`minimòm ${network}`, false, "API a pa refize 1 HTG!");
    } catch (err) {
      const expected = err instanceof BazikError && err.code === "amount_too_low";
      const reported = Number(err.body?.minimum_amount || 0);
      record(
        `minimòm ${network} = ${limits.minHtg} HTG`,
        expected && reported === limits.minHtg,
        expected ? `API bay ${reported}` : `kòd: ${err.code}`
      );
    }
  }

  // 4. Ankesman (nou tann yon refi sou yon kont `transfer`)
  try {
    await client.createPayment({ orderId: `CHECK_${Date.now()}`, amountHtgMinor: toMinor(100) });
    record("ankesman disponib", true, "kont lan ka ankese — cash-in ka aktive!");
  } catch (err) {
    record(
      "ankesman bloke (kont `transfer`)",
      err.code === "endpoint_not_authorized",
      err.code
    );
  }

  const failed = checks.filter((check) => !check.ok);
  console.log(`\n${checks.length - failed.length}/${checks.length} verifikasyon pase.`);

  if (failed.length > 0) {
    console.log("\n⚠️  Kontra a chanje. Mete `docs/contract.md` ak `src/mapper.js` ajou.");
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("CHECK FAIL:", err.code || "", err.message);
  process.exit(1);
});
