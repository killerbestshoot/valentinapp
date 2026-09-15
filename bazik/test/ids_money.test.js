"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const AppIds = require("../src/ids");
const money = require("../src/money");

/**
 * PARITE DART <-> NODE.
 *
 * Valè sa yo pwodui pa `lib/services/shared/app_ids.dart` (Dart), epi yo repwodui
 * egzakteman isit la an JS. Si yon moun chanje algorithm ID a yon bò, tès sa a
 * kase — e se sa nou vle, paske ID yo se kle idempotans nou sou Bazik.
 *
 * Menm fiksti yo kopye nan `test/bazik_id_parity_test.dart`.
 */
const DART_FIXTURES = [
  ["TU", "seed-test", "TU_02a0ee17-3687-5619-8457-cdb9fdc3f84f"],
  ["TU", "TU:abc", "TU_4064ed69-dcd1-5a0b-b962-804f1e1831b5"],
  ["TU", "enterprise-1:uid-9:2026-01-01", "TU_99f17563-0c18-5949-8883-a698eb806bdc"],
  ["TRF", "seed-test", "TRF_382288a7-4eec-557d-8ab5-3bd3e5cd2c49"],
  ["LG", "seed-test", "LG_6c08793b-ceae-5d1d-88f5-b626f57a7199"],
];

test("ID JS yo idantik ak ID Dart yo", () => {
  for (const [prefix, seed, expected] of DART_FIXTURES) {
    assert.equal(AppIds.generate(prefix, seed), expected, `${prefix}:${seed}`);
  }
});

test("menm seed bay menm ID, seed diferan bay ID diferan", () => {
  assert.equal(AppIds.transfer("a"), AppIds.transfer("a"));
  assert.notEqual(AppIds.transfer("a"), AppIds.transfer("b"));
});

test("san seed, ID yo inik", () => {
  const ids = new Set(Array.from({ length: 200 }, () => AppIds.transfer()));
  assert.equal(ids.size, 200);
});

test("fòma ID a respekte sa Dart la tann", () => {
  assert.ok(AppIds.isPrefixedUuid5(AppIds.topupRequest("x")));
  assert.ok(AppIds.isUuid5(AppIds.uuid5("x")));
});

test("konvèsyon lajan pa pèdi santim", () => {
  assert.equal(money.toMinor("10.50"), 1050);
  assert.equal(money.toMinor(10.5), 1050);
  assert.equal(money.fromMinor(1050), 10.5);

  // 10 USD * 132 = 1320 HTG
  assert.equal(money.convertToHtgMinor(1000, 132), 132000);
  assert.equal(money.convertFromHtgMinor(132000, 132), 1000);
});

test("adisyon repete sou santim antye pa deriv", () => {
  let minor = 0;
  for (let i = 0; i < 1000; i++) minor += money.toMinor(0.1);
  assert.equal(minor, 10000, "100,00 egzak");

  // Konparezon: menm bagay la ak double ap deriv.
  let float = 0;
  for (let i = 0; i < 1000; i++) float += 0.1;
  assert.notEqual(float, 100, "se rezon ki fè nou pa estoke double");
});

test("frè 5% yo kalkile jan Bazik fè l", () => {
  // Verifye kont sandbox la: 500 HTG -> fee 25, total 525
  assert.equal(money.feeMinor(50000), 2500);
  assert.equal(money.totalCostMinor(50000), 52500);

  // 75 000 HTG -> fee 3750, total 78 750
  assert.equal(money.feeMinor(7500000), 375000);
  assert.equal(money.totalCostMinor(7500000), 7875000);
});

test("limit rezo yo se sa API a deklare", () => {
  assert.equal(money.NETWORK_LIMITS.moncash.minHtg, 100);
  assert.equal(money.NETWORK_LIMITS.natcash.minHtg, 3998);
  assert.equal(money.NETWORK_LIMITS.moncash.maxHtg, 75000);

  assert.throws(() => money.assertNetworkAmount("moncash", 9900), { code: "amount_too_low" });
  assert.doesNotThrow(() => money.assertNetworkAmount("moncash", 10000));
  assert.throws(() => money.assertNetworkAmount("natcash", 399700), { code: "amount_too_low" });
  assert.throws(() => money.assertNetworkAmount("moncash", 7500100), { code: "amount_too_high" });
  assert.throws(() => money.assertNetworkAmount("mystery", 10000), { code: "unknown_network" });
});

test("montan envalid refize", () => {
  assert.throws(() => money.toMinor(0), { code: "invalid_amount" });
  assert.throws(() => money.toMinor(-5), { code: "invalid_amount" });
  assert.throws(() => money.toMinor("abc"), { code: "invalid_amount" });
});
