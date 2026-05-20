#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/samba-recycle-audit-$TS.txt"

exec > >(tee "$REPORT") 2>&1

echo "===== SAMBA RECYCLE AUDIT ====="
echo "Data: $(date)"
echo

echo "===== 1. Containers Samba ====="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" \
  | grep -i samba || true

echo
echo "===== 2. docker inspect ====="

SAMBA_CONTAINER="$(docker ps --format '{{.Names}} {{.Image}}' | grep -i samba | awk '{print $1}' | head -n1 || true)"

if [ -z "$SAMBA_CONTAINER" ]; then
  echo "Nenhum container samba encontrado."
  exit 1
fi

echo "Container:"
echo "$SAMBA_CONTAINER"

echo
docker inspect "$SAMBA_CONTAINER"

echo
echo "===== 3. smb.conf efetivo ====="

docker exec "$SAMBA_CONTAINER" sh -c '
if [ -f /etc/samba/smb.conf ]; then
  cat /etc/samba/smb.conf
else
  echo "smb.conf não encontrado"
fi
'

echo
echo "===== 4. Procurando recycle ====="

docker exec "$SAMBA_CONTAINER" sh -c '
grep -RniE "recycle|vfs|deleted|trash" /etc/samba 2>/dev/null || true
'

echo
echo "===== 5. Variáveis do container ====="

docker inspect "$SAMBA_CONTAINER" \
  --format '{{range .Config.Env}}{{println .}}{{end}}'

echo
echo "===== 6. Shares ====="

docker exec "$SAMBA_CONTAINER" sh -c '
testparm -s 2>/dev/null || true
'

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
