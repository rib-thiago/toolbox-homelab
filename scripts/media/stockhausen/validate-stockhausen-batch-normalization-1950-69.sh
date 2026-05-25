#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen/1950-69: Serial Music: Points to Groups - Moment Form - Electronic & Tape Music"
GROUPING="1950-69: Serial Music: Points to Groups - Moment Form - Electronic & Tape Music"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$(ls -t "$RAW_DIR"/stockhausen_batch_normalization_plan_1950-69_*.tsv 2>/dev/null | head -1)"
APPLY_TSV="$(ls -t "$RAW_DIR"/stockhausen_batch_safe_apply_*.tsv 2>/dev/null | head -1)"

VALIDATION_TSV="$RAW_DIR/stockhausen_batch_post_apply_validation_1950-69_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_batch_post_apply_validation_report_1950-69_$STAMP.txt"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório root não encontrado: $ROOT"
[[ -f "$PLAN_TSV" ]] || fail "Plano batch não encontrado."
[[ -f "$APPLY_TSV" ]] || fail "Apply TSV não encontrado."

mkdir -p "$RAW_DIR" "$REPORT_DIR"

get_tag() {
  local file="$1"
  local tag="$2"
  metaflac --show-tag="$tag" "$file" 2>/dev/null | sed "s/^$tag=//" | paste -sd ';' -
}

log "Validando normalização batch pós-aplicação — 1967-79..."
log "Root:  $ROOT"
log "Plan:  $PLAN_TSV"
log "Apply: $APPLY_TSV"

printf "album_dir\texpected_relative_path\tfile_exists\tfilename_ok\talbumartist_ok\tartist_ok\tcomposer_ok\tgrouping_ok\tmb_albumid_present\tmb_trackid_present\tperformer_present_or_empty_ok\tvalidation_status\tflags\n" > "$VALIDATION_TSV"

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
  flags_plan
do
  expected_abs="$ROOT/$album_dir/$proposed_filename"
  base="$(basename "$proposed_filename")"

  file_exists="no"
  filename_ok="no"
  albumartist_ok="no"
  artist_ok="no"
  composer_ok="no"
  grouping_ok="no"
  mb_albumid_present="no"
  mb_trackid_present="no"
  performer_present_or_empty_ok="yes"
  validation_status="OK"
  flags=""

  if [[ -f "$expected_abs" ]]; then
    file_exists="yes"
  else
    validation_status="ERROR"
    flags="${flags};MISSING_EXPECTED_FILE"
  fi

  if [[ "$base" =~ ^[0-9]{2}\ -\ .+\.flac$ ]]; then
    filename_ok="yes"
  else
    validation_status="ERROR"
    flags="${flags};BAD_FILENAME_PATTERN"
  fi

  if [[ "$file_exists" == "yes" ]]; then
    albumartist="$(get_tag "$expected_abs" ALBUMARTIST)"
    artist="$(get_tag "$expected_abs" ARTIST)"
    composer="$(get_tag "$expected_abs" COMPOSER)"
    grouping="$(get_tag "$expected_abs" GROUPING)"
    performer="$(get_tag "$expected_abs" PERFORMER)"
    mb_albumid_now="$(get_tag "$expected_abs" MUSICBRAINZ_ALBUMID)"
    mb_trackid_now="$(get_tag "$expected_abs" MUSICBRAINZ_TRACKID)"

    [[ "$albumartist" == "Karlheinz Stockhausen" ]] && albumartist_ok="yes"
    [[ "$artist" == "Karlheinz Stockhausen" ]] && artist_ok="yes"
    [[ "$composer" == "Karlheinz Stockhausen" ]] && composer_ok="yes"
    [[ "$grouping" == "$GROUPING" ]] && grouping_ok="yes"
    [[ -n "$mb_albumid_now" ]] && mb_albumid_present="yes"
    [[ -n "$mb_trackid_now" ]] && mb_trackid_present="yes"

    if [[ -n "$proposed_performer" && -z "$performer" ]]; then
      performer_present_or_empty_ok="no"
    fi
  fi

  for check in \
    "$file_exists" \
    "$filename_ok" \
    "$albumartist_ok" \
    "$artist_ok" \
    "$composer_ok" \
    "$grouping_ok" \
    "$mb_albumid_present" \
    "$mb_trackid_present" \
    "$performer_present_or_empty_ok"
  do
    if [[ "$check" != "yes" ]]; then
      validation_status="ERROR"
    fi
  done

  [[ "$albumartist_ok" != "yes" ]] && flags="${flags};BAD_ALBUMARTIST"
  [[ "$artist_ok" != "yes" ]] && flags="${flags};BAD_ARTIST"
  [[ "$composer_ok" != "yes" ]] && flags="${flags};BAD_COMPOSER"
  [[ "$grouping_ok" != "yes" ]] && flags="${flags};BAD_GROUPING"
  [[ "$mb_albumid_present" != "yes" ]] && flags="${flags};MISSING_MB_ALBUMID"
  [[ "$mb_trackid_present" != "yes" ]] && flags="${flags};MISSING_MB_TRACKID"
  [[ "$performer_present_or_empty_ok" != "yes" ]] && flags="${flags};MISSING_PERFORMER"

  flags="${flags#;}"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$album_dir" \
    "$proposed_filename" \
    "$file_exists" \
    "$filename_ok" \
    "$albumartist_ok" \
    "$artist_ok" \
    "$composer_ok" \
    "$grouping_ok" \
    "$mb_albumid_present" \
    "$mb_trackid_present" \
    "$performer_present_or_empty_ok" \
    "$validation_status" \
    "$flags" >> "$VALIDATION_TSV"
