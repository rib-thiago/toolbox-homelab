#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
ARCHIVE_ROOT="/srv/toolbox/shared/artwork-cold-archive/stockhausen"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$(ls -t "$RAW_DIR"/stockhausen_artwork_cold_archive_plan_*.tsv 2>/dev/null | head -1)"
PERIOD_TSV="$(ls -t "$RAW_DIR"/stockhausen_artwork_cold_archive_by_period_*.tsv 2>/dev/null | head -1)"

BUILD_TSV="$RAW_DIR/stockhausen_artwork_cold_archive_build_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_artwork_cold_archive_build_report_$STAMP.txt"

QUALITY=85

command -v cwebp >/dev/null 2>&1 || fail "cwebp não encontrado. Instale com: sudo apt install webp"
command -v 7z >/dev/null 2>&1 || fail "7z não encontrado. Instale com: sudo apt install p7zip-full"
[[ -f "$PLAN_TSV" ]] || fail "Plano não encontrado."
[[ -f "$PERIOD_TSV" ]] || fail "Resumo por período não encontrado."

mkdir -p "$ARCHIVE_ROOT" "$RAW_DIR" "$REPORT_DIR"

log "Iniciando build do cold archive de Artwork..."
log "Plano: $PLAN_TSV"
log "Qualidade WebP: $QUALITY"

printf "source_path\twebp_path\tstatus\tsource_size\twebp_size\n" > "$BUILD_TSV"

tail -n +2 "$PLAN_TSV" | while IFS=$'\t' read -r source_path period release relative_in_release ext size_bytes size_human planned_webp_path; do
  mkdir -p "$(dirname "$planned_webp_path")"

  if [[ -f "$planned_webp_path" ]]; then
    webp_size="$(stat -c '%s' "$planned_webp_path")"
    printf "%s\t%s\tSKIP_EXISTS\t%s\t%s\n" "$source_path" "$planned_webp_path" "$size_bytes" "$webp_size" >> "$BUILD_TSV"
    continue
  fi

  log "Convertendo: $source_path"

  if cwebp -quiet -q "$QUALITY" -m 6 "$source_path" -o "$planned_webp_path"; then
    webp_size="$(stat -c '%s' "$planned_webp_path")"
    printf "%s\t%s\tOK\t%s\t%s\n" "$source_path" "$planned_webp_path" "$size_bytes" "$webp_size" >> "$BUILD_TSV"
  else
    printf "%s\t%s\tERROR\t%s\t0\n" "$source_path" "$planned_webp_path" "$size_bytes" >> "$BUILD_TSV"
  fi
done

log "Empacotando por período..."

tail -n +2 "$PERIOD_TSV" | while IFS=$'\t' read -r period files size_bytes size_human planned_archive; do
  safe_period="$(basename "$planned_archive" .artwork-optimized.7z)"
  period_dir="$ARCHIVE_ROOT/${safe_period}"

  # O period_dir real no plano é o nome do período sanitizado antes do sufixo.
  period_dir="${planned_archive%.artwork-optimized.7z}"

  if [[ ! -d "$period_dir" ]]; then
    log "AVISO: diretório otimizado não encontrado para período: $period_dir"
    continue
  fi

  log "Criando pacote: $planned_archive"
  rm -f "$planned_archive"

  7z a -t7z -mx=9 -m0=lzma2 -ms=on "$planned_archive" "$period_dir" >/dev/null
done

{
  echo "Stockhausen artwork cold archive build report"
  echo "Generated: $(date -Is)"
  echo
  echo "Plan TSV:"
  echo "$PLAN_TSV"
  echo
  echo "Build TSV:"
  echo "$BUILD_TSV"
  echo
  echo "Archive root:"
  echo "$ARCHIVE_ROOT"
  echo
  echo "WebP quality:"
  echo "$QUALITY"
  echo
  echo "Conversion summary:"
  awk -F'\t' 'NR>1 {c[$3]++} END {for (k in c) print k, c[k]}' "$BUILD_TSV" | sort
  echo
  echo "Size summary:"
  awk -F'\t' '
    NR>1 {
      src += $4
      out += $5
    }
    END {
      printf "Original planned size: %.2f GiB\n", src/1073741824
      printf "Optimized WebP size: %.2f GiB\n", out/1073741824
      if (src > 0) printf "Reduction: %.2f%%\n", (1 - out/src) * 100
    }
  ' "$BUILD_TSV"
  echo
  echo "Generated archives:"
  find "$ARCHIVE_ROOT" -maxdepth 1 -type f -name '*.7z' -printf '%s\t%p\n' | sort -nr | awk '{
    size=$1
    path=$2
    if (size >= 1073741824) human=sprintf("%.2f GiB", size/1073741824)
    else if (size >= 1048576) human=sprintf("%.2f MiB", size/1048576)
    else human=sprintf("%.2f KiB", size/1024)
    print human "\t" path
  }'
  echo
  echo "Notes:"
  echo "- Originals were NOT deleted."
  echo "- Hot storage purge must only happen after validation."
  echo "- Cold archives are grouped by period."
} > "$REPORT"

log "Build concluído."
log "Build TSV: $BUILD_TSV"
log "Relatório: $REPORT"
