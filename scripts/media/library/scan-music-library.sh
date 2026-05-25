#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"

REPORT_DIR="/srv/toolbox/shared/reports/media"
REPORT_FILE="$REPORT_DIR/music-library-scan-$TS.txt"

LIBRARY="/srv/media/music"
STAGING="/srv/media/music-staging"

mkdir -p "$REPORT_DIR"

exec > >(tee "$REPORT_FILE") 2>&1

echo "===== MUSIC LIBRARY SCAN ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Diretórios-base ====="
echo "LIBRARY = $LIBRARY"
echo "STAGING = $STAGING"
echo

echo "===== 2. Uso geral ====="
du -sh "$LIBRARY" "$STAGING" 2>/dev/null || true
echo

echo "===== 3. Estrutura top-level ====="
echo "--- /srv/media/music ---"
find "$LIBRARY" -mindepth 1 -maxdepth 1 -type d | sort
echo

echo "--- /srv/media/music-staging ---"
find "$STAGING" -mindepth 1 -maxdepth 2 -type d | sort
echo

echo "===== 4. Estatísticas gerais ====="

ARTIST_COUNT=$(find "$LIBRARY" -mindepth 1 -maxdepth 1 -type d | wc -l)
ALBUM_COUNT=$(find "$LIBRARY" -mindepth 2 -maxdepth 2 -type d | wc -l)

echo "Artistas: $ARTIST_COUNT"
echo "Álbuns : $ALBUM_COUNT"
echo

echo "===== 5. Top 30 maiores artistas ====="
find "$LIBRARY" -mindepth 1 -maxdepth 1 -type d -print0 \
| while IFS= read -r -d '' dir; do
    du -sb "$dir"
done \
| sort -nr \
| head -30 \
| awk '
function human(x) {
  split("B KB MB GB TB", u)
  i=1
  while (x>=1024 && i<5) {x/=1024; i++}
  return sprintf("%.2f %s", x, u[i])
}
{
  size=$1
  $1=""
  sub(/^\t/,"")
  print human(size) "\t" $0
}'
echo

echo "===== 6. Top 50 maiores álbuns ====="
find "$LIBRARY" -mindepth 2 -maxdepth 2 -type d -print0 \
| while IFS= read -r -d '' dir; do
    du -sb "$dir"
done \
| sort -nr \
| head -50 \
| awk '
function human(x) {
  split("B KB MB GB TB", u)
  i=1
  while (x>=1024 && i<5) {x/=1024; i++}
  return sprintf("%.2f %s", x, u[i])
}
{
  size=$1
  $1=""
  sub(/^\t/,"")
  print human(size) "\t" $0
}'
echo

echo "===== 7. Contagem por extensão ====="
find "$LIBRARY" "$STAGING" -type f 2>/dev/null \
| awk '
{
  n=split($0,a,".")
  ext=(n>1 ? tolower(a[n]) : "[sem_extensao]")
  count[ext]++
}
END {
  for (e in count) print count[e], e
}' | sort -nr
echo

echo "===== 8. Arquivos de áudio ====="
find "$LIBRARY" "$STAGING" -type f \
\( \
-iname "*.flac" -o \
-iname "*.mp3" -o \
-iname "*.m4a" -o \
-iname "*.aac" -o \
-iname "*.opus" -o \
-iname "*.ogg" -o \
-iname "*.wav" \
\) | wc -l
echo

echo "===== 9. Diretórios vazios ====="
find "$LIBRARY" "$STAGING" -type d -empty 2>/dev/null
echo

echo "===== 10. Arquivos suspeitos ====="
find "$LIBRARY" "$STAGING" -type f \
\( \
-iname "*.tmp" -o \
-iname "*.part" -o \
-iname "*.crdownload" -o \
-iname "*.DS_Store" \
\)
echo

echo "===== 11. Covers e artefatos ====="
find "$LIBRARY" "$STAGING" -type f \
\( \
-iname "cover.*" -o \
-iname "folder.*" -o \
-iname "*.cue" -o \
-iname "*.log" -o \
-iname "*.pdf" \
\) | head -300
echo

echo "===== 12. Profundidade inesperada ====="
find "$LIBRARY" -mindepth 4 -type d | head -300
echo

echo "===== 13. Caracteres potencialmente problemáticos ====="
find "$LIBRARY" "$STAGING" \
| grep -E '[[:space:]]{2,}|[<>:"\\|?*]'
echo

echo "===== 14. Álbuns sem arquivos de áudio ====="

find "$LIBRARY" -mindepth 2 -maxdepth 2 -type d -print0 \
| while IFS= read -r -d '' album; do

    AUDIO_COUNT=$(find "$album" -type f \
    \( \
    -iname "*.flac" -o \
    -iname "*.mp3" -o \
    -iname "*.m4a" -o \
    -iname "*.aac" -o \
    -iname "*.opus" -o \
    -iname "*.ogg" -o \
    -iname "*.wav" \
    \) | wc -l)

    if [ "$AUDIO_COUNT" -eq 0 ]; then
        echo "$album"
    fi
done
echo

echo "===== 15. Resumo final ====="
echo "Artistas : $ARTIST_COUNT"
echo "Álbuns   : $ALBUM_COUNT"

TOTAL_AUDIO=$(find "$LIBRARY" "$STAGING" -type f \
\( \
-iname "*.flac" -o \
-iname "*.mp3" -o \
-iname "*.m4a" -o \
-iname "*.aac" -o \
-iname "*.opus" -o \
-iname "*.ogg" -o \
-iname "*.wav" \
\) | wc -l)

echo "Áudios   : $TOTAL_AUDIO"

echo
echo "Relatório salvo em:"
echo "$REPORT_FILE"
