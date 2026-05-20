#!/usr/bin/env bash
set -euo pipefail

OLD_HOST="$(hostname)"
NEW_HOST="homelab"

echo "===== HOSTNAME MIGRATION ====="
echo
echo "Hostname atual: $OLD_HOST"
echo "Novo hostname:  $NEW_HOST"
echo

echo "===== 1. BACKUP ====="

sudo cp /etc/hostname "/etc/hostname.bak.$(date +%Y%m%d-%H%M%S)"
sudo cp /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)"

echo "Backup concluído."
echo

echo "===== 2. ALTERANDO HOSTNAME ====="

sudo hostnamectl set-hostname "$NEW_HOST"

echo
echo "===== 3. AJUSTANDO /etc/hosts ====="

sudo sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/hosts

echo
echo "===== 4. VALIDAÇÃO ====="

echo
echo "--- hostname ---"
hostname

echo
echo "--- hostnamectl ---"
hostnamectl

echo
echo "--- /etc/hostname ---"
cat /etc/hostname

echo
echo "--- /etc/hosts ---"
cat /etc/hosts

echo
echo "===== 5. TESTE LOCAL ====="

getent hosts "$NEW_HOST" || true

echo
echo "===== CONCLUÍDO ====="
echo
echo "Pode ser necessário:"
echo "- abrir nova sessão shell"
echo "- reconectar SSH"
echo "- reboot futuramente"
