"use strict";

/**
 * Voye yon transfè Bazik depi liy kòmand lan.
 *
 *   # Pre-vol sèlman (PA voye anyen) — se default la
 *   node bazik/scripts/send_transfer.js --phone 37123456 --gdes 500
 *
 *   # Voye pou vre
 *   node bazik/scripts/send_transfer.js --phone 37123456 --gdes 500 --send
 *
 *   # NatCash (non benefisyè a obligatwa, minimòm 3998 HTG)
 *   node bazik/scripts/send_transfer.js --network natcash --phone 37123456 \
 *        --gdes 4000 --name "Jean Bastien" --send
 *
 *   # Swiv yon transfè ki deja pati
 *   node bazik/scripts/send_transfer.js --status <transactionId>
 *
 * Pa default li rete an PRE-VOL: li verifye token an, float la, devi a ak
 * limit yo, epi li di ou egzakteman sa ki t ap pase. Anyen pa deplase san
 * `--send`.
 */

const { loadEnvFile, redact } = require("./_env");
loadEnvFile();

const { loadConfig } = require("../src/config");
const { createBazikClient } = require("../src/client");
const { createFakeBazikClient } = require("../src/fake_client");
const { BazikError } = require("../src/errors");
const AppIds = require("../src/ids");
const {
  toMinor,
  fromMinor,
  NETWORK_LIMITS,
  assertNetworkAmount,
} = require("../src/money");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;

    const key = token.slice(2);
    const next = argv[i + 1];

    if (next === undefined || next.startsWith("--")) {
      args[key] = true;
    } else {
      args[key] = next;
      i++;
    }
  }
  return args;
}

function line(label, value) {
  console.log(`  ${String(label).padEnd(26)} ${value}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const config = loadConfig();

  const client = config.isFake
    ? createFakeBazikClient({ availableMinor: 10000000 })
    : createBazikClient(config);

  console.log(`\nBazik — mòd: ${config.mode}  (${config.baseUrl})`);

  if (config.isFake) {
    console.log(
      "⚠️  MÒD SIMILASYON: pa gen kle nan bazik/.env, donk anyen p ap rive\n" +
        "   sou Bazik ni sou dashboard la."
    );
  }

  // --- Swiv yon transfè ki egziste ---
  if (args.status && args.status !== true) {
    console.log(`\nEstati transfè ${args.status}:\n`);
    try {
      const result = await client.transferStatus(args.status);
      line("estati", result.status);
      line("gatewayId", result.gatewayId || "—");
      if (result.message) line("mesaj", result.message);
      console.log(`\n${redact(JSON.stringify(result.raw, null, 2))}\n`);
    } catch (err) {
      console.error(`❌ ${err.code}: ${err.message}\n`);
      process.exit(1);
    }
    return;
  }

  const network = String(args.network || "moncash").toLowerCase();
  const phone = String(args.phone || "");
  const receiverName = args.name && args.name !== true ? String(args.name) : "";
  const gdes = Number(args.gdes || 0);

  if (!NETWORK_LIMITS[network]) {
    console.error(`\n❌ Rezo a pa rekonèt: ${network} (moncash | natcash)\n`);
    process.exit(1);
  }

  if (!phone || !gdes) {
    console.error(
      "\n❌ Sèvi ak: --phone <8 chif> --gdes <montan HTG> " +
        "[--network moncash|natcash] [--name \"Non Konplè\"] [--send]\n"
    );
    process.exit(1);
  }

  const amountHtgMinor = toMinor(gdes);
  const reference = String(args.reference || AppIds.transfer(`cli:${phone}:${gdes}:${Date.now()}`));

  // --- 1. Limit rezo a (lokal, san rezo) ---
  console.log("\n1) Limit rezo a");
  try {
    assertNetworkAmount(network, amountHtgMinor);
    line("montan", `${gdes} HTG`);
    line("limit", `${NETWORK_LIMITS[network].minHtg} – ${NETWORK_LIMITS[network].maxHtg} HTG`);
    console.log("   ✅ montan an nan limit yo");
  } catch (err) {
    console.error(`   ❌ ${err.code}: ${err.message}\n`);
    process.exit(1);
  }

  if (network === "natcash" && !receiverName.trim()) {
    console.error("\n   ❌ NatCash mande --name \"Non Siyati\" benefisyè a.\n");
    process.exit(1);
  }

  // --- 2. Float Bazik la ---
  console.log("\n2) Float Bazik la");
  let wallet;
  try {
    wallet = await client.wallet();
    line("disponib", `${fromMinor(wallet.availableMinor)} ${wallet.currency}`);
    line("anviwònman", wallet.environment || "—");
  } catch (err) {
    console.error(`   ❌ ${err.code}: ${err.message}\n`);
    process.exit(1);
  }

  // --- 3. Devi a (frè yo) ---
  console.log("\n3) Devi");
  let quote;
  try {
    quote = await client.quote({ amountHtgMinor, network });
    line("benefisyè resevwa", `${fromMinor(quote.deliveryMinor)} HTG`);
    line(`frè (${quote.feePercent}%)`, `${fromMinor(quote.feeMinor)} HTG`);
    line("total nan float la", `${fromMinor(quote.totalCostMinor)} HTG`);
  } catch (err) {
    console.error(`   ❌ ${err.code}: ${err.message}\n`);
    process.exit(1);
  }

  const enough = wallet.availableMinor >= quote.totalCostMinor;
  console.log(
    enough
      ? "   ✅ float la ase"
      : `   ❌ float la PA ase: ${fromMinor(quote.totalCostMinor)} HTG nesesè, ` +
          `${fromMinor(wallet.availableMinor)} HTG disponib`
  );

  // --- 4. Voye (sèlman ak --send) ---
  if (!args.send) {
    console.log("\n4) Voye");
    console.log("   ⏸  PRE-VOL sèlman. Ajoute --send pou voye pou vre.\n");
    line("rezo", network);
    line("benefisyè", `${phone}${receiverName ? ` (${receiverName})` : ""}`);
    line("referenceId", reference);
    console.log("");
    return;
  }

  if (!enough) {
    console.error("\n❌ Nou pa voye: float la pa ase.\n");
    process.exit(1);
  }

  console.log("\n4) Voye pou vre...");

  try {
    const result = await client.createTransfer(network, {
      reference,
      amountHtgMinor,
      phone,
      receiverName,
      description: String(args.note || "Tès CLI VOUPVAPCASH"),
    });

    console.log("   ✅ Bazik aksepte demand lan\n");
    line("estati", result.status);
    line("gatewayId", result.gatewayId || "—");
    line("referenceId", reference);
    if (result.message) line("mesaj", result.message);

    console.log(
      `\n   Swiv li:\n   node bazik/scripts/send_transfer.js --status ${result.gatewayId || reference}\n`
    );
  } catch (err) {
    const code = err instanceof BazikError ? err.code : "erreur";
    console.error(`   ❌ ${code}: ${err.message}`);

    if (err.body) {
      console.error(`\n${redact(JSON.stringify(err.body, null, 2))}`);
    }
    console.error("");
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("\n❌", err.message, "\n");
  process.exit(1);
});
