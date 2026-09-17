"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { createReloadlyClient, ACCEPT_AIRTIME_V1 } = require("../src/client");
const { TEST_CONFIG } = require("./helpers");

const topupFixture = require("./fixtures/topup_digicel_haiti.json");
const operatorFixture = require("./fixtures/operator_digicel_haiti.json");

function json(status, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) };
}

/**
 * Yon `fetch` ki anrejistre chak apèl epi reponn selon yon woutè.
 * `routes` = [[predicate(url, init), response | (url, init, n) => response], ...]
 */
function fakeFetch(routes) {
  const calls = [];
  const fetchImpl = async (url, init = {}) => {
    calls.push({ url, init, body: init.body ? JSON.parse(init.body) : undefined });
    for (const [match, respond] of routes) {
      if (match(url, init)) {
        const n = calls.filter((c) => match(c.url, c.init)).length;
        const response = typeof respond === "function" ? respond(url, init, n) : respond;
        if (response instanceof Error) throw response;
        return response;
      }
    }
    throw new Error(`Pa gen wout pou ${url}`);
  };
  return { fetchImpl, calls };
}

const isToken = (url) => url === "https://auth.reloadly.com/oauth/token";
const isTopup = (url, init) => url.endsWith("/topups") && init.method === "POST";
const tokenOk = json(200, { access_token: "tok-1", token_type: "Bearer", expires_in: 86400 });

function client(fetchImpl, overrides = {}) {
  return createReloadlyClient({ ...TEST_CONFIG, mode: "sandbox", isFake: false, maxRetries: 2, ...overrides }, { fetchImpl });
}

const topupParams = {
  operatorId: 173,
  amountMinor: 1500,
  useLocalAmount: false,
  customIdentifier: "AIR_test",
  phone: "36377111",
};

test("jeton: `client_credentials` sou auth.reloadly.com ak audience sèvis la", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [(url) => url.endsWith("/accounts/balance"), json(200, { balance: 10, currencyCode: "USD" })],
  ]);

  await client(fetchImpl).balance();

  assert.equal(calls[0].init.method, "POST");
  assert.deepEqual(calls[0].body, {
    client_id: "test",
    client_secret: "test",
    grant_type: "client_credentials",
    audience: "https://topups-sandbox.reloadly.com",
  });
});

test("chak apèl API pote header vèsyon Airtime V1 la ak jeton an", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [(url) => url.includes("/auto-detect/"), json(200, operatorFixture)],
  ]);

  const operator = await client(fetchImpl).detectOperator("3637 7111");

  const api = calls[1];
  assert.equal(api.init.headers.Accept, ACCEPT_AIRTIME_V1);
  assert.equal(api.init.headers.Authorization, "Bearer tok-1");
  assert.match(api.url, /\/operators\/auto-detect\/phone\/%2B50936377111\/countries\/HT\?/);
  assert.match(api.url, /includePin=false/);
  assert.equal(operator.name, "Digicel Haiti");
});

test("jeton an nan cache: de apèl, yon sèl `oauth/token`", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [(url) => url.endsWith("/accounts/balance"), json(200, { balance: 10, currencyCode: "USD" })],
  ]);

  const c = client(fetchImpl);
  await c.balance();
  await c.balance();

  assert.equal(calls.filter((call) => isToken(call.url)).length, 1);
});

test("401: nou rafrechi jeton an epi re-eseye (refi ANVAN tretman)", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, (url, init, n) => json(200, { access_token: `tok-${n}`, expires_in: 86400 })],
    [isTopup, (url, init, n) => (n === 1 ? json(401, { message: "expired" }) : json(200, topupFixture))],
  ]);

  const result = await client(fetchImpl).topup(topupParams);

  assert.equal(result.status, "completed");
  assert.equal(calls.filter((c) => isToken(c.url)).length, 2);
  assert.equal(calls.filter((c) => isTopup(c.url, c.init)).at(-1).init.headers.Authorization, "Bearer tok-2");
});

test("POST /topups JAMÈ re-eseye sou yon 5xx: minit yo ka te pase", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [isTopup, json(502, { message: "Bad Gateway" })],
  ]);

  await assert.rejects(client(fetchImpl).topup(topupParams), { code: "http_502", status: 502 });
  assert.equal(calls.filter((c) => isTopup(c.url, c.init)).length, 1);
});

test("POST /topups JAMÈ re-eseye sou yon timeout / sokèt koupe", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [isTopup, new Error("socket hang up")],
  ]);

  await assert.rejects(client(fetchImpl).topup(topupParams), { code: "network_error" });
  assert.equal(calls.filter((c) => isTopup(c.url, c.init)).length, 1);
});

test("429 sou POST /topups: re-eseye (Reloadly refize l anvan tretman)", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [isTopup, (url, init, n) => (n === 1 ? json(429, { message: "slow down" }) : json(200, topupFixture))],
  ]);

  const result = await client(fetchImpl).topup(topupParams);
  assert.equal(result.gatewayId, "10670");
  assert.equal(calls.filter((c) => isTopup(c.url, c.init)).length, 2);
});

test("GET (lekti) re-eseye sou 5xx: san danje", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [
      (url) => url.endsWith("/accounts/balance"),
      (url, init, n) => (n === 1 ? json(503, {}) : json(200, { balance: 10, currencyCode: "USD" })),
    ],
  ]);

  const balance = await client(fetchImpl).balance();
  assert.equal(balance.balanceMinor, 1000);
  assert.equal(calls.filter((c) => c.url.endsWith("/accounts/balance")).length, 2);
});

test("erè metye Reloadly: kòd miniskil, pa re-eseye", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [isTopup, json(400, { errorCode: "INVALID_AMOUNT_FOR_OPERATOR", message: "Invalid amount" })],
  ]);

  await assert.rejects(client(fetchImpl).topup(topupParams), {
    code: "invalid_amount_for_operator",
    status: 400,
    retryable: false,
  });
  assert.equal(calls.filter((c) => isTopup(c.url, c.init)).length, 1);
});

test("kò POST /topups: nimewo entènasyonal, montan desimal, customIdentifier nou an", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [isTopup, json(200, topupFixture)],
  ]);

  await client(fetchImpl).topup(topupParams);

  assert.deepEqual(calls.find((c) => isTopup(c.url, c.init)).body, {
    operatorId: 173,
    amount: 15,
    useLocalAmount: false,
    customIdentifier: "AIR_test",
    recipientPhone: { countryCode: "HT", number: "+50936377111" },
  });
});

test("rechèch pa customIdentifier: sèlman yon koresponn EGZAK konte", async () => {
  const { fetchImpl, calls } = fakeFetch([
    [isToken, tokenOk],
    [
      (url) => url.includes("/topups/reports/transactions"),
      json(200, {
        content: [
          { ...topupFixture, transactionId: 1, customIdentifier: "AIR_other" },
          { ...topupFixture, transactionId: 2, customIdentifier: "AIR_test" },
        ],
      }),
    ],
  ]);

  const found = await client(fetchImpl).findTopupByCustomIdentifier("AIR_test");

  assert.match(calls[1].url, /\/topups\/reports\/transactions\?customIdentifier=AIR_test$/);
  assert.equal(found.gatewayId, "2");
});

test("prepare() jwenn jeton an san rele API a", async () => {
  const { fetchImpl, calls } = fakeFetch([[isToken, tokenOk]]);

  await client(fetchImpl).prepare();

  assert.deepEqual(calls.map((c) => c.url), ["https://auth.reloadly.com/oauth/token"]);
});
