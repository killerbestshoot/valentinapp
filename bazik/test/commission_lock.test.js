"use strict";

/** Komisyon bloke sou pasrèl yo + transfè atomik ant wallet. */

const test = require("node:test");
const assert = require("node:assert/strict");

const { createBazikService } = require("../index");
const { createSqliteStore } = require("../src/store/sqlite_store");
const { createFakeBazikClient } = require("../src/fake_client");
const { commissionUid } = require("../src/commission_wallet");
const { TEST_CONFIG } = require("./helpers");

function makeService({ bazikHtg = 20000, lockedHtg = 0 } = {}) {
  return createBazikService({
    store: createSqliteStore({ file: ":memory:" }),
    client: createFakeBazikClient({ availableMinor: bazikHtg * 100 }),
    config: { ...TEST_CONFIG },
    lockedHtgMinor: async () => lockedHtg * 100,
  });
}

async function seed(store, uid, minor, currency = "HTG") {
  await store.ensureWallet({ uid, enterpriseId: "E", role: "agent", currency });
  if (minor) await store.creditWallet({ uid, enterpriseId: "E", amountMinor: minor, currency, type: "seed", idempotencyKey: `seed:${uid}` });
}

test("komisyon bloke: float 20 000, 12 000 bloke → yon transfè 10 000 refize, men yon retrè komisyon pase", async (t) => {
  const service = makeService({ bazikHtg: 20000, lockedHtg: 12000 });
  t.after(() => service.close());
  await seed(service.store, "a", 5000000);

  const send = (seed, extra = {}) => service.transfers.send({
    network: "moncash", amountMinor: 1000000, currency: "HTG", uid: "a", enterpriseId: "E", phone: "37123456",
    idempotencySeed: seed, ...extra,
  });

  // 10 000 + 5 % = 10 500 > 8 000 disponib (20 000 − 12 000 bloke).
  await assert.rejects(send("t1"), (err) => err.code === "gateway_underfunded" && /rezève pou komisyon yo/.test(err.message));

  // Retrè komisyon: li gen dwa itilize kòb ki bloke a.
  const payout = await send("t2", { bypassLock: true });
  assert.notEqual(payout.transfer.status, "failed");
});

test("transfè atomik ant wallet: komisyon → prensipal, sòld ensifizan = anyen pa bouje", async (t) => {
  const service = makeService();
  t.after(() => service.close());
  const store = service.store;
  await seed(store, "a", 100000);
  await seed(store, commissionUid("a"), 30000);

  const move = (amount, key) => store.transferBetweenWallets({
    from: { uid: commissionUid("a"), enterpriseId: "E", amountMinor: amount, currency: "HTG", type: "commission_to_main", idempotencyKey: `${key}:out` },
    to: { uid: "a", enterpriseId: "E", amountMinor: amount, currency: "HTG", type: "commission_to_main", idempotencyKey: `${key}:in` },
  });

  await move(20000, "m1");
  assert.equal((await store.getWallet({ uid: "a", enterpriseId: "E" })).balanceMinor, 120000);
  assert.equal((await store.getWallet({ uid: commissionUid("a"), enterpriseId: "E" })).balanceMinor, 10000);

  await assert.rejects(move(50000, "m2"), (err) => err.code === "insufficient_funds");
  assert.equal((await store.getWallet({ uid: "a", enterpriseId: "E" })).balanceMinor, 120000, "kredi a pa pase si debi a echwe");
});
