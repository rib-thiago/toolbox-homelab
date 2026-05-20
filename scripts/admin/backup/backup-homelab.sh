#!/usr/bin/env bash
set -euo pipefail

PASSWORD_FILE="$HOME/.restic-password-homelab"
REPO="/mnt/backup-homelab/restic-repo"
EXCLUDES="$HOME/restic-excludes.txt"

LOG_DIR="$HOME/relatorios-backup"
DATE="$(date +%F-%H%M%S)"
LOG_FILE="$LOG_DIR/backup-homelab-$DATE.log"

mkdir -p "$LOG_DIR"

echo "============================================================" | tee "$LOG_FILE"
echo "Backup Homelab iniciado em $(date)" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

if ! mountpoint -q /mnt/backup-homelab; then
  echo "ERRO: /mnt/backup-homelab não está montado." | tee -a "$LOG_FILE"
  exit 1
fi

restic \
  --repo "$REPO" \
  --password-file "$PASSWORD_FILE" \
  backup \
  /srv/compose \
  /srv/data/homepage \
  /srv/toolbox \
  /home/thiago/relatorios-backup \
  --exclude-file "$EXCLUDES" \
  2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "Snapshots disponíveis" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

restic \
  --repo "$REPO" \
  --password-file "$PASSWORD_FILE" \
  snapshots \
  2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "Backup Homelab concluído em $(date)" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
