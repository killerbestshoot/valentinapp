# Intégration Bazik.io — VOUPVAPCASH

Passerelle MonCash / NatCash (Bazik) pour l'app. Le module est **sans dépendance
externe** : SQLite est celui intégré à Node (`node:sqlite`), les tests utilisent
`node:test`, et les appels HTTP passent par `fetch` natif. Aucun `npm install`
n'est nécessaire pour développer ou tester.

## Règle d'architecture

**La clé secrète Bazik ne doit jamais être dans l'app Flutter.** Elle serait
extractible d'un APK en quelques minutes. Tout appel à Bazik part du serveur :

```
Flutter (PaymentGateway)
   │  HTTP + Bearer token  (serveur Express, server/)
   ▼
bazik/src/service.js  ← façade
   ├── client.js       → api.bazik.io          (jamais appelé depuis le mobile)
   ├── transfer.js     → cas d'usage sortants
   ├── topup.js        → cas d'usage entrants
   ├── webhook.js      → réception signée + idempotente
   └── store/          → sqlite_store.js (base partagée server/data/app.db)
```

Le store expose des **opérations atomiques de haut niveau** (`settleTransfer`,
`settleTopup`) plutôt que des transactions brutes : impossible de créditer un
wallet sans marquer l'opération, ou l'inverse.

## Démarrer

```sh
# Tests (SQLite en mémoire, aucun réseau)
cd bazik && npm test

# Serveur + base SQLite
cd server && npm run dev                                   # http://127.0.0.1:4500
```

L'identité vient **uniquement** de la session (`Authorization: Bearer`), jamais
d'un champ envoyé par le client : l'uid, l'entreprise et son nom sont lus côté
serveur.

```sh
TOKEN=$(curl -s -X POST http://127.0.0.1:4500/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"admin@x.com","password":"…"}' | jq -r .token)

curl -X POST http://127.0.0.1:4500/api/bazik/quote \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"amount":10,"network":"moncash"}'
```

### Envoyer un transfert depuis le terminal

```sh
# Pré-vol : token, float, devis, limites — n'envoie rien
node bazik/scripts/send_transfer.js --phone 37123456 --gdes 500

# Envoi réel
node bazik/scripts/send_transfer.js --phone 37123456 --gdes 500 --send

# NatCash : nom du bénéficiaire obligatoire, minimum 3 998 HTG
node bazik/scripts/send_transfer.js --network natcash --phone 37123456 \
     --gdes 4000 --name "Jean Bastien" --send

# Suivre un transfert déjà parti
node bazik/scripts/send_transfer.js --status <transactionId>
```

Le script est en **pré-vol par défaut** : il vérifie le montant contre les
limites du réseau, lit le float Bazik, demande le devis, et refuse d'envoyer si
la provision est insuffisante — sans jamais appeler l'endpoint de transfert.
`--send` est le seul mode qui déplace de l'argent.

Les montants sont en **HTG** (`--gdes`), comme l'API. Pour tester le chemin
complet sans float, forcez le simulateur :

```sh
BAZIK_MODE=fake node bazik/scripts/send_transfer.js --phone 37123456 --gdes 500 --send
```

### Modes

`BAZIK_MODE` vaut `fake` (par défaut sans clés), `sandbox` ou `live`.
Le mode `fake` reproduit fidèlement le vrai comportement — frais 5 %, minimums
par réseau, `insufficient_balance` — et permet de jouer les cas d'échec,
presque impossibles à provoquer sur la sandbox.

Les clés vivent dans **`server/.env`**, couvert par `.gitignore` (`*.env`).
C'est la source unique : le serveur et les scripts y lisent tous les deux.

## Ce qui est réellement possible aujourd'hui

Le contrat a été relevé sur la sandbox : voir [`docs/contract.md`](docs/contract.md).
**La documentation publique de bazik.io est obsolète** sur presque tous les points.

Le compte sandbox est de type **`transfer`**, ce qui donne :

| Flux | État |
|---|---|
| Envoi MonCash (`/moncash/transfers`) | ✅ opérationnel |
| Envoi NatCash (`/natcash/transfers`) | ✅ opérationnel (min. 3 998 HTG) |
| Devis (`/transfers/quote`) | ✅ frais 5 % confirmés |
| Statut (`/transfers/{id}`) | ✅ |
| Solde passerelle (`/wallet`) | ✅ |
| **Encaissement** (`/moncash/token`) | ❌ 403 — exige un compte `online`/`instore` |
| `/moncash/withdraw`, `/balance`, `/order/{id}` | ❌ 403 — idem |

Le code d'encaissement (`topup.js`) est écrit et testé contre le simulateur ;
il lève `cash_in_unavailable` tant qu'un compte `online` n'est pas ouvert.
Aucune UI de recharge n'a été construite : ce serait une interface pour un flux
qui ne peut pas aboutir.

Deux contraintes à connaître avant de vendre le service :
- **frais 5 %** sur chaque transfert (`total_cost = montant + 5 %`), débités du
  wallet Bazik — donc du wallet de l'agent ;
- **minimum NatCash : 3 998 HTG** (~30 USD), contre 100 HTG en MonCash.

## Invariants garantis par les tests

- Le wallet est débité **avant** l'appel à Bazik ; tout échec rembourse
  exactement ce qui a été débité, **frais compris**.
- Deux webhooks identiques ne remboursent qu'une fois (idempotence sur
  `eventId` *et* sur l'état du transfert).
- Un double-clic produit un seul transfert (même seed → même `referenceId`).
- Une transaction passe `delivered` **uniquement** sur confirmation Bazik —
  c'est ce qui déclenche les commissions (`server/src/commission/engine.js`).
- Les IDs générés en Node sont **identiques** à ceux du Dart
  (`test/bazik_id_parity_test.dart` ↔ `bazik/test/ids_money.test.js`).
- L'argent est manipulé en centimes entiers, jamais en `double`.

## Passer en production

1. **Secrets** : `BAZIK_MODE=live` et les clés live dans `server/.env` (jamais
   dans le dépôt, jamais dans l'app Flutter).
2. **Webhook** : déclarer `https://<domaine>/api/bazik/webhook` dans le tableau
   de bord Bazik, avec `BAZIK_WEBHOOK_SECRET`. Sans secret, le webhook n'est
   accepté qu'en mode `fake`.
3. **Float** : approvisionner le wallet Bazik — la page « Santé système » de
   l'app le signale quand il est vide.

## Reste à confirmer

- Format exact du webhook et de sa signature — non observable tant que le wallet
  Bazik est à 0 (aucun transfert ne peut partir). `webhook.js` applique
  HMAC-SHA256 sur le corps brut, avec plusieurs noms d'en-tête tolérés ; à
  ajuster **à un seul endroit** au premier vrai webhook.
- Comportement d'un `referenceId` en doublon côté Bazik : rejet ou renvoi de
  l'existant ? Déterminant pour l'idempotence de bout en bout.
- `/moncash/customers/status` renvoie une 500 upstream (Digicel) en sandbox.
