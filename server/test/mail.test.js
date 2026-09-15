"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { loadMailConfig, HOSTINGER_SMTP } = require("../src/mail/config");
const { createMailer, MailError } = require("../src/mail");
const { createApiTransport, SEND_PATH } = require("../src/mail/api_transport");
const { otpEmail } = require("../src/mail/templates");

// --- Konfigirasyon ---

test("hostinger_smtp ranpli valè Hostinger yo pou kont li", () => {
  const config = loadMailConfig({
    MAIL_PROVIDER: "hostinger_smtp",
    SMTP_USER: "no-reply@voupvapcash.com",
    SMTP_PASS: "x",
  });

  assert.equal(config.smtp.host, HOSTINGER_SMTP.host);
  assert.equal(config.smtp.port, 465);
  assert.equal(config.smtp.secure, true);
  assert.equal(config.smtp.pool, true, "koneksyon an rete louvri ant de imel");
  assert.equal(config.from, "no-reply@voupvapcash.com");
});

test("SMTP_PORT=587 bay STARTTLS (lè 465 bloke)", () => {
  const config = loadMailConfig({
    MAIL_PROVIDER: "hostinger_smtp",
    SMTP_USER: "a@b.com",
    SMTP_PASS: "x",
    SMTP_PORT: "587",
    SMTP_SECURE: "false",
  });

  assert.equal(config.smtp.port, 587);
  assert.equal(config.smtp.secure, false);
});

test("ansyen konfigirasyon Gmail la kontinye mache", () => {
  // `.env` ki egziste a gen yon adrès @gmail.com: nou pa dwe kase l.
  const config = loadMailConfig({ SMTP_USER: "moun@gmail.com", SMTP_PASS: "x" });

  assert.equal(config.provider, "gmail");
  assert.equal(config.smtp.service, "gmail");
});

test("yon token Hostinger chwazi API a otomatikman", () => {
  const config = loadMailConfig({
    HOSTINGER_MAIL_TOKEN: "tok",
    HOSTINGER_MAILBOX_ID: "AC123",
  });

  assert.equal(config.provider, "hostinger_api");
  assert.equal(config.api.baseUrl, "https://api.mail.hostinger.com");
});

test("konfigirasyon ki pa konplè bay yon erè klè", () => {
  assert.throws(
    () => loadMailConfig({ MAIL_PROVIDER: "hostinger_smtp", SMTP_USER: "a@b.com" }),
    /SMTP_USER ak SMTP_PASS/
  );

  assert.throws(
    () => loadMailConfig({ MAIL_PROVIDER: "hostinger_api", HOSTINGER_MAIL_TOKEN: "tok" }),
    /HOSTINGER_MAILBOX_ID/
  );

  assert.throws(() => loadMailConfig({ MAIL_PROVIDER: "pigeon" }), /MAIL_PROVIDER pa valid/);
});

test("mòd console entèdi an pwodiksyon", () => {
  assert.throws(
    () => loadMailConfig({ NODE_ENV: "production" }),
    /entèdi an pwodiksyon/,
    "yon OTP ki ale nan log la olye nan imel la se yon pàn silansye"
  );
});

// --- Transpò API ---

/** Yon faux `fetch` ki anrejistre sa nou voye. */
function fakeFetch(responses) {
  const calls = [];
  let index = 0;

  const impl = async (url, options) => {
    calls.push({ url, options, body: JSON.parse(options.body) });
    const next = responses[Math.min(index, responses.length - 1)];
    index += 1;
    return {
      status: next.status,
      ok: next.status >= 200 && next.status < 300,
      text: async () => JSON.stringify(next.body || {}),
    };
  };

  impl.calls = calls;
  return impl;
}

function apiConfig(overrides = {}) {
  return {
    provider: "hostinger_api",
    fromName: "VOUPVAPCASH",
    timeoutMs: 1000,
    maxRetries: 0,
    api: { baseUrl: "https://api.mail.hostinger.com", token: "tok", mailboxId: "AC123" },
    ...overrides,
  };
}

test("API a rele bon chemen an ak bon payload la", async () => {
  const fetchImpl = fakeFetch([{ status: 204 }]);
  const transport = createApiTransport(apiConfig(), { fetchImpl });

  await transport.send({
    to: "moun@example.com",
    subject: "123456 — kòd ou",
    text: "kòd: 123456",
    html: "<b>123456</b>",
  });

  const call = fetchImpl.calls[0];
  assert.equal(call.url, `https://api.mail.hostinger.com${SEND_PATH("AC123")}`);
  assert.equal(call.options.headers.Authorization, "Bearer tok");
  assert.deepEqual(call.body.to, ["moun@example.com"], "`to` dwe yon tablo");
  assert.equal(call.body.displayName, "VOUPVAPCASH");
});

test("204 san kò konte kòm siksè", async () => {
  const transport = createApiTransport(apiConfig(), { fetchImpl: fakeFetch([{ status: 204 }]) });
  const result = await transport.send({ to: "a@b.com", subject: "s", text: "t", html: "h" });
  assert.equal(result.ok, true);
});

test("401 pa re-eseye (token an pa pral vin bon pou kont li)", async () => {
  const fetchImpl = fakeFetch([{ status: 401, body: { message: "Unauthorized" } }]);
  const mailer = createMailer({
    config: apiConfig({ maxRetries: 3 }),
    transport: createApiTransport(apiConfig(), { fetchImpl }),
  });

  await assert.rejects(mailer.sendOtp("a@b.com", "123456", 300), { code: "unauthorized" });
  assert.equal(fetchImpl.calls.length, 1, "yon sèl tantativ");
});

test("422 pa re-eseye non plis", async () => {
  const fetchImpl = fakeFetch([{ status: 422, body: { message: "Invalid" } }]);
  const transport = createApiTransport(apiConfig(), { fetchImpl });

  await assert.rejects(transport.send({ to: "pa-yon-imel", subject: "s" }), {
    code: "invalid_payload",
  });
});

test("500 re-eseye epi reyisi", async () => {
  const fetchImpl = fakeFetch([{ status: 500, body: {} }, { status: 204 }]);
  const config = apiConfig({ maxRetries: 2 });
  const mailer = createMailer({
    config,
    transport: createApiTransport(config, { fetchImpl }),
  });

  const result = await mailer.sendOtp("a@b.com", "123456", 300);
  assert.equal(result.ok, true);
  assert.equal(fetchImpl.calls.length, 2);
});

// --- Modèl imel ---

test("kòd la nan sijè a tou", () => {
  const email = otpEmail({ code: "123456", ttlSeconds: 300 });

  assert.match(email.subject, /123456/, "konsa moun nan li kòd la nan notifikasyon an");
  assert.match(email.text, /123456/);
  assert.match(email.html, /123456/);
  assert.match(email.text, /5 minit/);
});

test("imel la pa gen okenn lyen (pwoteksyon kont phishing)", () => {
  const email = otpEmail({ code: "123456", ttlSeconds: 300 });
  assert.ok(!/href=/i.test(email.html), "yon imel OTP san lyen pi difisil pou imite");
});

test("mailer console pa voye anyen deyò", async () => {
  const mailer = createMailer({ env: { MAIL_PROVIDER: "console" } });
  await mailer.sendOtp("a@b.com", "123456", 300);

  assert.equal(mailer.provider, "console");
  assert.equal(mailer.transport.sent.length, 1);
});
