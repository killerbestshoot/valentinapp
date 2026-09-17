# Contrat de l'API Reloadly Airtime — Minit Haiti

> Relevé le 17/09/2026 dans le **SDK Java officiel** `Reloadly/reloadly-sdk-java`
> (branche `main`, dernier push 26/02/2025) : constantes, DTO et fixtures de test.
>
> **Pas dans la documentation publique** : `docs.reloadly.com` est une application
> JavaScript illisible sans navigateur, et l'intégration Bazik a montré qu'une
> documentation peut ne pas correspondre à l'API. Le SDK est du code que Reloadly
> exécute contre sa propre API.
>
> **Vérifié sur la sandbox le 17/09/2026** (`topups-sandbox.reloadly.com`) : jeton,
> solde, auto-detect, recharges réelles Digicel (#179870, #179871, #179873) et
> Natcom en montant local (#179872), statut, rapport par `customIdentifier`,
> erreurs. Réponses brutes : `reloadly/test/fixtures/sandbox_*_2026.json`.

## 1. Authentification

`POST https://auth.reloadly.com/oauth/token` (`AuthenticationAPI.BASE_URL`)

```json
{ "client_id": "…", "client_secret": "…",
  "grant_type": "client_credentials",
  "audience": "https://topups-sandbox.reloadly.com" }
```

Réponse (`TokenHolder`) : `access_token`, `token_type`, `expires_in` (secondes).

L'`audience` est l'URL du service (`service.getServiceUrl()`) : un jeton sandbox ne
vaut pas en live.

## 2. URL et en-têtes

| Mode | URL (`ServiceURLs`) |
|---|---|
| sandbox | `https://topups-sandbox.reloadly.com` |
| live | `https://topups.reloadly.com` |

Chaque appel : `Authorization: Bearer …` et
`Accept: application/com.reloadly.topups-v1+json` (`Version.AIRTIME_V1`).

## 3. Endpoints utilisés

| Usage | Endpoint (classe SDK) |
|---|---|
| Solde du compte | `GET /accounts/balance` (`AccountOperations`) |
| Opérateur d'un numéro | `GET /operators/auto-detect/phone/{+509…}/countries/HT` (`OperatorOperations`) |
| Opérateur par id | `GET /operators/{operatorId}` |
| Recharge | `POST /topups` (`TopupOperations.send`) |
| Statut | `GET /topups/{transactionId}/status` |
| Retrouver par notre id | `GET /topups/reports/transactions?customIdentifier=…` (`TransactionHistoryFilter`) |

Filtres opérateur (`OperatorFilter`) : `suggestedAmounts`, `includeData`,
`includeBundles`, `includePin`, `includeRange`, `includeFixed`.

## 4. Recharge

Requête (`PhoneTopupRequest`) :

```json
{ "operatorId": 173, "amount": 15, "useLocalAmount": false,
  "customIdentifier": "AIR_…",
  "recipientPhone": { "countryCode": "HT", "number": "+50936377111" } }
```

Réponse (`TopupTransaction`, fixture `phone_topup_transaction.json`) :
`transactionId`, `operatorTransactionId`, `customIdentifier`, `operatorId`,
`operatorName`, `requestedAmount` + devise, `deliveredAmount` + devise, `discount` +
devise, `transactionDate`, `balanceInfo { oldBalance, newBalance, currencyCode }`.

- `requestedAmount` est dans la devise du compte (USD), `deliveredAmount` dans celle
  de l'opérateur (HTG).
- Le compte est débité de `requestedAmount − discount`
  (fixture : 1648,56 → 1635,36 pour 15 − 1,80).
- **La remise (`discount`) est la marge de l'entreprise** sur chaque recharge.

Statuts (`AirtimeTransactionStatus`) : `PROCESSING`, `SUCCESSFUL`, `REFUNDED`, `FAILED`.
`REFUNDED` = échec pour l'agent (Reloadly recrédite le compte).

## 5. Opérateur

Champs lus (`Operator`) : `id`/`operatorId`, `name`, `country.isoName`,
`denominationType` (`RANGE` | `FIXED`), `senderCurrencyCode`,
`destinationCurrencyCode`, `supportsLocalAmounts`, `minAmount`, `maxAmount`,
`localMinAmount`, `localMaxAmount`, `fixedAmounts`, `localFixedAmounts`,
`suggestedAmounts`, `fx.rate`, `data`, `bundle`, `pin`.

Fixture Digicel Haiti (2021) : `RANGE` 5–70 USD, `supportsLocalAmounts: false`,
`fx.rate` 68. **Ces chiffres datent de 2021** : les vraies limites viennent de
l'auto-detect, jamais d'une constante dans le code.

## 6. Erreurs

`APIError` : `timeStamp`, `message`, `path`, `errorCode`, `infoLink`, `details`.
Nous passons `errorCode` en minuscules (`INVALID_AMOUNT_FOR_OPERATOR` →
`invalid_amount_for_operator`).

## 7. Choix d'intégration

| Règle | Pourquoi |
|---|---|
| Montant saisi dans la devise du **wallet** ; `useLocalAmount` seulement si wallet = devise opérateur et `supportsLocalAmounts` | aucune conversion cachée |
| Wallet débité **avant** l'appel, dans la même transaction que la ligne | pas de minutes livrées sans trace |
| Jeton obtenu **avant** le débit | une panne `auth.reloadly.com` ne crée pas de recharge « en vérification » |
| `POST /topups` jamais rejoué sur délai dépassé / 5xx | la recharge a pu passer |
| Délai dépassé / 5xx → pas de remboursement, `processing` | rembourser des minutes livrées = perte sèche |
| Refus 4xx → remboursement exact | Reloadly n'a rien traité |
| `customIdentifier` = notre `topup_id` | seul moyen de retrouver une recharge sans `transactionId` |
| « Introuvable » → pas de remboursement automatique | absence dans un rapport ≠ recharge non partie |

## 8. Observé sur la sandbox (17/09/2026)

### Réponses

- [x] `POST /topups` renvoie **`"status": "SUCCESSFUL"`** (absent de la fixture 2021),
      plus `fee` et `balanceInfo.cost` (coût réel débité du compte).
- [x] `GET /topups/{id}/status` : `{ code, message, status, transaction }`, conforme au SDK.
- [x] `GET /topups/reports/transactions?customIdentifier=…` trouve la recharge
      **immédiatement** (0 ms après la réponse), avec son `status`.
- [x] Un id `AIR_…` de 40 caractères est accepté comme `customIdentifier`.
- [x] Latence d'une recharge synchrone : 280 à 820 ms.
- [x] Opérateurs : champ `status: "ACTIVE"` et objet `fees` (tout à 0).

### Opérateurs Haïti

| # | Nom | Plage | Taux (`fx.rate`) | Local | Remise | Remise locale |
|---|---|---|---|---|---|---|
| 173 | Digicel Haiti | 4 – 100 USD | 121,46 | non | **2 %** | 0 % |
| 174 | Natcom Haiti | 0,50 – 99,24 USD | 131 | 65 – 13 000 HTG | **5 %** | **0 %** |
| 172 | Digicel Haiti Bundles | FIXED | 133 | non | 2 % | `bundle: true` |
| 682 | Natcom Haiti Bundles | FIXED | 131,25 | non | 2 % | `bundle: true` |
| 1296 | Natcom Haiti Special Bundle | FIXED | 1 | non | 10 % | **`bundle: false`** |

- **La remise est toute la marge** : 0,08 USD sur une recharge Digicel de 4 USD.
- **En montant local (wallet HTG → Natcom), la remise est 0 %** : aucune marge.
- **#1296 est un forfait non marqué `bundle`** : le filtre sur les drapeaux ne suffit
  pas. D'où la règle : l'opérateur vient **toujours** de l'auto-detect du numéro, et un
  `operatorId` différent envoyé par le client est refusé (`operator_mismatch`).
- L'auto-detect a renvoyé 173 et 174 (pas les forfaits) avec les filtres
  `includeData/Bundles/Pin=false`.

### Erreurs

| Cas | HTTP | `errorCode` |
|---|---|---|
| Montant sous le minimum | 400 | `INVALID_AMOUNT_FOR_OPERATOR` (« minimum amount for this operator is 4.00 USD ») |
| Numéro fixe (`+50922…`) | 404 | `COULD_NOT_AUTO_DETECT_OPERATOR` |
| **`customIdentifier` déjà utilisé** | **400** | **`CUSTOM_IDENTIFIER_ALREADY_USED`** |

`CUSTOM_IDENTIFIER_ALREADY_USED` est un 400 qui ne signifie **pas** « refusé » :
Reloadly a **déjà traité** une recharge avec cet id. Rembourser offrirait les minutes.
Le code la retrouve par `customIdentifier` et la clôture (cas réel : base restaurée
depuis une sauvegarde qui ne connaissait pas la recharge).

### Taux de change

`POST /operators/{id}/fx-rate` `{ "amount": 4 }` → `{ "fxRate": 485.84 }`. Malgré son
nom, **`fxRate` est le montant total converti**, pas un taux (10 USD → 1214,6).
Il vaut `fx.rate × montant` : c'est l'estimation que nous affichons.

**Écart en sandbox** : Digicel 4 USD, estimation et `fx-rate` = 485,84 HTG, mais
`deliveredAmount` = **523,57 HTG** (≈ 130,89/USD, proche du taux Natcom). Probable
simulation sandbox. **À comparer sur les premières recharges live** : l'écran affiche
« estimation » avant l'envoi et le montant réellement livré après.

## 9. Reste à confirmer en live

- [ ] `deliveredAmount` égal à l'estimation (`fx.rate × montant`) ?
- [ ] Remises du compte live (celles de la sandbox : 2 % Digicel, 5 % Natcom).
- [ ] Recharge `PROCESSING` : jamais observée en sandbox (toutes `SUCCESSFUL` en synchrone).
