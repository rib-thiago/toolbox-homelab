#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S)"

TOOLBOX_APP="/srv/toolbox/app"
TOOLBOX_SHARED="/srv/toolbox/shared"

PROVISIONAL_REPORT_DIR="/srv/toolbox/shared/reports/media"
PROVISIONAL_RAW_DIR="/srv/toolbox/shared/library-db/raw"

REPORT_FILE="${PROVISIONAL_REPORT_DIR}/toolbox_host_container_tools_diagnosis_report_${STAMP}.txt"
TSV_FILE="${PROVISIONAL_RAW_DIR}/toolbox_host_container_tools_diagnosis_${STAMP}.tsv"

SCRIPT_ROOT="/srv/toolbox/app/scripts"
BIN_ROOT="/srv/toolbox/app/bin"
DOCKER_ROOT="/srv/toolbox/app/docker"
COMPOSE_ROOT="/srv/toolbox/app/compose"

TOOL_LIST="
bash
sh
python3
python
pip
git
curl
jq
rg
grep
sed
awk
find
stat
du
df
file
tree
sqlite3
man
groff
bat
batcat
fd
fd-find
nano
shellcheck
docker
docker-compose
systemctl
journalctl
ufw
ss
ip
lsblk
findmnt
free
sensors
smartctl
restic
tailscale
smbstatus
getfacl
setfacl
tesseract
pdftoppm
pdftotext
pdfinfo
magick
convert
identify
gs
exiftool
ffmpeg
ffprobe
flac
metaflac
shnsplit
shntool
cuebreakpoints
cueprint
cuetag
cuetools
sox
beet
fpcalc
mid3v2
id3v2
eyeD3
kid3-cli
picard
"

tool_category() {
  local tool
  tool="$1"

  case "$tool" in
    tesseract|pdftoppm|pdftotext|pdfinfo|magick|convert|identify|gs|exiftool)
      printf 'document_image_pdf'
      ;;
    ffmpeg|ffprobe|flac|metaflac|shnsplit|shntool|cuebreakpoints|cueprint|cuetag|cuetools|sox|beet|fpcalc|mid3v2|id3v2|eyeD3|kid3-cli|picard)
      printf 'audio_media_archive'
      ;;
    docker|docker-compose|systemctl|journalctl|ufw|ss|ip|lsblk|findmnt|free|sensors|smartctl|restic|tailscale|smbstatus|getfacl|setfacl)
      printf 'host_admin'
      ;;
    bash|sh|python3|python|pip|git|curl|jq|rg|grep|sed|awk|find|stat|du|df|file|tree|sqlite3|man|groff|bat|batcat|fd|fd-find|nano|shellcheck)
      printf 'core_dev_unix'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

recommended_runtime_hint() {
  local tool
  tool="$1"

  case "$tool" in
    docker|docker-compose|systemctl|journalctl|ufw|ss|ip|lsblk|findmnt|free|sensors|smartctl|restic|tailscale|smbstatus|getfacl|setfacl)
      printf 'host'
      ;;
    tesseract|pdftoppm|pdftotext|pdfinfo|magick|convert|identify|gs)
      printf 'container_or_both'
      ;;
    exiftool)
      printf 'both_possible'
      ;;
    ffmpeg|ffprobe|flac|metaflac|shnsplit|shntool|cuebreakpoints|cueprint|cuetag|cuetools|sox|fpcalc)
      printf 'host_for_live_library_container_for_staging_jobs'
      ;;
    beet|mid3v2|id3v2|eyeD3|kid3-cli|picard)
      printf 'host_or_specialized_media_container'
      ;;
    *)
      printf 'both_possible'
      ;;
  esac
}

require_writable_dir() {
  local dir
  local label

  dir="$1"
  label="$2"

  if [ ! -d "$dir" ]; then
    fail "${label} does not exist: ${dir}"
  fi

  if [ ! -w "$dir" ]; then
    fail "${label} is not writable: ${dir}"
  fi
}

tsv_escape() {
  local raw
  raw="$1"

  raw="${raw//$'\t'/ }"
  raw="${raw//$'\n'/ }"
  raw="${raw//$'\r'/ }"

  printf '%s' "$raw"
}

