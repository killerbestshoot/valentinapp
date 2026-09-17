"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { createAccountInsights } = require("../src/insights");
const { createFakeReloadlyClient } = require("../src/fake_client");
const { ReloadlyError } = require("../src/errors");
const { TEST_CONFIG } = require("./helpers");

/** Espyone apèl yo: se sa ki pwouve yon admin pa DEKLANCHE apèl lajan yo. */
function spied(options) {
  const client = createFakeReloadlyClient(options);
  const calls = [];
  for (const name of ["scopes", "operatorsByCountry", "promotionsByCountry", "balance", "commission", "recentTopups"]) {
    const original = client[name];
    client[name] = async (...args) => (calls.push(name), original(...args));
  }
  return { client, calls };
}

const make = (client, now = () => 1000) => createAccountInsights({ client, config: { ...TEST_CONFIG }, now });

test("owner: tout seksyon yo, ak 6 pèmisyon yo", async () => {
  const { client } = spied();
  await client.topup({ operatorId: 173, amountMinor: 500, customIdentifier: "AIR_a", phone: "37123456" });

  const view = await make(client).overview({ isOwner: true });

  assert.deepEqual(
    view.permissions.map((p) => `${p.scope}:${p.granted}:${p.ownerOnly}`),
    [
      "send-topups:true:false",
      "read-operators:true:false",
      "read-promotions:true:false",
      "read-topups-history:true:true",
      "read-prepaid-balance:true:true",
      "read-prepaid-commissions:true:true",
    ]
  );
  assert.equal(view.sections.operators.data[0].name, "Digicel Haiti");
  assert.deepEqual(view.sections.promotions, { ok: true, data: [] });
  assert.equal(view.sections.balance.data.currency, "USD");
  assert.deepEqual(
    view.sections.commissions.data.map((c) => `${c.operatorName}:${c.percentage}`),
    ["Digicel Haiti:2", "Natcom Haiti:5"]
  );
  assert.equal(view.sections.history.data[0].customIdentifier, "AIR_a");
});

test("admin: sòld, komisyon, istorik REZÈVE — e Reloadly pa menm rele pou yo", async () => {
  // Yon sòld rekonesab: si "777" parèt yon kote nan repons lan, li fuit.
  const { client, calls } = spied({ balance: 777.77 });

  const view = await make(client).overview({ isOwner: false });

  for (const name of ["balance", "commissions", "history"]) {
    assert.deepEqual(view.sections[name], { ok: false, restricted: true }, name);
  }
  assert.equal(view.sections.operators.ok, true);
  assert.equal(view.sections.promotions.ok, true);
  assert.ok(!calls.includes("balance"));
  assert.ok(!calls.includes("commission"));
  assert.ok(!calls.includes("recentTopups"));
  // Non seksyon an rete (`sections.balance`), men AYEN done ladan l.
  assert.equal(view.sections.balance.data, undefined);
  assert.ok(!JSON.stringify(view).includes("777"), "okenn montan sòld nan repons admin nan");
});

test("pèmisyon ki manke: seksyon an make `missing_scope`, SAN apèl", async () => {
  const { client, calls } = spied({ scopes: ["send-topups", "read-operators"] });

  const view = await make(client).overview({ isOwner: true });

  assert.equal(view.permissions.find((p) => p.scope === "read-prepaid-balance").granted, false);
  assert.deepEqual(view.sections.balance, { ok: false, error: "missing_scope" });
  assert.deepEqual(view.sections.history, { ok: false, error: "missing_scope" });
  assert.ok(!calls.includes("balance") && !calls.includes("recentTopups"));
  assert.equal(view.sections.operators.ok, true);
});

test("yon erè sou yon seksyon pa kase lòt yo", async () => {
  const { client } = spied();
  client.promotionsByCountry = async () => {
    throw new ReloadlyError("http_503", "Service Unavailable", { status: 503 });
  };

  const view = await make(client).overview({ isOwner: true });

  assert.equal(view.sections.promotions.ok, false);
  assert.equal(view.sections.promotions.error, "http_503");
  assert.equal(view.sections.balance.ok, true);
  assert.equal(view.sections.operators.ok, true);
});

test("yon pèmisyon Reloadly ajoute pita parèt nan lis la", async () => {
  const { client } = spied({ scopes: ["send-topups", "read-giftcards"] });
  const view = await make(client).overview({ isOwner: false });
  assert.ok(view.permissions.some((p) => p.scope === "read-giftcards" && p.granted));
});

test("cache 60 s pa wòl: ajan pa ka fè Reloadly resevwa yon apèl pa rafrechisman", async () => {
  const { client, calls } = spied();
  let t = 1000;
  const insights = make(client, () => t);

  await insights.overview({ isOwner: true });
  const first = calls.length;
  t += 30 * 1000;
  await insights.overview({ isOwner: true });
  assert.equal(calls.length, first);

  await insights.overview({ isOwner: false });
  assert.ok(calls.length > first, "vi admin nan gen pwòp cache li (pa done owner yo)");

  t += 61 * 1000;
  await insights.overview({ isOwner: true });
  assert.ok(calls.length > first * 2 - 1);
});
