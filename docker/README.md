# Livraison Docker — VOUPVAPCASH

```
Internet ──► caddy (HTTPS, profil tls) ──► web (nginx : app Flutter + /api) ──► api (Node 24)
                                                                                  │
                                                                     volume app-data (/data)
                                                                     ├── app.db      (SQLite)
                                                                     ├── otp_db.json
                                                                     └── backups/
```

| Service | Image | Rôle |
|---|---|---|
| `api` | `docker/api/Dockerfile` | API, commissions, OTP, passerelle Bazik. **Aucun port publié.** |
| `web` | `docker/web/Dockerfile` | App Flutter web compilée, relais `/api` → `api`, limite de débit sur connexion/OTP |
| `caddy` | `caddy:2.10-alpine` | HTTPS Let's Encrypt automatique — seulement avec `--profile tls` |

Aucun secret n'entre dans les images : ils sont lus au démarrage depuis `server/.env`.

## Prérequis

- Docker Engine 24+ et Docker Compose 2.24+ (`docker compose version`).
- Pour le HTTPS : un nom de domaine dont le DNS pointe vers le serveur, ports 80 et 443 ouverts.
- La compilation Flutter demande environ 4 Go de RAM. Sur un petit VPS, construisez
  les images ailleurs puis poussez-les dans un registre (voir plus bas).

## Première installation

```sh
# 1. Secrets du serveur
cp server/.env.example server/.env
chmod 600 server/.env
#    À renseigner obligatoirement :
#    - OTP_SECRET            → openssl rand -hex 32
#    - BAZIK_MODE=live, BAZIK_USER_ID, BAZIK_SECRET_KEY, BAZIK_WEBHOOK_SECRET
#    - SMTP (Hostinger) ou HOSTINGER_MAIL_TOKEN
#    - CORS_ORIGINS=https://app.exemple.com

# 2. Paramètres de déploiement
cp .env.example .env
#    DOMAIN=app.exemple.com

# 3. Construire et démarrer (avec HTTPS)
docker compose --profile tls up -d --build

# 4. Vérifier : api et web doivent être "healthy"
docker compose ps
curl -fsS https://app.exemple.com/healthz

# 5. Créer le premier compte (propriétaire)
docker compose exec api node scripts/create_user.js \
  --email owner@exemple.com --password '…' --role owner --name "Nom Complet"
```

6. Dans le tableau de bord Bazik, déclarer le webhook :
   `https://app.exemple.com/api/bazik/webhook`

> Le mot de passe passé à `create_user.js` reste dans l'historique du shell :
> changez-le à la première connexion (Paramètres → mot de passe).

### Le serveur refuse de démarrer

C'est voulu. En production, `api` vérifie sa configuration avant d'accepter la
moindre requête et s'arrête avec la liste des problèmes :

```sh
docker compose logs api
```

| Message | Raison |
|---|---|
| `OTP_SECRET manke oswa twò kout` | sans secret, les codes OTP ne peuvent pas être vérifiés |
| `Pasrèl Bazik la an mòd fake` | sans clés Bazik, les « transferts » seraient simulés : l'agent serait débité, les commissions versées, mais aucun argent ne partirait |
| `BAZIK_WEBHOOK_SECRET manke` | les confirmations Bazik seraient rejetées, les transferts resteraient en vérification |
| `MAIL_PROVIDER=console entèdi` | les codes OTP partiraient dans les logs au lieu des e-mails |

Pour une démonstration sans vrai argent : `BAZIK_MODE=fake` et `ALLOW_FAKE_GATEWAY=true`.

## Sans le profil TLS

Si un reverse proxy existe déjà sur la machine (nginx, Traefik…), n'activez pas
`caddy` : `web` écoute sur `127.0.0.1:8080` (réglable par `HTTP_BIND` / `HTTP_PORT`
dans `.env`). Le proxy doit transmettre `X-Forwarded-For`, sinon la limite de
débit verra tous les agents avec la même adresse.

```sh
docker compose up -d --build
```

Un vhost nginx prêt à l'emploi pour `voupvapcash.tech` (TLS Let's Encrypt,
redirection `www` → apex, HSTS, `X-Forwarded-For`) est fourni dans
[`deploy/nginx/`](../deploy/nginx/README.md).

