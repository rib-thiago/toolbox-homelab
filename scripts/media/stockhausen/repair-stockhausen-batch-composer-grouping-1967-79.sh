#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_batch_repair_composer_grouping_1967-79_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_batch_repair_composer_grouping_report_1967-79_$STAMP.txt"

COMPOSER_VALUE="Karlheinz Stockhausen"
GROUPING_VALUE="1967-79: Live Electronics - Intuitive Music - Formula Form"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
[[ -d "$ROOT" ]] || fail "Root não encontrado: $ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Reparando COMPOSER/GROUPING no corpus 1967-79..."
log "Root: $ROOT"

printf "file\told_composer\tnew_composer\told_grouping\tnew_grouping\tstatus\n" > "$OUT_TSV"

while IFS= read -r -d '' f; do
  old_composer="$(metaflac --show-tag=COMPOSER "$f" 2>/dev/null | sed 's/^COMPOSER=//' | paste -sd ';' -)"
  old_grouping="$(metaflac --show-tag=GROUPING "$f" 2>/dev/null | sed 's/^GROUPING=//' | paste -sd ';' -)"

  metaflac --remove-tag=COMPOSER --set-tag="COMPOSER=$COMPOSER_VALUE" "$f"
  metaflac --remove-tag=GROUPING --set-tag="GROUPING=$GROUPING_VALUE" "$f"

  printf "%s\t%s\t%s\t%s\t%s\tOK\n" \
    "$f" \
    "$old_composer" \
    "$COMPOSER_VALUE" \
    "$old_grouping" \
    "$GROUPING_VALUE" >> "$OUT_TSV"

done < <(find "$ROOT" -type f -iname '*.flac' -print0 | sort -z)

{
  echo "Stockhausen batch repair COMPOSER/GROUPING report — 1967-79"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Output:"
  echo "$OUT_TSV"
  echo
  echo "Summary:"
  printf "Files repaired: "
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"
  echo
  echo "Values applied:"
  echo "COMPOSER=$COMPOSER_VALUE"
  echo "GROUPING=$GROUPING_VALUE"
  echo
  echo "Old composer examples:"
  awk -F'\t' 'NR>1 {print $2}' "$OUT_TSV" | sort -u | head -20
  echo
  echo "Old grouping examples:"
  awk -F'\t' 'NR>1 {print $4}' "$OUT_TSV" | sort -u | head -20
} > "$REPORT"

log "Reparo concluído."
log "TSV: $OUT_TSV"
log "Relatório: $REPORT"
