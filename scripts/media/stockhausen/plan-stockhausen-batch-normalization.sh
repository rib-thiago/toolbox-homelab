#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form"
GROUPING="1967-79: Live Electronics - Intuitive Music - Formula Form"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$RAW_DIR/stockhausen_batch_normalization_plan_1967-79_$STAMP.tsv"
ALBUM_TSV="$RAW_DIR/stockhausen_batch_album_summary_1967-79_$STAMP.tsv"
ANOMALY_TSV="$RAW_DIR/stockhausen_batch_anomalies_1967-79_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_batch_normalization_plan_1967-79_$STAMP.txt"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório não encontrado: $ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

get_tag() {
  local file="$1"
  local tag="$2"
  metaflac --show-tag="$tag" "$file" 2>/dev/null | sed "s/^$tag=//" | paste -sd ';' -
}

sanitize_filename() {
  printf '%s' "$1" \
    | sed 's/[[:cntrl:]]//g' \
    | sed 's#[/]#-#g' \
    | sed 's/[?*<>|"]/ /g' \
    | sed 's/:/ -/g' \
    | sed 's/[[:space:]][[:space:]]*/ /g' \
    | sed 's/[[:space:]]*$//' \
    | sed 's/^[[:space:]]*//'
}

strip_work_prefix_for_filename() {
  local title="$1"

  # Remove prefixo "Obra (...): " quando existir.
  # Mantém a tag Title intacta; só simplifica filename.
  printf '%s' "$title" | sed -E 's/^[^:]{3,120}\([^)]*\):[[:space:]]*//'
}

printf "album_dir\trelative_path\tcurrent_filename\ttracknumber\ttitle\tproposed_filename\tcurrent_albumartist\tproposed_albumartist\tcurrent_artist\tproposed_artist\tcurrent_composer\tproposed_composer\tcurrent_grouping\tproposed_grouping\tcurrent_performer\tproposed_performer\tmb_albumid\tmb_trackid\tconfidence\tflags\n" > "$PLAN_TSV"

printf "album_dir\tflac_count\talbumartist_values\tartist_values\tcomposer_values\tgrouping_values\tperformer_values\tmb_albumid_count\tmb_trackid_count\tconfidence\tflags\n" > "$ALBUM_TSV"

printf "album_dir\trelative_path\tissue\tdetail\n" > "$ANOMALY_TSV"

log "Planejando normalização batch do corpus 1967-79..."
log "Root: $ROOT"

