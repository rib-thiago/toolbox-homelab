#!/usr/bin/env bash
set -u

# Plan Git classification and commit groups for Toolbox media/Stockhausen work.
#
# This script does not modify Git state.
# It does not run git add, git commit, git rm, or delete files.
#
# It classifies accumulated media documentation and scripts:
#   - docs/media
#   - scripts/media/library
#   - scripts/media/soulseek
#   - scripts/media/stockhausen
#
# It proposes commit groups without staging anything.

bootstrap_fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

TOOLBOX_APP="/srv/toolbox/app"
LIB_DIR="${TOOLBOX_APP}/scripts/lib"

LOGGING_LIB="${LIB_DIR}/logging.sh"
TIMESTAMPS_LIB="${LIB_DIR}/timestamps.sh"
TSV_LIB="${LIB_DIR}/tsv.sh"
REPORTS_LIB="${LIB_DIR}/reports.sh"

[ -f "$LOGGING_LIB" ] || bootstrap_fail "Missing lib file: $LOGGING_LIB"
[ -f "$TIMESTAMPS_LIB" ] || bootstrap_fail "Missing lib file: $TIMESTAMPS_LIB"
[ -f "$TSV_LIB" ] || bootstrap_fail "Missing lib file: $TSV_LIB"
[ -f "$REPORTS_LIB" ] || bootstrap_fail "Missing lib file: $REPORTS_LIB"

source "$LOGGING_LIB"
source "$TIMESTAMPS_LIB"
source "$TSV_LIB"
source "$REPORTS_LIB"

STAMP="$(toolbox_timestamp)"

REPORT_FILE="$(toolbox_report_path "toolbox_media_stockhausen_commit_groups" "plan" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_media_stockhausen_commit_groups" "plan" "$STAMP")"

DOCS_MEDIA_DIR="${TOOLBOX_APP}/docs/media"
SCRIPTS_MEDIA_DIR="${TOOLBOX_APP}/scripts/media"
LIBRARY_DIR="${SCRIPTS_MEDIA_DIR}/library"
SOULSEEK_DIR="${SCRIPTS_MEDIA_DIR}/soulseek"
STOCKHAUSEN_DIR="${SCRIPTS_MEDIA_DIR}/stockhausen"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"

