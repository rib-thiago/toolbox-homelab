#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S)"

MUSIC_ROOT="/srv/media/music/Karlheinz Stockhausen"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"

VALIDATION_REPORT="$(ls -t "$REPORT_DIR"/stockhausen_artwork_cold_archive_validation_report_*.txt 2>/dev/null | head -1)"
ARCHIVE_ROOT="/srv/toolbox/shared/artwork-cold-archive/stockhausen"

SNAPSHOT_TSV="$RAW_DIR/stockhausen_hot_artwork_purge_snapshot_$STAMP.tsv"
PURGE_TSV="$RAW_DIR/stockhausen_hot_artwork_purge_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_hot_artwork_purge_report_$STAMP.txt"

[[ -d "$MUSIC_ROOT" ]] || fail "Music root não encontrado."
[[ -d "$ARCHIVE_ROOT" ]] || fail "Cold archive não encontrado."
[[ -f "$VALIDATION_REPORT" ]] || fail "Validation report não encontrado."

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Stockhausen Hot Artwork Purge"
log "Cold archive root: $ARCHIVE_ROOT"
log "Validation report: $VALIDATION_REPORT"

printf "artwork_dir\talbum_dir\tfiles\tsize_bytes\tsize_human\n" > "$SNAPSHOT_TSV"

TOTAL_DIRS=0
TOTAL_FILES=0
TOTAL_BYTES=0

while IFS= read -r artwork_dir; do
  album_dir="$(dirname "$artwork_dir")"

  files="$(find "$artwork_dir" -type f | wc -l)"
  size_bytes="$(du -sb "$artwork_dir" | awk '{print $1}')"
  size_human="$(du -sh "$artwork_dir" | awk '{print $1}')"

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$artwork_dir" \
    "$album_dir" \
    "$files" \
    "$size_bytes" \
    "$size_human" >> "$SNAPSHOT_TSV"

  TOTAL_DIRS=$((TOTAL_DIRS + 1))
  TOTAL_FILES=$((TOTAL_FILES + files))
  TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))

done < <(
  find "$MUSIC_ROOT" -type d -iname "Artwork" | sort
)

TOTAL_HUMAN="$(numfmt --to=iec-i --suffix=B "$TOTAL_BYTES")"

log "Snapshot criado:"
log "$SNAPSHOT_TSV"

log "Resumo:"
log "Artwork dirs: $TOTAL_DIRS"
log "Files:        $TOTAL_FILES"
log "Total size:   $TOTAL_HUMAN"

echo
echo "IMPORTANT:"
echo "- Cold archive validation already passed."
echo "- This WILL remove Artwork/ directories from hot storage."
echo "- cover.jpg files outside Artwork/ are preserved."
echo "- Only Artwork/ directories will be deleted."
echo
echo "Type PURGE to continue:"
read -r CONFIRM

[[ "$CONFIRM" == "PURGE" ]] || fail "Operação cancelada."

printf "artwork_dir\tstatus\n" > "$PURGE_TSV"

log "Executando purge..."

PURGED=0
FAILED=0

while IFS=$'\t' read -r artwork_dir album_dir files size_bytes size_human; do
  [[ "$artwork_dir" == "artwork_dir" ]] && continue

  if rm -rf "$artwork_dir"; then
    printf "%s\tOK\n" "$artwork_dir" >> "$PURGE_TSV"
    PURGED=$((PURGED + 1))
    log "PURGED: $artwork_dir"
  else
    printf "%s\tERROR\n" "$artwork_dir" >> "$PURGE_TSV"
    FAILED=$((FAILED + 1))
    log "ERROR: $artwork_dir"
  fi

done < "$SNAPSHOT_TSV"

{
  echo "Stockhausen hot artwork purge report"
  echo "Generated: $(date -Is)"
  echo
  echo "Music root:"
  echo "$MUSIC_ROOT"
  echo
  echo "Cold archive:"
  echo "$ARCHIVE_ROOT"
  echo
  echo "Validation report:"
  echo "$VALIDATION_REPORT"
  echo
  echo "Outputs:"
  echo "$SNAPSHOT_TSV"
  echo "$PURGE_TSV"
  echo
  echo "Summary:"
  echo "Artwork directories purged: $PURGED"
  echo "Failures: $FAILED"
  echo "Files removed: $TOTAL_FILES"
  echo "Estimated space freed: $TOTAL_HUMAN"
  echo
  echo "Status summary:"
  awk -F'\t' 'NR>1 {c[$2]++} END {for (k in c) print k, c[k]}' "$PURGE_TSV" | sort
  echo
  echo "Notes:"
  echo "- Only Artwork/ directories were removed."
  echo "- cover.jpg hot-layer files remain untouched."
  echo "- Cold archives remain preserved under:"
  echo "  $ARCHIVE_ROOT"
} > "$REPORT"

log "Purge concluído."
log "Purge TSV: $PURGE_TSV"
log "Relatório: $REPORT"
