# VOUPVAPCASH

Application de transfert d'argent pour agents, administrateurs et propriétaires
d'entreprise en Haïti : envois MonCash / NatCash via Bazik, wallets multi-devises
(HTG, USD, MXN…), commissions, retraits et supervision.

## Architecture

```
Flutter (lib/)  ──HTTP + Bearer token──►  server/ (Express, port 4500)
                                              │
                                              ├── SQLite : server/data/app.db
                                              ├── bazik/  → api.bazik.io
                                              └── Hostinger → e-mails OTP
```

- **Aucun Firebase.** Toutes les données vivent dans une seule base SQLite
  côté serveur ; l'app ne garde qu'un jeton de session.
- **Session courte.** Sans signe de navigation pendant 5 minutes, la session
  se ferme des deux côtés : l'app renvoie sur l'écran de connexion et le
  serveur supprime le jeton (`SESSION_IDLE_MINUTES`, plafond absolu
  `SESSION_TTL_HOURS`).
- **Aucun secret dans l'app.** Les clés Bazik et SMTP sont dans `server/.env`
  (ignoré par git — modèle : `server/.env.example`).
- L'argent est stocké en centimes entiers ; chaque mouvement de wallet laisse
  une ligne dans `wallet_ledger`, écrite dans la même transaction que le solde.

| Dossier | Contenu |
|---|---|
| `lib/app/` | app, routeur (`go_router`) et gardes de rôle |
| `lib/core/` | client HTTP, session, configuration, rôles |
| `lib/features/` | accès API par domaine (auth, transactions, users, wallet, payments, operations) |
| `lib/pages/` | écrans |
| `server/` | API, authentification, commissions, OTP — voir [`server/README.md`](server/README.md) |
| `bazik/` | intégration Bazik — voir [`bazik/README.md`](bazik/README.md) |

## Rôles

`owner` > `admin` > `agent` > `client`. La hiérarchie est appliquée **par le
serveur** (un admin ne peut ni créer ni modifier un owner, personne ne se modifie
soi-même) ; le routeur Flutter ne fait que masquer les écrans.

- owner et admin → `/admin` (tableau de bord entreprise ; `/owner` y mène aussi)
- agent et client → `/dashboard`

## Démarrer

```sh
# 1. Serveur
cd server
cp .env.example .env          # puis renseigner les clés
npm install
node scripts/create_user.js --email admin@exemple.com --password '…' --role admin
npm run dev                   # http://127.0.0.1:4500

# 2. App
flutter pub get
flutter run -d chrome
# autre serveur : --dart-define=API_BASE_URL=https://api.exemple.com
```

Sans serveur, l'app tourne en démonstration avec
`--dart-define=MOCK_FIREBASE=true` (nom historique : le mode n'a plus de lien
avec Firebase). Raccourcis : `owner@…`, `admin@…`, `client@…`, tout autre e-mail
= agent.

## Livraison (Docker)

```sh
cp server/.env.example server/.env   # secrets : OTP_SECRET, Bazik, SMTP
cp .env.example .env                 # DOMAIN
docker compose --profile tls up -d --build
```

Guide complet (sauvegardes, mises à jour, restauration) : [`docker/README.md`](docker/README.md).

## Tests

```sh
flutter analyze && flutter test     # app
cd server && npm test               # auth, hiérarchie, commissions, mail, OTP
cd bazik && npm test                # transferts, webhooks, idempotence, argent
```
