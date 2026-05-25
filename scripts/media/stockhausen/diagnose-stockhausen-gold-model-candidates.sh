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

OUT_TSV="$RAW_DIR/stockhausen_gold_model_candidates_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_gold_model_candidates_report_$STAMP.txt"

command -v exiftool >/dev/null 2>&1 || fail "exiftool não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório raiz não encontrado: $ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Iniciando diagnóstico de candidatos a modelo ouro..."
log "Raiz: $ROOT"

printf "release_path\tdisc_dirs\tflacs\tis_multidisc\tcover_files\tartwork_dirs\tartwork_size_human\tmbid_tags\tmissing_titles\talbumartist_values\tartist_values\tcomposer_values\talbum_values\tgrouping_guess\tscore\trecommendation\n" > "$OUT_TSV"

is_release_dir() {
  local dir="$1"
  local base
  base="$(basename "$dir")"

  [[ "$base" =~ ^[0-9]{3}[[:space:]]+Stockhausen[[:space:]]+- ]] && return 0
  return 1
}

analyze_release() {
  local release="$1"
  local tmp flac_count disc_count is_multidisc cover_count artwork_count artwork_size
  local mbid_tags missing_titles albumartist_values artist_values composer_values album_values grouping_guess score recommendation

  tmp="$(mktemp)"

  mapfile -d '' flacs < <(find "$release" -type f -iname '*.flac' -print0 | sort -z)
  flac_count="${#flacs[@]}"

  [[ "$flac_count" -gt 0 ]] || {
    rm -f "$tmp"
    return
  }

  mapfile -d '' discdirs < <(find "$release" -mindepth 1 -maxdepth 1 -type d -iname 'CD*' -print0 | sort -z)
  disc_count="${#discdirs[@]}"

  is_multidisc="no"
  [[ "$disc_count" -gt 1 ]] && is_multidisc="yes"

  for f in "${flacs[@]}"; do
    exiftool -s "$f" >> "$tmp"
  done

  cover_count="$(find "$release" -type f \( -iname 'cover.jpg' -o -iname 'cover.jpeg' -o -iname 'folder.jpg' -o -iname 'front.jpg' \) | wc -l | tr -d ' ')"
  artwork_count="$(find "$release" -type d -iname 'Artwork' | wc -l | tr -d ' ')"
  artwork_size="$(du -sh "$release" 2>/dev/null | awk '{print $1}')"

  mbid_tags="$(awk -F: 'tolower($1) ~ /musicbrainz/ {c++} END {print c+0}' "$tmp")"

  missing_titles="$(
    missing=0
    for f in "${flacs[@]}"; do
      title="$(exiftool -s3 -Title "$f" 2>/dev/null)"
      [[ -z "$title" ]] && missing=$((missing + 1))
    done
    echo "$missing"
  )"

  albumartist_values="$(
    awk -F: 'tolower($1) ~ /^[[:space:]]*albumartist[[:space:]]*$/ {
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

  composer_values="$(
    awk -F: 'tolower($1) ~ /^[[:space:]]*composer[[:space:]]*$/ {
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

  grouping_guess="$(basename "$(dirname "$release")")"

  score=0

  [[ "$is_multidisc" == "yes" ]] && score=$((score + 25))
  [[ "$flac_count" -ge 8 ]] && score=$((score + 15))
  [[ "$mbid_tags" -gt 0 ]] && score=$((score + 20))
  [[ "$missing_titles" -eq 0 ]] && score=$((score + 20))
  [[ "$albumartist_values" == *"Karlheinz Stockhausen"* ]] && score=$((score + 10))
  [[ -n "$album_values" ]] && score=$((score + 10))
  [[ "$cover_count" -gt 0 ]] && score=$((score + 5))
  [[ "$artwork_count" -gt 0 ]] && score=$((score + 5))

  if [[ "$is_multidisc" == "yes" && "$missing_titles" -eq 0 && "$flac_count" -ge 8 ]]; then
    recommendation="STRONG_MULTICD_CANDIDATE"
  elif [[ "$missing_titles" -eq 0 && "$mbid_tags" -gt 0 ]]; then
    recommendation="STRONG_SINGLECD_CANDIDATE"
  elif [[ "$missing_titles" -eq 0 ]]; then
    recommendation="USABLE_CANDIDATE"
  else
    recommendation="WEAK_CANDIDATE"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$release" \
    "$disc_count" \
    "$flac_count" \
    "$is_multidisc" \
    "$cover_count" \
    "$artwork_count" \
    "$artwork_size" \
    "$mbid_tags" \
    "$missing_titles" \
    "$albumartist_values" \
    "$artist_values" \
    "$composer_values" \
    "$album_values" \
    "$grouping_guess" \
    "$score" \
    "$recommendation" >> "$OUT_TSV"

  rm -f "$tmp"
}

count=0

while IFS= read -r -d '' dir; do
  if is_release_dir "$dir"; then
    count=$((count + 1))
    log "Analisando release $count: $dir"
    analyze_release "$dir"
  fi
done < <(find "$ROOT" -type d -print0 | sort -z)

log "Gerando relatório..."

{
  echo "Stockhausen gold model candidate diagnostic report"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Output TSV:"
  echo "$OUT_TSV"
  echo
  echo "Releases analyzed:"
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Recommendation summary:"
  awk -F'\t' 'NR>1 {c[$16]++} END {for (k in c) print k, c[k]}' "$OUT_TSV" | sort

  echo
  echo "Top multi-CD candidates:"
  awk -F'\t' 'NR>1 && $4 == "yes" {print $15 "\t" $16 "\t" $3 " flacs\t" $1}' "$OUT_TSV" \
    | sort -nr \
    | head -20

  echo
  echo "Top candidates overall:"
  awk -F'\t' 'NR>1 {print $15 "\t" $16 "\t" $4 "\t" $3 " flacs\t" $1}' "$OUT_TSV" \
    | sort -nr \
    | head -30

  echo
  echo "Candidates with MusicBrainz tags:"
  awk -F'\t' 'NR>1 && $8 > 0 {print $15 "\t" $8 " MB tags\t" $1}' "$OUT_TSV" \
    | sort -nr \
    | head -30

  echo
  echo "Candidates with missing titles:"
  awk -F'\t' 'NR>1 && $9 > 0 {print $9 " missing titles\t" $1}' "$OUT_TSV" \
    | sort -nr \
    | head -20

} > "$REPORT"

log "Diagnóstico concluído."
log "TSV:       $OUT_TSV"
log "Relatório: $REPORT"
