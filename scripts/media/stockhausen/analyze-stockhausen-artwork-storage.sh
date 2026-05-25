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

OUT_TSV="$RAW_DIR/stockhausen_artwork_storage_$STAMP.tsv"
DUP_TSV="$RAW_DIR/stockhausen_artwork_duplicates_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_artwork_storage_report_$STAMP.txt"

command -v file >/dev/null 2>&1 || fail "file não encontrado."
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum não encontrado."
[[ -d "$ROOT" ]] || fail "Diretório raiz não encontrado: $ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR"

log "Iniciando análise de armazenamento de artwork Stockhausen..."
log "Raiz: $ROOT"

printf "path\trelease_path\tfilename\textension\tsize_bytes\tsize_human\tsha256\timage_info\n" > "$OUT_TSV"

while IFS= read -r -d '' img; do
  rel="${img#$ROOT/}"
  filename="$(basename "$img")"
  extension="${filename##*.}"
  extension="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"
  size_bytes="$(stat -c '%s' "$img")"
  size_human="$(du -h "$img" | awk '{print $1}')"
  hash="$(sha256sum "$img" | awk '{print $1}')"
  image_info="$(file -b "$img" | tr '\t' ' ')"

  release_path="$(dirname "$img")"
  release_path="${release_path#$ROOT/}"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$rel" \
    "$release_path" \
    "$filename" \
    "$extension" \
    "$size_bytes" \
    "$size_human" \
    "$hash" \
    "$image_info" >> "$OUT_TSV"

done < <(
  find "$ROOT" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o \
    -iname '*.png' -o -iname '*.webp' -o \
    -iname '*.tif' -o -iname '*.tiff' -o \
    -iname '*.bmp' \
  \) -print0 | sort -z
)

log "Gerando análise de duplicatas..."

printf "sha256\tcount\ttotal_size_bytes\tpaths\n" > "$DUP_TSV"

awk -F'\t' '
  NR > 1 {
    count[$7]++
    size[$7] += $5
    paths[$7] = paths[$7] $1 " | "
  }
  END {
    for (h in count) {
      if (count[h] > 1) {
        print h "\t" count[h] "\t" size[h] "\t" paths[h]
      }
    }
  }
' "$OUT_TSV" | sort -k3,3nr >> "$DUP_TSV"

log "Gerando relatório..."

{
  echo "Stockhausen artwork storage analysis report"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Outputs:"
  echo "$OUT_TSV"
  echo "$DUP_TSV"
  echo
  echo "General summary:"
  printf "Artwork/image files: "
  awk 'NR>1 {c++} END {print c+0}' "$OUT_TSV"

  printf "Total artwork size: "
  awk -F'\t' 'NR>1 {sum += $5} END {
    if (sum >= 1073741824) printf "%.2f GiB\n", sum/1073741824;
    else if (sum >= 1048576) printf "%.2f MiB\n", sum/1048576;
    else if (sum >= 1024) printf "%.2f KiB\n", sum/1024;
    else print sum " B";
  }' "$OUT_TSV"

  echo
  echo "By extension:"
  awk -F'\t' '
    NR>1 {
      count[$4]++
      size[$4]+=$5
    }
    END {
      for (e in count) {
        printf "%s\t%d files\t", e, count[e]
        if (size[e] >= 1073741824) printf "%.2f GiB\n", size[e]/1073741824;
        else if (size[e] >= 1048576) printf "%.2f MiB\n", size[e]/1048576;
        else if (size[e] >= 1024) printf "%.2f KiB\n", size[e]/1024;
        else printf "%d B\n", size[e]
      }
    }
  ' "$OUT_TSV" | sort

  echo
  echo "Largest image files:"
  awk -F'\t' 'NR>1 {print $5 "\t" $6 "\t" $1 "\t" $8}' "$OUT_TSV" \
    | sort -nr \
    | head -40

  echo
  echo "Duplicate groups:"
  printf "Groups: "
  awk 'NR>1 {c++} END {print c+0}' "$DUP_TSV"

  printf "Duplicated files: "
  awk -F'\t' 'NR>1 {files += $2} END {print files+0}' "$DUP_TSV"

  printf "Duplicated total size: "
  awk -F'\t' 'NR>1 {sum += $3} END {
    if (sum >= 1073741824) printf "%.2f GiB\n", sum/1073741824;
    else if (sum >= 1048576) printf "%.2f MiB\n", sum/1048576;
    else if (sum >= 1024) printf "%.2f KiB\n", sum/1024;
    else print sum " B";
  }' "$DUP_TSV"

  echo
  echo "Largest duplicate groups:"
  awk -F'\t' 'NR>1 {print $3 "\t" $2 " files\t" $1}' "$DUP_TSV" \
    | sort -nr \
    | head -30

  echo
  echo "Cover-like files:"
  awk -F'\t' 'NR>1 && tolower($3) ~ /(cover|folder|front)/ {print $6 "\t" $1}' "$OUT_TSV" \
    | head -80

  echo
  echo "Potential high-impact candidates for compression:"
  awk -F'\t' '
    NR>1 && $5 >= 5242880 {
      print $6 "\t" $1 "\t" $8
    }
  ' "$OUT_TSV" | head -80

  echo
  echo "Notes:"
  echo "- This script does not modify files."
  echo "- Duplicate size is gross duplicated group size, not net recoverable space."
  echo "- Compression policy should be decided after reviewing image formats, resolutions and archival needs."
} > "$REPORT"

log "Análise concluída."
log "TSV:        $OUT_TSV"
log "Duplicatas: $DUP_TSV"
log "Relatório:  $REPORT"
