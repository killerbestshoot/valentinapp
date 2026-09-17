"use strict";

/**
 * To echanj: YON apèl pa jou, estoke, itilize tout jounen an.
 *
 * Fiksti a se repons REYÈL exchangerate-api.com le 17/09/2026 (san kle a).
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "rates-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const { createRatesRefresher, getRatesRefresher, resetRatesRefresher } = require("../src/rates/rates_refresher");
const { fetchLatestUsdRates, parseLatest } = require("../src/rates/exchange_rate_api");
const { createSqliteStore } = require("../../bazik/src/store/sqlite_store");
const { createRateBook } = require("../../bazik/src/rates");

const REAL = require("./fixtures/exchangerate_api_latest_usd_2026-09-17.json");
const KEY = "cle-secrete-de-test-123456";
const HOUR = 3600 * 1000;

// Done yo date 17/09 00:00:01 UTC; pwochen mizajou 18/09 00:00:01 UTC.
const PROVIDER_AT = REAL.time_last_update_unix * 1000;
const NEXT_AT = REAL.time_next_update_unix * 1000;
const DAY1_NOON = PROVIDER_AT + 12 * HOUR;

test.after(() => {
  resetRatesRefresher();
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

function resetTables() {
  const database = db.getDb();
  database.exec("DELETE FROM exchange_rate_fetches");
  database.exec("UPDATE exchange_rates SET source = 'seed'");
  database.exec("DELETE FROM exchange_rates WHERE currency NOT IN ('HTG','USD','MXN','DOP','CLP','BRL')");
  database.prepare("UPDATE exchange_rates SET rate_to_htg = ? WHERE currency = 'USD'").run(132);
  database.prepare("UPDATE exchange_rates SET rate_to_htg = ? WHERE currency = 'MXN'").run(7.25);
}

/** Yon `fetchLatest` ki konte apèl yo, ak yon revèy nou kontwole. */
function harness({ body = REAL, error = null, apiKey = KEY } = {}) {
  resetTables();
  const clock = { t: DAY1_NOON };
  const calls = [];
  const logs = [];
  const log = { log: (m) => logs.push(m), warn: (m) => logs.push(m), error: (...m) => logs.push(m.join(" ")) };

  const fetchLatest = async ({ apiKey: key }) => {
    calls.push({ key, at: clock.t });
    if (typeof error === "function") {
      const e = error(calls.length);
      if (e) throw e;
    } else if (error) {
      throw error;
    }
    return parseLatest(typeof body === "function" ? body(calls.length) : body);
  };

  const make = () => createRatesRefresher({ apiKey, fetchLatest, now: () => clock.t, log });
  return { clock, calls, logs, make, refresher: make() };
}

const rate = (currency) =>
  db.getDb().prepare("SELECT rate_to_htg, source, updated_at FROM exchange_rates WHERE currency = ?").get(currency);

// --- Kliyan API a ------------------------------------------------------------

test("repons reyèl la: 166 deviz, pivo HTG, dat done yo", () => {
  const parsed = parseLatest(REAL);

  assert.equal(Object.keys(parsed.rateToHtg).length, 166);
  assert.equal(parsed.rateToHtg.HTG, 1);
  assert.equal(parsed.rateToHtg.USD, 130.6979);
  assert.ok(Math.abs(parsed.rateToHtg.MXN - 130.6979 / 17.1932) < 1e-12);
  assert.equal(parsed.providerUpdatedAt, Date.UTC(2026, 8, 17, 0, 0, 1));
  assert.equal(parsed.nextUpdateAt, Date.UTC(2026, 8, 18, 0, 0, 1));
});

test("kliyan: URL v6 /latest/USD, erè `invalid-key` pèmanan, kle a JAMÈ nan mesaj yo", async () => {
  let url;
  const ok = await fetchLatestUsdRates({
    apiKey: KEY,
    fetchImpl: async (u) => ((url = u), { status: 200, json: async () => REAL }),
  });
  assert.equal(url, `https://v6.exchangerate-api.com/v6/${KEY}/latest/USD`);
  assert.equal(ok.rateToHtg.USD, 130.6979);

  await assert.rejects(
    fetchLatestUsdRates({
      apiKey: KEY,
      fetchImpl: async () => ({ status: 403, json: async () => ({ result: "error", "error-type": "invalid-key" }) }),
    }),
    (err) => err.code === "invalid-key" && err.permanent === true && !err.message.includes(KEY)
  );

  await assert.rejects(
    fetchLatestUsdRates({
      apiKey: KEY,
      fetchImpl: async (u) => {
        throw new TypeError(`fetch failed: ${u}`); // yon erè ki pote URL la (ak kle a)
      },
    }),
    (err) => err.code === "network_error" && err.permanent === false && !err.message.includes(KEY)
  );

  await assert.rejects(
    fetchLatestUsdRates({ apiKey: KEY, fetchImpl: async () => ({ status: 502, json: async () => { throw new SyntaxError(); } }) }),
    { code: "bad_response" }
  );
});