tsv_row() {
  local tool
  local category
  local host_available
  local host_path
  local host_version
  local container_name
  local container_available
  local container_path
  local container_version
  local script_references
  local recommended_runtime
  local notes

  tool="$1"
  category="$2"
  host_available="$3"
  host_path="$4"
  host_version="$5"
  container_name="$6"
  container_available="$7"
  container_path="$8"
  container_version="$9"
  script_references="${10}"
  recommended_runtime="${11}"
  notes="${12}"

  {
    tsv_escape "$tool"
    printf '\t'
    tsv_escape "$category"
    printf '\t'
    tsv_escape "$host_available"
    printf '\t'
    tsv_escape "$host_path"
    printf '\t'
    tsv_escape "$host_version"
    printf '\t'
    tsv_escape "$container_name"
    printf '\t'
    tsv_escape "$container_available"
    printf '\t'
    tsv_escape "$container_path"
    printf '\t'
    tsv_escape "$container_version"
    printf '\t'
    tsv_escape "$script_references"
    printf '\t'
    tsv_escape "$recommended_runtime"
    printf '\t'
    tsv_escape "$notes"
    printf '\n'
  } >> "$TSV_FILE"
}

section() {
  local title
  title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

subsection() {
  local title
  title="$1"

  {
    printf '\n'
    printf '%s\n' '----------------------------------------------------------------'
    printf '%s\n' "$title"
    printf '%s\n' '----------------------------------------------------------------'
  } >> "$REPORT_FILE"
}

append_shell() {
  local title
  local cmd
  local rc

  title="$1"
  cmd="$2"

  subsection "$title"

  {
    printf '%s\n\n' "$ $cmd"
  } >> "$REPORT_FILE"

  bash -lc "$cmd" >> "$REPORT_FILE" 2>&1
  rc="$?"

  if [ "$rc" -ne 0 ]; then
    printf '\n[exit_code=%s]\n' "$rc" >> "$REPORT_FILE"
  fi

  return 0
}

safe_version_host() {
  local tool
  local output

  tool="$1"
  output=""

  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'missing'
    return 0
  fi

  case "$tool" in
    python|python3)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    pip)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    tesseract)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    pdftoppm|pdftotext|pdfinfo)
      output="$("$tool" -v 2>&1 | head -2 | tr '\n' ' ' || true)"
      ;;
    magick|convert|identify)
      output="$("$tool" -version 2>&1 | head -1 || true)"
      ;;
    gs)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    exiftool)
      output="$("$tool" -ver 2>&1 | head -1 || true)"
      ;;
    ffmpeg|ffprobe)
      output="$("$tool" -version 2>&1 | head -1 || true)"
      ;;
    flac|metaflac)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    shnsplit|shntool)
      output="$("$tool" -v 2>&1 | head -1 || true)"
      ;;
    cuebreakpoints|cueprint|cuetag)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    sox)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    git|curl|jq|sqlite3|docker|restic|tailscale)
      output="$("$tool" --version 2>&1 | head -1 || true)"
      ;;
    *)
      output="$("$tool" --version 2>&1 | head -1 || "$tool" -version 2>&1 | head -1 || "$tool" -v 2>&1 | head -1 || true)"
      ;;
  esac

  if [ -z "$output" ]; then
    output="available_version_unknown"
  fi

  printf '%s' "$output"
}

container_exec() {
  local container
  local cmd

  container="$1"
  cmd="$2"

  docker exec "$container" sh -lc "$cmd" 2>/dev/null
}

safe_version_container() {
  local container
  local tool
  local output

  container="$1"
  tool="$2"
  output=""

  if [ -z "$container" ]; then
    printf 'no_container'
    return 0
  fi

  if ! container_exec "$container" "command -v '$tool' >/dev/null 2>&1"; then
    printf 'missing'
    return 0
  fi

  case "$tool" in
    python|python3)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    pip)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    tesseract)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    pdftoppm|pdftotext|pdfinfo)
      output="$(container_exec "$container" "$tool -v 2>&1 | head -2 | tr '\n' ' '" || true)"
      ;;
    magick|convert|identify)
      output="$(container_exec "$container" "$tool -version 2>&1 | head -1" || true)"
      ;;
    gs)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    exiftool)
      output="$(container_exec "$container" "$tool -ver 2>&1 | head -1" || true)"
      ;;
    ffmpeg|ffprobe)
      output="$(container_exec "$container" "$tool -version 2>&1 | head -1" || true)"
      ;;
    flac|metaflac)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    shnsplit|shntool)
      output="$(container_exec "$container" "$tool -v 2>&1 | head -1" || true)"
      ;;
    cuebreakpoints|cueprint|cuetag)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    sox)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    git|curl|jq|sqlite3)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1" || true)"
      ;;
    *)
      output="$(container_exec "$container" "$tool --version 2>&1 | head -1 || $tool -version 2>&1 | head -1 || $tool -v 2>&1 | head -1 || true" || true)"
      ;;
  esac

  if [ -z "$output" ]; then
    output="available_version_unknown"
  fi

  printf '%s' "$output"
}

