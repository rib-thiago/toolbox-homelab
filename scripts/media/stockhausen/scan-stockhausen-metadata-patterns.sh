#!/usr/bin/env bash
set -euo pipefail

ROOT="/srv/media/music/Karlheinz Stockhausen"
DB="/srv/toolbox/shared/library-db/sqlite/music-library.sqlite"
OUT="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
TS="$(date +%Y%m%d-%H%M%S)"

META_TSV="$OUT/stockhausen_metadata.tsv"
ALBUM_TSV="$OUT/stockhausen_album_summary.tsv"
REPORT="$REPORT_DIR/stockhausen-metadata-scan-$TS.txt"

mkdir -p "$OUT" "$REPORT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== STOCKHAUSEN METADATA PATTERN SCAN ====="
echo "Data: $(date)"
echo "Root: $ROOT"
echo "DB: $DB"
echo

if [ ! -d "$ROOT" ]; then
  echo "ERRO: diretório não existe: $ROOT"
  exit 1
fi

echo "===== 1. Dependências ====="

if command -v exiftool >/dev/null 2>&1; then
  echo "exiftool: OK"
else
  echo "ERRO: exiftool não encontrado."
  echo "Instale com: sudo apt install -y libimage-exiftool-perl"
  exit 1
fi

if command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3: OK"
else
  echo "AVISO: sqlite3 não encontrado; parte DB será ignorada."
fi

echo

echo "===== 2. Álbuns Stockhausen no SQLite ====="

if [ -f "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 -header -column "$DB" "
    SELECT album_id,
           album_title,
           audio_count,
           ROUND(size_bytes / 1024.0 / 1024.0 / 1024.0, 2) AS size_gb
    FROM albums
    WHERE artist_name = 'Karlheinz Stockhausen'
    ORDER BY album_title;
  "
else
  echo "Banco não encontrado ou sqlite3 ausente."
fi

echo

echo "===== 3. Gerando TSV detalhado ====="

printf "album_group\talbum_dir\tdisc_dir\tfile_path\textension\ttrack\tdisc\ttitle\tartist\talbum\talbumartist\tcomposer\tgenre\tdate\tyear\tlabel\tcatalognumber\tmusicbrainz_albumid\tmusicbrainz_trackid\n" > "$META_TSV"

find "$ROOT" -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.ogg" -o -iname "*.opus" -o -iname "*.wav" \) -print0 \
| sort -z \
| while IFS= read -r -d '' file; do
  rel="${file#$ROOT/}"

  album_group="$(cut -d/ -f1 <<< "$rel")"
  album_dir="$(cut -d/ -f2 <<< "$rel")"

  if [ "$(awk -F/ '{print NF}' <<< "$rel")" -ge 4 ]; then
    disc_dir="$(cut -d/ -f3 <<< "$rel")"
  else
    disc_dir=""
  fi

  ext="${file##*.}"
  ext="${ext,,}"

  exiftool -s3 \
    -TrackNumber \
    -DiscNumber \
    -Title \
    -Artist \
    -Album \
    -AlbumArtist \
    -Composer \
    -Genre \
    -Date \
    -Year \
    -Label \
    -CatalogNumber \
    -MusicBrainzAlbumID \
    -MusicBrainzTrackID \
    "$file" 2>/dev/null \
  | awk -v album_group="$album_group" \
        -v album_dir="$album_dir" \
        -v disc_dir="$disc_dir" \
        -v file="$file" \
        -v ext="$ext" '
    BEGIN {
      for (i=1; i<=14; i++) v[i]=""
    }
    {
      gsub(/\t/, " ", $0)
      v[NR]=$0
    }
    END {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        album_group, album_dir, disc_dir, file, ext,
        v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13], v[14]
    }
  '
done >> "$META_TSV"

echo "TSV detalhado:"
echo "$META_TSV"
echo

echo "===== 4. Gerando resumo por álbum/diretório ====="

awk -F'\t' '
NR==1 { next }
{
  key=$1 "\t" $2
  files[key]++
  if ($8  != "") title[key]++
  if ($9  != "") artist[key]++
  if ($10 != "") album[key]++
  if ($11 != "") albumartist[key]++
  if ($12 != "") composer[key]++
  if ($13 != "") genre[key]++
  if ($14 != "") date[key]++
  if ($17 != "") mbalbum[key]++
  if ($18 != "") mbtrack[key]++
}
END {
  print "album_group\talbum_dir\taudio_files\ttitle_tags\tartist_tags\talbum_tags\talbumartist_tags\tcomposer_tags\tgenre_tags\tdate_tags\tmb_album_tags\tmb_track_tags\tpicard_likely"
  for (k in files) {
    picard = (mbalbum[k] > 0 || mbtrack[k] > 0) ? "yes" : "no"
    print k "\t" files[k] "\t" title[k]+0 "\t" artist[k]+0 "\t" album[k]+0 "\t" albumartist[k]+0 "\t" composer[k]+0 "\t" genre[k]+0 "\t" date[k]+0 "\t" mbalbum[k]+0 "\t" mbtrack[k]+0 "\t" picard
  }
}' "$META_TSV" | sort > "$ALBUM_TSV"

echo "Resumo por álbum:"
echo "$ALBUM_TSV"
echo

echo "===== 5. Possíveis diretórios já tratados pelo Picard ====="

awk -F'\t' '
NR==1 { next }
$12 == "yes" {
  print $1 " / " $2 " | arquivos=" $3 " | MB album=" $10 " | MB track=" $11
}
' "$ALBUM_TSV" | head -50

echo

echo "===== 6. Diretórios SEM indício MusicBrainz/Picard ====="

awk -F'\t' '
NR==1 { next }
$12 == "no" {
  print $1 " / " $2 " | arquivos=" $3
}
' "$ALBUM_TSV" | head -80

echo

echo "===== 7. Amostra de padrões de tags ====="

echo "--- AlbumArtist mais comuns ---"
awk -F'\t' 'NR>1 && $11 != "" { count[$11]++ } END { for (x in count) print count[x], x }' "$META_TSV" | sort -nr | head -30
echo

echo "--- Composer mais comuns ---"
awk -F'\t' 'NR>1 && $12 != "" { count[$12]++ } END { for (x in count) print count[x], x }' "$META_TSV" | sort -nr | head -30
echo

echo "--- Genre mais comuns ---"
awk -F'\t' 'NR>1 && $13 != "" { count[$13]++ } END { for (x in count) print count[x], x }' "$META_TSV" | sort -nr | head -30
echo

echo "--- Date/Year mais comuns ---"
awk -F'\t' 'NR>1 { if ($14 != "") count[$14]++; else if ($15 != "") count[$15]++ } END { for (x in count) print count[x], x }' "$META_TSV" | sort -nr | head -30
echo

echo "===== 8. Próximo passo ====="
echo "Com base nos TSVs, vamos identificar o(s) diretório(s) Picard-like e extrair um padrão de tags/nomes."
echo
echo "Relatório:"
echo "$REPORT"
