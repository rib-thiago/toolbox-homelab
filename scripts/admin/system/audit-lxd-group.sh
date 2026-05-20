#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/lxd-group-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== LXD / GROUP AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Usuário atual ====="

id
echo

echo "===== 2. Grupo lxd ====="

getent group lxd || true
echo

echo "===== 3. Pacotes LXD/LXC ====="

dpkg -l | grep -Ei 'lxd|lxc' || true
echo

echo "===== 4. Snap LXD ====="

snap list 2>/dev/null | grep -Ei 'lxd|lxc' || true
echo

echo "===== 5. Serviços systemd ====="

systemctl list-unit-files | grep -Ei 'lxd|lxc' || true
echo

echo "===== 6. Serviços ativos ====="

systemctl | grep -Ei 'lxd|lxc' || true
echo

echo "===== 7. Processos ====="

ps aux | grep -Ei 'lxd|lxc' | grep -v grep || true
echo

echo "===== 8. Sockets ====="

sudo ss -tulpn | grep -Ei 'lxd|lxc' || true
echo

echo "===== 9. Diretórios ====="

for d in \
  /var/lib/lxd \
  /var/snap/lxd \
  /snap/lxd \
  ~/.config/lxc
do
  if [ -e "$d" ]; then
    echo "--- EXISTE: $d ---"
    sudo du -sh "$d" 2>/dev/null || true
    sudo ls -lah "$d" 2>/dev/null || true
  fi
done

echo
echo "===== 10. Comando lxc ====="

which lxc || true
echo

lxc list 2>/dev/null || true
echo

echo "===== 11. Permissões docker vs lxd ====="

echo "--- docker.sock ---"
ls -lah /var/run/docker.sock 2>/dev/null || true
echo

echo "--- lxd socket ---"
sudo find /var -type s 2>/dev/null | grep -Ei 'lxd' || true
echo

echo "===== 12. Avaliação preliminar ====="

echo
echo "Critérios:"
echo "- se não houver containers"
echo "- se não houver daemon ativo"
echo "- se não houver snap lxd"
echo "- se não houver uso real"
echo
echo "=> provavelmente o grupo lxd é apenas herança Ubuntu Desktop"

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
