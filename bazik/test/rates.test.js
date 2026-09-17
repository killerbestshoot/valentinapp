"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { DatabaseSync } = require("node:sqlite");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const { makeService, seedAgent, balanceOf } = require("./helpers");
const { createSqliteStore } = require("../src/store/sqlite_store");
const { createRateBook, API_SOURCE } = require("../src/rates");
const { createSqliteService } = require("../index");
const { createFakeBazikClient } = require("../src/fake_client");
const { TEST_CONFIG } = require("./helpers");

const HOUR = 3600 * 1000;
const NOW = Date.UTC(2026, 8, 17, 12, 0, 0);

async function apiRates(store, updatedAt = NOW - 12 * HOUR) {
  // Valè exchangerate-api.com le 17/09/2026 (baz USD), konvèti an "HTG pou 1".
  await store.setRate("USD", 130.6979, { source: API_SOURCE, updatedAt });
  await store.setRate("MXN", 7.60172, { source: API_SOURCE, updatedAt });
  await store.setRate("CLP", 0.136747, { source: API_SOURCE, updatedAt });
}

test("liv to: menm deviz = menm montan egzak, san tchèk ni rechèch to", async (t) => {
  const store = createSqliteStore();
  t.after(() => store.close());
  const rates = createRateBook({ store, requireFresh: true, now: () => NOW });

  // Menm ak to `seed` e `requireFresh`: pa gen konvèsyon, pa gen blokaj.
  const same = await rates.convert(12345, "MXN", "mxn");
  assert.equal(same.amountMinor, 12345);
  assert.equal(same.crossCurrency, false);

  const htg = await rates.convert(50000, "HTG", "HTG");
  assert.equal(htg.amountMinor, 50000);
});

test("liv to: MXN -> USD pase pa HTG, `down` pa janm voye plis pase valè a", async (t) => {
  const store = createSqliteStore();
  t.after(() => store.close());
  await apiRates(store);
  const rates = createRateBook({ store, now: () => NOW });

  // 100 MXN × 7,60172 / 130,6979 = 5,8163 USD
  const nearest = await rates.convert(10000, "MXN", "USD");
  const down = await rates.convert(10000, "MXN", "USD", { rounding: "down" });

  assert.equal(nearest.amountMinor, 582);
  assert.equal(down.amountMinor, 581);
  assert.ok(Math.abs(nearest.rate - 7.60172 / 130.6979) < 1e-12);
  assert.equal(nearest.crossCurrency, true);
  assert.equal(nearest.stale, false);
  assert.equal(nearest.updatedAt, NOW - 12 * HOUR);
});

test("liv to: erè flotan pa koute yon santim (x,99999999 -> x+1 an `down`)", async (t) => {
  const store = createSqliteStore();
  t.after(() => store.close());
  await store.setRate("AAA", 0.1 + 0.2, { source: API_SOURCE, updatedAt: NOW }); // 0,30000000000000004
  await store.setRate("BBB", 0.3, { source: API_SOURCE, updatedAt: NOW });
  const rates = createRateBook({ store, now: () => NOW });

  assert.equal((await rates.convert(100, "BBB", "AAA", { rounding: "down" })).amountMinor, 100);
});

test("pwodiksyon: to `seed` (poko janm soti nan API a) BLOKE konvèsyon an", async (t) => {
  const store = createSqliteStore(); // to seed yo: USD 132, MXN 7,25...
  t.after(() => store.close());
  const rates = createRateBook({ store, requireFresh: true, now: () => NOW });

  await assert.rejects(rates.convert(10000, "USD", "HTG"), (err) =>
    err.code === "rates_stale" && /poko janm soti nan API/.test(err.message)
  );
});

test("pwodiksyon: to API ki twò vye BLOKE; to API ki fre pase", async (t) => {
  const store = createSqliteStore();
  t.after(() => store.close());
  const rates = createRateBook({ store, requireFresh: true, maxAgeMs: 72 * HOUR, now: () => NOW });

  await apiRates(store, NOW - 80 * HOUR);
  await assert.rejects(rates.convert(10000, "USD", "HTG"), (err) =>
    err.code === "rates_stale" && /80 h/.test(err.message)
  );

  await apiRates(store, NOW - 20 * HOUR);
  assert.equal((await rates.convert(10000, "USD", "HTG")).amountMinor, 1306979);
});

test("devlopman: to seed toujou itilizab, men make `stale`", async (t) => {
  const store = createSqliteStore();
  t.after(() => store.close());
  const rates = createRateBook({ store, now: () => NOW });

  const converted = await rates.convert(10000, "USD", "HTG");
  assert.equal(converted.amountMinor, 1320000);
  assert.equal(converted.stale, true);
});

test("transfè: montan an MXN, wallet USD — benefisyè a resevwa HTG, debi a an USD", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: 50000 }); // 500 USD

  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: 100000, // 1 000 MXN
    currency: "MXN",
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "mxn-usd",
  });

  // 1 000 MXN × 7,25 = 7 250 HTG; +5% = 7 612,50 HTG; / 132 = 57,67 USD
  assert.equal(transfer.currency, "MXN");
  assert.equal(transfer.amountHtgMinor, 725000);
  assert.equal(transfer.totalHtgMinor, 761250);
  assert.equal(transfer.walletCurrency, "USD");
  assert.equal(transfer.debitMinor, Math.round(761250 / 132));
  assert.equal(await balanceOf(service.store, agent), 50000 - Math.round(761250 / 132));
});

