# Sauvegarde quotidienne — voupvapcash.tech

Une tâche cron lance `server/scripts/backup_db.js` dans le conteneur `api`, chaque nuit à 3 h. La sauvegarde utilise `VACUUM INTO` (instantané cohérent, même pendant des écritures) puis `PRAGMA integrity_check` ; une copie abîmée est supprimée et les anciennes sont conservées.

| Fichier | Destination |
| --- | --- |
| `voupvapcash-backup.sh` | `/usr/local/bin/voupvapcash-backup.sh` |
| `voupvapcash-backup.cron` | `/etc/cron.d/voupvapcash-backup` — **sans extension** |

## Installation

```sh
sudo install -m 755 deploy/backup/voupvapcash-backup.sh /usr/local/bin/voupvapcash-backup.sh
sudo install -m 644 -o root -g root \
     deploy/backup/voupvapcash-backup.cron /etc/cron.d/voupvapcash-backup
```

Le changement de nom n'est pas cosmétique : cron ignore silencieusement tout fichier de `/etc/cron.d` dont le nom contient un point. Installé sous `voupvapcash-backup.cron`, le travail ne s'exécuterait jamais, sans la moindre erreur nulle part.

Vérifiez ensuite le chemin du dépôt dans `/etc/cron.d/voupvapcash-backup` — il vaut `/home/deploy/valentinapp` par défaut :

```sh
sudo sed -n '/^PROJECT_DIR/p' /etc/cron.d/voupvapcash-backup
```

## Essayer sans attendre 3 h

```sh
sudo /usr/local/bin/voupvapcash-backup.sh
sudo docker compose -f /home/deploy/valentinapp/docker-compose.yml \
     exec -T api ls -lh /data/backups
```

Sortie attendue : une ligne `succès` et un fichier `app-AAAAMMJJ-HHMMSS.db`(horodatage UTC).

## Rotation du journal

Sans ça, `/var/log/voupvapcash-backup.log` grossit indéfiniment.

```sh
sudo tee /etc/logrotate.d/voupvapcash-backup >/dev/null <<'EOF'
/var/log/voupvapcash-backup.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0640 root adm
}
EOF
sudo logrotate --debug /etc/logrotate.d/voupvapcash-backup
```

## Surveiller

```sh
tail -20 /var/log/voupvapcash-backup.log
grep ÉCHEC /var/log/voupvapcash-backup.log
```

Le script s'arrête en code 1 si le dossier du projet est introuvable, si le conteneur `api` n'est pas démarré, ou si `backup_db.js` échoue. Décommentez `MAILTO` dans le fichier cron pour recevoir un courriel à chaque échec — cela suppose un MTA installé sur la machine, ce qui n'est pas le cas par défaut sur un VPS. Sans MTA, **le journal est la seule alerte** : relisez-le.

## Ce que cette tâche ne fait pas

Les copies restent dans le volume Docker `app-data`, sur le disque du serveur. Une panne de ce disque les emporte avec la base. Sortez-les régulièrement :

```sh
docker compose cp api:/data/backups ./backups
```

Tant que cette étape n'est pas automatisée vers une autre machine ou un stockage objet, vous êtes protégé d'une corruption de la base, pas de la perte du serveur.

## Désinstaller

```sh
sudo rm /etc/cron.d/voupvapcash-backup /usr/local/bin/voupvapcash-backup.sh
sudo rm -f /etc/logrotate.d/voupvapcash-backup
```