## Mise à jour

```sh
git pull
docker compose exec api node scripts/backup_db.js      # toujours avant
docker compose --profile tls up -d --build
docker compose ps
```

Le schéma de la base est mis à jour automatiquement au démarrage (colonnes
ajoutées, jamais supprimées). `api` finit les requêtes en cours avant de
s'arrêter (jusqu'à 25 s), pour ne pas couper un envoi Bazik au milieu.

## Sauvegardes

```sh
# Sauvegarde cohérente à chaud, vérifiée, 14 dernières gardées
docker compose exec api node scripts/backup_db.js

# Copier les sauvegardes hors du serveur
docker compose cp api:/data/backups ./backups
```

La sauvegarde utilise `VACUUM INTO` (instantané cohérent, même pendant des
écritures) puis `PRAGMA integrity_check` : une copie abîmée est supprimée et les
anciennes sont conservées. Options : `--keep 30`, `--dir /data/backups`.

Sauvegarde quotidienne à 3 h via le cron de l'hôte (`crontab -e`) :

```cron
0 3 * * * cd /chemin/vers/mon_premye_app && docker compose exec -T api node scripts/backup_db.js >> /var/log/voupvapcash-backup.log 2>&1
```

Une sauvegarde qui reste sur le même disque ne protège pas d'une panne du
serveur : copiez `backups/` ailleurs (stockage objet, autre machine).

### Restaurer

La copie passe par un conteneur éphémère lancé avec l'utilisateur de l'API :
un `docker cp` créerait un fichier appartenant à root, que le serveur ne
pourrait plus modifier.

```sh
docker compose stop api

# Depuis une sauvegarde restée dans le volume
docker compose run --rm --no-deps api sh -c \
  'rm -f /data/app.db-journal /data/app.db-wal /data/app.db-shm &&
   cp /data/backups/app-20260915-030000.db /data/app.db'

# … ou depuis un fichier de la machine (dossier ./backups)
docker compose run --rm --no-deps -v "$PWD/backups:/restore:ro" api sh -c \
  'rm -f /data/app.db-journal /data/app.db-wal /data/app.db-shm &&
   cp /restore/app-20260915-030000.db /data/app.db'

docker compose start api
```

Supprimer le journal est indispensable : un journal resté d'un arrêt brutal
serait « rejoué » par SQLite sur la base restaurée et la corromprait.

## Construire ailleurs, déployer sur le serveur

```sh
# Machine de build
APP_VERSION=1.0.0 docker compose build
docker tag voupvapcash-api:1.0.0 registre.exemple.com/voupvapcash-api:1.0.0
docker tag voupvapcash-web:1.0.0 registre.exemple.com/voupvapcash-web:1.0.0
docker push registre.exemple.com/voupvapcash-api:1.0.0
docker push registre.exemple.com/voupvapcash-web:1.0.0
```

Sur le serveur, pointez `image:` vers le registre et lancez `docker compose up -d`
sans `--build`. Pour un serveur amd64 depuis un Mac Apple Silicon, ajoutez
`--platform linux/amd64` au build.

## Tests dans l'image

```sh
docker build -f docker/api/Dockerfile --target test .
```

Exécute les tests `bazik` et `server` sur la même version de Node que la production.

## Sécurité en place

- Conteneurs non-root, système de fichiers en lecture seule, aucune capacité Linux.
- L'API n'est joignable que par `web` ; seuls `web` (ou `caddy`) publient un port.
- `web` n'écoute que sur `127.0.0.1` par défaut.
- Limite de 20 requêtes/minute par IP (rafale de 10) sur connexion et OTP.
- En-têtes `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, HSTS via Caddy.
- Logs Docker plafonnés (5 × 10 Mo par service).

## Limites

- **Une seule instance de `api`.** SQLite, le fichier OTP et la limite de
  tentatives de connexion (en mémoire) ne supportent pas plusieurs réplicas.
  Ne pas utiliser `--scale api=2`.
- **L'app Android/iOS** n'a pas d'origine de page : elle doit être compilée avec
  une URL absolue, `--dart-define=API_BASE_URL=https://app.exemple.com`.