done

{
  echo "Stockhausen batch post-apply validation report — 1967-79"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Inputs:"
  echo "$PLAN_TSV"
  echo "$APPLY_TSV"
  echo
  echo "Output:"
  echo "$VALIDATION_TSV"
  echo
  echo "Summary:"
  printf "Rows validated: "
  awk 'NR>1 {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "OK: "
  awk -F'\t' 'NR>1 && $12 == "OK" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "ERROR: "
  awk -F'\t' 'NR>1 && $12 == "ERROR" {c++} END {print c+0}' "$VALIDATION_TSV"

  echo
  echo "Check summaries:"
  printf "Files exist: "
  awk -F'\t' 'NR>1 && $3 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "Filename OK: "
  awk -F'\t' 'NR>1 && $4 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "AlbumArtist OK: "
  awk -F'\t' 'NR>1 && $5 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "Artist OK: "
  awk -F'\t' 'NR>1 && $6 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "Composer OK: "
  awk -F'\t' 'NR>1 && $7 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "Grouping OK: "
  awk -F'\t' 'NR>1 && $8 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "MB AlbumId present: "
  awk -F'\t' 'NR>1 && $9 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "MB TrackId present: "
  awk -F'\t' 'NR>1 && $10 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  printf "Performer OK: "
  awk -F'\t' 'NR>1 && $11 == "yes" {c++} END {print c+0}' "$VALIDATION_TSV"

  echo
  echo "Status summary:"
  awk -F'\t' 'NR>1 {c[$12]++} END {for (k in c) print k, c[k]}' "$VALIDATION_TSV" | sort

  echo
  echo "Failures:"
  awk -F'\t' 'NR>1 && $12 != "OK" {print "- " $1 " :: " $2 " :: " $13}' "$VALIDATION_TSV" | head -120

  echo
  echo "Notes:"
  echo "- This script does not modify files."
  echo "- It validates the 1967-79 post-apply state against the latest batch plan."
} > "$REPORT"

log "Validação concluída."
log "Validation TSV: $VALIDATION_TSV"
log "Relatório:      $REPORT"
