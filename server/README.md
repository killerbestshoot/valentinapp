# Serveur VOUPVAPCASH

Backend unique de l'app : authentification, données et passerelle Bazik, sur
une seule base SQLite (`server/data/app.db`, `node:sqlite`, Node ≥ 22).

| Route | Rôle |
|---|---|
| `/api/auth` | connexion e-mail + mot de passe, session, changement de mot de passe |
| `/api/users` | staff de l'entreprise (hiérarchie owner > admin > agent) |
| `/api/transactions` | création, liste, statistiques, statut |
| `/api/wallets` | soldes, historique, taux, recharges (avec conversion de devise) |
| `/api/commissions`, `/api/services` | commissions et taux par service |
| `/api/payouts` | demandes de retrait, approbation → transfert Bazik |
| `/api/system` | santé et notifications |
| `/api/otp` | codes OTP par e-mail (Hostinger) |
| `/api/bazik` | passerelle MonCash / NatCash (voir [`bazik/README.md`](../bazik/README.md)) |

```sh
npm run dev     # http://127.0.0.1:4500
npm test        # tests auth, hiérarchie, commissions, mail, OTP — sans réseau
node scripts/create_user.js --email admin@x.com --password '…' --role admin
node scripts/create_user.js --list
```

Toutes les routes sauf `/api/auth/login`, `/api/otp` et le webhook Bazik
exigent `Authorization: Bearer <token>`.

## Envoi d'e-mails

Le code ne connaît pas le transport : il appelle `getMailer().sendOtp(...)`, et
`MAIL_PROVIDER` décide. Quatre valeurs possibles :

| `MAIL_PROVIDER` | Transport | Quand l'utiliser |
|---|---|---|
| `hostinger_smtp` | `smtp.hostinger.com:465` (SSL) | Le cas normal |
| `hostinger_api` | `POST api.mail.hostinger.com/api/v1/mailboxes/{id}/send` | Quand les ports SMTP sortants sont bloqués |
| `gmail` | SMTP Gmail | La configuration actuelle, conservée pour la transition |
| `console` | Aucun — le code s'écrit dans les logs | Dev uniquement ; **refusé** si `NODE_ENV=production` |

Sans `MAIL_PROVIDER`, le provider est déduit : un `HOSTINGER_MAIL_TOKEN` donne
`hostinger_api`, un `SMTP_USER` en `@gmail.com` donne `gmail`, sinon
`hostinger_smtp`. La configuration Gmail en place continue donc de fonctionner
sans rien changer.

### Hostinger par SMTP

```env
MAIL_PROVIDER=hostinger_smtp
SMTP_HOST=smtp.hostinger.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=no-reply@votre-domaine.com
SMTP_PASS=<mot de passe de la boîte mail>
MAIL_FROM_NAME=VOUPVAPCASH
```

Les valeurs exactes sont dans hPanel → **Emails → Mailboxes → Connect apps &
devices → Advanced settings**. Le mot de passe est celui de la boîte mail,
pas celui du compte Hostinger.

Si le port 465 est bloqué par le réseau, basculez en STARTTLS :
`SMTP_PORT=587` et `SMTP_SECURE=false`.

### Hostinger par API HTTP

```env
MAIL_PROVIDER=hostinger_api
HOSTINGER_MAIL_TOKEN=<jeton>
HOSTINGER_MAILBOX_ID=<resource id, ex. AC1a2b3c4d5e6f7g>
```

Le jeton se crée dans hPanel, onglet de provisionnement e-mail ; il est **limité
à une seule boîte mail**. L'adresse d'expéditeur n'est pas dans la requête :
c'est la boîte à laquelle le jeton donne accès. `MAIL_FROM_NAME` ne change que
le nom affiché.

Intérêt réel de cette voie : le jour où l'envoi partira de Cloud Functions,
beaucoup d'environnements serverless bloquent les ports SMTP sortants. Le
basculement est alors une variable d'environnement, pas une réécriture.

### Vérifier la configuration sans envoyer

```sh
curl http://127.0.0.1:4500/api/otp/health
```

En SMTP, cela ouvre réellement la connexion et authentifie (`transporter.verify()`).
En API, cela ne valide que la présence du jeton — Hostinger n'expose pas de ping ;
le vrai test est le premier envoi.

## Ce qui protège les OTP

Le stockage précédent gardait les codes **en clair** dans un JSON, sans limite de
tentatives : un code à 6 chiffres se force en quelques minutes. Désormais :

- seul un **HMAC-SHA256** du code est écrit sur disque (`OTP_SECRET`, obligatoire
  en production), lié à l'adresse e-mail — un hash volé ne sert pas ailleurs ;
- **5 tentatives** maximum, après quoi le code meurt ;
- **60 secondes** entre deux envois vers la même adresse — cela protège aussi
  votre quota Hostinger, qui est limité par boîte et par jour ;
- un code ne sert **qu'une fois** ;
- comparaison en temps constant ;
- les codes sont tirés avec `crypto.randomInt`, jamais `Math.random()`.

L'e-mail place le code **dans le sujet** (visible depuis la notification) et ne
contient **aucun lien** — un message OTP sans lien est plus difficile à imiter
pour du hameçonnage.

Réglages : `OTP_TTL_SECONDS`, `OTP_MAX_ATTEMPTS`, `OTP_RESEND_COOLDOWN_SECONDS`.

## Limites connues

- Le stockage OTP est un fichier JSON : suffisant pour le développement, mais il
  ne résiste pas à plusieurs instances du serveur en parallèle. À déplacer dans
  SQLite avant une mise en production.
- Il n'y a pas encore de limite par adresse IP, seulement par adresse e-mail. Un
  attaquant disposant de nombreuses adresses peut toujours consommer du quota.
- Hostinger applique un plafond d'envois par boîte et par jour, variable selon le
  plan : à vérifier avant une montée en charge.
