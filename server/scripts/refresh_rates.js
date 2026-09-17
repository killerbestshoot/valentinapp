"use strict";

/**
 * To echanj yo, depi liy kòmand lan.
 *
 *   node scripts/refresh_rates.js                          # mete ajou SI sa dwe fèt (règ "1 pa jou")
 *   node scripts/refresh_rates.js --status                 # montre eta a, san rele API a
 *   node scripts/refresh_rates.js --force                  # rele API a kanmenm (konte nan kota a)
 *   node scripts/refresh_rates.js --force --accept-large-change
 *                                                          # aplike menm si gad 25% la refize,
 *                                                          # APRE ou fin verifye to yo alamen
 *
 * Ak Docker: docker compose exec api node scripts/refresh_rates.js --status
 */

require("dotenv").config({ path: require("node:path").join(__dirname, "..", ".env") });

const { getRatesRefresher } = require("../src/rates/rates_refresher");
const { getDb } = require("../src/db/db");

function fmt(ms) {
  return ms ? new Date(ms).toISOString().replace("T", " ").slice(0, 19) + " UTC" : "—";
}

async function main() {
  const args = new Set(process.argv.slice(2));
  const refresher = getRatesRefresher();

  if (!args.has("--status")) {
    const result = await refresher.refresh({
      force: args.has("--force"),
      acceptLargeChanges: args.has("--accept-large-change"),
    });
    console.log(`Rezilta: ${result.status}${result.reason ? ` (${result.reason})` : ""}${result.code ? ` [${result.code}]` : ""}`);
    if (result.status === "rejected") {
      for (const row of result.suspicious) {
        console.log(`  ${row.currency}: ${row.from.toFixed(4)} -> ${row.to.toFixed(4)} HTG (${(row.change * 100).toFixed(1)}%)`);
      }
    }
  }

  const status = refresher.status();
  console.log(`\nSous:            ${status.source}${status.stale ? "  ⚠️  PA AJOU" : ""}`);
  console.log(`Kle API:         ${status.keyConfigured ? "konfigire" : "MANKE (EXCHANGE_RATE_API_KEY)"}`);
  console.log(`Done yo date:    ${fmt(status.updatedAt)}`);
  console.log(`Dènye siksè:     ${fmt(status.lastSuccessAt)}`);
  console.log(`Pwochen done:    ${fmt(status.nextUpdateAt)}`);
  if (status.lastError) {
    console.log(`Dènye erè:       ${status.lastError.code} (${status.lastError.status}) ${fmt(status.lastError.at)}`);
  }

  const rows = getDb()
    .prepare("SELECT currency, rate_to_htg FROM exchange_rates WHERE currency IN ('USD','MXN','DOP','CLP','BRL','EUR','CAD') ORDER BY currency")
    .all();
  console.log("\nHTG pou 1 inite:");
  for (const row of rows) console.log(`  ${row.currency}  ${row.rate_to_htg.toFixed(4)}`);
}

main().catch((err) => {
  console.error("❌", err.code || "", err.message);
  process.exit(1);
});
