"use strict";

/**
 * TO ECHANJ YO: YON APÈL PA JOU, ESTOKE, EPI ITILIZE TOUT JOUNEN AN.
 *
 * Tout konvèsyon (transfè Bazik, minit Reloadly, komisyon, rechaj wallet) li
 * `exchange_rates` nan baz la atravè `bazik/src/rates.js`. Modil sa a se sèl
 * kote ki EKRI to yo, depi exchangerate-api.com.
 *
 * KILÈ NOU RELE API A
 *   - Sèlman lè done yo ka te chanje: `now >= next_update_at` (API a bay dat
 *     sa a — chak jou a 00:00 UTC), oswa si nou poko janm reyisi.
 *   - Maksimòm YON apèl ki reyisi pa jou UTC. Yon redemaraj serveur pa rele
 *     API a ankò: eta a nan baz la (`exchange_rate_fetches`), pa nan memwa.
 *   - Erè pèmanan (move kle, kota fini): pa re-eseye jodi a.
 *   - Erè tanporè (rezo, 5xx): re-eseye apre 30 min, maksimòm 6 fwa pa jou.
 *
 * GAD SEKIRITE: si yon to ki te DEJA soti nan API a chanje plis pase 25% an
 * yon sèl mizajou, nou refize TOUT mizajou a e nou kenbe ansyen to yo. Yon
 * done kowonpi (HTG = 1,3 olye 130) ta fè chak transfè voye 100 fwa twòp.
 */

const { getDb, transaction, now: dbNow } = require("../db/db");
const { fetchLatestUsdRates } = require("./exchange_rate_api");

const API_SOURCE = "exchangerate-api";
const MAX_CHANGE = 0.25;
const RETRY_AFTER_MS = 30 * 60 * 1000;
const MAX_FAILED_ATTEMPTS_PER_DAY = 6;
const CHECK_EVERY_MS = 60 * 60 * 1000;
const STALE_AFTER_MS = 36 * 3600 * 1000;