detect_toolbox_containers() {
  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi

  docker ps --format '{{.Names}}' 2>/dev/null |
    while IFS= read -r name; do
      [ -n "$name" ] || continue

      inspect="$(
        docker inspect "$name" \
          --format '{{.Name}} {{.Config.Image}} {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}} {{range $k,$v := .Config.Labels}}{{$k}}={{$v}} {{end}}' \
          2>/dev/null || true
      )"

      case "$inspect" in
        *toolbox*|*/srv/toolbox*|*/toolbox*|*TOOLBOX*|*Toolbox*)
          printf '%s\n' "$name"
          ;;
      esac
    done | sort -u
}

script_reference_count() {
  local tool
  local count

  tool="$1"

  if [ ! -d "$TOOLBOX_APP" ]; then
    printf '0'
    return 0
  fi

  count="$(
    grep -RIl --exclude-dir=.git --exclude='*.tsv' --exclude='*.txt' \
      -E "(^|[^[:alnum:]_./-])${tool}([^[:alnum:]_./-]|$)" \
      "$SCRIPT_ROOT" "$BIN_ROOT" "$DOCS_ROOT" 2>/dev/null |
      wc -l |
      tr -d ' '
  )"

  printf '%s' "$count"
}

write_header() {
  {
    printf 'Toolbox host/container tools diagnosis\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Toolbox shared: %s\n' "$TOOLBOX_SHARED"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope: diagnose only. No apt install, no docker build, no docker compose up, no mkdir, no chmod, no mv, no rm, no git writes.\n'
    printf '\n'
    printf 'Important note:\n'
    printf '  This script writes its own artifacts to inherited/provisional locations:\n'
    printf '    human report: %s\n' "$PROVISIONAL_REPORT_DIR"
    printf '    structured TSV: %s\n' "$PROVISIONAL_RAW_DIR"
    printf '  This is NOT a final output policy. These locations are used only to record this diagnosis.\n'
    printf '\n'
    printf 'Purpose:\n'
    printf '  Compare tools available on the host and inside detected Toolbox container(s).\n'
    printf '  Identify gaps before deciding whether to add media/audio tools to a Docker image.\n'
    printf '  Support the host-mode/container-mode architectural reconciliation.\n'
  } > "$REPORT_FILE"

  {
    printf 'tool\tcategory\thost_available\thost_path\thost_version\tcontainer_name\tcontainer_available\tcontainer_path\tcontainer_version\tscript_references\trecommended_runtime\tnotes\n'
  } > "$TSV_FILE"
}

write_container_detection() {
  section "1. CONTAINER DETECTION"

  append_shell "Docker availability" "command -v docker || true; docker --version 2>/dev/null || true"
  append_shell "Running containers" "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null || true"
  append_shell "Toolbox container candidates" "docker ps --format '{{.Names}}' 2>/dev/null | while read -r name; do inspect=\$(docker inspect \"\$name\" --format '{{.Name}} {{.Config.Image}} {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}} {{range \$k,\$v := .Config.Labels}}{{\$k}}={{\$v}} {{end}}' 2>/dev/null || true); case \"\$inspect\" in *toolbox*|*/srv/toolbox*|*/toolbox*|*TOOLBOX*|*Toolbox*) echo \"\$name\" ;; esac; done | sort -u"
  append_shell "Docker compose files under Toolbox app" "find '$TOOLBOX_APP' -maxdepth 4 -type f \\( -name 'docker-compose.yml' -o -name 'compose.yml' -o -name 'Dockerfile' \\) 2>/dev/null | sort || true"
}

write_environment_context() {
  section "2. ENVIRONMENT CONTEXT"

  append_shell "Host PATH" "printf '%s\n' \"\$PATH\" | tr ':' '\n'"
  append_shell "Host MANPATH" "printf '%s\n' \"\${MANPATH-}\" | tr ':' '\n'"
  append_shell "Toolbox app structure" "find '$TOOLBOX_APP' -maxdepth 3 -type d 2>/dev/null | sort || true"
  append_shell "Toolbox scripts by domain" "find '$TOOLBOX_APP/scripts' -maxdepth 3 -type d 2>/dev/null | sort || true"
  append_shell "Dockerfile package hints" "grep -RniE 'apt-get install|apt install|tesseract|poppler|imagemagick|exiftool|ffmpeg|flac|shntool|cuetools|sox|man-db|groff' '$DOCKER_ROOT' '$TOOLBOX_APP/Dockerfile' 2>/dev/null || true"
}

