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

OUT_TSV="$RAW_DIR/stockhausen_library_quality_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_library_quality_report_$STAMP.txt"

command -v exiftool >/dev/null 2>&1 || fail "exiftool não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório raiz não encontrado: $ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Iniciando análise de qualidade da biblioteca Stockhausen..."
log "Raiz: $ROOT"

printf "album_path\tflacs\tmbid_tags\tuuid_genre\tnumeric_composer\tmissing_title\talbumartist_ok\talbum_values\tartist_values\tcomposer_values\tgenre_values\tscore\tclass\n" > "$OUT_TSV"

album_count=0

while IFS= read -r -d '' dir; do
  mapfile -d '' flacs < <(find "$dir" -maxdepth 1 -type f -iname '*.flac' -print0 | sort -z)

  [[ "${#flacs[@]}" -gt 0 ]] || continue

  album_count=$((album_count + 1))
  log "Analisando álbum $album_count: $dir"

  tmp="$(mktemp)"

  for f in "${flacs[@]}"; do
    exiftool -s "$f" >> "$tmp"
  done

  flac_count="${#flacs[@]}"

  mbid_tags="$(awk -F: 'tolower($1) ~ /musicbrainz/ {c++} END {print c+0}' "$tmp")"
  uuid_genre="$(awk -F: 'tolower($1) ~ /^[[:space:]]*genre[[:space:]]*$/ && $2 ~ /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/ {c++} END {print c+0}' "$tmp")"
  numeric_composer="$(awk -F: 'tolower($1) ~ /^[[:space:]]*composer[[:space:]]*$/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); if ($2 ~ /^[0-9]+$/) c++} END {print c+0}' "$tmp")"
  missing_title="$(
    for f in "${flacs[@]}"; do
      title="$(exiftool -s3 -Title "$f" 2>/dev/null)"
      [[ -z "$title" ]] && echo 1
    done | wc -l | tr -d ' '
  )"

  albumartist_ok="$(
    ok=0
    total=0
    for f in "${flacs[@]}"; do
      aa="$(exiftool -s3 -AlbumArtist "$f" 2>/dev/null)"
      [[ "$aa" == "Karlheinz Stockhausen" ]] && ok=$((ok + 1))
      total=$((total + 1))
    done
    if [[ "$total" -gt 0 && "$ok" -eq "$total" ]]; then
      echo "yes"
    else
      echo "no"
    fi
  )"

  album_values="$(awk -F: 'tolower($1) ~ /^[[:space:]]*album[[:space:]]*$/ {sub(/^[^:]+:[ \t]*/, ""); print}' "$tmp" | sort -u | paste -sd '|' -)"
  artist_values="$(awk -F: 'tolower($1) ~ /^[[:space:]]*artist[[:space:]]*$/ {sub(/^[^:]+:[ \t]*/, ""); print}' "$tmp" | sort -u | paste -sd '|' -)"
  composer_values="$(awk -F: 'tolower($1) ~ /^[[:space:]]*composer[[:space:]]*$/ {sub(/^[^:]+:[ \t]*/, ""); print}' "$tmp" | sort -u | paste -sd '|' -)"
  genre_values="$(awk -F: 'tolower($1) ~ /^[[:space:]]*genre[[:space:]]*$/ {sub(/^[^:]+:[ \t]*/, ""); print}' "$tmp" | sort -u | paste -sd '|' -)"

  score=0

  [[ "$mbid_tags" -gt 0 ]] && score=$((score + 25))
  [[ "$albumartist_ok" == "yes" ]] && score=$((score + 25))
  [[ "$missing_title" -eq 0 ]] && score=$((score + 15))
  [[ -n "$album_values" ]] && score=$((score + 10))
  [[ "$uuid_genre" -gt 0 ]] && score=$((score - 25))
  [[ "$numeric_composer" -gt 0 ]] && score=$((score - 25))

  if [[ "$mbid_tags" -eq 0 && "$missing_title" -gt 0 ]]; then
    class="RAW"
  elif [[ "$score" -ge 60 && "$uuid_genre" -eq 0 && "$numeric_composer" -eq 0 ]]; then
    class="GOOD"
  elif [[ "$mbid_tags" -gt 0 ]] && { [[ "$uuid_genre" -gt 0 ]] || [[ "$numeric_composer" -gt 0 ]]; }; then
    class="PARTIAL"
  elif [[ "$score" -lt 20 ]]; then
    class="BROKEN"
  else
    class="PARTIAL"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$dir" \
    "$flac_count" \
    "$mbid_tags" \
    "$uuid_genre" \
    "$numeric_composer" \
    "$missing_title" \
    "$albumartist_ok" \
    "$album_values" \
    "$artist_values" \
    "$composer_values" \
    "$genre_values" \
    "$score" \
    "$class" >> "$OUT_TSV"

  rm -f "$tmp"

done < <(find "$ROOT" -type d -print0 | sort -z)

log "Gerando relatório..."

{
  echo "Stockhausen library quality report"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Outputs:"
  echo "$OUT_TSV"
  echo
  echo "Albums analyzed:"
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Class summary:"
  awk -F'\t' 'NR>1 {c[$13]++} END {for (k in c) print k, c[k]}' "$OUT_TSV" | sort

  echo
  echo "Corruption patterns:"
  printf "Albums with UUID in Genre: "
  awk -F'\t' 'NR>1 && $4 > 0 {c++} END {print c+0}' "$OUT_TSV"

  printf "Albums with numeric Composer: "
  awk -F'\t' 'NR>1 && $5 > 0 {c++} END {print c+0}' "$OUT_TSV"

  printf "Albums with missing Title: "
  awk -F'\t' 'NR>1 && $6 > 0 {c++} END {print c+0}' "$OUT_TSV"

  printf "Albums with AlbumArtist != Karlheinz Stockhausen: "
  awk -F'\t' 'NR>1 && $7 != "yes" {c++} END {print c+0}' "$OUT_TSV"

  printf "Albums with MusicBrainz tags: "
  awk -F'\t' 'NR>1 && $3 > 0 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Worst albums by score:"
  awk -F'\t' 'NR>1 {print $12 "\t" $13 "\t" $1}' "$OUT_TSV" | sort -n | head -20

} > "$REPORT"

log "Análise concluída."
log "TSV:     $OUT_TSV"
log "Relatório: $REPORT"
