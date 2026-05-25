#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

REFERENCE_ALBUM="/srv/media/music/Karlheinz Stockhausen/1950-69: Serial Music: Points to Groups - Moment Form - Electronic & Tape Music/001 Stockhausen - Chöre für Doris, Kreuzspiel etc (1991) {Stockhausen-Verlag No. 1}"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

TRACK_TSV="$RAW_DIR/stockhausen_reference_album_tracks_$STAMP.tsv"
TAG_TSV="$RAW_DIR/stockhausen_reference_album_tags_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_reference_album_report_$STAMP.txt"

log "Iniciando extração do álbum de referência Stockhausen CD 1..."

command -v exiftool >/dev/null 2>&1 || fail "exiftool não encontrado."
[[ -d "$REFERENCE_ALBUM" ]] || fail "Diretório do álbum não encontrado: $REFERENCE_ALBUM"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

mapfile -d '' FILES < <(find "$REFERENCE_ALBUM" -maxdepth 1 -type f -iname "*.flac" -print0 | sort -z)

[[ "${#FILES[@]}" -gt 0 ]] || fail "Nenhum arquivo .flac encontrado."

log "Arquivos FLAC encontrados: ${#FILES[@]}"
log "Gerando TSV por faixa..."

{
  echo -e "file\ttracknumber\ttitle\tartist\talbumartist\talbum\tdate\tyear\tcomposer\tgenre\tdiscnumber\ttotaldiscs\tmusicbrainz_trackid\tmusicbrainz_releasetrackid\tmusicbrainz_albumid\tmusicbrainz_artistid\tmusicbrainz_albumartistid\treleasegroupid\tlabel\tcatalognumber\tbarcode"

  for f in "${FILES[@]}"; do
    vals="$(exiftool -s3 \
      -FileName \
      -TrackNumber \
      -Title \
      -Artist \
      -AlbumArtist \
      -Album \
      -Date \
      -Year \
      -Composer \
      -Genre \
      -DiscNumber \
      -TotalDiscs \
      -MusicBrainzTrackId \
      -MusicBrainzReleaseTrackId \
      -MusicBrainzAlbumId \
      -MusicBrainzArtistId \
      -MusicBrainzAlbumArtistId \
      -MusicBrainzReleaseGroupId \
      -Label \
      -CatalogNumber \
      -Barcode \
      "$f" | paste -sd '\t' -)"
    echo "$vals"
  done
} > "$TRACK_TSV"

log "Gerando TSV completo de tags..."

{
  echo -e "file\ttag\tvalue"
  for f in "${FILES[@]}"; do
    base="$(basename "$f")"
    exiftool -s "$f" \
      | sed 's/[[:space:]]*: /\t/' \
      | awk -v file="$base" 'BEGIN{FS="\t"; OFS="\t"} NF>=2 {print file,$1,$2}'
  done
} > "$TAG_TSV"

log "Gerando relatório..."

{
  echo "Stockhausen reference album metadata report"
  echo "Generated: $(date -Is)"
  echo
  echo "Reference album:"
  echo "$REFERENCE_ALBUM"
  echo
  echo "FLAC files found: ${#FILES[@]}"
  echo
  echo "Outputs:"
  echo "$TRACK_TSV"
  echo "$TAG_TSV"
  echo
  echo "MusicBrainz/Picard tag presence:"
  echo

  for tag in \
    MusicBrainzTrackId \
    MusicBrainzReleaseTrackId \
    MusicBrainzAlbumId \
    MusicBrainzArtistId \
    MusicBrainzAlbumArtistId \
    MusicBrainzReleaseGroupId \
    AcoustidId \
    AcoustidFingerprint \
    ReleaseType \
    ReleaseStatus \
    ReleaseCountry \
    Label \
    CatalogNumber \
    Barcode
  do
    count="$(awk -F'\t' -v tag="$tag" '$2 == tag {c++} END {print c+0}' "$TAG_TSV")"
    printf "%-32s %s\n" "$tag" "$count"
  done

  echo
  echo "Most common tags:"
  cut -f2 "$TAG_TSV" | sort | uniq -c | sort -nr | head -80

  echo
  echo "Distinct Album values:"
  awk -F'\t' 'NR>1 {print $6}' "$TRACK_TSV" | sort -u

  echo
  echo "Distinct AlbumArtist values:"
  awk -F'\t' 'NR>1 {print $5}' "$TRACK_TSV" | sort -u

  echo
  echo "Distinct Artist values:"
  awk -F'\t' 'NR>1 {print $4}' "$TRACK_TSV" | sort -u

  echo
  echo "Distinct Composer values:"
  awk -F'\t' 'NR>1 {print $9}' "$TRACK_TSV" | sort -u

  echo
  echo "Distinct Genre values:"
  awk -F'\t' 'NR>1 {print $10}' "$TRACK_TSV" | sort -u

} > "$REPORT"

log "Extração concluída."
log "Track TSV: $TRACK_TSV"
log "Tag TSV:   $TAG_TSV"
log "Report:    $REPORT"