test("repons san HTG oswa ak yon lòt baz: refize, anyen pa ekri", () => {
  assert.throws(() => parseLatest({ ...REAL, base_code: "EUR" }), { code: "bad_response" });
  const noHtg = { ...REAL, conversion_rates: { ...REAL.conversion_rates, HTG: 0 } };
  assert.throws(() => parseLatest(noHtg), { code: "bad_response" });
});

// --- Yon apèl pa jou -----------------------------------------------------------

test("premye mizajou: tout to yo ekri, sous `exchangerate-api`, dat = dat DONE yo", async () => {
  const { refresher, calls } = harness();

  const result = await refresher.refresh();

  assert.equal(result.status, "success");
  assert.equal(result.currencies, 166);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].key, KEY);
  assert.deepEqual({ ...rate("USD") }, { rate_to_htg: 130.6979, source: "exchangerate-api", updated_at: PROVIDER_AT });
  assert.equal(rate("EUR").source, "exchangerate-api", "deviz ki pa t nan seed yo ajoute tou");
});

test("menm jou a: dezyèm apèl la pa fèt — menm apre yon REDEMARAJ serveur", async () => {
  const { refresher, calls, clock, make } = harness();

  await refresher.refresh();
  clock.t += 3 * HOUR;
  assert.deepEqual(await refresher.refresh(), { status: "skipped", reason: "not_due" });

  const afterRestart = make(); // nouvo pwosesis, menm baz
  clock.t += 5 * HOUR;
  assert.deepEqual(await afterRestart.refresh(), { status: "skipped", reason: "not_due" });

  assert.equal(calls.length, 1);
});

test("jou apre a: yon apèl, SÈLMAN apre lè API a anonse done yo chanje", async () => {
  const { refresher, calls, clock } = harness();

  // Premye apèl a 23:00 UTC jou 1: pwochen done yo a 00:00:01 jou 2.
  clock.t = NEXT_AT - HOUR;
  await refresher.refresh();

  clock.t = NEXT_AT - 1; // jou 2, men done yo poko chanje
  assert.equal((await refresher.refresh()).status, "skipped");

  clock.t = NEXT_AT + 10 * 60 * 1000;
  assert.equal((await refresher.refresh()).status, "success");
  assert.equal(calls.length, 2);
});

test("move kle: pa gen lòt esè JODI A (kota a pa boule), men demen wi", async () => {
  const invalid = Object.assign(new Error("exchangerate-api refize demann lan: invalid-key."), { code: "invalid-key", permanent: true });
  const { refresher, calls, clock } = harness({ error: invalid });

  assert.equal((await refresher.refresh()).status, "error");
  clock.t += 2 * HOUR;
  assert.equal((await refresher.refresh()).reason, "not_due");
  assert.equal(calls.length, 1);

  clock.t += 24 * HOUR;
  await refresher.refresh();
  assert.equal(calls.length, 2);
});

test("pàn rezo: nouvo esè apre 30 min, maksimòm 6 esè pa jou", async () => {
  const network = Object.assign(new Error("exchangerate-api pa reponn (rezo)."), { code: "network_error", permanent: false });
  const { refresher, calls, clock } = harness({ error: network });

  clock.t = PROVIDER_AT + HOUR; // 01:00 UTC
  await refresher.refresh();
  clock.t += 10 * 60 * 1000;
  assert.equal((await refresher.refresh()).reason, "not_due", "10 min apre: twò bonè");

  for (let i = 0; i < 10; i++) {
    clock.t += 31 * 60 * 1000;
    await refresher.refresh();
  }
  assert.equal(calls.length, 6, "6 esè, pa 11");
});

test("rezo retounen apre yon echèk: mizajou a pase", async () => {
  const network = Object.assign(new Error("rezo"), { code: "network_error", permanent: false });
  const { refresher, clock } = harness({ error: (n) => (n === 1 ? network : null) });

  assert.equal((await refresher.refresh()).status, "error");
  clock.t += 31 * 60 * 1000;
  assert.equal((await refresher.refresh()).status, "success");
  assert.equal(rate("USD").source, "exchangerate-api");
});

// --- Gad sekirite ----------------------------------------------------------------

