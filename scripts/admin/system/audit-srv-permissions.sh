#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/srv-permissions-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== /SRV PERMISSIONS AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Espaço ====="

df -hT
echo

echo "===== 2. Diretórios principais ====="

for d in \
  /srv \
  /srv/media \
  /srv/compose \
  /srv/data \
  /srv/toolbox
do
  echo
  echo "--- $d ---"
  stat -c '%U:%G %u:%g %a %A %n' "$d" 2>/dev/null || true
done

echo
echo "===== 3. Ownership até profundidade 2 ====="

sudo find /srv \
  -maxdepth 2 \
  -printf '%u:%g %m %p\n' \
  | sort

echo
echo "===== 4. Diretórios world-writable ====="

sudo find /srv \
  -type d \
  -perm -0002 \
  -printf '%m %u:%g %p\n' \
  2>/dev/null || true

echo
echo "===== 5. Arquivos world-writable ====="

sudo find /srv \
  -type f \
  -perm -0002 \
  -printf '%m %u:%g %p\n' \
  2>/dev/null || true

echo
echo "===== 6. Arquivos sem owner thiago/root ====="

sudo find /srv \
  ! -user thiago \
  ! -user root \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -400

echo
echo "===== 7. Arquivos sem grupo thiago/root/docker ====="

sudo find /srv \
  ! -group thiago \
  ! -group root \
  ! -group docker \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -400

echo
echo "===== 8. Diretórios 777 ====="

sudo find /srv \
  -type d \
  -perm 0777 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null || true

echo
echo "===== 9. Arquivos 777 ====="

sudo find /srv \
  -type f \
  -perm 0777 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null || true

echo
echo "===== 10. Arquivos sensíveis ====="

sudo find /srv \
  \( \
    -iname "*.env" -o \
    -iname "*secret*" -o \
    -iname "*token*" -o \
    -iname "*passwd*" -o \
    -iname "*key*" -o \
    -iname "config.json" \
  \) \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -400

echo
echo "===== 11. ACLs não triviais ====="

sudo getfacl -R /srv 2>/dev/null \
  | grep -E '^# file:|^user:|^group:' \
  | head -400 || true

echo
echo "===== 12. Docker volumes ====="

docker volume ls || true

echo
echo "===== 13. Ownership docker compose ====="

sudo find /srv/compose \
  -maxdepth 3 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -500

echo
echo "===== 14. Ownership media ====="

sudo find /srv/media \
  -maxdepth 3 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -500

echo
echo "===== 15. Ownership toolbox ====="

sudo find /srv/toolbox \
  -maxdepth 3 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -500

echo
echo "===== 16. Possíveis inconsistências ====="

echo
echo "Critérios esperados:"
echo "- media: thiago:thiago"
echo "- compose: mistura controlada root/thiago"
echo "- sem 777"
echo "- sem world-writable"
echo "- sem ACLs estranhas"
echo "- secrets mais restritos"
echo

echo "===== RELATÓRIO ====="
echo "$REPORT"