while IFS= read -r -d '' album_dir; do
  album_name="$(basename "$album_dir")"
  log "Analisando álbum: $album_name"

  mapfile -d '' FLACS < <(find "$album_dir" -type f -iname '*.flac' -print0 | sort -z)

  [[ "${#FLACS[@]}" -gt 0 ]] || continue

  tmp_albumartist="$(mktemp)"
  tmp_artist="$(mktemp)"
  tmp_composer="$(mktemp)"
  tmp_grouping="$(mktemp)"
  tmp_performer="$(mktemp)"

  mb_albumid_count=0
  mb_trackid_count=0
  album_flags=""

  for f in "${FLACS[@]}"; do
    rel="${f#$album_dir/}"
    current_filename="$(basename "$f")"
    dir_rel="$(dirname "$rel")"

    tracknumber="$(get_tag "$f" TRACKNUMBER)"
    title="$(get_tag "$f" TITLE)"
    albumartist="$(get_tag "$f" ALBUMARTIST)"
    artist="$(get_tag "$f" ARTIST)"
    composer="$(get_tag "$f" COMPOSER)"
    grouping="$(get_tag "$f" GROUPING)"
    performer="$(get_tag "$f" PERFORMER)"
    mb_albumid="$(get_tag "$f" MUSICBRAINZ_ALBUMID)"
    mb_trackid="$(get_tag "$f" MUSICBRAINZ_TRACKID)"

    [[ -n "$albumartist" ]] && printf "%s\n" "$albumartist" >> "$tmp_albumartist"
    [[ -n "$artist" ]] && printf "%s\n" "$artist" >> "$tmp_artist"
    [[ -n "$composer" ]] && printf "%s\n" "$composer" >> "$tmp_composer"
    [[ -n "$grouping" ]] && printf "%s\n" "$grouping" >> "$tmp_grouping"
    [[ -n "$performer" ]] && printf "%s\n" "$performer" >> "$tmp_performer"

    [[ -n "$mb_albumid" ]] && mb_albumid_count=$((mb_albumid_count + 1))
    [[ -n "$mb_trackid" ]] && mb_trackid_count=$((mb_trackid_count + 1))

    flags=""
    confidence="HIGH"

    if [[ -z "$tracknumber" ]]; then
      flags="${flags};MISSING_TRACKNUMBER"
      confidence="LOW"
      printf "%s\t%s\tMISSING_TRACKNUMBER\tTrackNumber ausente\n" "$album_name" "$rel" >> "$ANOMALY_TSV"
    fi

    if [[ -z "$title" ]]; then
      flags="${flags};MISSING_TITLE"
      confidence="LOW"
      printf "%s\t%s\tMISSING_TITLE\tTitle ausente\n" "$album_name" "$rel" >> "$ANOMALY_TSV"
    fi

    if [[ -z "$mb_albumid" || -z "$mb_trackid" ]]; then
      flags="${flags};MISSING_MBID"
      [[ "$confidence" != "LOW" ]] && confidence="MEDIUM"
    fi

    proposed_albumartist="Karlheinz Stockhausen"
    proposed_artist="Karlheinz Stockhausen"
    proposed_composer="Karlheinz Stockhausen"
    proposed_grouping="$GROUPING"

    proposed_performer="$performer"

    # Se performer estiver vazio e Artist/AlbumArtist tiverem ensemble junto com Stockhausen,
    # marca candidato para revisão, sem inventar automaticamente.
    if [[ -z "$performer" ]]; then
      if [[ "$albumartist" == *";"* || "$artist" == *";"* ]]; then
        flags="${flags};PERFORMER_CANDIDATE_FROM_ARTIST_FIELDS"
        [[ "$confidence" == "HIGH" ]] && confidence="MEDIUM"
      fi
    fi

    filename_title="$(strip_work_prefix_for_filename "$title")"
    filename_title="$(sanitize_filename "$filename_title")"

    track_base="${tracknumber%%/*}"

    if [[ "$track_base" =~ ^[0-9]+$ && -n "$filename_title" ]]; then
      track_padded="$(printf "%02d" "$track_base")"
      proposed_filename="$track_padded - $filename_title.flac"
    else
      proposed_filename=""
      flags="${flags};CANNOT_PROPOSE_FILENAME"
      confidence="LOW"
      printf "%s\t%s\tCANNOT_PROPOSE_FILENAME\ttracknumber='%s' title='%s'\n" "$album_name" "$rel" "$tracknumber" "$title" >> "$ANOMALY_TSV"
    fi

    if [[ "$dir_rel" != "." && -n "$proposed_filename" ]]; then
      proposed_filename="$dir_rel/$proposed_filename"
    fi

    flags="${flags#;}"

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$album_name" \
      "$rel" \
      "$current_filename" \
      "$tracknumber" \
      "$title" \
      "$proposed_filename" \
      "$albumartist" \
      "$proposed_albumartist" \
      "$artist" \
      "$proposed_artist" \
      "$composer" \
      "$proposed_composer" \
      "$grouping" \
      "$proposed_grouping" \
      "$performer" \
      "$proposed_performer" \
      "$mb_albumid" \
      "$mb_trackid" \
      "$confidence" \
      "$flags" >> "$PLAN_TSV"
  done

  albumartist_values="$(sort -u "$tmp_albumartist" | paste -sd '|' -)"
  artist_values="$(sort -u "$tmp_artist" | paste -sd '|' -)"
  composer_values="$(sort -u "$tmp_composer" | paste -sd '|' -)"
  grouping_values="$(sort -u "$tmp_grouping" | paste -sd '|' -)"
  performer_values="$(sort -u "$tmp_performer" | paste -sd '|' -)"

  rm -f "$tmp_albumartist" "$tmp_artist" "$tmp_composer" "$tmp_grouping" "$tmp_performer"

  album_confidence="HIGH"

  if [[ "$mb_albumid_count" -eq 0 || "$mb_trackid_count" -eq 0 ]]; then
    album_confidence="MEDIUM"
    album_flags="${album_flags};PARTIAL_OR_MISSING_MBIDS"
  fi

  album_flags="${album_flags#;}"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$album_name" \
    "${#FLACS[@]}" \
    "$albumartist_values" \
    "$artist_values" \
    "$composer_values" \
    "$grouping_values" \
    "$performer_values" \
    "$mb_albumid_count" \
    "$mb_trackid_count" \
    "$album_confidence" \
    "$album_flags" >> "$ALBUM_TSV"

done < <(
  find "$ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z
)

{
  echo "Stockhausen batch normalization plan — 1967-79 corpus"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Outputs:"
  echo "$PLAN_TSV"
  echo "$ALBUM_TSV"
  echo "$ANOMALY_TSV"
  echo
  echo "Summary:"
  printf "Albums analyzed: "
  awk 'NR>1 {c++} END {print c+0}' "$ALBUM_TSV"

  printf "Tracks analyzed: "
  awk 'NR>1 {c++} END {print c+0}' "$PLAN_TSV"

  echo
  echo "Confidence summary:"
  awk -F'\t' 'NR>1 {c[$19]++} END {for (k in c) print k, c[k]}' "$PLAN_TSV" | sort

  echo
  echo "Album confidence summary:"
  awk -F'\t' 'NR>1 {c[$10]++} END {for (k in c) print k, c[k]}' "$ALBUM_TSV" | sort

  echo
  echo
  echo "Most common flags:"
  awk -F'\t' '
    NR>1 && $20 != "" {
      n=split($20,a,";")
      for (i=1;i<=n;i++) c[a[i]]++
    }
    END {for (k in c) print c[k], k}
  ' "$PLAN_TSV" | sort -nr | head -30

  echo
  echo
  echo "Album summary:"
  column -t -s $'\t' "$ALBUM_TSV" | head -80

  echo
  echo
  echo "Sample proposed renames:"
  awk -F'\t' 'NR>1 && $3 != $6 {print "ALBUM: " $1 "\nOLD: " $2 "\nNEW: " $6 "\n"}' "$PLAN_TSV" | head -120

  echo
  echo
  echo "Anomalies:"
  awk -F'\t' 'NR>1 {print "- " $1 " :: " $2 " :: " $3 " :: " $4}' "$ANOMALY_TSV" | head -120

  echo
  echo "Notes:"
  echo "- This is a planning script only."
  echo "- No files were modified."
  echo "- The target corpus is 1967-79 only."
  echo "- Proposed metadata follows the current Stockhausen policy."
} > "$REPORT"

log "Plano batch concluído."
log "Plan TSV:    $PLAN_TSV"
log "Album TSV:   $ALBUM_TSV"
log "Anomaly TSV: $ANOMALY_TSV"
log "Report:      $REPORT"
