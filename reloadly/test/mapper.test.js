"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const mapper = require("../src/mapper");

const fixture = (name) => require(`./fixtures/${name}`);

test("operatè: fiksti SDK Digicel Haiti li kòrèkteman", () => {
  const op = mapper.readOperator(fixture("operator_digicel_haiti.json"));

  assert.equal(op.operatorId, 173);
  assert.equal(op.name, "Digicel Haiti");
  assert.equal(op.countryCode, "HT");
  assert.equal(op.denominationType, "RANGE");
  assert.equal(op.senderCurrency, "USD");
  assert.equal(op.destinationCurrency, "HTG");
  assert.equal(op.supportsLocalAmounts, false);
  assert.equal(op.fxRate, 68);
  assert.equal(op.minMinor, 500);
  assert.equal(op.maxMinor, 7000);
  assert.equal(op.localMinMinor, 0, "`null` pa dwe tounen yon limit");
  assert.deepEqual(op.fixedMinor, []);
  assert.equal(op.suggestedMinor[0], 500);
  assert.equal(op.isPin || op.isData || op.isBundle, false);
});

test("rechaj: repons SDK la san `status` men ak `transactionId` = reyisi", () => {
  const topup = mapper.readTopup(fixture("topup_digicel_haiti.json"));

  assert.equal(topup.gatewayId, "10670");
  assert.equal(topup.status, "completed");
  assert.equal(topup.rawStatus, "");
  assert.equal(topup.requestedMinor, 1500);
  assert.equal(topup.deliveredMinor, 108931);
  assert.equal(topup.deliveredCurrency, "HTG");
  assert.equal(topup.discountMinor, 180);
  assert.equal(topup.balanceAfterMinor, 163536);
});

test("estati: fiksti SDK Natcom Haiti SUCCESSFUL", () => {
  const status = mapper.readStatusResponse(fixture("status_natcom_haiti.json"));

  assert.equal(status.status, "completed");
  assert.equal(status.topup.operatorName, "Natcom Haiti");
  assert.equal(status.topup.deliveredMinor, 197712);
});

test("estati: REFUNDED ak FAILED se echèk, estati enkoni pa deside anyen", () => {
  assert.equal(mapper.normalizeStatus("REFUNDED"), "failed");
  assert.equal(mapper.normalizeStatus("FAILED"), "failed");
  assert.equal(mapper.normalizeStatus("PROCESSING"), "processing");
  assert.equal(mapper.normalizeStatus("SUCCESSFUL"), "completed");
  assert.equal(mapper.normalizeStatus("SOMETHING_NEW"), "");
});

test("rechaj san `transactionId` ni estati: pa janm konsidere reyisi", () => {
  assert.equal(mapper.readTopup({}).status, "");
});

test("sòld: fiksti SDK", () => {
  assert.deepEqual(
    { ...mapper.readBalanceResponse(fixture("account_balance.json")), raw: undefined },
    { balanceMinor: 100000, currency: "USD", raw: undefined }
  );
});

test("nimewo Ayiti: tout fòm kouran yo bay +509 ak 8 chif", () => {
  for (const input of ["37123456", "3712 3456", "+509 3712-3456", "50937123456", "(509) 37 12 34 56"]) {
    assert.equal(mapper.normalizeHaitiPhone(input).international, "+50937123456", input);
  }

  for (const input of ["", "3712345", "371234567", "+1 305 555 1234"]) {
    assert.throws(() => mapper.normalizeHaitiPhone(input), { code: "invalid_phone" }, input);
  }
});

test("demann rechaj: fòm `PhoneTopupRequest` SDK a", () => {
  assert.deepEqual(
    mapper.buildTopupRequest({
      operatorId: "173",
      amountMinor: 1500,
      useLocalAmount: false,
      customIdentifier: "AIR_x",
      phone: "3637 7111",
    }),
    {
      operatorId: 173,
      amount: 15,
      useLocalAmount: false,
      customIdentifier: "AIR_x",
      recipientPhone: { countryCode: "HT", number: "+50936377111" },
    }
  );
});

test("erè: `errorCode` Reloadly tounen yon kòd miniskil", () => {
  const error = mapper.readErrorResponse({
    timeStamp: "2026-09-17 10:00:00",
    message: "Invalid amount for operator",
    path: "/topups",
    errorCode: "INVALID_AMOUNT_FOR_OPERATOR",
    infoLink: "https://docs.reloadly.com",
    details: [],
  });

  assert.equal(error.code, "invalid_amount_for_operator");
  assert.equal(error.rawCode, "INVALID_AMOUNT_FOR_OPERATOR");
  assert.equal(error.message, "Invalid amount for operator");
});

// --- Repons REYÈL sandbox la (17/09/2026) --------------------------------------

test("sandbox: rechaj Digicel 4 USD — estati eksplisit, montan livre, remiz 2%", () => {
  const topup = mapper.readTopup(fixture("sandbox_topup_digicel_2026.json"));

  assert.equal(topup.status, "completed");
  assert.equal(topup.rawStatus, "SUCCESSFUL");
  assert.equal(topup.gatewayId, "179870");
  assert.equal(topup.requestedMinor, 400);
  assert.equal(topup.deliveredMinor, 52357);
  assert.equal(topup.discountMinor, 8, "4 USD × 2% = 0,08 USD: se tout maj antrepriz la");
  assert.equal(topup.balanceAfterMinor, 98104);
});

test("sandbox: operatè Digicel 2026 — limit reyèl ak estati", () => {
  const op = mapper.readOperator(fixture("sandbox_operator_digicel_2026.json"));

  assert.equal(op.minMinor, 400);
  assert.equal(op.maxMinor, 10000);
  assert.equal(op.fxRate, 121.4599991);
  assert.equal(op.status, "ACTIVE");
  assert.equal(op.suggestedMinor[0], 400);
});

test("sandbox: kòd erè reyèl yo tounen kòd nou konnen", () => {
  const errors = fixture("sandbox_errors_2026.json");

  assert.equal(mapper.readErrorResponse(errors.amountBelowMinimum.body).code, "invalid_amount_for_operator");
  assert.equal(mapper.readErrorResponse(errors.landlineAutoDetect.body).code, "could_not_auto_detect_operator");
  assert.equal(mapper.readErrorResponse(errors.customIdentifierReused.body).code, "custom_identifier_already_used");
});
