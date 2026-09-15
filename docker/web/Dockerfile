# syntax=docker/dockerfile:1

# App Flutter web servie par nginx, qui relaie aussi /api vers le serveur.
# Contexte de build : racine du dépôt.
#
#   docker build -f docker/web/Dockerfile -t voupvapcash-web .

ARG FLUTTER_VERSION=3.41.6

# --- Compilation Flutter ------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
WORKDIR /src

# Les dépendances d'abord : cette couche reste en cache tant que pubspec ne bouge pas.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY analysis_options.yaml ./
COPY lib lib
COPY web web

# Vide = l'app appelle l'API sur sa propre origine (nginx relaie /api).
# Une seule image fonctionne donc sur n'importe quel domaine.
ARG API_BASE_URL=

# --no-web-resources-cdn : CanvasKit est servi par nginx au lieu de gstatic.com.
RUN flutter build web --release --no-web-resources-cdn \
      --dart-define=API_BASE_URL=${API_BASE_URL}

# --- Service ------------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.30-alpine AS runtime

COPY docker/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
