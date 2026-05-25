#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

INPUT_TSV="$(ls -t "$RAW_DIR"/stockhausen_library_quality_*.tsv 2>/dev/null | head -1)"
OUT_TSV="$RAW_DIR/stockhausen_partials_analysis_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_partials_analysis_report_$STAMP.txt"

command -v exiftool >/dev/null 2>&1 || fail "exiftool não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório raiz não encontrado: $ROOT"
[[ -n "${INPUT_TSV:-}" && -f "$INPUT_TSV" ]] || fail "Nenhum TSV stockhausen_library_quality_*.tsv encontrado em $RAW_DIR"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Iniciando análise refinada dos PARTIALs..."
log "Input TSV: $INPUT_TSV"

printf "album_path\tflacs\tmbid_tags\talbumartist_ok\talbumartist_values\talbum_values\tartist_values\ttitle_missing\tis_multidisc_dir\tpartial_reason\n" > "$OUT_TSV"

partial_count=0

awk -F'\t' 'NR > 1 && $13 == "PARTIAL" {print $1}' "$INPUT_TSV" | while IFS= read -r dir; do
  [[ -d "$dir" ]] || continue

  mapfile -d '' flacs < <(find "$dir" -maxdepth 1 -type f -iname '*.flac' -print0 | sort -z)
  [[ "${#flacs[@]}" -gt 0 ]] || continue

  partial_count=$((partial_count + 1))
  log "Analisando PARTIAL: $dir"

  tmp="$(mktemp)"

  for f in "${flacs[@]}"; do
    exiftool -s "$f" >> "$tmp"
  done

  flac_count="${#flacs[@]}"

  mbid_tags="$(awk -F: 'tolower($1) ~ /musicbrainz/ {c++} END {print c+0}' "$tmp")"

  albumartist_values="$(
    awk -F: 'tolower($1) ~ /^[[:space:]]*albumartist[[:space:]]*$/ {
      sub(/^[^:]+:[ \t]*/, "")
      print
    }' "$tmp" | sort -u | paste -sd '|' -
  )"

  album_values="$(
    awk -F: 'tolower($1) ~ /^[[:space:]]*album[[:space:]]*$/ {
      sub(/^[^:]+:[ \t]*/, "")
      print
    }' "$tmp" | sort -u | paste -sd '|' -
  )"

  artist_values="$(
    awk -F: 'tolower($1) ~ /^[[:space:]]*artist[[:space:]]*$/ {
      sub(/^[^:]+:[ \t]*/, "")
      print
    }' "$tmp" | sort -u | paste -sd '|' -
  )"

  title_missing="$(
    missing=0
    for f in "${flacs[@]}"; do
      title="$(exiftool -s3 -Title "$f" 2>/dev/null)"
      [[ -z "$title" ]] && missing=$((missing + 1))
    done
    echo "$missing"
  )"

  aa_ok="no"
  if [[ "$albumartist_values" == "Karlheinz Stockhausen" ]]; then
    aa_ok="yes"
  fi

  is_multidisc_dir="no"
  base="$(basename "$dir")"
  parent="$(basename "$(dirname "$dir")")"

  if [[ "$base" =~ ^CD[[:space:]]*[0-9A-Za-z]+$ ]] || [[ "$parent" =~ [23][Cc][Dd]|[0-9]+CD|CD[[:space:]]*[0-9] ]]; then
    is_multidisc_dir="yes"
  fi

  reason="PARTIAL_UNKNOWN"

  if [[ "$mbid_tags" -eq 0 && -z "$albumartist_values" ]]; then
    reason="PARTIAL_NO_MB_NO_ALBUMARTIST"
  elif [[ "$mbid_tags" -eq 0 && "$aa_ok" == "yes" ]]; then
    reason="PARTIAL_NO_MB_BUT_ALBUMARTIST_OK"
  elif [[ "$mbid_tags" -eq 0 ]]; then
    reason="PARTIAL_NO_MB"
  elif [[ "$aa_ok" != "yes" && -z "$albumartist_values" ]]; then
    reason="PARTIAL_ALBUMARTIST_MISSING"
  elif [[ "$aa_ok" != "yes" && "$albumartist_values" == *"|"* ]]; then
    reason="PARTIAL_MULTI_ALBUMARTIST"
  elif [[ "$aa_ok" != "yes" ]]; then
    reason="PARTIAL_ALBUMARTIST_VARIANT"
  elif [[ "$is_multidisc_dir" == "yes" ]]; then
    reason="PARTIAL_MULTIDISC_DIR"
  elif [[ "$title_missing" -gt 0 ]]; then
    reason="PARTIAL_MISSING_TITLE"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$dir" \
    "$flac_count" \
    "$mbid_tags" \
    "$aa_ok" \
    "$albumartist_values" \
    "$album_values" \
    "$artist_values" \
    "$title_missing" \
    "$is_multidisc_dir" \
    "$reason" >> "$OUT_TSV"

  rm -f "$tmp"

done

log "Gerando relatório..."

{
  echo "Stockhausen PARTIAL metadata refinement report"
  echo "Generated: $(date -Is)"
  echo
  echo "Input TSV:"
  echo "$INPUT_TSV"
  echo
  echo "Output TSV:"
  echo "$OUT_TSV"
  echo
  echo "PARTIAL albums analyzed:"
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Partial reason summary:"
  awk -F'\t' 'NR>1 {c[$10]++} END {for (k in c) print k, c[k]}' "$OUT_TSV" | sort

  echo
  echo "AlbumArtist value frequency:"
  awk -F'\t' 'NR>1 {print $5}' "$OUT_TSV" | sort | uniq -c | sort -nr | head -40

  echo
  echo "PARTIALs without MusicBrainz tags:"
  awk -F'\t' 'NR>1 && $3 == 0 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "PARTIALs with MusicBrainz tags:"
  awk -F'\t' 'NR>1 && $3 > 0 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "PARTIALs with missing AlbumArtist:"
  awk -F'\t' 'NR>1 && $5 == "" {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "PARTIALs with multiple AlbumArtist values:"
  awk -F'\t' 'NR>1 && $5 ~ /\|/ {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "PARTIALs with missing titles:"
  awk -F'\t' 'NR>1 && $8 > 0 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Sample PARTIAL_ALBUMARTIST_VARIANT:"
  awk -F'\t' 'NR>1 && $10 == "PARTIAL_ALBUMARTIST_VARIANT" {print "- " $5 " :: " $1}' "$OUT_TSV" | head -20

  echo
  echo "Sample PARTIAL_NO_MB:"
  awk -F'\t' 'NR>1 && $10 == "PARTIAL_NO_MB" {print "- " $1}' "$OUT_TSV" | head -20

} > "$REPORT"

log "Análise refinada concluída."
log "TSV:       $OUT_TSV"
log "Relatório: $REPORT"
