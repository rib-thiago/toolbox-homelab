#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

HOME_REPORTS="$HOME/relatorios-backup"
TARGET_ROOT="/srv/toolbox/shared/reports"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$TARGET_ROOT/system/report-migration-audit-$TS.txt"

mkdir -p "$TARGET_ROOT"/{backup,docker,network,system}

exec > >(tee "$REPORT") 2>&1

echo "===== REPORT MIGRATION AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "Origem:"
echo "$HOME_REPORTS"
echo

echo "Destino:"
echo "$TARGET_ROOT"
echo

if [ ! -d "$HOME_REPORTS" ]; then
  echo "Diretório de origem não existe. Nada a migrar."
  exit 0
fi

echo "===== 1. Arquivos restantes na origem ====="
find "$HOME_REPORTS" -maxdepth 1 -type f -printf '%f\n' | sort
echo

echo "===== 2. Checando correspondência no destino ====="

MISSING_COUNT=0

while IFS= read -r src; do
  base="$(basename "$src")"

  case "$base" in
    backup-*|prune-backup-*|diagnostico-backup-*|diagnostico-toolbox-backup-*)
      dest="$TARGET_ROOT/backup/$base"
      ;;
    diagnostico-docker-*)
      dest="$TARGET_ROOT/docker/$base"
      ;;
    diagnostico-rede-*|inventario-rede-*|diagnostico-avahi-*)
      dest="$TARGET_ROOT/network/$base"
      ;;
    diagnostico-hardening-*)
      dest="$TARGET_ROOT/system/$base"
      ;;
    *)
      dest="$TARGET_ROOT/system/$base"
      ;;
  esac

  if [ -f "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      echo "[OK] $base -> $dest"
    else
      echo "[DIFF] $base existe no destino, mas conteúdo difere: $dest"
      MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
  else
    echo "[MISSING] $base -> esperado em $dest"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done < <(find "$HOME_REPORTS" -maxdepth 1 -type f | sort)

echo
echo "===== 3. Resumo ====="

if [ "$MISSING_COUNT" -eq 0 ]; then
  echo "Todos os relatórios restantes em ~/relatorios-backup já existem no destino com conteúdo idêntico."
  echo
  echo "Pode apagar com:"
  echo "rm -rf ~/relatorios-backup"
else
  echo "Há $MISSING_COUNT arquivo(s) ausentes ou divergentes."
  echo
  echo "Não apague ~/relatorios-backup ainda."
fi

echo
echo "===== 4. Estrutura atual do destino ====="
find "$TARGET_ROOT" -maxdepth 2 -type f -printf '%p\n' | sort

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
