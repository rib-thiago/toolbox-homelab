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

OUT_TSV="$RAW_DIR/stockhausen_gold_post_apply_validation_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_gold_post_apply_validation_report_$STAMP.txt"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
[[ -d "$GOLD_ALBUM" ]] || fail "Diretório do álbum ouro não encontrado."

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Validando normalização aplicada no modelo ouro..."

printf "relative_path\tfilename_ok\talbumartist\tartist\tcomposer\tgrouping\tperformer\tmb_albumid\tmb_trackid\tmb_releasetrackid\tmb_releasegroupid\n" > "$OUT_TSV"

mapfile -d '' FLACS < <(find "$GOLD_ALBUM" -type f -iname '*.flac' -print0 | sort -z)

for f in "${FLACS[@]}"; do
  rel="${f#$GOLD_ALBUM/}"
  base="$(basename "$f")"

  filename_ok="no"
  [[ "$base" =~ ^[0-9]{2}\ -\ .+\.flac$ ]] && filename_ok="yes"

  get_tag() {
    metaflac --show-tag="$1" "$f" 2>/dev/null | sed "s/^$1=//" | paste -sd ';' -
  }

  albumartist="$(get_tag AlbumArtist)"
  artist="$(get_tag Artist)"
  composer="$(get_tag Composer)"
  grouping="$(get_tag Grouping)"
  performer="$(get_tag Performer)"
  mb_albumid="$(get_tag MusicBrainzAlbumId)"
  mb_trackid="$(get_tag MusicBrainzTrackId)"
  mb_releasetrackid="$(get_tag MusicBrainzReleaseTrackId)"
  mb_releasegroupid="$(get_tag MusicBrainzReleaseGroupId)"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$rel" \
    "$filename_ok" \
    "$albumartist" \
    "$artist" \
    "$composer" \
    "$grouping" \
    "$performer" \
    "$mb_albumid" \
    "$mb_trackid" \
    "$mb_releasetrackid" \
    "$mb_releasegroupid" >> "$OUT_TSV"
done

{
  echo "Stockhausen gold post-apply validation report"
  echo "Generated: $(date -Is)"
  echo
  echo "Gold album:"
  echo "$GOLD_ALBUM"
  echo
  echo "Output TSV:"
  echo "$OUT_TSV"
  echo
  echo "Summary:"
  printf "FLAC files: "
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"

  printf "Filename OK: "
  awk -F'\t' 'NR>1 && $2 == "yes" {c++} END {print c+0}' "$OUT_TSV"

  printf "AlbumArtist OK: "
  awk -F'\t' 'NR>1 && $3 == "Karlheinz Stockhausen" {c++} END {print c+0}' "$OUT_TSV"

  printf "Artist OK: "
  awk -F'\t' 'NR>1 && $4 == "Karlheinz Stockhausen" {c++} END {print c+0}' "$OUT_TSV"

  printf "Composer OK: "
  awk -F'\t' 'NR>1 && $5 == "Karlheinz Stockhausen" {c++} END {print c+0}' "$OUT_TSV"

  printf "Grouping OK: "
  awk -F'\t' 'NR>1 && $6 == "1967-79: Live Electronics - Intuitive Music - Formula Form" {c++} END {print c+0}' "$OUT_TSV"

  printf "Performer OK: "
  awk -F'\t' 'NR>1 && $7 == "Collegium Vocale Köln" {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "MusicBrainz preservation:"
  printf "MusicBrainzAlbumId present: "
  awk -F'\t' 'NR>1 && $8 != "" {c++} END {print c+0}' "$OUT_TSV"

  printf "MusicBrainzTrackId present: "
  awk -F'\t' 'NR>1 && $9 != "" {c++} END {print c+0}' "$OUT_TSV"

  printf "MusicBrainzReleaseTrackId present: "
  awk -F'\t' 'NR>1 && $10 != "" {c++} END {print c+0}' "$OUT_TSV"

  printf "MusicBrainzReleaseGroupId present: "
  awk -F'\t' 'NR>1 && $11 != "" {c++} END {print c+0}' "$OUT_TSV"

  echo
  echo "Duplicate filenames:"
  find "$GOLD_ALBUM" -type f -iname '*.flac' -printf '%f\n' | sort | uniq -d

  echo
  echo "Failures:"
  awk -F'\t' '
    NR>1 && (
      $2!="yes" ||
      $3!="Karlheinz Stockhausen" ||
      $4!="Karlheinz Stockhausen" ||
      $5!="Karlheinz Stockhausen" ||
      $6!="1967-79: Live Electronics - Intuitive Music - Formula Form" ||
      $7!="Collegium Vocale Köln" ||
      $8=="" || $9=="" || $10=="" || $11==""
    ) {
      print "- " $1
    }
  ' "$OUT_TSV" | head -100

} > "$REPORT"

log "Validação concluída."
log "TSV:       $OUT_TSV"
log "Relatório: $REPORT"