section() {
  local title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

record() {
  local category="$1"
  local item="$2"
  local check="$3"
  local status="$4"
  local details="$5"

  printf '[%s] %s — %s — %s\n' "$status" "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "$status" "$details" >> "$TSV_FILE"
}

write_headers() {
  {
    printf 'Toolbox media/Stockhausen Git commit group planning report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  classify media/Stockhausen/Soulseek/library files;\n'
    printf '  propose commit groups;\n'
    printf '  validate shell syntax where applicable;\n'
    printf '  identify items needing review;\n'
    printf '  no git add;\n'
    printf '  no git commit;\n'
    printf '  no git rm;\n'
    printf '  no file deletion;\n'
    printf '  no media library changes;\n'
    printf '  no metadata edits;\n'
    printf '  no Docker changes.\n'
    printf '\n'
    printf 'This is a plan/diagnosis script only.\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "check" "status" "details" > "$TSV_FILE"
}

git_required() {
  section "Git repository diagnosis"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/tmp/toolbox-media-git-root.$$ 2>/tmp/toolbox-media-git-err.$$; then
    local root
    local branch

    root="$(cat /tmp/toolbox-media-git-root.$$)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || printf 'UNKNOWN')"

    record "git" "repository" "root" "ok" "$root"
    record "git" "repository" "branch" "ok" "$branch"
  else
    local err
    err="$(cat /tmp/toolbox-media-git-err.$$ 2>/dev/null || printf 'unknown error')"
    record "git" "$TOOLBOX_APP" "repository" "fail" "$err"
    rm -f /tmp/toolbox-media-git-root.$$ /tmp/toolbox-media-git-err.$$
    fail "Not a Git repository: $TOOLBOX_APP"
  fi

  rm -f /tmp/toolbox-media-git-root.$$ /tmp/toolbox-media-git-err.$$
}

write_current_status() {
  section "Current Git status for media-related paths"

  {
    cd "$TOOLBOX_APP" || exit 0
    git status --short docs/media scripts/media
  } >> "$REPORT_FILE" 2>&1

  record "git" "media paths" "git status --short" "recorded" "see report"
}

diagnose_directory() {
  local dir="$1"
  local label="$2"

  section "Directory diagnosis: ${label}"

  if [ -d "$dir" ]; then
    local total
    local files
    local dirs
    local sh_files
    local md_files

    total="$(find "$dir" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
    files="$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')"
    dirs="$(find "$dir" -type d 2>/dev/null | wc -l | tr -d ' ')"
    sh_files="$(find "$dir" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
    md_files="$(find "$dir" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"

    record "directory" "$label" "exists" "ok" "$dir"
    record "directory" "$label" "counts" "recorded" "total=${total}; files=${files}; dirs=${dirs}; sh=${sh_files}; md=${md_files}"

    {
      printf '\nListing, max depth 3:\n'
      find "$dir" -maxdepth 3 -print 2>/dev/null | sort
    } >> "$REPORT_FILE"
  else
    record "directory" "$label" "exists" "missing" "$dir"
  fi
}

classify_script_name() {
  local rel_path="$1"
  local base
  local domain
  local action
  local theme
  local group
  local priority
  local notes

  base="$(basename "$rel_path")"
  domain="media"
  action="unknown"
  theme="unknown"
  group="review"
  priority="review"
  notes="requires manual review"

  case "$rel_path" in
    scripts/media/library/*)
      domain="library"
      group="media-library"
      priority="commit-candidate"
      notes="library inventory/database tooling"
      ;;
    scripts/media/soulseek/*)
      domain="soulseek"
      group="media-soulseek"
      priority="commit-candidate"
      notes="Soulseek/slskd/staging workflow tooling"
      ;;
    scripts/media/stockhausen/*)
      domain="stockhausen"
      ;;
  esac

  case "$base" in
    diagnose-*)
      action="diagnose"
      ;;
    analyze-*)
      action="analyze"
      ;;
    scan-*)
      action="scan"
      ;;
    extract-*)
      action="extract"
      ;;
    plan-*)
      action="plan"
      ;;
    apply-*)
      action="apply"
      ;;
    repair-*)
      action="repair"
      ;;
    resume-*)
      action="resume"
      ;;
    validate-*)
      action="validate"
      ;;
    build-*)
      action="build"
      ;;
    purge-*)
      action="purge"
      ;;
    split-*)
      action="split"
      ;;
    filter-*)
      action="filter"
      ;;
    *)
      action="unknown"
      ;;
  esac

  case "$base" in
    *artwork*|*cold-archive*)
      theme="artwork-cold-archive"
      group="stockhausen-artwork"
      priority="commit-candidate"
      notes="artwork cold archive planning/build/validation/purge workflow"
      ;;
    *import-050*|split-stockhausen-import-050.sh)
      theme="import-050"
      group="stockhausen-import-050"
      priority="commit-candidate"
      notes="delta import workflow for album 050 Freitag aus Licht"
      ;;
    *navidrome*|*final-freeze*|*final*)
      theme="final-freeze-navidrome"
      group="stockhausen-final-freeze"
      priority="commit-candidate"
      notes="final freeze snapshot and Navidrome/count diagnostics"
      ;;
    *gold*|*reference-album*)
      theme="gold-model"
      group="stockhausen-gold-model"
      priority="commit-candidate"
      notes="gold model/reference album workflow"
      ;;
    *metadata-patterns*|*library-quality*|*partials*|*medium-albums*|*catalog-reconciliation*)
      theme="diagnosis-quality-reconciliation"
      group="stockhausen-diagnostics"
      priority="commit-candidate"
      notes="metadata diagnosis, quality classification, catalog reconciliation"
      ;;
    *batch-normalization*|*local-normalization*|*performer-fix*|*composer-grouping*)
      theme="normalization-repair-validation"
      group="stockhausen-normalization"
      priority="commit-candidate"
      notes="block/local normalization, performer fix, repair and validation workflows"
      ;;
  esac

  if [ "$domain" = "stockhausen" ] && [ "$group" = "review" ]; then
    group="stockhausen-review"
    priority="review"
    notes="Stockhausen script not matched by heuristic"
  fi

  tsv_row "script-classification" "$rel_path" "$action" "$priority" "domain=${domain}; theme=${theme}; group=${group}; notes=${notes}" >> "$TSV_FILE"

  {
    printf '[%s] %s\n' "$priority" "$rel_path"
    printf '    action=%s domain=%s theme=%s group=%s\n' "$action" "$domain" "$theme" "$group"
    printf '    %s\n' "$notes"
  } >> "$REPORT_FILE"
}

classify_docs_media_file() {
  local rel_path="$1"
  local base
  local group
  local priority
  local notes

  base="$(basename "$rel_path")"
  group="docs-media"
  priority="commit-candidate"
  notes="media documentation"

  case "$base" in
    *stockhausen*|*Stockhausen*)
      group="docs-media-stockhausen"
      notes="Stockhausen media documentation"
      ;;
    *soulseek*|*Soulseek*|*slskd*)
      group="docs-media-soulseek"
      notes="Soulseek/slskd media documentation"
      ;;
    *library*|*Library*|*inventory*|*database*)
      group="docs-media-library"
      notes="library/database media documentation"
      ;;
  esac

  tsv_row "doc-classification" "$rel_path" "docs-media" "$priority" "group=${group}; notes=${notes}" >> "$TSV_FILE"

  {
    printf '[%s] %s\n' "$priority" "$rel_path"
    printf '    group=%s\n' "$group"
    printf '    %s\n' "$notes"
  } >> "$REPORT_FILE"
}

classify_media_files() {
  section "Classify docs/media files"

  if [ -d "$DOCS_MEDIA_DIR" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      classify_docs_media_file "${file#$TOOLBOX_APP/}"
    done <<EOF_DOCS
$(find "$DOCS_MEDIA_DIR" -type f 2>/dev/null | sort)
EOF_DOCS
  else
    record "doc-classification" "docs/media" "scan" "missing" "docs/media directory not found"
  fi

  section "Classify scripts/media files"

  if [ -d "$SCRIPTS_MEDIA_DIR" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      classify_script_name "${file#$TOOLBOX_APP/}"
    done <<EOF_SCRIPTS
$(find "$SCRIPTS_MEDIA_DIR" -type f -name '*.sh' 2>/dev/null | sort)
EOF_SCRIPTS
  else
    record "script-classification" "scripts/media" "scan" "missing" "scripts/media directory not found"
  fi
}

validate_bash_syntax_for_media_scripts() {
  section "Validate bash syntax for scripts/media"

  local fail_count
  fail_count=0

  if [ ! -d "$SCRIPTS_MEDIA_DIR" ]; then
    record "bashcheck" "scripts/media" "bash -n" "missing" "scripts/media directory not found"
    return 0
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue

    local rel
    rel="${file#$TOOLBOX_APP/}"

    if bash -n "$file" >/tmp/toolbox-media-bashcheck-stdout.$$ 2>/tmp/toolbox-media-bashcheck-stderr.$$; then
      record "bashcheck" "$rel" "bash -n" "ok" "syntax ok"
    else
      local err
      err="$(cat /tmp/toolbox-media-bashcheck-stderr.$$ 2>/dev/null || printf 'unknown error')"
      record "bashcheck" "$rel" "bash -n" "fail" "$err"
      fail_count=$((fail_count + 1))
    fi

    rm -f /tmp/toolbox-media-bashcheck-stdout.$$ /tmp/toolbox-media-bashcheck-stderr.$$
  done <<EOF_BASH
$(find "$SCRIPTS_MEDIA_DIR" -type f -name '*.sh' 2>/dev/null | sort)
EOF_BASH

  record "bashcheck" "scripts/media" "summary" "recorded" "fail_count=${fail_count}"
}

detect_script_headers() {
  section "Detect script conventions in scripts/media"

  if [ ! -d "$SCRIPTS_MEDIA_DIR" ]; then
    record "convention" "scripts/media" "scan" "missing" "scripts/media directory not found"
    return 0
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue

    local rel
    local has_shebang
    local has_set_u
    local has_log
    local has_fail
    local uses_lib
    local notes

    rel="${file#$TOOLBOX_APP/}"

    if head -n 1 "$file" 2>/dev/null | grep -Fxq '#!/usr/bin/env bash'; then
      has_shebang="yes"
    else
      has_shebang="no"
    fi

    if grep -Eq '^[[:space:]]*set -u([[:space:]]|$)' "$file" 2>/dev/null; then
      has_set_u="yes"
    else
      has_set_u="no"
    fi

    if grep -Eq '^[[:space:]]*log\(\)' "$file" 2>/dev/null; then
      has_log="yes"
    else
      has_log="no"
    fi

    if grep -Eq '^[[:space:]]*fail\(\)' "$file" 2>/dev/null; then
      has_fail="yes"
    else
      has_fail="no"
    fi

    if grep -Eq 'source .*/scripts/lib/|source "\$.*scripts/lib|scripts/lib/' "$file" 2>/dev/null; then
      uses_lib="yes"
    else
      uses_lib="no"
    fi

    notes="shebang=${has_shebang}; set_u=${has_set_u}; log=${has_log}; fail=${has_fail}; uses_lib=${uses_lib}"

    if [ "$has_shebang" = "yes" ] && [ "$has_set_u" = "yes" ]; then
      record "convention" "$rel" "header" "ok" "$notes"
    else
      record "convention" "$rel" "header" "review" "$notes"
    fi
  done <<EOF_CONV
$(find "$SCRIPTS_MEDIA_DIR" -type f -name '*.sh' 2>/dev/null | sort)
EOF_CONV
}

summarize_groups_from_tsv() {
  section "Heuristic group summary"

  {
    printf 'Groups inferred from script/doc classification:\n'
    printf '\n'
    awk -F '\t' '
      NR > 1 && ($1 == "script-classification" || $1 == "doc-classification") {
        details=$5
        group=details
        sub(/^.*group=/, "", group)
        sub(/;.*/, "", group)
        if (group != details && group != "") count[group]++
      }
      END {
        for (g in count) {
          printf "  %s: %d\n", g, count[g]
        }
      }
    ' "$TSV_FILE" | sort
  } >> "$REPORT_FILE"

  record "summary" "heuristic groups" "group count" "recorded" "see report"
}

write_commit_plan() {
  section "Proposed commit plan"

  {
    printf 'Recommended commit sequence for media/Stockhausen work:\n'
    printf '\n'
    printf 'Commit M1 — media documentation\n'
    printf '  Message suggestion:\n'
    printf '    docs/media: add media archival documentation\n'
    printf '  Include:\n'
    printf '    docs/media/\n'
    printf '\n'
    printf 'Commit M2 — library and Soulseek media tooling\n'
    printf '  Message suggestion:\n'
    printf '    scripts/media: add library and soulseek tooling\n'
    printf '  Include:\n'
    printf '    scripts/media/library/\n'
    printf '    scripts/media/soulseek/\n'
    printf '\n'
    printf 'Commit S1 — Stockhausen diagnostics and gold model\n'
    printf '  Message suggestion:\n'
    printf '    scripts/media: add stockhausen diagnostics and gold model tooling\n'
    printf '  Include likely groups:\n'
    printf '    stockhausen-diagnostics\n'
    printf '    stockhausen-gold-model\n'
    printf '\n'
    printf 'Commit S2 — Stockhausen normalization and validation workflows\n'
    printf '  Message suggestion:\n'
    printf '    scripts/media: add stockhausen normalization workflows\n'
    printf '  Include likely groups:\n'
    printf '    stockhausen-normalization\n'
    printf '\n'
    printf 'Commit S3 — Stockhausen artwork cold archive workflow\n'
    printf '  Message suggestion:\n'
    printf '    scripts/media: add stockhausen artwork archive workflow\n'
    printf '  Include likely groups:\n'
    printf '    stockhausen-artwork\n'
    printf '\n'
    printf 'Commit S4 — Stockhausen album 050 import workflow\n'
    printf '  Message suggestion:\n'
    printf '    scripts/media: add stockhausen album 050 import workflow\n'
    printf '  Include likely groups:\n'
    printf '    stockhausen-import-050\n'
    printf '\n'
    printf 'Commit S5 — Stockhausen final freeze and Navidrome checks\n'
    printf '  Message suggestion:\n'
    printf '    scripts/media: add stockhausen final freeze checks\n'
    printf '  Include likely groups:\n'
    printf '    stockhausen-final-freeze\n'
    printf '\n'
    printf 'Do not stage all scripts/media at once until this plan is reviewed.\n'
    printf 'Do not stage generated reports, TSVs or actual media files.\n'
  } >> "$REPORT_FILE"

  record "commit-plan" "M1" "docs/media" "proposed" "docs/media: add media archival documentation"
  record "commit-plan" "M2" "library-soulseek" "proposed" "scripts/media: add library and soulseek tooling"
  record "commit-plan" "S1" "diagnostics-gold-model" "proposed" "scripts/media: add stockhausen diagnostics and gold model tooling"
  record "commit-plan" "S2" "normalization-validation" "proposed" "scripts/media: add stockhausen normalization workflows"
  record "commit-plan" "S3" "artwork-cold-archive" "proposed" "scripts/media: add stockhausen artwork archive workflow"
  record "commit-plan" "S4" "album-050-import" "proposed" "scripts/media: add stockhausen album 050 import workflow"
  record "commit-plan" "S5" "final-freeze-navidrome" "proposed" "scripts/media: add stockhausen final freeze checks"
}

write_review_items() {
  section "Items requiring explicit review"

  {
    printf 'Review before staging:\n'
    printf '\n'
    printf '1. Any script classified as stockhausen-review or unknown action.\n'
    printf '2. Any script failing bash -n.\n'
    printf '3. Any script without #!/usr/bin/env bash or set -u.\n'
    printf '4. Whether scripts should be migrated to scripts/lib now or later.\n'
    printf '5. Whether docs/media is ready to commit as a unit.\n'
    printf '6. Whether scripts/media/library and scripts/media/soulseek should be together or separate.\n'
    printf '7. Whether Stockhausen workflows should be committed by lifecycle phase or by historical work phase.\n'
    printf '\n'
    printf 'Do not fix or migrate scripts in this diagnostic step.\n'
  } >> "$REPORT_FILE"

  record "review" "media-stockhausen" "manual review" "recorded" "see report"
}

write_summary() {
  section "Summary"

  local script_count
  local doc_count
  local bash_fail_count
  local convention_review_count

  script_count="$(awk -F '\t' 'NR > 1 && $1 == "script-classification" {count++} END {print count+0}' "$TSV_FILE")"
  doc_count="$(awk -F '\t' 'NR > 1 && $1 == "doc-classification" {count++} END {print count+0}' "$TSV_FILE")"
  bash_fail_count="$(awk -F '\t' 'NR > 1 && $1 == "bashcheck" && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  convention_review_count="$(awk -F '\t' 'NR > 1 && $1 == "convention" && $4 == "review" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Classified scripts: %s\n' "$script_count"
    printf 'Classified docs: %s\n' "$doc_count"
    printf 'Bash syntax failures: %s\n' "$bash_fail_count"
    printf 'Convention review items: %s\n' "$convention_review_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified except this planning report and TSV.\n'
    printf '\n'
    printf 'Next recommended step:\n'
    printf '  review the proposed groups, then create staging scripts group-by-group.\n'
  } >> "$REPORT_FILE"

  record "summary" "media-stockhausen-plan" "planning completed" "recorded" "scripts=${script_count}; docs=${doc_count}; bash_fail=${bash_fail_count}; convention_review=${convention_review_count}"
}

main() {
  write_headers

  log "Planning Toolbox media/Stockhausen commit groups."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  git_required
  write_current_status
  diagnose_directory "$DOCS_MEDIA_DIR" "docs/media"
  diagnose_directory "$SCRIPTS_MEDIA_DIR" "scripts/media"
  diagnose_directory "$LIBRARY_DIR" "scripts/media/library"
  diagnose_directory "$SOULSEEK_DIR" "scripts/media/soulseek"
  diagnose_directory "$STOCKHAUSEN_DIR" "scripts/media/stockhausen"
  classify_media_files
  validate_bash_syntax_for_media_scripts
  detect_script_headers
  summarize_groups_from_tsv
  write_commit_plan
  write_review_items
  write_summary

  log "Media/Stockhausen commit group planning completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