test("chanjman > 25% sou yon to ki te DEJA soti nan API a: TOUT mizajou a refize", async () => {
  const corrupt = {
    ...REAL,
    time_last_update_unix: REAL.time_next_update_unix,
    time_next_update_unix: REAL.time_next_update_unix + 86400,
    // HTG = 1,306979 olye 130,6979 (desimal deplase): chak USD ta vo 100 fwa mwens.
    conversion_rates: { ...REAL.conversion_rates, HTG: 1.306979 },
  };
  const { refresher, clock, calls } = harness({ body: (n) => (n === 1 ? REAL : corrupt) });

  await refresher.refresh();
  clock.t = NEXT_AT + HOUR;
  const result = await refresher.refresh();

  assert.equal(result.status, "rejected");
  assert.equal(rate("USD").rate_to_htg, 130.6979, "ansyen to yo kenbe");

  clock.t += 2 * HOUR;
  assert.equal((await refresher.refresh()).reason, "not_due", "menm done sispèk yo: pa re-eseye jodi a");
  assert.equal(calls.length, 2);

  // Apre verifikasyon alamen, CLI a ka aksepte l.
  const forced = await refresher.refresh({ force: true, acceptLargeChanges: true });
  assert.equal(forced.status, "success");
  assert.equal(rate("USD").rate_to_htg, 1.306979);
});

test("premye mizajou apre to `seed` yo: gad la pa aplike (seed yo pa soti nan API a)", async () => {
  const { refresher } = harness();
  db.getDb().prepare("UPDATE exchange_rates SET rate_to_htg = 3 WHERE currency = 'MXN'").run(); // seed absid

  assert.equal((await refresher.refresh()).status, "success");
  assert.ok(Math.abs(rate("MXN").rate_to_htg - 7.60172) < 1e-4);
});

// --- San kle, eta, demaraj ---------------------------------------------------------

test("san kle: okenn apèl", async () => {
  const { refresher, calls } = harness({ apiKey: "" });
  assert.deepEqual(await refresher.refresh(), { status: "skipped", reason: "missing_key" });
  assert.equal(calls.length, 0);
});

test("eta: sous, dat, `stale`, dènye erè — e JAMÈ kle a", async () => {
  const { refresher, clock } = harness();

  const before = refresher.status();
  assert.equal(before.source, "seed");
  assert.equal(before.stale, true);
  assert.equal(before.keyConfigured, true);

  await refresher.refresh();
  const after = refresher.status();
  assert.equal(after.source, "exchangerate-api");
  assert.equal(after.updatedAt, PROVIDER_AT);
  assert.equal(after.nextUpdateAt, NEXT_AT);
  assert.equal(after.stale, false);
  assert.ok(!JSON.stringify(after).includes(KEY));

  clock.t = PROVIDER_AT + 40 * HOUR;
  assert.equal(refresher.status().stale, true, "40 h san mizajou");
});

test("start(): yon tcheke tou swit, minitè a pa kenbe pwosesis la vivan", async () => {
  const { refresher, calls } = harness();
  refresher.start({ intervalMs: 50 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  refresher.stop();
  assert.equal(calls.length, 1);
});

test("POLITIK PWODIKSYON: konvèsyon refize ak to seed, aksepte apre mizajou jounen an", async () => {
  const { refresher, clock } = harness();
  const store = createSqliteStore({ file: process.env.APP_DB_PATH, seedRates: false });
  const rates = createRateBook({ store, requireFresh: true, now: () => clock.t });

  await assert.rejects(rates.convert(10000, "MXN", "USD"), { code: "rates_stale" });

  await refresher.refresh();
  const converted = await rates.convert(10000, "MXN", "USD", { rounding: "down" });
  // 100 MXN = 5,8163 USD ak to reyèl 17/09/2026
  assert.equal(converted.amountMinor, 581);
  assert.equal(converted.updatedAt, PROVIDER_AT);

  await store.close();
});

test("GET /api/wallets/rates: to yo + meta, san kle a", async (t) => {
  const { refresher } = harness();
  await refresher.refresh();

  process.env.EXCHANGE_RATE_API_KEY = KEY;
  resetRatesRefresher();
  t.after(() => {
    delete process.env.EXCHANGE_RATE_API_KEY;
    resetRatesRefresher();
  });

  const users = require("../src/auth/users");
  const { createSession } = require("../src/auth/sessions");
  const { attachUser } = require("../src/auth/middleware");
  const walletRoutes = require("../src/routes/wallets.routes");

  const user = await users.createUser({ email: "rates@example.com", password: "modpas-solid-2026", role: "agent" });
  const token = createSession(user.uid).token;

  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/wallets", walletRoutes);
  const server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  t.after(() => server.close());

  const response = await fetch(`http://127.0.0.1:${server.address().port}/api/wallets/rates`, {
    headers: { authorization: `Bearer ${token}` },
  });
  const text = await response.text();
  const json = JSON.parse(text);

  assert.equal(json.rates.USD, 130.6979);
  assert.equal(json.meta.source, "exchangerate-api");
  assert.equal(json.meta.keyConfigured, true);
  assert.ok(!text.includes(KEY), "la clé ne doit jamais sortir du serveur");
  assert.equal(getRatesRefresher().status().source, "exchangerate-api");
});
