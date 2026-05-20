#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="/srv/toolbox/shared/reports/system"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/snap-removal-plan-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== SNAP REMOVAL PLAN ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Snaps instalados ====="
snap list || true
echo

echo "===== 2. Espaço atual ====="
df -h /
echo
du -sh /var/lib/snapd 2>/dev/null || true
du -sh /snap 2>/dev/null || true
echo

echo "===== 3. Pacotes apt relacionados ====="
dpkg -l | grep -Ei 'snap|firefox|xdg-desktop' || true
echo

echo "===== 4. Simulação de remoção apt ====="
echo "--- apt remove snapd firefox ---"
apt -s remove snapd firefox 2>/dev/null || true
echo

echo "===== 5. Serviços que desapareceriam ====="
systemctl list-unit-files | grep snap || true
echo

echo "===== 6. Mounts snap ativos ====="
mount | grep '/snap/' || true
echo

echo "===== 7. Dependências reversas importantes ====="
echo "--- apt-cache rdepends snapd ---"
apt-cache rdepends snapd 2>/dev/null || true
echo

echo "===== 8. Verificação crítica homelab ====="

echo "--- docker ---"
systemctl is-active docker || true

echo "--- tailscale ---"
systemctl is-active tailscaled || true

echo "--- ufw ---"
systemctl is-active ufw || true

echo "--- nginx proxy manager containers ---"
docker ps --format '{{.Names}}' | grep -Ei 'nginx|proxy' || true

echo "--- samba ---"
systemctl is-active smbd || true

echo

echo "===== 9. Plano previsto (NÃO EXECUTADO) ====="

cat <<EOF
Ordem provável de remoção:

1. snap remove firefox
2. snap remove snap-store
3. snap remove snapd-desktop-integration
4. snap remove gnome-46-2404
5. snap remove gnome-42-2204
6. snap remove gtk-common-themes
7. snap remove mesa-2404
8. snap remove core24
9. snap remove core22
10. apt purge snapd

Depois:
- remover ~/snap
- remover ~/.snap
- remover /var/cache/snapd
- remover /var/lib/snapd
- remover /snap

Tudo isso SOMENTE após revisão humana.
EOF

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