function startOfUtcDay(ms) {
  const date = new Date(ms);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function createRatesRefresher({
  apiKey = "",
  fetchLatest = fetchLatestUsdRates,
  now = dbNow,
  log = console,
} = {}) {
  const db = () => getDb();

  function lastSuccess() {
    return db()
      .prepare("SELECT * FROM exchange_rate_fetches WHERE status = 'success' ORDER BY attempted_at DESC, id DESC LIMIT 1")
      .get();
  }

  function failuresToday() {
    return db()
      .prepare(
        `SELECT * FROM exchange_rate_fetches
          WHERE status != 'success' AND attempted_at >= ? ORDER BY attempted_at DESC, id DESC`
      )
      .all(startOfUtcDay(now()));
  }

  /** Poukisa nou ta rele API a kounye a — oswa `null` si nou pa dwe. */
  function dueReason() {
    if (!apiKey) return null;

    const t = now();
    const success = lastSuccess();

    if (success && success.attempted_at >= startOfUtcDay(t)) return null;
    if (success && success.next_update_at && t < success.next_update_at) return null;

    const failures = failuresToday();
    if (failures.some((attempt) => attempt.permanent === 1)) return null;
    if (failures.length >= MAX_FAILED_ATTEMPTS_PER_DAY) return null;
    if (failures[0] && t - failures[0].attempted_at < RETRY_AFTER_MS) return null;

    return success ? "next_update" : "never_fetched";
  }

  function record(attempt) {
    db()
      .prepare(
        `INSERT INTO exchange_rate_fetches
          (attempted_at, status, provider_updated_at, next_update_at, currencies,
           error_code, error_message, permanent)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        now(),
        attempt.status,
        attempt.providerUpdatedAt ?? null,
        attempt.nextUpdateAt ?? null,
        attempt.currencies || 0,
        attempt.errorCode || "",
        attempt.errorMessage || "",
        attempt.permanent ? 1 : 0
      );
  }

  /**
   * @param {object} [options]
   * @param {boolean} [options.force] ignore règ "yon fwa pa jou" a (CLI sèlman)
   * @param {boolean} [options.acceptLargeChanges] aplike menm si gad 25% la
   *   deklanche — apre yon moun fin verifye to yo alamen
   */
  async function refresh({ force = false, acceptLargeChanges = false } = {}) {
    if (!apiKey) return { status: "skipped", reason: "missing_key" };

    const reason = force ? "forced" : dueReason();
    if (!reason) return { status: "skipped", reason: "not_due" };

    let latest;
    try {
      latest = await fetchLatest({ apiKey });
    } catch (err) {
      const errorCode = err.code || "error";
      record({ status: "error", errorCode, errorMessage: err.message, permanent: err.permanent });
      log.warn(`[rates] ⚠️  mizajou to yo echwe (${errorCode})${err.permanent ? " — pa gen lòt esè jodi a" : ""}`);
      return { status: "error", code: errorCode, permanent: Boolean(err.permanent) };
    }

    const previous = db()
      .prepare("SELECT currency, rate_to_htg FROM exchange_rates WHERE source = ?")
      .all(API_SOURCE);

    const suspicious = previous
      .filter((row) => latest.rateToHtg[row.currency] > 0 && row.rate_to_htg > 0)
      .map((row) => ({
        currency: row.currency,
        from: row.rate_to_htg,
        to: latest.rateToHtg[row.currency],
        change: latest.rateToHtg[row.currency] / row.rate_to_htg - 1,
      }))
      .filter((row) => Math.abs(row.change) > MAX_CHANGE);

    if (suspicious.length > 0 && !acceptLargeChanges) {
      const detail = suspicious
        .slice(0, 5)
        .map((row) => `${row.currency} ${(row.change * 100).toFixed(1)}%`)
        .join(", ");
      record({
        status: "rejected",
        providerUpdatedAt: latest.providerUpdatedAt,
        nextUpdateAt: latest.nextUpdateAt,
        errorCode: "suspicious_change",
        errorMessage: detail,
        // Menm done yo ap retounen jodi a: pa re-eseye jiska demen.
        permanent: true,
      });
      log.error(`[rates] ❌ mizajou REFIZE: chanjman sispèk (${detail}). Ansyen to yo kenbe.`);
      return { status: "rejected", suspicious };
    }

    const entries = Object.entries(latest.rateToHtg);
    transaction((database) => {
      const upsert = database.prepare(
        `INSERT INTO exchange_rates (currency, rate_to_htg, updated_at, source) VALUES (?, ?, ?, ?)
         ON CONFLICT(currency) DO UPDATE SET rate_to_htg = excluded.rate_to_htg,
           updated_at = excluded.updated_at, source = excluded.source`
      );
      for (const [currency, rateToHtg] of entries) {
        upsert.run(currency, rateToHtg, latest.providerUpdatedAt, API_SOURCE);
      }
    });

    record({
      status: "success",
      providerUpdatedAt: latest.providerUpdatedAt,
      nextUpdateAt: latest.nextUpdateAt,
      currencies: entries.length,
    });

    const usd = latest.rateToHtg.USD;
    log.log(
      `[rates] ✅ ${entries.length} to mete ajou (1 USD = ${usd?.toFixed(4)} HTG, done ${new Date(latest.providerUpdatedAt).toISOString()})`
    );

    return { status: "success", reason, currencies: entries.length, ...latest };
  }

  async function refreshIfDue() {
    return refresh();
  }

  /** Eta to yo pou UI a ak administratè a — san kle a. */
  function status() {
    const usd = db()
      .prepare("SELECT rate_to_htg, source, updated_at FROM exchange_rates WHERE currency = 'USD'")
      .get();
    const success = lastSuccess();
    const lastAttempt = db()
      .prepare("SELECT * FROM exchange_rate_fetches ORDER BY attempted_at DESC, id DESC LIMIT 1")
      .get();

    const source = usd?.source || "seed";
    const updatedAt = usd?.updated_at || null;

    return {
      provider: "exchangerate-api.com",
      keyConfigured: Boolean(apiKey),
      source,
      updatedAt,
      stale: source !== API_SOURCE || !updatedAt || now() - updatedAt > STALE_AFTER_MS,
      lastSuccessAt: success?.attempted_at || null,
      nextUpdateAt: success?.next_update_at || null,
      lastError:
        lastAttempt && lastAttempt.status !== "success"
          ? { at: lastAttempt.attempted_at, code: lastAttempt.error_code, status: lastAttempt.status }
          : null,
    };
  }

  let timer = null;

  /** Tcheke lè a chak èdtan; se `dueReason` ki deside si nou rele API a. */
  function start({ intervalMs = CHECK_EVERY_MS } = {}) {
    const tick = () =>
      refreshIfDue().catch((err) => log.error("[rates] erè enprevi:", err.code || err.message));

    tick();
    timer = setInterval(tick, intervalMs);
    // Pa kenbe pwosesis la vivan pou sa (tès, skrip, `docker stop`).
    timer.unref?.();
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  return { refresh, refreshIfDue, dueReason, status, start, stop };
}

let instance = null;

function getRatesRefresher() {
  if (!instance) {
    instance = createRatesRefresher({ apiKey: String(process.env.EXCHANGE_RATE_API_KEY || "").trim() });
  }
  return instance;
}

/** Pou tès yo. */
function resetRatesRefresher() {
  instance?.stop();
  instance = null;
}

module.exports = {
  createRatesRefresher,
  getRatesRefresher,
  resetRatesRefresher,
  API_SOURCE,
  MAX_CHANGE,
  RETRY_AFTER_MS,
  MAX_FAILED_ATTEMPTS_PER_DAY,
};
