# Contrat réel de l'API Bazik — capturé en sandbox

> Relevé le 14/09/2026 contre `https://api.bazik.io` avec le compte sandbox
> `bzk_sandbox_2a95e794_…`, via `bazik/scripts/probe*.js`.
>
> **La documentation publique de bazik.io est obsolète.** Ce fichier fait foi.
> Tout ce qui est codé dans `src/mapper.js` vient d'ici.

## 1. Différences avec la doc publique

| Doc publique | Réalité |
|---|---|
| `access_token`, `token_type`, `expires_in` | `token`, `expires_at` (epoch **ms absolu**) |
| `/account/balance` | `/balance` (interdit au type `transfer`) et `/wallet` |
| `/moncash/verify` | `/moncash/payments/{referenceId}`, `/order/{orderId}` |
| `/transfers/moncash` | `/moncash/transfers` (non listé, mais existant) |
| `/transfers/natcash` | `/natcash/transfers` |
| `/transfers/status` | `GET /transfers/{transactionId}` |
| « intégration gratuite » / « 2,9 % » | **5 % de frais** (`fee_percentage: 5`) |
| non documenté | `/transfers/quote`, `/moncash/customers/status` |

## 2. Type de compte — contrainte majeure

Le compte est de type **`transfer`**. L'API refuse explicitement :

```json
{ "error": "endpoint_not_authorized",
  "message": "Your account type (transfer) is not authorized to access this endpoint. This endpoint is available for: online, instore." }
```

| Endpoint | type `transfer` | Besoin |
|---|---|---|
| `POST /token` | ✅ | — |
| `GET /wallet` | ✅ | — |
| `POST /transfers/quote` | ✅ | — |
| `POST /moncash/transfers` | ✅ | — |
| `POST /natcash/transfers` | ✅ | — |
| `GET /transfers/{transactionId}` | ✅ | — |
| `POST /moncash/customers/status` | ⚠️ (upstream 500 en sandbox) | — |
| `POST /moncash/token` (encaissement) | ❌ 403 | compte `online`/`instore` |
| `POST /moncash/withdraw` | ❌ 403 | compte `online`/`instore` |
| `GET /balance` | ❌ 403 | compte `online`/`instore` |
| `GET /order/{orderId}` | ❌ 403 | compte `online`/`instore` |

**Conséquence** : avec ce compte, VOUPVAPCASH peut **envoyer** (payout, livraison)
mais pas **encaisser**. La recharge de wallet par MonCash exige un second compte
de type `online`. Le code d'encaissement existe et est testé contre le simulateur,
mais renverra `endpoint_not_authorized` tant que le compte n'est pas ouvert.

## 3. Endpoints

### `POST /token`

```json
// requête
{ "userID": "bzk_sandbox_…", "secretKey": "sk_sandbox_…" }
// réponse 200
{ "success": true, "token": "eyJ…", "user_id": "bzk_sandbox_…",
  "expires_at": 1789506365688, "message": "Authentication successful" }
```

`expires_at` est un **timestamp absolu en millisecondes**, pas une durée.

### `GET /wallet`

```json
{ "available": 0, "reserved": 0, "currency": "HTG",
  "environment": "sandbox", "last_updated": "2026-09-14T21:02:04.155954+00:00" }
```

Le solde Bazik doit être **préalimenté** : sans provision, aucun transfert ne part.

### `POST /transfers/quote`

```json
// requête — `provider` ∈ { moncash, natcash }
{ "amount": 500, "provider": "moncash" }
// réponse 200
{ "delivery_amount": 500, "fee": 25, "total_cost": 525, "currency": "HTG",
  "provider": "moncash", "fee_percentage": 5, "timestamp": "…", "environment": "sandbox" }
```

`total_cost = delivery_amount + fee`, frais **5 %** sur les deux réseaux.
C'est `total_cost` qui est débité du wallet Bazik, pas `delivery_amount`.

### `POST /moncash/transfers`

Champs requis (l'API accepte deux orthographes) :
`gdes` | `amount`, `wallet` | `receiver`, `description` | `desc`, `referenceId` | `reference`.

```json
{ "gdes": 500, "wallet": "37123456", "description": "…", "referenceId": "TRF_…" }
```

### `POST /natcash/transfers`

Champs requis : `gdes`, `wallet`, `customerFirstName`, `customerLastName`
(+ `description`, `referenceId`). **Le nom du bénéficiaire est obligatoire, contrairement à MonCash.**

### `GET /transfers/{transactionId}`

```json
// 404
{ "error": "Transfer not found", "message": "No transfer found with transaction ID: …" }
```

### `POST /moncash/customers/status`

Requiert `wallet`. En sandbox, l'upstream Digicel renvoie une 500
(`NullPointerException: "pin" is null`) — panne côté fournisseur, pas côté intégration.
À re-tester avant de s'appuyer dessus pour valider un numéro.

## 4. Règles métier vérifiées

| Règle | MonCash | NatCash |
|---|---|---|
| Montant minimum | **100 HTG** | **3 998 HTG** |
| Montant maximum | 75 000 HTG | 75 000 HTG (à confirmer) |
| Frais | 5 % | 5 % |

```json
// 400 amount_too_low
{ "error": "amount_too_low", "message": "Minimum Natcash transfer amount is 3998 HTG…",
  "minimum_amount": 3998, "requested_amount": 10, "currency": "HTG" }

// 400 amount_too_high
{ "error": "amount_too_high", "maximum_amount": 75000, "requested_amount": 100000 }

// 400 insufficient_balance
{ "error": "insufficient_balance",
  "message": "Your available balance (0.00 HTG) is insufficient for this transfer (105.00 HTG required including fees)",
  "required": 105, "available": 0 }
```

Le minimum NatCash de 3 998 HTG (~30 USD) est une contrainte produit forte :
la majorité des petits envois ne passeront pas par NatCash.

## 5. Reste à confirmer

- [ ] Format exact du **webhook** et de sa signature (`whsec_…`) — non observable
      sans déclencher un vrai transfert, donc bloqué tant que le wallet Bazik est à 0.
- [ ] Statuts renvoyés par `GET /transfers/{id}` sur un transfert réel.
- [ ] Plafond NatCash (75 000 supposé, non vérifié).
- [ ] Comportement de `referenceId` en doublon : rejet ou renvoi du transfert existant ?
      (déterminant pour l'idempotence — à tester dès que le wallet est provisionné)
