#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

sanitize_filename() {
  local name="$1"

  printf '%s' "$name" \
    | sed 's/[[:cntrl:]]//g' \
    | sed 's/[\/]/-/g' \
    | sed 's/[?*<>|"]/ /g' \
    | sed 's/:/ -/g' \
    | sed 's/[[:space:]][[:space:]]*/ /g' \
    | sed 's/[[:space:]]*$//' \
    | sed 's/^[[:space:]]*//'
}

strip_work_prefix_for_filename() {
  local title="$1"

  # Regra do modelo ouro:
  # Tag Title preserva o título completo.
  # Filename remove prefixo redundante da obra quando o título começa com:
  # "Stimmung (...): subdivisão"
  printf '%s' "$title" | sed -E 's/^Stimmung[[:space:]]*\([^)]*\):[[:space:]]*//'
}

GOLD_ALBUM="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
PLAN_DIR="/srv/toolbox/shared/reports/media/normalization-plans"
STAMP="$(date +%Y%m%d-%H%M%S)"

RENAME_TSV="$RAW_DIR/stockhausen_gold_normalization_rename_plan_$STAMP.tsv"
TAG_TSV="$RAW_DIR/stockhausen_gold_normalization_tag_plan_$STAMP.tsv"
REPORT="$PLAN_DIR/stockhausen_gold_normalization_plan_$STAMP.txt"

command -v exiftool >/dev/null 2>&1 || fail "exiftool não encontrado."
[[ -d "$GOLD_ALBUM" ]] || fail "Diretório do álbum ouro não encontrado: $GOLD_ALBUM"

mkdir -p "$RAW_DIR" "$REPORT_DIR" "$PLAN_DIR"

log "Gerando plano de normalização do modelo ouro..."
log "Álbum ouro: $GOLD_ALBUM"

printf "old_relative_path\tnew_relative_path\ttracknumber\ttitle\tfilename_title\n" > "$RENAME_TSV"
printf "relative_path\tfield\told_value\tnew_value\taction\n" > "$TAG_TSV"

mapfile -d '' FLACS < <(find "$GOLD_ALBUM" -type f -iname '*.flac' -print0 | sort -z)

[[ "${#FLACS[@]}" -gt 0 ]] || fail "Nenhum FLAC encontrado."

for f in "${FLACS[@]}"; do
  rel="${f#$GOLD_ALBUM/}"
  dir_rel="$(dirname "$rel")"

  tracknumber="$(exiftool -s3 -TrackNumber "$f" 2>/dev/null)"
  title="$(exiftool -s3 -Title "$f" 2>/dev/null)"
  artist="$(exiftool -s3 -Artist "$f" 2>/dev/null)"
  albumartist="$(exiftool -s3 -AlbumArtist "$f" 2>/dev/null)"
  composer="$(exiftool -s3 -Composer "$f" 2>/dev/null)"
  grouping="$(exiftool -s3 -Grouping "$f" 2>/dev/null)"

  filename_title="$(strip_work_prefix_for_filename "$title")"
  filename_title="$(sanitize_filename "$filename_title")"

  track_padded="$(printf "%02d" "${tracknumber%%/*}")"
  new_filename="$track_padded - $filename_title.flac"
  new_rel="$dir_rel/$new_filename"

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$rel" \
    "$new_rel" \
    "$tracknumber" \
    "$title" \
    "$filename_title" >> "$RENAME_TSV"

  if [[ "$albumartist" != "Karlheinz Stockhausen" ]]; then
    printf "%s\tAlbumArtist\t%s\tKarlheinz Stockhausen\tUPDATE\n" \
      "$rel" "$albumartist" >> "$TAG_TSV"
  fi

  if [[ "$artist" != "Karlheinz Stockhausen" ]]; then
    printf "%s\tArtist\t%s\tKarlheinz Stockhausen\tUPDATE\n" \
      "$rel" "$artist" >> "$TAG_TSV"
  fi

  if [[ "$composer" != "Karlheinz Stockhausen" ]]; then
    printf "%s\tComposer\t%s\tKarlheinz Stockhausen\tUPDATE\n" \
      "$rel" "$composer" >> "$TAG_TSV"
  fi

  if [[ "$grouping" != "1967-79: Live Electronics - Intuitive Music - Formula Form" ]]; then
    printf "%s\tGrouping\t%s\t1967-79: Live Electronics - Intuitive Music - Formula Form\tUPDATE\n" \
      "$rel" "$grouping" >> "$TAG_TSV"
  fi

  # Performer derivado do AlbumArtist atual do modelo ouro.
  # Se AlbumArtist contém "Karlheinz Stockhausen; Collegium Vocale Köln",
  # preservamos o ensemble em Performer.
  if [[ "$albumartist" == *"Collegium Vocale Köln"* ]]; then
    printf "%s\tPerformer\t\tCollegium Vocale Köln\tADD\n" \
      "$rel" >> "$TAG_TSV"
  fi
done

{
  echo "Stockhausen gold model normalization plan"
  echo "Generated: $(date -Is)"
  echo
  echo "Gold album:"
  echo "$GOLD_ALBUM"
  echo
  echo "Outputs:"
  echo "$RENAME_TSV"
  echo "$TAG_TSV"
  echo
  echo "Summary:"
  printf "FLAC files planned: "
  awk 'NR>1 {c++} END {print c+0}' "$RENAME_TSV"

  printf "Rename operations: "
  awk -F'\t' 'NR>1 && $1 != $2 {c++} END {print c+0}' "$RENAME_TSV"

  printf "Tag operations: "
  awk 'NR>1 {c++} END {print c+0}' "$TAG_TSV"

  echo
  echo "Tag operation summary:"
  awk -F'\t' 'NR>1 {c[$2 ":" $5]++} END {for (k in c) print k, c[k]}' "$TAG_TSV" | sort

  echo
  echo "Rename preview:"
  awk -F'\t' 'NR>1 {print "OLD: " $1 "\nNEW: " $2 "\n"}' "$RENAME_TSV" | head -80

  echo
  echo "Tag preview:"
  awk -F'\t' 'NR>1 {print $1 " :: " $2 " :: [" $3 "] -> [" $4 "] (" $5 ")"}' "$TAG_TSV" | head -120

  echo
  echo "Potential duplicate target filenames:"
  awk -F'\t' 'NR>1 {c[$2]++} END {for (k in c) if (c[k] > 1) print c[k], k}' "$RENAME_TSV" | sort -nr

} > "$REPORT"

log "Plano gerado."
log "Rename TSV: $RENAME_TSV"
log "Tag TSV:    $TAG_TSV"
log "Relatório:  $REPORT"
