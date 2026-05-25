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
ARCHIVE_ROOT="/srv/toolbox/shared/artwork-cold-archive/stockhausen"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$RAW_DIR/stockhausen_artwork_cold_archive_plan_$STAMP.tsv"
PERIOD_TSV="$RAW_DIR/stockhausen_artwork_cold_archive_by_period_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_artwork_cold_archive_plan_report_$STAMP.txt"

[[ -d "$ROOT" ]] || fail "Diretório raiz não encontrado: $ROOT"

mkdir -p "$RAW_DIR" "$REPORT_DIR" "$ARCHIVE_ROOT"

log "Planejando cold archive de Artwork por período..."
log "Raiz: $ROOT"

printf "source_path\tperiod\trelease\trelative_in_release\textension\tsize_bytes\tsize_human\tplanned_webp_path\n" > "$PLAN_TSV"

while IFS= read -r -d '' img; do
  rel="${img#$ROOT/}"

  # período = primeiro nível dentro de Karlheinz Stockhausen
  period="${rel%%/*}"

  rest="${rel#*/}"
  release="${rest%%/*}"

  relative_in_release="${rest#*/}"
  filename="$(basename "$img")"
  ext="${filename##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  size_bytes="$(stat -c '%s' "$img")"
  size_human="$(du -h "$img" | awk '{print $1}')"

  base_no_ext="${relative_in_release%.*}"

  safe_period="$(printf '%s' "$period" | sed 's#[/:]# - #g')"
  planned_webp="$ARCHIVE_ROOT/$safe_period/$release/${base_no_ext}.webp"

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$img" \
    "$period" \
    "$release" \
    "$relative_in_release" \
    "$ext" \
    "$size_bytes" \
    "$size_human" \
    "$planned_webp" >> "$PLAN_TSV"

done < <(
  find "$ROOT" -type f \( \
    -path '*/Artwork/*' -a \( \
      -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' \
    \) \
  \) -print0 | sort -z
)

printf "period\tfiles\tsize_bytes\tsize_human\tplanned_archive\n" > "$PERIOD_TSV"

awk -F'\t' '
  NR>1 {
    count[$2]++
    size[$2]+=$6
  }
  END {
    for (p in count) {
      safe=p
      gsub(/[\\/:]/, " - ", safe)
      archive="/srv/toolbox/shared/artwork-cold-archive/stockhausen/" safe ".artwork-optimized.7z"

      human=size[p]
      if (human >= 1073741824) {
        human=sprintf("%.2f GiB", human/1073741824)
      } else if (human >= 1048576) {
        human=sprintf("%.2f MiB", human/1048576)
      } else if (human >= 1024) {
        human=sprintf("%.2f KiB", human/1024)
      } else {
        human=human " B"
      }

      print p "\t" count[p] "\t" size[p] "\t" human "\t" archive
    }
  }
' "$PLAN_TSV" | sort >> "$PERIOD_TSV"

{
  echo "Stockhausen artwork cold archive plan"
  echo "Generated: $(date -Is)"
  echo
  echo "Root:"
  echo "$ROOT"
  echo
  echo "Archive root:"
  echo "$ARCHIVE_ROOT"
  echo
  echo "Outputs:"
  echo "$PLAN_TSV"
  echo "$PERIOD_TSV"
  echo
  echo "Summary:"
  printf "Artwork files planned: "
  awk 'NR>1 {c++} END {print c+0}' "$PLAN_TSV"

  printf "Current total Artwork size: "
  awk -F'\t' 'NR>1 {sum += $6} END {
    if (sum >= 1073741824) printf "%.2f GiB\n", sum/1073741824;
    else if (sum >= 1048576) printf "%.2f MiB\n", sum/1048576;
    else if (sum >= 1024) printf "%.2f KiB\n", sum/1024;
    else print sum " B";
  }' "$PLAN_TSV"

  echo
  echo "By period:"
  column -t -s $'\t' "$PERIOD_TSV"

  echo
  echo
  echo "Largest source files:"
  awk -F'\t' 'NR>1 {print $6 "\t" $7 "\t" $1}' "$PLAN_TSV" | sort -nr | head -40

  echo
  echo
  echo "Planned archives:"
  awk -F'\t' 'NR>1 {print "- " $5}' "$PERIOD_TSV"

  echo
  echo
  echo "Notes:"
  echo "- This script does not modify files."
  echo "- Hot layer policy: keep cover.jpg only."
  echo "- Cold layer policy: optimized Artwork packed by period."
  echo "- Next script should convert Artwork files to WebP under $ARCHIVE_ROOT, preserving period/release structure."
  echo "- Purge of original Artwork directories must happen only after build and validation."
} > "$REPORT"

log "Plano concluído."
log "Plan TSV:   $PLAN_TSV"
log "Period TSV: $PERIOD_TSV"
log "Report:     $REPORT"
