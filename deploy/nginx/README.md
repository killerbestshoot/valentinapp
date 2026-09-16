# nginx de l'hôte — voupvapcash.tech

Alternative au profil `tls` de docker compose (Caddy) : c'est nginx, installé
sur la machine, qui termine le TLS et relaie vers le conteneur `web`.

```
Internet ──► nginx (hôte : 80/443, TLS) ──► 127.0.0.1:8080 ──► web ──► api
```

N'activez pas les deux : `docker compose --profile tls up -d` ferait écouter
Caddy sur 80/443, déjà pris par nginx.

## Prérequis

- Le DNS de `voupvapcash.tech` **et** `www.voupvapcash.tech` pointe vers ce serveur
  (enregistrements A, et AAAA si le serveur a une IPv6).
- Ports 80 et 443 ouverts.
- `nginx` et `certbot` installés :
  `sudo apt install nginx certbot python3-certbot-nginx`
- L'app tourne : `docker compose up -d --build` (sans `--profile tls`), avec
  `HTTP_BIND=127.0.0.1` et `HTTP_PORT=8080` dans `.env` — les valeurs par défaut.

Vérifiez avant de continuer :

```sh
curl -fsS http://127.0.0.1:8080/healthz    # → {"ok":true}
```

## Première installation

```sh
# 1. Dossier du défi ACME
sudo mkdir -p /var/www/certbot

# 2. vhost provisoire (HTTP seul) : sans lui, nginx ne démarrerait pas,
#    puisque le vrai vhost réclame un certificat qui n'existe pas encore.
sudo cp deploy/nginx/voupvapcash.tech.bootstrap.conf \
        /etc/nginx/sites-available/voupvapcash.tech
sudo ln -sf /etc/nginx/sites-available/voupvapcash.tech \
            /etc/nginx/sites-enabled/voupvapcash.tech
sudo nginx -t && sudo systemctl reload nginx

# 3. Certificat (méthode webroot : nginx n'est jamais arrêté)
sudo certbot certonly --webroot -w /var/www/certbot \
     -d voupvapcash.tech -d www.voupvapcash.tech \
     --email <votre-email> --agree-tos --no-eff-email

# 4. vhost définitif (HTTPS + relais)
sudo cp deploy/nginx/voupvapcash.tech.conf \
        /etc/nginx/sites-available/voupvapcash.tech
sudo nginx -t && sudo systemctl reload nginx

# 5. Vérifier
curl -fsS https://voupvapcash.tech/healthz          # → {"ok":true}
curl -sI  http://voupvapcash.tech | head -1         # → 301
curl -sI  https://www.voupvapcash.tech | head -1    # → 301
```

Le renouvellement est automatique (timer `certbot.timer`). Pour que nginx
recharge le certificat renouvelé :

```sh
echo -e '#!/bin/sh\nsystemctl reload nginx' | \
  sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
sudo certbot renew --dry-run
```

## À régler ailleurs

| Où | Valeur |
|---|---|
| `server/.env` | `CORS_ORIGINS=https://voupvapcash.tech` |
| Tableau de bord Bazik | webhook `https://voupvapcash.tech/api/bazik/webhook` |
| Build Android/iOS | `--dart-define=API_BASE_URL=https://voupvapcash.tech` |

`.env` à la racine : laissez `API_BASE_URL` vide — l'app web appelle l'API sur
sa propre origine. `DOMAIN` ne sert qu'à Caddy, il est ignoré ici.

## Ce que ce vhost ne refait pas

Le conteneur `web` s'en charge déjà ; les répéter ici enverrait des en-têtes en
double ou compterait les requêtes deux fois :

- en-têtes `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`,
  `Permissions-Policy` ;
- limite de 20 req/min par IP sur `/api/auth/login`, `/api/auth/bootstrap` et
  `/api/otp/` — d'où l'importance du `X-Forwarded-For` posé par ce vhost ;
- compression gzip, cache de l'app Flutter, repli `try_files → /index.html`.

Seuls le TLS, HSTS et la redirection vers l'apex viennent d'ici.

## Dépannage

| Symptôme | Cause probable |
|---|---|
| `502 Bad Gateway` | conteneur `web` arrêté, ou `HTTP_BIND`/`HTTP_PORT` modifiés dans `.env` sans mettre à jour l'`upstream` |
| nginx ne démarre pas, `cannot load certificate` | étape 3 non faite, ou nom de domaine différent dans `/etc/letsencrypt/live/` |
| `duplicate default_server` | le bloc commenté en fin de vhost a été activé alors que `/etc/nginx/sites-enabled/default` existe toujours |
| Tous les agents bloqués en 429 | `X-Forwarded-For` non transmis : `web` voit l'IP du proxy pour tout le monde |
| Le défi ACME renvoie 404 | `/var/www/certbot` absent, ou la redirection 301 passe avant le bloc `acme-challenge` (gardez le `^~`) |
