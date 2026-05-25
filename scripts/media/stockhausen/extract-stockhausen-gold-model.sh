#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

GOLD_ALBUM="/srv/media/music/Karlheinz Stockhausen/1967-79: Live Electronics - Intuitive Music - Formula Form/012 Stockhausen - Stimmung (1993) {2CD Set Stockhausen-Verlag No. 12}"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

TRACKS_TSV="$RAW_DIR/stockhausen_gold_model_tracks_$STAMP.tsv"
TAGS_TSV="$RAW_DIR/stockhausen_gold_model_all_tags_$STAMP.tsv"
FILES_TSV="$RAW_DIR/stockhausen_gold_model_files_$STAMP.tsv"
ARTWORK_TSV="$RAW_DIR/stockhausen_gold_model_artwork_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_gold_model_report_$STAMP.txt"

command -v exiftool >/dev/null 2>&1 || fail "exiftool não encontrado."
[[ -d "$GOLD_ALBUM" ]] || fail "Diretório do álbum ouro não encontrado: $GOLD_ALBUM"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Iniciando extração do modelo ouro..."
log "Álbum ouro: $GOLD_ALBUM"

mapfile -d '' FLACS < <(find "$GOLD_ALBUM" -type f -iname '*.flac' -print0 | sort -z)

[[ "${#FLACS[@]}" -gt 0 ]] || fail "Nenhum FLAC encontrado no álbum ouro."

log "FLACs encontrados: ${#FLACS[@]}"

log "Gerando inventário de arquivos..."
printf "relative_path\ttype\tsize_bytes\tsize_human\n" > "$FILES_TSV"

while IFS= read -r -d '' f; do
  rel="${f#$GOLD_ALBUM/}"
  type="$(file -b "$f" | tr '\t' ' ')"
  size_bytes="$(stat -c '%s' "$f")"
  size_human="$(du -h "$f" | awk '{print $1}')"
  printf "%s\t%s\t%s\t%s\n" "$rel" "$type" "$size_bytes" "$size_human" >> "$FILES_TSV"
done < <(find "$GOLD_ALBUM" -type f -print0 | sort -z)

log "Gerando inventário de artwork..."
printf "relative_path\tsize_bytes\tsize_human\timage_info\n" > "$ARTWORK_TSV"

while IFS= read -r -d '' img; do
  rel="${img#$GOLD_ALBUM/}"
  size_bytes="$(stat -c '%s' "$img")"
  size_human="$(du -h "$img" | awk '{print $1}')"
  image_info="$(file -b "$img" | tr '\t' ' ')"
  printf "%s\t%s\t%s\t%s\n" "$rel" "$size_bytes" "$size_human" "$image_info" >> "$ARTWORK_TSV"
done < <(
  find "$GOLD_ALBUM" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' \
  \) -print0 | sort -z
)

log "Gerando TSV compacto de faixas..."
printf "relative_path\tdiscnumber\ttracknumber\ttitle\tartist\talbumartist\tcomposer\talbum\tdate\toriginaldate\tlabel\tcatalognumber\treleasetype\treleasestatus\treleasecountry\tmedia\tgrouping\tgenre\tmusicbrainz_albumid\tmusicbrainz_trackid\tmusicbrainz_releasetrackid\tmusicbrainz_releasegroupid\n" > "$TRACKS_TSV"

for f in "${FLACS[@]}"; do
  rel="${f#$GOLD_ALBUM/}"

  discnumber="$(exiftool -s3 -DiscNumber "$f" 2>/dev/null)"
  tracknumber="$(exiftool -s3 -TrackNumber "$f" 2>/dev/null)"
  title="$(exiftool -s3 -Title "$f" 2>/dev/null)"
  artist="$(exiftool -s3 -Artist "$f" 2>/dev/null)"
  albumartist="$(exiftool -s3 -AlbumArtist "$f" 2>/dev/null)"
  composer="$(exiftool -s3 -Composer "$f" 2>/dev/null)"
  album="$(exiftool -s3 -Album "$f" 2>/dev/null)"
  date="$(exiftool -s3 -Date "$f" 2>/dev/null)"
  originaldate="$(exiftool -s3 -OriginalDate "$f" 2>/dev/null)"
  label="$(exiftool -s3 -Label "$f" 2>/dev/null)"
  catalognumber="$(exiftool -s3 -CatalogNumber "$f" 2>/dev/null)"
  releasetype="$(exiftool -s3 -ReleaseType "$f" 2>/dev/null)"
  releasestatus="$(exiftool -s3 -ReleaseStatus "$f" 2>/dev/null)"
  releasecountry="$(exiftool -s3 -ReleaseCountry "$f" 2>/dev/null)"
  media="$(exiftool -s3 -Media "$f" 2>/dev/null)"
  grouping="$(exiftool -s3 -Grouping "$f" 2>/dev/null)"
  genre="$(exiftool -s3 -Genre "$f" 2>/dev/null)"
  mb_albumid="$(exiftool -s3 -MusicBrainzAlbumId "$f" 2>/dev/null)"
  mb_trackid="$(exiftool -s3 -MusicBrainzTrackId "$f" 2>/dev/null)"
  mb_releasetrackid="$(exiftool -s3 -MusicBrainzReleaseTrackId "$f" 2>/dev/null)"
  mb_releasegroupid="$(exiftool -s3 -MusicBrainzReleaseGroupId "$f" 2>/dev/null)"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$rel" \
    "$discnumber" \
    "$tracknumber" \
    "$title" \
    "$artist" \
    "$albumartist" \
    "$composer" \
    "$album" \
    "$date" \
    "$originaldate" \
    "$label" \
    "$catalognumber" \
    "$releasetype" \
    "$releasestatus" \
    "$releasecountry" \
    "$media" \
    "$grouping" \
    "$genre" \
    "$mb_albumid" \
    "$mb_trackid" \
    "$mb_releasetrackid" \
    "$mb_releasegroupid" >> "$TRACKS_TSV"
