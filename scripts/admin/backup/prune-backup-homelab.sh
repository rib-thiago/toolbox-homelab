#!/usr/bin/env bash
set -euo pipefail

REPO="/mnt/backup-homelab/restic-repo"
LOG_DIR="$HOME/relatorios-backup"
DATE="$(date +%F-%H%M%S)"
LOG_FILE="$LOG_DIR/prune-backup-homelab-$DATE.log"

mkdir -p "$LOG_DIR"

echo "============================================================" | tee "$LOG_FILE"
echo "Manutenção Restic iniciada em $(date)" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

if ! mountpoint -q /mnt/backup-homelab; then
  echo "ERRO: /mnt/backup-homelab não está montado." | tee -a "$LOG_FILE"
  exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "Snapshots antes da retenção:" | tee -a "$LOG_FILE"

restic --repo "$REPO" snapshots 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Aplicando política de retenção:" | tee -a "$LOG_FILE"
echo "keep-last 7, keep-weekly 4, keep-monthly 3" | tee -a "$LOG_FILE"

restic \
  --repo "$REPO" \
  forget \
  --keep-last 7 \
  --keep-weekly 4 \
  --keep-monthly 3 \
  --prune \
  2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Verificando integridade do repositório:" | tee -a "$LOG_FILE"

restic --repo "$REPO" check 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Snapshots depois da retenção:" | tee -a "$LOG_FILE"

restic --repo "$REPO" snapshots 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Manutenção Restic concluída em $(date)" | tee -a "$LOG_FILE"
echo "Log salvo em: $LOG_FILE" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
