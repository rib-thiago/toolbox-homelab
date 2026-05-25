#!/usr/bin/env bash
set -euo pipefail

LIBRARY="/srv/media/music"
STAGING="/srv/media/music-staging"

OUT_ROOT="/srv/toolbox/shared/library-db"
RAW_DIR="$OUT_ROOT/raw"
REPORT_DIR="$OUT_ROOT/reports"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/inventory-build-$TS.txt"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

ARTISTS_TSV="$RAW_DIR/artists.tsv"
ALBUMS_TSV="$RAW_DIR/albums.tsv"
FILES_TSV="$RAW_DIR/files.tsv"
STAGING_TSV="$RAW_DIR/staging.tsv"

exec > >(tee "$REPORT") 2>&1

echo "===== BUILD MUSIC INVENTORY TSV ====="
echo "Data: $(date)"
echo "Library: $LIBRARY"
echo "Staging: $STAGING"
echo

echo -e "artist_id\tartist_name\tpath\talbum_count\tsize_bytes" > "$ARTISTS_TSV"
echo -e "album_id\tartist_id\tartist_name\talbum_title\tpath\tfile_count\taudio_count\tsize_bytes" > "$ALBUMS_TSV"
echo -e "file_id\talbum_id\tartist_name\talbum_title\tpath\textension\tsize_bytes\tkind" > "$FILES_TSV"
echo -e "item_id\tstage\tpath\tdepth\tfile_count\taudio_count\tsize_bytes" > "$STAGING_TSV"

is_audio_ext() {
  case "${1,,}" in
    flac|mp3|m4a|aac|opus|ogg|wav) return 0 ;;
    *) return 1 ;;
  esac
}

kind_from_ext() {
  local ext="${1,,}"
  case "$ext" in
    flac|mp3|m4a|aac|opus|ogg|wav) echo "audio" ;;
    jpg|jpeg|png|gif|webp) echo "image" ;;
    cue) echo "cue" ;;
    log|txt|md|nfo) echo "text" ;;
    pdf) echo "pdf" ;;
    m3u|m3u8|pls) echo "playlist" ;;
    *) echo "other" ;;
  esac
}

artist_id=0
album_id=0
file_id=0

echo "===== 1. Inventariando biblioteca curada ====="

while IFS= read -r -d '' artist_dir; do
  artist_id=$((artist_id + 1))
  artist_name="$(basename "$artist_dir")"
  artist_size="$(du -sb "$artist_dir" | awk '{print $1}')"
  album_count="$(find "$artist_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)"

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$artist_id" "$artist_name" "$artist_dir" "$album_count" "$artist_size" \
    >> "$ARTISTS_TSV"

  while IFS= read -r -d '' album_dir; do
    album_id=$((album_id + 1))
    album_title="$(basename "$album_dir")"
    album_size="$(du -sb "$album_dir" | awk '{print $1}')"
    file_count="$(find "$album_dir" -type f | wc -l)"
    audio_count="$(find "$album_dir" -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.opus" -o -iname "*.ogg" -o -iname "*.wav" \) | wc -l)"

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$album_id" "$artist_id" "$artist_name" "$album_title" "$album_dir" "$file_count" "$audio_count" "$album_size" \
      >> "$ALBUMS_TSV"

    while IFS= read -r -d '' file_path; do
      file_id=$((file_id + 1))
      base="$(basename "$file_path")"

      if [[ "$base" == *.* ]]; then
        ext="${base##*.}"
      else
        ext="[sem_extensao]"
      fi

      size="$(stat -c '%s' "$file_path")"
      kind="$(kind_from_ext "$ext")"

      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$file_id" "$album_id" "$artist_name" "$album_title" "$file_path" "${ext,,}" "$size" "$kind" \
        >> "$FILES_TSV"
    done < <(find "$album_dir" -type f -print0 | sort -z)

  done < <(find "$artist_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

done < <(find "$LIBRARY" -mindepth 1 -maxdepth 1 -type d ! -name ".deleted" -print0 | sort -z)

echo "Artistas inventariados: $artist_id"
echo "Álbuns inventariados:   $album_id"
echo "Arquivos inventariados: $file_id"
echo

echo "===== 2. Inventariando staging ====="

item_id=0

while IFS= read -r -d '' item; do
  item_id=$((item_id + 1))

  rel="${item#$STAGING/}"
  stage="${rel%%/*}"

  depth="$(awk -F/ '{print NF}' <<< "$rel")"
  size="$(du -sb "$item" | awk '{print $1}')"
  file_count="$(find "$item" -type f | wc -l)"
  audio_count="$(find "$item" -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.opus" -o -iname "*.ogg" -o -iname "*.wav" \) | wc -l)"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$item_id" "$stage" "$item" "$depth" "$file_count" "$audio_count" "$size" \
    >> "$STAGING_TSV"

done < <(find "$STAGING" -mindepth 1 -maxdepth 2 -type d -print0 | sort -z)

echo "Itens de staging inventariados: $item_id"
echo

echo "===== 3. Arquivos gerados ====="
ls -lh "$RAW_DIR"
echo

echo "===== 4. Amostras ====="

echo "--- artists.tsv ---"
head -10 "$ARTISTS_TSV"
echo

echo "--- albums.tsv ---"
head -10 "$ALBUMS_TSV"
echo

echo "--- files.tsv ---"
head -10 "$FILES_TSV"
echo

echo "--- staging.tsv ---"
head -20 "$STAGING_TSV"
echo

echo "===== 5. Próximo passo ====="
echo "Depois de revisar estes TSVs, criaremos o schema SQLite inicial."
echo
echo "Relatório:"
echo "$REPORT"
