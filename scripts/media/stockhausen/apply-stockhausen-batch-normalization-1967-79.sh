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
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"

STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$(ls -t "$RAW_DIR"/stockhausen_batch_normalization_plan_1967-79_*.tsv 2>/dev/null | head -1)"

SNAPSHOT_TSV="$SNAPSHOT_DIR/stockhausen_batch_pre_apply_snapshot_1967-79_$STAMP.tsv"
APPLY_TSV="$RAW_DIR/stockhausen_batch_apply_1967-79_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_batch_apply_report_1967-79_$STAMP.txt"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório root não encontrado: $ROOT"
[[ -f "$PLAN_TSV" ]] || fail "Plano batch não encontrado."

mkdir -p "$RAW_DIR" "$REPORT_DIR" "$SNAPSHOT_DIR"

log "Stockhausen batch normalization apply — 1967-79"
log "Root: $ROOT"
log "Plan: $PLAN_TSV"

total_tracks="$(awk 'NR>1 {c++} END {print c+0}' "$PLAN_TSV")"
rename_count="$(awk -F'\t' 'NR>1 && $2 != $6 {c++} END {print c+0}' "$PLAN_TSV")"
high_count="$(awk -F'\t' 'NR>1 && $19 == "HIGH" {c++} END {print c+0}' "$PLAN_TSV")"
non_high_count="$(awk -F'\t' 'NR>1 && $19 != "HIGH" {c++} END {print c+0}' "$PLAN_TSV")"
flags_count="$(awk -F'\t' 'NR>1 && $20 != "" {c++} END {print c+0}' "$PLAN_TSV")"

echo
echo "Operations summary:"
echo "- Tracks:        $total_tracks"
echo "- Renames:       $rename_count"
echo "- HIGH:          $high_count"
echo "- Non-HIGH:      $non_high_count"
echo "- Flagged rows:  $flags_count"
echo
echo "IMPORTANT:"
echo "- This WILL modify real FLAC files in the 1967-79 corpus."
echo "- It will apply AlbumArtist, Artist, Composer and Grouping."
echo "- It will rename files according to the latest plan."
echo "- Performer tags will be preserved."
echo "- MusicBrainz IDs will be preserved."
echo "- cover.jpg and cold archives will NOT be modified."
echo

if [[ "$non_high_count" -ne 0 || "$flags_count" -ne 0 ]]; then
  fail "Plano contém linhas não-HIGH ou flags. Revise antes de aplicar."
fi

printf "Type APPLY-1967-79 to continue: "
read -r CONFIRM

[[ "$CONFIRM" == "APPLY-1967-79" ]] || fail "Operação cancelada."

log "Criando snapshot pré-aplicação..."

printf "album_dir\trelative_path\tabsolute_path\ttags_before\n" > "$SNAPSHOT_TSV"

awk -F'\t' 'NR>1 {print $1 "\t" $2}' "$PLAN_TSV" | while IFS=$'\t' read -r album_dir rel; do
  abs="$ROOT/$album_dir/$rel"

  if [[ ! -f "$abs" ]]; then
    printf "%s\t%s\t%s\tMISSING_FILE\n" "$album_dir" "$rel" "$abs" >> "$SNAPSHOT_TSV"
    continue
  fi

  tags="$(metaflac --export-tags-to=- "$abs" 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
  printf "%s\t%s\t%s\t%s\n" "$album_dir" "$rel" "$abs" "$tags" >> "$SNAPSHOT_TSV"
done

log "Snapshot salvo:"
log "$SNAPSHOT_TSV"

printf "album_dir\told_relative_path\tnew_relative_path\tstatus\tdetail\n" > "$APPLY_TSV"

log "Aplicando tags e renames..."

tail -n +2 "$PLAN_TSV" | while IFS=$'\t' read -r \
  album_dir \
  relative_path \
  current_filename \
  tracknumber \
  title \
  proposed_filename \
  current_albumartist \
  proposed_albumartist \
  current_artist \
  proposed_artist \
  current_composer \
  proposed_composer \
  current_grouping \
  proposed_grouping \
  current_performer \
  proposed_performer \
  mb_albumid \
  mb_trackid \
  confidence \
  flags
do
  old_abs="$ROOT/$album_dir/$relative_path"
  new_abs="$ROOT/$album_dir/$proposed_filename"

  if [[ ! -f "$old_abs" ]]; then
    printf "%s\t%s\t%s\tERROR\tmissing source file\n" "$album_dir" "$relative_path" "$proposed_filename" >> "$APPLY_TSV"
    log "ERROR missing: $old_abs"
    continue
  fi

  metaflac --remove-tag=ALBUMARTIST --set-tag="ALBUMARTIST=$proposed_albumartist" "$old_abs"
  metaflac --remove-tag=ARTIST --set-tag="ARTIST=$proposed_artist" "$old_abs"
  metaflac --remove-tag=COMPOSER --set-tag="COMPOSER=$proposed_composer" "$old_abs"
  metaflac --remove-tag=GROUPING --set-tag="GROUPING=$proposed_grouping" "$old_abs"

  if [[ "$relative_path" != "$proposed_filename" ]]; then
    mkdir -p "$(dirname "$new_abs")"

    if [[ -e "$new_abs" ]]; then
      printf "%s\t%s\t%s\tERROR\ttarget exists\n" "$album_dir" "$relative_path" "$proposed_filename" >> "$APPLY_TSV"
      log "ERROR target exists: $new_abs"
      continue
    fi

    mv "$old_abs" "$new_abs"
    printf "%s\t%s\t%s\tRENAMED\tOK\n" "$album_dir" "$relative_path" "$proposed_filename" >> "$APPLY_TSV"
    log "RENAMED: $album_dir :: $relative_path -> $proposed_filename"
  else
    printf "%s\t%s\t%s\tTAGGED_ONLY\tOK\n" "$album_dir" "$relative_path" "$proposed_filename" >> "$APPLY_TSV"
  fi
done

{
  echo "Stockhausen batch normalization apply report — 1967-79"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Plan:"
  echo "$PLAN_TSV"
  echo
  echo "Outputs:"
  echo "$SNAPSHOT_TSV"
  echo "$APPLY_TSV"
  echo
  echo "Summary:"
  printf "Tracks in plan: "
  awk 'NR>1 {c++} END {print c+0}' "$PLAN_TSV"

  printf "Tagged only: "
  awk -F'\t' 'NR>1 && $4 == "TAGGED_ONLY" {c++} END {print c+0}' "$APPLY_TSV"

  printf "Renamed: "
  awk -F'\t' 'NR>1 && $4 == "RENAMED" {c++} END {print c+0}' "$APPLY_TSV"

  printf "Errors: "
  awk -F'\t' 'NR>1 && $4 == "ERROR" {c++} END {print c+0}' "$APPLY_TSV"

  echo
  echo "Status summary:"
  awk -F'\t' 'NR>1 {c[$4]++} END {for (k in c) print k, c[k]}' "$APPLY_TSV" | sort

  echo
  echo "Notes:"
  echo "- Metadata written with metaflac."
  echo "- Performer tags were preserved."
  echo "- MusicBrainz tags were preserved."
  echo "- cover.jpg and cold archives were not modified."
} > "$REPORT"

log "Aplicação batch concluída."
log "Apply TSV: $APPLY_TSV"
log "Relatório: $REPORT"
