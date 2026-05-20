#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="/srv/toolbox/shared/reports/system"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/snap-stack-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== SNAP STACK AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Snap instalado ====="
if command -v snap >/dev/null 2>&1; then
    snap list
else
    echo "snap não instalado"
fi
echo

echo "===== 2. Serviços snapd ====="
systemctl list-unit-files | grep snap || true
echo
systemctl --no-pager --type=service | grep snap || true
echo

echo "===== 3. Espaço ocupado por snap ====="

for d in \
    /var/lib/snapd \
    /var/cache/snapd \
    /snap \
    "$HOME/snap" \
    "$HOME/.snap"
do
    echo "--- $d ---"
    du -sh "$d" 2>/dev/null || true
done
echo

echo "===== 4. Revisões antigas de snaps ====="
snap list --all 2>/dev/null || true
echo

echo "===== 5. Mounts snap ativos ====="
mount | grep snap || true
echo

echo "===== 6. Processos relacionados ====="
ps aux | grep -Ei 'snap|firefox' | grep -v grep || true
echo

echo "===== 7. Diretórios HOME relacionados ====="
find "$HOME/snap" -maxdepth 3 -mindepth 1 2>/dev/null | sort || true
echo
find "$HOME/.snap" -maxdepth 3 -mindepth 1 2>/dev/null | sort || true
echo

echo "===== 8. Pacotes apt relacionados ====="
dpkg -l | grep -Ei 'snap|firefox' || true
echo

echo "===== 9. Avaliação preliminar ====="
cat <<EOF
Objetivo:
- verificar se o host ainda depende de Snap desktop;
- avaliar remoção de:
  - firefox
  - snap-store
  - gnome runtimes
  - snapd-desktop-integration
- confirmar se sobrará apenas infraestrutura headless.

NÃO remove nada.
EOF

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