write_host_tool_inventory() {
  local tool
  local path
  local version
  local category
  local refs
  local runtime

  section "3. HOST TOOL INVENTORY"

  for tool in $TOOL_LIST; do
    category="$(tool_category "$tool")"
    runtime="$(recommended_runtime_hint "$tool")"
    refs="$(script_reference_count "$tool")"

    if command -v "$tool" >/dev/null 2>&1; then
      path="$(command -v "$tool" 2>/dev/null || true)"
      version="$(safe_version_host "$tool")"

      {
        printf '%s\t%s\t%s\t%s\n' "$tool" "$category" "$path" "$version"
      } >> "$REPORT_FILE"

      tsv_row "$tool" "$category" "yes" "$path" "$version" "HOST" "-" "-" "-" "$refs" "$runtime" "host inventory"
    else
      {
        printf '%s\t%s\tMISSING\n' "$tool" "$category"
      } >> "$REPORT_FILE"

      tsv_row "$tool" "$category" "no" "-" "missing" "HOST" "-" "-" "-" "$refs" "$runtime" "missing on host"
    fi
  done
}

write_container_tool_inventory() {
  local container
  local tool
  local category
  local refs
  local runtime
  local path
  local version
  local containers
  local found_any

  section "4. CONTAINER TOOL INVENTORY"

  containers="$(detect_toolbox_containers || true)"
  found_any="no"

  if [ -z "$containers" ]; then
    printf 'No running Toolbox container candidate detected.\n' >> "$REPORT_FILE"
    printf 'This is not necessarily an error. It means host/container comparison is incomplete.\n' >> "$REPORT_FILE"

    for tool in $TOOL_LIST; do
      category="$(tool_category "$tool")"
      runtime="$(recommended_runtime_hint "$tool")"
      refs="$(script_reference_count "$tool")"
      tsv_row "$tool" "$category" "-" "-" "-" "NO_CONTAINER_DETECTED" "no" "-" "no_container" "$refs" "$runtime" "container not detected"
    done

    return 0
  fi

  while IFS= read -r container; do
    [ -n "$container" ] || continue
    found_any="yes"

    subsection "Container: $container"

    append_shell "Container inspect summary: $container" "docker inspect '$container' --format 'Name={{.Name}} Image={{.Config.Image}} Status={{.State.Status}} Started={{.State.StartedAt}}' 2>/dev/null || true"
    append_shell "Container mounts: $container" "docker inspect '$container' --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Mode}}){{println}}{{end}}' 2>/dev/null || true"
    append_shell "Container PATH/MANPATH: $container" "docker exec '$container' sh -lc 'echo PATH=\$PATH; echo MANPATH=\${MANPATH-}' 2>/dev/null || true"

    for tool in $TOOL_LIST; do
      category="$(tool_category "$tool")"
      runtime="$(recommended_runtime_hint "$tool")"
      refs="$(script_reference_count "$tool")"

      if container_exec "$container" "command -v '$tool' >/dev/null 2>&1"; then
        path="$(container_exec "$container" "command -v '$tool'" || true)"
        version="$(safe_version_container "$container" "$tool")"

        {
          printf '%s\t%s\t%s\t%s\t%s\n' "$container" "$tool" "$category" "$path" "$version"
        } >> "$REPORT_FILE"

        tsv_row "$tool" "$category" "-" "-" "-" "$container" "yes" "$path" "$version" "$refs" "$runtime" "container inventory"
      else
        {
          printf '%s\t%s\t%s\tMISSING\n' "$container" "$tool" "$category"
        } >> "$REPORT_FILE"

        tsv_row "$tool" "$category" "-" "-" "-" "$container" "no" "-" "missing" "$refs" "$runtime" "missing in container"
      fi
    done
  done <<EOF
$containers
EOF

  if [ "$found_any" = "no" ]; then
    printf 'No usable container loop entries.\n' >> "$REPORT_FILE"
  fi
}

