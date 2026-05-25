#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

PLAN_TSV="${1:-}"
CORPUS_ID="${2:-}"

[[ -n "$PLAN_TSV" ]] || fail "Uso: filter-stockhausen-plan-high-only.sh PLAN_TSV CORPUS_ID"
[[ -n "$CORPUS_ID" ]] || fail "CORPUS_ID ausente."
[[ -f "$PLAN_TSV" ]] || fail "Plano não encontrado: $PLAN_TSV"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_batch_normalization_plan_${CORPUS_ID}_HIGH_ONLY_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_batch_normalization_plan_${CORPUS_ID}_HIGH_ONLY_$STAMP.txt"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

awk -F'\t' 'NR==1 || $19=="HIGH"' "$PLAN_TSV" > "$OUT_TSV"

{
  echo "Stockhausen HIGH-only normalization plan"
  echo "Generated: $(date -Is)"
  echo
  echo "Input:"
  echo "$PLAN_TSV"
  echo
  echo "Output:"
  echo "$OUT_TSV"
  echo
  echo "Summary:"
  printf "Rows original: "
  awk 'NR>1 {c++} END {print c+0}' "$PLAN_TSV"

  printf "Rows HIGH-only: "
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Albums included:"
  awk -F'\t' 'NR>1 {print $1}' "$OUT_TSV" | sort -u

  echo
  echo
  echo "Confidence summary:"
  awk -F'\t' 'NR>1 {c[$19]++} END {for (k in c) print k, c[k]}' "$OUT_TSV" | sort
} > "$REPORT"

echo "$OUT_TSV"
echo "$REPORT"
