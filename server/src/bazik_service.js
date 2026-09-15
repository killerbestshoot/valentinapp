"use strict";

/**
 * Sèvis Bazik pou serveur dev la (SQLite).
 *
 * Kle yo soti nan `server/.env`, ke `dotenv` chaje nan `index.js`. Se yon sèl
 * kote: anvan, nou t ap li yon dezyèm fichye `bazik/.env`, e de sous ta ka pa
 * dakò.
 *
 * Si pa gen kle Bazik, `loadConfig` tonbe sou mòd `fake` pou kont li: serveur
 * a demare san rezo.
 */

const path = require("node:path");

const { createSqliteService } = require("../../bazik/index.js");

let service = null;

function getBazikService() {
  if (service) return service;

  // MENM fichye ak baz aplikasyon an (`db.js`). Si nou te kite `bazik.db` apa,
  // `wallets` ak `wallet_ledger` t ap egziste an de kopi ki pa dakò: app la
  // t ap montre yon sòld, Bazik t ap debite yon lòt.
  const file =
    process.env.APP_DB_PATH ||
    process.env.BAZIK_DB_PATH ||
    path.join(__dirname, "..", "data", "app.db");

  service = createSqliteService({ file });

  console.log(`[bazik] mòd=${service.config.mode} db=${file}`);

  // Yon mòd similasyon ki pase an silans se pi move bagay la: ou teste tout
  // yon jounen epi ou kwè lajan ap deplase.
  if (service.config.isFake) {
    console.warn(
      "[bazik] ⚠️  MÒD SIMILASYON: okenn apèl p ap rive sou Bazik, " +
        "e anyen p ap parèt sou dashboard la. Mete BAZIK_USER_ID/BAZIK_SECRET_KEY " +
        "nan server/.env pou ou pase an sandbox."
    );
  } else {
    // Yon float vid bay menm sentòm nan: okenn tranzaksyon sou dashboard la.
    service
      .gatewayWallet()
      .then((wallet) => {
        if (wallet.availableMinor <= 0) {
          console.warn(
            "[bazik] ⚠️  Wallet Bazik la vid (0 HTG). Tout transfè ap refize ak " +
              "`insufficient_balance`, e Bazik p ap kreye okenn tranzaksyon."
          );
        } else {
          console.log(`[bazik] float disponib: ${wallet.availableMinor / 100} ${wallet.currency}`);
        }
      })
      .catch((err) => console.warn("[bazik] pa ka li sòld pasrèl la:", err.code || err.message));
  }

  return service;
}

module.exports = { getBazikService };