done

log "Gerando dump completo de tags..."
printf "relative_path\ttag\tvalue\n" > "$TAGS_TSV"

for f in "${FLACS[@]}"; do
  rel="${f#$GOLD_ALBUM/}"

  exiftool -s "$f" \
    | sed 's/[[:space:]]*: /\t/' \
    | awk -v file="$rel" 'BEGIN{FS="\t"; OFS="\t"} NF >= 2 {print file,$1,$2}' >> "$TAGS_TSV"
done

log "Gerando relatório consolidado..."

{
  echo "Stockhausen gold model extraction report"
  echo "Generated: $(date -Is)"
  echo
  echo "Gold album:"
  echo "$GOLD_ALBUM"
  echo
  echo "Outputs:"
  echo "$TRACKS_TSV"
  echo "$TAGS_TSV"
  echo "$FILES_TSV"
  echo "$ARTWORK_TSV"
  echo
  echo "Filesystem summary:"
  printf "Total files: "
  find "$GOLD_ALBUM" -type f | wc -l
  printf "FLAC files: "
  find "$GOLD_ALBUM" -type f -iname '*.flac' | wc -l
  printf "Directories: "
  find "$GOLD_ALBUM" -type d | wc -l
  printf "Album size: "
  du -sh "$GOLD_ALBUM" | awk '{print $1}'
  echo
  echo "Disc directories:"
  find "$GOLD_ALBUM" -mindepth 1 -maxdepth 1 -type d -printf "- %f\n" | sort
  echo
  echo "Artwork summary:"
  printf "Artwork/image files: "
  awk 'NR>1 {c++} END {print c+0}' "$ARTWORK_TSV"
  printf "Artwork/image total size: "
  awk -F'\t' 'NR>1 {sum += $2} END {
    if (sum >= 1073741824) printf "%.2fG\n", sum/1073741824;
    else if (sum >= 1048576) printf "%.2fM\n", sum/1048576;
    else if (sum >= 1024) printf "%.2fK\n", sum/1024;
    else print sum "B";
  }' "$ARTWORK_TSV"
  echo
  echo "Cover-like files:"
  awk -F'\t' 'NR>1 && tolower($1) ~ /(cover|folder|front)/ {print "- " $1 " (" $3 ")"}' "$ARTWORK_TSV" | head -30
  echo
  echo "Distinct Album values:"
  awk -F'\t' 'NR>1 {print $8}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct AlbumArtist values:"
  awk -F'\t' 'NR>1 {print $6}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct Artist values:"
  awk -F'\t' 'NR>1 {print $5}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct Composer values:"
  awk -F'\t' 'NR>1 {print $7}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct Date values:"
  awk -F'\t' 'NR>1 {print $9}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct OriginalDate values:"
  awk -F'\t' 'NR>1 {print $10}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct Label values:"
  awk -F'\t' 'NR>1 {print $11}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct CatalogNumber values:"
  awk -F'\t' 'NR>1 {print $12}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct Grouping values:"
  awk -F'\t' 'NR>1 {print $17}' "$TRACKS_TSV" | sort -u
  echo
  echo "Distinct Genre values:"
  awk -F'\t' 'NR>1 {print $18}' "$TRACKS_TSV" | sort -u
  echo
  echo "MusicBrainz presence:"
  printf "Files with MusicBrainzAlbumId: "
  awk -F'\t' 'NR>1 && $19 != "" {c++} END {print c+0}' "$TRACKS_TSV"
  printf "Files with MusicBrainzTrackId: "
  awk -F'\t' 'NR>1 && $20 != "" {c++} END {print c+0}' "$TRACKS_TSV"
  printf "Files with MusicBrainzReleaseTrackId: "
  awk -F'\t' 'NR>1 && $21 != "" {c++} END {print c+0}' "$TRACKS_TSV"
  printf "Files with MusicBrainzReleaseGroupId: "
  awk -F'\t' 'NR>1 && $22 != "" {c++} END {print c+0}' "$TRACKS_TSV"
  echo
  echo "Most common tags:"
  awk -F'\t' 'NR>1 {print $2}' "$TAGS_TSV" | sort | uniq -c | sort -nr | head -80
  echo
  echo "Current filename sample:"
  awk -F'\t' 'NR>1 {print "- " $1}' "$TRACKS_TSV" | head -30
  echo
  echo "Track title sample:"
  awk -F'\t' 'NR>1 {print "- " $2 "/" $3 " :: " $4}' "$TRACKS_TSV" | head -40
} > "$REPORT"

log "Extração concluída."
log "Tracks TSV:  $TRACKS_TSV"
log "Tags TSV:    $TAGS_TSV"
log "Files TSV:   $FILES_TSV"
log "Artwork TSV: $ARTWORK_TSV"
log "Relatório:   $REPORT"
