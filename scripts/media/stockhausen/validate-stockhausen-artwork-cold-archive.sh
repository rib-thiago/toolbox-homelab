#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
ARCHIVE_ROOT="/srv/toolbox/shared/artwork-cold-archive/stockhausen"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$(ls -t "$RAW_DIR"/stockhausen_artwork_cold_archive_plan_*.tsv 2>/dev/null | head -1)"
BUILD_TSV="$(ls -t "$RAW_DIR"/stockhausen_artwork_cold_archive_build_*.tsv 2>/dev/null | head -1)"
PERIOD_TSV="$(ls -t "$RAW_DIR"/stockhausen_artwork_cold_archive_by_period_*.tsv 2>/dev/null | head -1)"

VALIDATION_TSV="$RAW_DIR/stockhausen_artwork_cold_archive_validation_$STAMP.tsv"
ARCHIVE_TSV="$RAW_DIR/stockhausen_artwork_cold_archive_archives_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_artwork_cold_archive_validation_report_$STAMP.txt"

command -v 7z >/dev/null 2>&1 || fail "7z não encontrado. Instale com: sudo apt install p7zip-full"
command -v file >/dev/null 2>&1 || fail "file não encontrado."

[[ -f "$PLAN_TSV" ]] || fail "Plano não encontrado."
[[ -f "$BUILD_TSV" ]] || fail "Build TSV não encontrado."
[[ -f "$PERIOD_TSV" ]] || fail "Resumo por período não encontrado."
[[ -d "$ARCHIVE_ROOT" ]] || fail "Archive root não encontrado: $ARCHIVE_ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Validando cold archive de Artwork Stockhausen..."
log "Plan:  $PLAN_TSV"
log "Build: $BUILD_TSV"

printf "source_path\twebp_path\tbuild_status\twebp_exists\twebp_size\twebp_filetype\tvalidation_status\n" > "$VALIDATION_TSV"

tail -n +2 "$BUILD_TSV" | while IFS=$'\t' read -r source_path webp_path build_status source_size webp_size_build; do
  webp_exists="no"
  webp_size="0"
  webp_filetype=""
  validation_status="MISSING_WEBP"

  if [[ -f "$webp_path" ]]; then
    webp_exists="yes"
    webp_size="$(stat -c '%s' "$webp_path")"
    webp_filetype="$(file -b "$webp_path" | tr '\t' ' ')"

    if [[ "$webp_filetype" == *"Web/P image"* || "$webp_filetype" == *"RIFF"* ]]; then
      validation_status="OK"
    else
      validation_status="BAD_FILETYPE"
    fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$source_path" \
    "$webp_path" \
    "$build_status" \
    "$webp_exists" \
    "$webp_size" \
    "$webp_filetype" \
    "$validation_status" >> "$VALIDATION_TSV"
done

log "Validando archives .7z..."

printf "archive_path\texists\tsize_bytes\tsize_human\tsevenzip_test_status\n" > "$ARCHIVE_TSV"

tail -n +2 "$PERIOD_TSV" | while IFS=$'\t' read -r period files size_bytes size_human planned_archive; do
  exists="no"
  archive_size="0"
  archive_human="0 B"
  status="MISSING"

  if [[ -f "$planned_archive" ]]; then
    exists="yes"
    archive_size="$(stat -c '%s' "$planned_archive")"
    archive_human="$(du -h "$planned_archive" | awk '{print $1}')"

    log "7z test: $planned_archive"
    if 7z t "$planned_archive" >/dev/null 2>&1; then
      status="OK"
    else
      status="ERROR"
    fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$planned_archive" \
    "$exists" \
    "$archive_size" \
    "$archive_human" \
    "$status" >> "$ARCHIVE_TSV"
done

{
  echo "Stockhausen artwork cold archive validation report"
  echo "Generated: $(date -Is)"
  echo
  echo "Archive root:"
  echo "$ARCHIVE_ROOT"
  echo
  echo "Inputs:"
  echo "$PLAN_TSV"
  echo "$BUILD_TSV"
  echo "$PERIOD_TSV"
  echo
  echo "Outputs:"
  echo "$VALIDATION_TSV"
  echo "$ARCHIVE_TSV"
  echo
  echo "Conversion validation summary:"
  awk -F'\t' 'NR>1 {c[$7]++} END {for (k in c) print k, c[k]}' "$VALIDATION_TSV" | sort
  echo
  echo "Build status summary:"
  awk -F'\t' 'NR>1 {c[$3]++} END {for (k in c) print k, c[k]}' "$VALIDATION_TSV" | sort
  echo
  echo "Archive validation summary:"
  awk -F'\t' 'NR>1 {c[$5]++} END {for (k in c) print k, c[k]}' "$ARCHIVE_TSV" | sort
  echo
  echo "Size summary:"
  awk -F'\t' '
    NR>1 {
      total += $5
    }
    END {
      if (total >= 1073741824) printf "Validated WebP size: %.2f GiB\n", total/1073741824;
      else if (total >= 1048576) printf "Validated WebP size: %.2f MiB\n", total/1048576;
      else if (total >= 1024) printf "Validated WebP size: %.2f KiB\n", total/1024;
      else print "Validated WebP size: " total " B";
    }
  ' "$VALIDATION_TSV"
  awk -F'\t' '
    NR>1 {
      total += $3
    }
    END {
      if (total >= 1073741824) printf "7z archive size: %.2f GiB\n", total/1073741824;
      else if (total >= 1048576) printf "7z archive size: %.2f MiB\n", total/1048576;
      else if (total >= 1024) printf "7z archive size: %.2f KiB\n", total/1024;
      else print "7z archive size: " total " B";
    }
  ' "$ARCHIVE_TSV"
  echo
  echo "Archives:"
  column -t -s $'\t' "$ARCHIVE_TSV"
  echo
  echo "Failures:"
  awk -F'\t' 'NR>1 && $7 != "OK" {print "- " $1 " -> " $7}' "$VALIDATION_TSV" | head -100
  awk -F'\t' 'NR>1 && $5 != "OK" {print "- " $1 " -> " $5}' "$ARCHIVE_TSV" | head -100
  echo
  echo "Notes:"
  echo "- This script does not delete original Artwork directories."
  echo "- Purge is only safe after OK conversion validation and OK archive validation."
} > "$REPORT"

log "Validação concluída."
log "Validation TSV: $VALIDATION_TSV"
log "Archive TSV:    $ARCHIVE_TSV"
log "Relatório:      $REPORT"
