#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

RAW_DIR="/srv/toolbox/shared/library-db/raw"
PLAN_DIR="/srv/toolbox/shared/reports/media/normalization-plans"
REPORT_DIR="/srv/toolbox/shared/reports/media"
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"

STAMP="$(date +%Y%m%d-%H%M%S)"

RENAME_PLAN="$(ls -t "$RAW_DIR"/stockhausen_gold_normalization_rename_plan_*.tsv 2>/dev/null | head -1)"
TAG_PLAN="$(ls -t "$RAW_DIR"/stockhausen_gold_normalization_tag_plan_*.tsv 2>/dev/null | head -1)"

[[ -n "${RENAME_PLAN:-}" ]] || fail "Rename plan não encontrado."
[[ -n "${TAG_PLAN:-}" ]] || fail "Tag plan não encontrado."

mkdir -p "$REPORT_DIR" "$SNAPSHOT_DIR"

SNAPSHOT="$SNAPSHOT_DIR/stockhausen_gold_pre_apply_snapshot_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_gold_apply_report_$STAMP.txt"

log "Stockhausen Gold Normalization Apply"
echo

echo "Rename plan:"
echo "$RENAME_PLAN"
echo

echo "Tag plan:"
echo "$TAG_PLAN"
echo

rename_count="$(awk 'NR>1 && $1 != $2 {c++} END {print c+0}' "$RENAME_PLAN")"
tag_count="$(awk 'NR>1 {c++} END {print c+0}' "$TAG_PLAN")"

echo "Operations summary:"
echo "- Renames: $rename_count"
echo "- Tag operations: $tag_count"
echo

echo "IMPORTANT:"
echo "- This WILL modify real FLAC files."
echo "- This operation is intended ONLY for the gold model album."
echo "- MusicBrainz IDs will be preserved."
echo "- Artwork will NOT be modified."
echo

printf "Type APPLY to continue: "
read -r confirm

[[ "$confirm" == "APPLY" ]] || fail "Operação cancelada."

log "Criando snapshot pré-aplicação..."

printf "file\tfield\tvalue\n" > "$SNAPSHOT"

mapfile -t unique_files < <(
  awk -F'\t' 'NR>1 {print $1}' "$TAG_PLAN" | sort -u
)

for rel in "${unique_files[@]}"; do
  abs="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}/$rel"

  exiftool -s "$abs" \
    | sed 's/[[:space:]]*: /\t/' \
    | awk -v file="$rel" 'BEGIN{FS="\t"; OFS="\t"} NF >= 2 {print file,$1,$2}' >> "$SNAPSHOT"
done

log "Snapshot salvo em:"
log "$SNAPSHOT"

log "Aplicando tags..."

while IFS=$'\t' read -r rel field old new action; do
  [[ "$rel" == "relative_path" ]] && continue

  abs="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}/$rel"

  case "$action" in
    UPDATE|ADD)
      log "TAG [$field] -> [$new]"
      metaflac --remove-tag="$field" --set-tag="$field=$new" "$abs"
      ;;
  esac

done < "$TAG_PLAN"

log "Aplicando renames..."

while IFS=$'\t' read -r old_rel new_rel track title filename_title; do
  [[ "$old_rel" == "old_relative_path" ]] && continue

  old_abs="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}/$old_rel"

  new_abs="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}/$new_rel"

  if [[ "$old_abs" != "$new_abs" ]]; then
    log "RENAME:"
    log "OLD: $old_rel"
    log "NEW: $new_rel"

    mv "$old_abs" "$new_abs"
  fi

done < "$RENAME_PLAN"

{
  echo "Stockhausen gold normalization apply report"
  echo "Generated: $(date -Is)"
  echo
  echo "Rename plan:"
  echo "$RENAME_PLAN"
  echo
  echo "Tag plan:"
  echo "$TAG_PLAN"
  echo
  echo "Snapshot:"
  echo "$SNAPSHOT"
  echo
  echo "Operations:"
  echo "- Renames applied: $rename_count"
  echo "- Tag operations applied: $tag_count"
  echo
  echo "Normalization completed successfully."
} > "$REPORT"

log "Aplicação concluída."
log "Relatório:"
log "$REPORT"
