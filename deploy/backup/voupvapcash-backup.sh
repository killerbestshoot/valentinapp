#!/bin/sh
# VOUPVAPCASH — sauvegarde quotidienne de la base SQLite.
#
# Appelé par /etc/cron.d/voupvapcash-backup. Installation : deploy/backup/README.md
#
# Enveloppe `scripts/backup_db.js` pour trois raisons qu'une ligne de crontab
# ne couvre pas : vérifier que l'API tourne avant de croire à une sauvegarde,
# horodater chaque ligne du journal, et renvoyer un code de sortie exploitable.

set -eu

PROJECT_DIR="${PROJECT_DIR:-/home/deploy/valentinapp}"
KEEP="${KEEP:-14}"

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"; }

cd "$PROJECT_DIR" 2>/dev/null || {
    log "ÉCHEC: dossier projet introuvable ($PROJECT_DIR) — réglez PROJECT_DIR dans /etc/cron.d/voupvapcash-backup"
    exit 1
}

# `docker compose exec` sur un service arrêté renvoie une erreur Docker peu
# lisible. Sans ce test, un `api` tombé produirait un journal obscur et l'on
# croirait les sauvegardes à jour.
if [ -z "$(docker compose ps -q api 2>/dev/null)" ]; then
    log "ÉCHEC: le conteneur api n'est pas démarré — aucune sauvegarde prise"
    exit 1
fi

log "début (keep=$KEEP)"

if docker compose exec -T api node scripts/backup_db.js --keep "$KEEP"; then
    log "succès"
else
    code=$?
    # backup_db.js supprime une copie qui échoue à `PRAGMA integrity_check` et
    # laisse les anciennes en place : un échec ne détruit jamais l'historique.
    log "ÉCHEC: backup_db.js a renvoyé $code — les sauvegardes précédentes sont intactes"
    exit "$code"
fi
