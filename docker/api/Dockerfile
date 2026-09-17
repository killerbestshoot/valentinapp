# syntax=docker/dockerfile:1

# Serveur VOUPVAPCASH : API + base SQLite + passerelles Bazik et Reloadly.
# Contexte de build : racine du dépôt (le serveur importe ../bazik et ../reloadly).
#
#   docker build -f docker/api/Dockerfile -t voupvapcash-api .
#   docker build -f docker/api/Dockerfile --target test .   # tests dans l'image

# Node 24 = LTS. `node:sqlite` y est disponible sans option.
ARG NODE_VERSION=24

FROM node:${NODE_VERSION}-bookworm-slim AS base
WORKDIR /app

# --- Dépendances de production uniquement -----------------------------------
FROM base AS deps
COPY server/package.json server/package-lock.json server/
RUN npm ci --prefix server --omit=dev --ignore-scripts && npm cache clean --force

# --- Tests (cible optionnelle) ----------------------------------------------
FROM base AS test
COPY server/package.json server/package-lock.json server/
RUN npm ci --prefix server --ignore-scripts
COPY bazik bazik
COPY reloadly reloadly
COPY server server
RUN cd bazik && npm test && cd ../reloadly && npm test && cd ../server && npm test

# --- Image livrée -----------------------------------------------------------
FROM base AS runtime

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=4500 \
    APP_DB_PATH=/data/app.db \
    OTP_DB_PATH=/data/otp_db.json \
    BACKUP_DIR=/data/backups

# Les données vivent dans un volume monté sur /data, jamais dans l'image.
RUN mkdir -p /data && chown node:node /data

COPY --from=deps /app/server/node_modules server/node_modules
COPY bazik/index.js bazik/package.json bazik/
COPY bazik/src bazik/src
COPY bazik/scripts bazik/scripts
# Sans ces lignes l'API s'arrête au démarrage : `Cannot find module '../../reloadly'`.
COPY reloadly/index.js reloadly/package.json reloadly/
COPY reloadly/src reloadly/src
COPY reloadly/scripts reloadly/scripts
COPY server/package.json server/
COPY server/src server/src
COPY server/scripts server/scripts

USER node
WORKDIR /app/server
EXPOSE 4500

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:' + (process.env.PORT || 4500) + '/healthz').then((r) => process.exit(r.ok ? 0 : 1), () => process.exit(1))"]

CMD ["node", "src/index.js"]
