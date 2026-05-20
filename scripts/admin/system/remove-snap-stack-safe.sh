#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="/srv/toolbox/shared/reports/system"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/snap-removal-execution-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== SAFE SNAP REMOVAL ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

if [ "$(id -u)" -ne 0 ]; then
  echo "ERRO: execute com sudo."
  exit 1
fi

echo "===== 1. Estado inicial ====="

df -h /
echo

snap list || true
echo

echo "===== 2. Verificação crítica ====="

echo "--- docker ---"
systemctl is-active docker || true

echo "--- tailscale ---"
systemctl is-active tailscaled || true

echo "--- ufw ---"
systemctl is-active ufw || true

echo "--- nginx proxy manager ---"
docker ps --format '{{.Names}}' | grep nginx || true

echo

echo "===== 3. Removendo snaps desktop ====="

remove_snap() {
  local name="$1"

  if snap list "$name" >/dev/null 2>&1; then
    echo
    echo "[REMOVE] snap remove $name"
    snap remove "$name"
  else
    echo
    echo "[SKIP] $name não instalado"
  fi
}

remove_snap firefox
remove_snap snap-store
remove_snap snapd-desktop-integration
remove_snap gnome-46-2404
remove_snap gnome-42-2204
remove_snap gtk-common-themes
remove_snap mesa-2404

echo
echo "===== 4. Removendo bases snap ====="

remove_snap core24
remove_snap core22
remove_snap bare

echo
echo "===== 5. Purge snapd ====="

apt purge -y snapd

echo
echo "===== 6. Limpando resíduos ====="

rm -rf /snap
rm -rf /var/snap
rm -rf /var/lib/snapd
rm -rf /var/cache/snapd

rm -rf "$HOME/snap"
rm -rf "$HOME/.snap"

echo
echo "===== 7. apt autoremove ====="

apt autoremove -y

echo
echo "===== 8. Estado final ====="

df -h /
echo

echo "--- mounts snap restantes ---"
mount | grep snap || true
echo

echo "--- serviços snap restantes ---"
systemctl list-unit-files | grep snap || true
echo

echo "--- snaps restantes ---"
snap list || true
echo

echo "--- docker ---"
systemctl is-active docker || true

echo "--- tailscale ---"
systemctl is-active tailscaled || true

echo "--- ufw ---"
systemctl is-active ufw || true

echo
echo "===== 9. IMPORTANTE ====="

cat <<EOF
Recomendado:
- NÃO reiniciar imediatamente se estiver usando serviços ativos.
- Em outro momento:
    sudo reboot

Após reboot:
- verificar:
    mount | grep snap
    snap list
EOF

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
