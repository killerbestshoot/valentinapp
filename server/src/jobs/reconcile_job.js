"use strict";

/**
 * Rekonsilyasyon otomatik — chak 5 minit pa defo (`RECONCILE_INTERVAL_MS`).
 *
 * Yon webhook ka pèdi. San pasaj sa a, yon transfè Bazik oswa yon rechaj minit
 * ki pa t resevwa konfimasyon li rete "an kou" pou tout tan, wallet ajan an
 * debite. Chak pasaj:
 *   1. mande Bazik/PSL estati transfè ki an kou yo (`pollPending`)
 *   2. menm bagay pou rechaj Reloadly yo
 *   3. aplike komisyon tranzaksyon ki fèk livre yo
 *
 * Transfè san ID Bazik ke Bazik pa jwenn yo make "verifikasyon manyèl": yo
 * pa re-eseye, yon owner rezoud yo (`POST /api/bazik/transfers/:id/resolve`).
 */

const { getBazikService } = require("../bazik_service");
const { getAirtimeService } = require("../airtime_service");
const { applyPendingCommissions } = require("../commission/engine");
const { publish } = require("../realtime/bus");

const DEFAULT_INTERVAL_MS = 5 * 60000;

function createReconcileJob({
  intervalMs = Number(process.env.RECONCILE_INTERVAL_MS ?? DEFAULT_INTERVAL_MS),
  bazik = () => getBazikService(),
  airtime = () => getAirtimeService(),
  commissions = applyPendingCommissions,
  log = console,
} = {}) {
  let timer = null;
  let running = false;

  /** Yon pasaj. Pa janm de an menm tan; yon etap ki echwe pa bloke lòt yo. */
  async function runOnce() {
    if (running) return { skipped: true };
    running = true;
    const result = { transfers: 0, topups: 0, commissions: 0, errors: [] };
    try {
      try {
        const updated = await bazik().transfers.pollPending(50);
        result.transfers = updated.filter((u) => !u.error).length;
      } catch (err) {
        result.errors.push(`bazik: ${err.message}`);
      }
      try {
        const service = airtime();
        if (service && !service.disabled && service.topups?.pollPending) {
          const updated = await service.topups.pollPending();
          result.topups = Array.isArray(updated) ? updated.length : 0;
        }
      } catch (err) {
        // Reloadly pa konfigire = pa gen rechaj pou rekonsilye.
        if (err.code !== "airtime_disabled") result.errors.push(`reloadly: ${err.message}`);
      }
      try {
        const applied = await commissions({ limit: 100 });
        result.commissions = applied.filter((r) => r.status === "applied").length;
      } catch (err) {
        result.errors.push(`commission: ${err.message}`);
      }
      if (result.transfers || result.topups || result.commissions) {
        // Yon webhook pèdi rekonsilye: ekran ki ouvè yo dwe wè l touswit.
        publish("*", ["transfers", "transactions", "wallets", "commissions"], { source: "reconcile" });
      }
      if (result.transfers || result.topups || result.commissions || result.errors.length) {
        log.log(`[reconcile] transfè ${result.transfers}, rechaj ${result.topups}, komisyon ${result.commissions}` +
          (result.errors.length ? ` — erè: ${result.errors.join("; ")}` : ""));
      }
      return result;
    } finally {
      running = false;
    }
  }

  function start() {
    if (timer || !(intervalMs > 0)) return false;
    timer = setInterval(() => runOnce().catch((err) => log.error("[reconcile]", err)), intervalMs);
    timer.unref?.();
    return true;
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  return { runOnce, start, stop, intervalMs };
}

let shared = null;
function getReconcileJob() {
  if (!shared) shared = createReconcileJob();
  return shared;
}

module.exports = { createReconcileJob, getReconcileJob, DEFAULT_INTERVAL_MS };
