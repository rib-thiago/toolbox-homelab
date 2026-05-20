#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"

LATEST_MATCHES="$(ls -1t "$OUT_DIR"/deleted-vs-music-matches-*.tsv | head -n 1)"
LATEST_ONLY="$(ls -1t "$OUT_DIR"/deleted-vs-music-only-deleted-*.tsv | head -n 1)"

TS="$(date +%Y%m%d-%H%M%S)"

REPORT="$OUT_DIR/cleanup-deleted-safe-$TS.txt"
REMOVE_LIST="$OUT_DIR/cleanup-removed-$TS.tsv"
UNIQUE_ANALYSIS="$OUT_DIR/cleanup-unique-analysis-$TS.tsv"

exec > >(tee "$REPORT") 2>&1

gb() {
  awk -v bytes="${1:-0}" 'BEGIN { printf "%.2f", bytes/1024/1024/1024 }'
}

echo "===== SAFE CLEANUP ANALYSIS ====="
echo "Data: $(date)"
echo
echo "Matches:"
echo "$LATEST_MATCHES"
echo
echo "Only deleted:"
echo "$LATEST_ONLY"
echo

if [ ! -f "$LATEST_MATCHES" ]; then
  echo "Arquivo matches não encontrado."
  exit 1
fi

if [ ! -f "$LATEST_ONLY" ]; then
  echo "Arquivo only-deleted não encontrado."
  exit 1
fi

echo "===== 1. ANALISANDO ARQUIVOS ÚNICOS ====="

printf "TYPE\tSIZE_GB\tEXT\tPATH\n" > "$UNIQUE_ANALYSIS"

while IFS=$'\t' read -r hash size path; do

  ext="${path##*.}"

  if [ "$ext" = "$path" ]; then
    ext="NO_EXT"
  fi

  type="$(file -b "$path" 2>/dev/null || echo UNKNOWN)"

  size_gb="$(awk -v bytes="$size" 'BEGIN { printf "%.4f", bytes/1024/1024/1024 }')"

  printf "%s\t%s\t%s\t%s\n" \
    "$type" \
    "$size_gb" \
    "$ext" \
    "$path"

done < "$LATEST_ONLY" >> "$UNIQUE_ANALYSIS"

echo "Arquivo de análise criado:"
echo "$UNIQUE_ANALYSIS"
echo

echo "===== RESUMO DOS ÚNICOS ====="

awk -F '\t' '
NR>1 {
  ext[$3]++
  size[$3]+=$2
}
END {
  printf "%-15s %-10s %-10s\n", "EXT", "COUNT", "SIZE_GB"
  for (e in ext) {
    printf "%-15s %-10d %-10.4f\n", e, ext[e], size[e]
  }
}
' "$UNIQUE_ANALYSIS"

echo
echo "===== AMOSTRA DOS ÚNICOS ====="

column -t -s $'\t' "$UNIQUE_ANALYSIS" | head -20 || true

echo
echo "===== 2. PREPARANDO REMOÇÃO SEGURA ====="

MATCH_COUNT=0
MATCH_SIZE=0

while IFS=$'\t' read -r hash size deleted_path music_path; do

  if [ -f "$deleted_path" ]; then
    printf "%s\t%s\t%s\n" \
      "$size" \
      "$hash" \
      "$deleted_path" \
      >> "$REMOVE_LIST"

    MATCH_COUNT=$((MATCH_COUNT + 1))
    MATCH_SIZE=$((MATCH_SIZE + size))
  fi

done < "$LATEST_MATCHES"

echo "Arquivos seguros para remoção:"
echo "$MATCH_COUNT"

echo "Espaço potencial recuperável:"
echo "$(gb "$MATCH_SIZE") GB"

echo
echo "===== 3. CONFIRMAÇÃO ====="
echo
echo "O script NÃO removeu nada ainda."
echo
echo "Lista pronta para remoção:"
echo "$REMOVE_LIST"
echo
echo "Análise dos únicos:"
echo "$UNIQUE_ANALYSIS"
echo
echo "Para efetivamente remover depois:"
echo
echo "while IFS=\$'\t' read -r size hash path; do"
echo "  sudo rm -f \"\$path\""
echo "done < \"$REMOVE_LIST\""