test("transfè kwaze ki echwe: ranbousman EGZAK nan deviz WALLET la", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: 50000 });

  // 37000000 toujou echwe nan similatè a.
  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: 100000,
    currency: "MXN",
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37000000",
    idempotencySeed: "mxn-fail",
  });

  assert.equal(transfer.status, "failed");
  assert.equal(await balanceOf(service.store, agent), 50000);

  const refund = service.store._db
    .prepare("SELECT currency, amount_minor FROM wallet_ledger WHERE type LIKE '%refund'")
    .get();
  assert.equal(refund.currency, "USD", "liy ranbousman an nan deviz wallet la, pa MXN");
  assert.equal(refund.amount_minor, transfer.debitMinor);
});

test("devi ak uid: debi a nan deviz wallet ajan an", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());
  const agent = await seedAgent(service.store, { balanceMinor: 50000 });

  const quote = await service.transfers.quote({ ...agent, amountMinor: 100000, currency: "MXN", network: "moncash" });

  assert.equal(quote.currency, "MXN");
  assert.equal(quote.walletCurrency, "USD");
  assert.equal(quote.debitMinor, Math.round(761250 / 132));
});

test("pwodiksyon: transfè ak to seed refize AVAN debi", async (t) => {
  const service = createSqliteService({
    client: createFakeBazikClient({ autoComplete: true }),
    config: { ...TEST_CONFIG },
    ratesPolicy: { requireFresh: true },
  });
  t.after(() => service.close());
  const agent = await seedAgent(service.store, { balanceMinor: 50000 });

  await assert.rejects(
    service.transfers.send({ ...agent, network: "moncash", amountMinor: 1000, phone: "37123456", idempotencySeed: "stale" }),
    { code: "rates_stale" }
  );
  assert.equal(await balanceOf(service.store, agent), 50000);
});

test("rechaj (cash-in) an USD pou yon wallet HTG: kredi a konvèti an HTG", async (t) => {
  const { service } = makeService({ allowCashIn: true });
  t.after(() => service.close());

  await service.store.ensureWallet({ uid: "htg-1", enterpriseId: "ENT1", currency: "HTG" });

  const { topup } = await service.topups.create({
    targetUid: "htg-1",
    enterpriseId: "ENT1",
    amountMinor: 1000, // 10 USD
    currency: "USD",
    idempotencySeed: "cashin-usd-htg",
  });

  assert.equal(topup.currency, "HTG", "sinon 10 'USD' ta tounen 10 HTG nan wallet la");
  assert.equal(topup.amountMinor, 132000);
});

test("migrasyon: yon baz ANSYEN (san kolòn yo) resevwa yo san pèdi done", async (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "rates-migration-"));
  const file = path.join(dir, "old.db");
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));

  const old = new DatabaseSync(file);
  old.exec(`
    CREATE TABLE exchange_rates (currency TEXT PRIMARY KEY, rate_to_htg REAL NOT NULL, updated_at INTEGER NOT NULL);
    INSERT INTO exchange_rates VALUES ('USD', 131, 1);
    CREATE TABLE bazik_transfers (
      transfer_id TEXT PRIMARY KEY, reference TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, network TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', gateway_id TEXT NOT NULL DEFAULT '', gateway_status TEXT NOT NULL DEFAULT '',
      amount_minor INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'USD', amount_htg_minor INTEGER NOT NULL,
      fee_htg_minor INTEGER NOT NULL DEFAULT 0, total_htg_minor INTEGER NOT NULL DEFAULT 0, debit_minor INTEGER NOT NULL DEFAULT 0,
      rate_to_htg REAL NOT NULL, uid TEXT NOT NULL DEFAULT '', enterprise_id TEXT NOT NULL DEFAULT '', enterprise_name TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '', receiver_name TEXT NOT NULL DEFAULT '', tx_id TEXT NOT NULL DEFAULT '',
      wallet_debited INTEGER NOT NULL DEFAULT 0, refunded INTEGER NOT NULL DEFAULT 0, failure_reason TEXT NOT NULL DEFAULT '',
      note TEXT NOT NULL DEFAULT '', created_by TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, settled_at INTEGER
    );
    INSERT INTO bazik_transfers (transfer_id, reference, kind, network, amount_minor, currency, amount_htg_minor, rate_to_htg, created_at, updated_at)
      VALUES ('TRF_old', 'TRF_old', 'payout', 'moncash', 1000, 'USD', 131000, 131, 1, 1);
  `);
  old.close();

  const store = createSqliteStore({ file });
  t.after(() => store.close());

  const info = await store.getRateInfo("USD");
  assert.equal(info.rateToHtg, 131, "to ki te la a pa touche");
  assert.equal(info.source, "seed");

  const transfer = await store.getTransfer("TRF_old");
  assert.equal(transfer.walletCurrency, "USD", "ansyen liy: wallet la te menm deviz ak montan an");
});
