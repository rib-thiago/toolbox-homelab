#!/usr/bin/env bash
set -euo pipefail

BASE="/srv/media/music-staging"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT_DIR="/srv/toolbox/shared/reports/media"
REPORT="$REPORT_DIR/reorganize-music-staging-$TS.txt"

mkdir -p "$REPORT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== REORGANIZE MUSIC STAGING ====="
echo "Data: $(date)"
echo "Base: $BASE"
echo

if [ ! -d "$BASE" ]; then
  echo "ERRO: diretório não existe: $BASE"
  exit 1
fi

echo "===== 1. Estado antes ====="
find "$BASE" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
echo
du -sh "$BASE"/* 2>/dev/null || true
echo

echo "===== 2. Criando estrutura oficial ====="

mkdir -p \
  "$BASE/incoming" \
  "$BASE/downloading" \
  "$BASE/reviewing" \
  "$BASE/tagging" \
  "$BASE/ready" \
  "$BASE/rejected" \
  "$BASE/imports" \
  "$BASE/archive"

chown -R 1000:1000 "$BASE"
find "$BASE" -type d -maxdepth 2 -exec chmod 775 {} \;

echo "Estrutura criada."
echo

echo "===== 3. Movendo conteúdo antigo para reviewing ====="

for item in "$BASE"/*; do
  name="$(basename "$item")"

  case "$name" in
    incoming|downloading|reviewing|tagging|ready|rejected|imports|archive)
      echo "[KEEP] $name"
      ;;
    *)
      echo "[MOVE] $item -> $BASE/reviewing/"
      mv -n "$item" "$BASE/reviewing/"
      ;;
  esac
done

echo
echo "===== 4. Estado depois ====="
find "$BASE" -mindepth 1 -maxdepth 2 -type d | sort
echo
du -sh "$BASE"/* 2>/dev/null || true
echo

echo "===== 5. Relatório ====="
echo "$REPORT"
