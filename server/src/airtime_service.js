"use strict";

/**
 * Sèvis Minit Haiti (Reloadly Airtime) pou serveur a.
 *
 * Li chita sou store Bazik la: MENM fichye SQLite, MENM `wallets`, MENM
 * `wallet_ledger`. Yon rechaj ak yon transfè MonCash debite yon sèl sòld.
 *
 * AN PWODIKSYON, SAN KLE RELOADLY, SÈVIS LA DEZAKTIVE — li pa tonbe an
 * similasyon. Similatè a "livre" minit ki pa janm rive: ajan an ta debite,
 * kliyan an pa ta resevwa anyen. `ALLOW_FAKE_GATEWAY=true` (demo) se sèl
 * eksepsyon, menm jan ak Bazik.
 *
 * Li pa bloke demaraj la non plis: Minit Haiti se yon sèvis anplis, pa yon
 * rezon pou MonCash ak NatCash sispann mache.
 */

const { createAirtimeService, loadReloadlyConfig } = require("../../reloadly/index.js");
const { getBazikService } = require("./bazik_service");

let service = null;

function isDisabled(config, env = process.env) {
  return (
    String(env.NODE_ENV || "").trim() === "production" &&
    config.isFake &&
    String(env.ALLOW_FAKE_GATEWAY || "").trim() !== "true"
  );
}

function getAirtimeService() {
  if (service) return service;

  const config = loadReloadlyConfig(process.env);
  const bazik = getBazikService();
  // MENM liv to ak transfè yo: menm to, menm politik fraîcheur.
  const created = createAirtimeService({ ledgerStore: bazik.store, config, rates: bazik.rates });
  service = { ...created, disabled: isDisabled(config) };

  if (service.disabled) {
    console.warn(
      "[reloadly] ⚠️  Minit Haiti DEZAKTIVE: pa gen RELOADLY_CLIENT_ID/RELOADLY_CLIENT_SECRET. " +
        "Wout /api/airtime yo reponn 503."
    );
  } else if (config.isFake) {
    console.warn(
      "[reloadly] ⚠️  MÒD SIMILASYON: okenn minit p ap pati. Mete kle Reloadly yo " +
        "nan server/.env pou ou pase an sandbox."
    );
  } else {
    console.log(`[reloadly] mòd=${config.mode}`);
    service.topups
      .accountBalance()
      .then((account) => {
        if (account.balanceMinor <= 0) {
          console.warn("[reloadly] ⚠️  Kont Reloadly la vid: tout rechaj ap refize.");
        } else {
          console.log(`[reloadly] kont: ${account.balanceMinor / 100} ${account.currency}`);
        }
      })
      .catch((err) => console.warn("[reloadly] pa ka li sòld kont lan:", err.code || err.message));
  }

  return service;
}

/** Pou tès yo. */
function resetAirtimeService() {
  service = null;
}

module.exports = { getAirtimeService, resetAirtimeService, isDisabled };
