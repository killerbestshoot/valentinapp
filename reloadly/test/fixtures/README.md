# Fiksti Reloadly

Kopye tel kel (san `logoUrls`, `promotions`, `geographicalRechargePlans`) depi
SDK Java ofisyèl la, `Reloadly/reloadly-sdk-java`, branch `main`,
`java-sdk-airtime/src/test/resources/`:

| Fichye isit la | Sous |
|---|---|
| `operator_digicel_haiti.json` | `operator/operator_auto_detect_unfiltered.json` |
| `topup_digicel_haiti.json` | `topup/phone_topup_transaction.json` |
| `status_natcom_haiti.json` | `topup/phone_topup_transaction_status.json` |
| `account_balance.json` | `account/account_balance.json` |

Se repons Reloadly te pwodui (2021–2022), pa repons nou envante. Chif yo
(limit, to, remiz) ka fin chanje: se FÒM yo tès yo verifye.

## Repons sandbox (17/09/2026)

Obsève sou `https://topups-sandbox.reloadly.com` ak kont sandbox antrepriz la.
Nimewo benefisyè a ranplase pa `50937123456`; tout lòt chan yo tel kel.

| Fichye | Sa li montre |
|---|---|
| `sandbox_topup_digicel_2026.json` | `POST /topups` reponn AK `status: "SUCCESSFUL"`, e `balanceInfo.cost` |
| `sandbox_operator_digicel_2026.json` | Digicel Haiti: RANGE 4–100 USD, remiz 2%, `status: "ACTIVE"` |
| `sandbox_errors_2026.json` | kòd erè reyèl: montan anba minimòm, fiks, `customIdentifier` deja itilize |