write_script_dependency_scan() {
  section "5. SCRIPT AND DOC TOOL REFERENCES"

  append_shell "Tool references in scripts/bin/docs" "grep -RniE 'metaflac|ffmpeg|ffprobe|flac|shnsplit|shntool|cuebreakpoints|cueprint|cuetag|cuetools|sox|beet|fpcalc|mid3v2|id3v2|eyeD3|kid3-cli|picard|tesseract|pdftoppm|pdftotext|pdfinfo|magick|convert|identify|exiftool|docker|restic|tailscale|smartctl|sensors|ufw|smbstatus' '$SCRIPT_ROOT' '$BIN_ROOT' '$TOOLBOX_APP/docs' 2>/dev/null | sed -n '1,500p' || true"
  append_shell "Stockhausen tool references" "grep -RniE 'metaflac|ffmpeg|ffprobe|flac|shnsplit|shntool|cuebreakpoints|cueprint|cuetag|cuetools|sox|exiftool|find|stat' '$TOOLBOX_APP/scripts/media/stockhausen' 2>/dev/null | sed -n '1,500p' || true"
  append_shell "PDF/OCR/image tool references" "grep -RniE 'tesseract|pdftoppm|pdftotext|pdfinfo|magick|convert|identify|exiftool|ghostscript|gs' '$SCRIPT_ROOT' '$BIN_ROOT' '$TOOLBOX_APP/docs' 2>/dev/null | sed -n '1,500p' || true"
  append_shell "Admin host-state tool references" "grep -RniE 'docker|systemctl|journalctl|ufw|ss|ip |lsblk|findmnt|smartctl|sensors|restic|tailscale|smbstatus|getfacl|setfacl' '$SCRIPT_ROOT' '$BIN_ROOT' '$TOOLBOX_APP/docs' 2>/dev/null | sed -n '1,500p' || true"
}

write_gap_summary() {
  section "6. PRELIMINARY GAP SUMMARY"

  {
    printf 'This section is interpretive and preliminary. It does not install or change anything.\n'
    printf '\n'
    printf 'Questions this inventory is meant to answer after review:\n'
    printf '  1. Which document/PDF/image tools are only in the container?\n'
    printf '  2. Which music/audio tools are only on the host?\n'
    printf '  3. Which admin tools are necessarily host-mode?\n'
    printf '  4. Which tools should exist in both runtimes?\n'
    printf '  5. Whether a media-enabled Toolbox Docker image is useful.\n'
    printf '\n'
    printf 'Expected interpretation model:\n'
    printf '  - host-mode: live homelab state, /srv, Docker, Git, storage, media library, Navidrome/Samba/backup diagnostics.\n'
    printf '  - container-mode: reproducible processing over input/work/output, OCR/PDF/image/text/NLP and possibly audio staging jobs.\n'
    printf '  - run-job: valid for encapsulated tasks and can be called from a larger operational workflow.\n'
  } >> "$REPORT_FILE"
}

write_next_step() {
  section "7. NEXT STEP RECOMMENDED AFTER THIS DIAGNOSIS"

  {
    printf 'Recommended next step:\n'
    printf '  Review this report and TSV to classify tools into:\n'
    printf '    - host-only required;\n'
    printf '    - container-only sufficient;\n'
    printf '    - both useful;\n'
    printf '    - missing but needed;\n'
    printf '    - candidate for media Docker image.\n'
    printf '\n'
    printf 'Do not yet:\n'
    printf '  - install packages;\n'
    printf '  - edit Dockerfile;\n'
    printf '  - rebuild image;\n'
    printf '  - move scripts;\n'
    printf '  - create scripts/lib;\n'
    printf '  - change output policy;\n'
    printf '  - commit to Git.\n'
  } >> "$REPORT_FILE"
}

main() {
  require_writable_dir "$PROVISIONAL_REPORT_DIR" "provisional report dir"
  require_writable_dir "$PROVISIONAL_RAW_DIR" "provisional raw dir"

  DOCS_ROOT="${TOOLBOX_APP}/docs"

  write_header

  log "Writing provisional human report: $REPORT_FILE"
  log "Writing provisional structured TSV: $TSV_FILE"
  log "Note: output destinations are provisional for this diagnosis, not final policy."

  write_container_detection
  write_environment_context
  write_host_tool_inventory
  write_container_tool_inventory
  write_script_dependency_scan
  write_gap_summary
  write_next_step

  log "Host/container tools diagnosis completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report:   %s\n' "$REPORT_FILE"
  printf '  Structured TSV: %s\n' "$TSV_FILE"
  printf '\n'
  printf 'Reminder: these output destinations are provisional and inherited from recent scripts, not a final policy.\n'
}

main "$@"
