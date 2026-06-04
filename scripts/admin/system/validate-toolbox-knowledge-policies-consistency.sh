#!/usr/bin/env bash
set -u

APP_DIR="${APP_DIR:-/srv/toolbox/app}"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/system"
RAW_DIR="$SHARED_DIR/library-db/raw/system"

REPORT="$REPORT_DIR/toolbox_knowledge_policies_consistency_$STAMP.txt"
TSV="$RAW_DIR/toolbox_knowledge_policies_consistency_$STAMP.tsv"

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
INFO_COUNT=0

POLICIES=(
  "knowledge/policies/agent-safety-policy.md"
  "knowledge/policies/change-management-policy.md"
  "knowledge/policies/reporting-policy.md"
  "knowledge/policies/filesystem-safety-policy.md"
  "knowledge/policies/media-curation-policy.md"
  "knowledge/policies/architecture-knowledge-policy.md"
)

CORE_CONTEXT_REFS=(
  "knowledge/context/agent-entrypoint.md"
  "knowledge/context/homelab-context.md"
  "knowledge/context/toolbox-context.md"
)

CORE_POLICY_TERMS=(
  "diagnose"
  "plan"
  "apply"
  "validate"
  "approval"
  "reports"
  "TSV"
  "/srv/toolbox/app"
  "/srv/toolbox/shared"
  "existing Toolbox"
  "human approval"
)

require_function() {
  local fn="$1"

  if ! declare -F "$fn" >/dev/null 2>&1; then
    printf '%s\n' "[ERRO] Required function not found: $fn" >&2
    exit 1
  fi
}

require_lib_contract() {
  require_function log
  require_function fail
  require_function toolbox_timestamp
  require_function toolbox_now
  require_function toolbox_shared_dir
}

ensure_output_dirs() {
  mkdir -p "$REPORT_DIR" "$RAW_DIR"
}

tsv_escape() {
  local value="${1:-}"
  printf '%s' "$value" | tr '\t\r\n' '   '
}

write_tsv_header() {
  printf 'timestamp\tstatus\tcheck_id\tpath\tdetail\n' > "$TSV"
}

record() {
  local status="$1"
  local check_id="$2"
  local path="$3"
  local detail="$4"
  local now

  now="$(toolbox_now)"

  case "$status" in
    OK)
      OK_COUNT=$((OK_COUNT + 1))
      ;;
    WARN)
      WARN_COUNT=$((WARN_COUNT + 1))
      ;;
    FAIL)
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
    INFO)
      INFO_COUNT=$((INFO_COUNT + 1))
      ;;
    *)
      status="FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      detail="Invalid validation status"
      ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(tsv_escape "$now")" \
    "$(tsv_escape "$status")" \
    "$(tsv_escape "$check_id")" \
    "$(tsv_escape "$path")" \
    "$(tsv_escape "$detail")" >> "$TSV"

  printf '[%s] %-5s %-58s %s\n' "$check_id" "$status" "$path" "$detail" >> "$REPORT"
}

write_report_header() {
  {
    printf '# Toolbox knowledge policies consistency validation\n\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'App dir: %s\n' "$APP_DIR"
    printf 'Shared dir: %s\n' "$SHARED_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n\n' "$TSV"
    printf '## Scope\n\n'
    printf 'This validation reviews the current minimal policy layer under knowledge/policies.\n\n'
    printf 'Expected policy files:\n\n'
    for p in "${POLICIES[@]}"; do
      printf -- '- `%s`\n' "$p"
    done
    printf '\n## Checks\n\n'
  } > "$REPORT"
}

write_report_summary() {
  {
    printf '\n## Summary\n\n'
    printf 'OK: %s\n' "$OK_COUNT"
    printf 'WARN: %s\n' "$WARN_COUNT"
    printf 'FAIL: %s\n' "$FAIL_COUNT"
    printf 'INFO: %s\n' "$INFO_COUNT"
    printf '\n'
  } >> "$REPORT"
}

check_file_exists() {
  local path="$1"

  if [ -f "$APP_DIR/$path" ]; then
    record "OK" "policy_exists" "$path" "policy file exists"
  else
    record "FAIL" "policy_exists" "$path" "expected policy file is missing"
  fi
}

check_markdown_fences() {
  local path="$1"
  local full_path="$APP_DIR/$path"
  local count

  if [ ! -f "$full_path" ]; then
    record "FAIL" "markdown_fence" "$path" "cannot check missing file"
    return 0
  fi

  count="$(python3 - "$full_path" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text()
print(text.count("```"))
PY
)"

  if [ $((count % 2)) -eq 0 ]; then
    record "OK" "markdown_fence" "$path" "balanced markdown code fences: $count"
  else
    record "FAIL" "markdown_fence" "$path" "unbalanced markdown code fences: $count"
  fi
}

check_reference() {
  local ref="$1"
  local path="$2"
  local full_path="$APP_DIR/$path"

  if [ ! -f "$full_path" ]; then
    record "FAIL" "reference" "$path" "cannot check missing file for reference: $ref"
    return 0
  fi

  if grep -F "$ref" "$full_path" >/dev/null 2>&1; then
    record "OK" "reference" "$path" "reference found: $ref"
  else
    record "WARN" "reference" "$path" "reference not found: $ref"
  fi
}

check_required_heading() {
  local heading="$1"
  local path="$2"
  local full_path="$APP_DIR/$path"

  if [ ! -f "$full_path" ]; then
    record "FAIL" "heading" "$path" "cannot check missing file for heading: $heading"
    return 0
  fi

  if grep -F "## $heading" "$full_path" >/dev/null 2>&1; then
    record "OK" "heading" "$path" "heading found: $heading"
  else
    record "WARN" "heading" "$path" "heading not found: $heading"
  fi
}

check_term_in_corpus() {
  local term="$1"
  local count

  count="$(cd "$APP_DIR" && grep -Fhi "$term" "${POLICIES[@]}" 2>/dev/null | wc -l | tr -d ' ')"

  if [ "${count:-0}" -gt 0 ]; then
    record "OK" "corpus_term" "knowledge/policies" "term found across policy corpus: $term ($count matches)"
  else
    record "WARN" "corpus_term" "knowledge/policies" "term not found across policy corpus: $term"
  fi
}

check_path_references_exist() {
  python3 - "$APP_DIR" "${POLICIES[@]}" > "$RAW_DIR/.policy_path_reference_check_$STAMP.tmp" <<'PY'
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])
policies = [Path(p) for p in sys.argv[2:]]

pattern = re.compile(r'`((?:knowledge|docs|scripts)/[^`]+?\.md)`')
seen = set()

for rel in policies:
    full = app / rel
    if not full.exists():
        continue
    text = full.read_text()
    for match in pattern.findall(text):
        seen.add(match)

for ref in sorted(seen):
    exists = (app / ref).exists()
    status = "OK" if exists else "WARN"
    detail = "referenced path exists" if exists else "referenced path does not exist"
    print(f"{status}\tpath_reference\t{ref}\t{detail}")
PY

  while IFS=$'\t' read -r status check_id path detail; do
    [ -n "${status:-}" ] || continue
    record "$status" "$check_id" "$path" "$detail"
  done < "$RAW_DIR/.policy_path_reference_check_$STAMP.tmp"

  rm -f "$RAW_DIR/.policy_path_reference_check_$STAMP.tmp"
}

check_repeated_lines() {
  python3 - "$APP_DIR" "${POLICIES[@]}" > "$RAW_DIR/.policy_repeated_lines_$STAMP.tmp" <<'PY'
from pathlib import Path
from collections import defaultdict
import sys

app = Path(sys.argv[1])
policies = [Path(p) for p in sys.argv[2:]]

occ = defaultdict(set)

ignore_prefixes = (
    "#",
    "- `knowledge/context/",
    "- `knowledge/policies/",
    "- `docs/operations/",
    "- `docs/media/",
    "* `knowledge/context/",
    "* `knowledge/policies/",
    "* `docs/operations/",
    "* `docs/media/",
)

accepted_repeated_lines = {
    "If a document appears stale, incomplete, or inconsistent with observed host state, the inconsistency must be reported and reviewed.",
    "This policy does not replace existing Toolbox policies, conventions, or operational documentation.",
    "* whether `nohup`, `nf`, `nflog`, `tblive`, external redirection, or `run-job` should be used.",
    "If a conflict exists between this policy and an older document, the operator or agent must stop and ask for human review instead of choosing one silently.",
}

for rel in policies:
    full = app / rel
    if not full.exists():
        continue
    for line in full.read_text().splitlines():
        stripped = " ".join(line.strip().split())
        if len(stripped) < 80:
            continue
        if stripped.startswith(ignore_prefixes):
            continue
        if stripped in accepted_repeated_lines:
            continue
        occ[stripped].add(str(rel))

rows = []
for line, files in occ.items():
    if len(files) >= 3:
        rows.append((line, sorted(files)))

for line, files in sorted(rows, key=lambda item: (-len(item[1]), item[0]))[:30]:
    print(f"WARN\trepeated_line\tknowledge/policies\tline repeated in {len(files)} policy files: {line[:180]}")
PY

  if [ -s "$RAW_DIR/.policy_repeated_lines_$STAMP.tmp" ]; then
    while IFS=$'\t' read -r status check_id path detail; do
      [ -n "${status:-}" ] || continue
      record "$status" "$check_id" "$path" "$detail"
    done < "$RAW_DIR/.policy_repeated_lines_$STAMP.tmp"
  else
    record "OK" "repeated_line" "knowledge/policies" "no strong repeated long lines detected across three or more policy files"
  fi

  rm -f "$RAW_DIR/.policy_repeated_lines_$STAMP.tmp"
}

run_primary_validator() {
  local output
  local status

  set +e
  output="$(cd "$APP_DIR" && scripts/admin/system/validate-toolbox-knowledge-context.sh 2>&1)"
  status=$?
  set -e 2>/dev/null || true

  if [ "$status" -eq 0 ]; then
    record "OK" "primary_validator" "scripts/admin/system/validate-toolbox-knowledge-context.sh" "primary knowledge validator passed"
  else
    record "FAIL" "primary_validator" "scripts/admin/system/validate-toolbox-knowledge-context.sh" "primary knowledge validator failed"
    {
      printf '\n## Primary validator output\n\n'
      printf '%s\n' "$output"
    } >> "$REPORT"
  fi
}

check_git_diff_check() {
  local output
  local status

  set +e
  output="$(cd "$APP_DIR" && git diff --check 2>&1)"
  status=$?
  set -e 2>/dev/null || true

  if [ "$status" -eq 0 ]; then
    record "OK" "git_diff_check" "$APP_DIR" "git diff --check passed"
  else
    record "FAIL" "git_diff_check" "$APP_DIR" "git diff --check failed"
    {
      printf '\n## git diff --check output\n\n'
      printf '%s\n' "$output"
    } >> "$REPORT"
  fi
}

check_git_status() {
  local status

  status="$(cd "$APP_DIR" && git status --short)"

  if [ -z "$status" ]; then
    record "OK" "git_status" "$APP_DIR" "working tree clean"
  else
    record "WARN" "git_status" "$APP_DIR" "working tree has pending changes"
    {
      printf '\n## Git status --short\n\n'
      printf '%s\n' "$status"
    } >> "$REPORT"
  fi
}

write_policy_listing() {
  {
    printf '\n## Policy files\n\n'
    cd "$APP_DIR" && find knowledge/policies -maxdepth 1 -type f -name '*.md' -print | sort
    printf '\n'
  } >> "$REPORT"
}

main() {
  require_lib_contract
  ensure_output_dirs
  write_tsv_header
  write_report_header

  log "Starting Toolbox knowledge policies consistency validation."

  for policy in "${POLICIES[@]}"; do
    check_file_exists "$policy"
    check_markdown_fences "$policy"

    for ref in "${CORE_CONTEXT_REFS[@]}"; do
      check_reference "$ref" "$policy"
    done

    check_required_heading "Primary principle" "$policy"
  done

  check_reference "knowledge/policies/agent-safety-policy.md" "knowledge/policies/change-management-policy.md"
  check_reference "knowledge/policies/change-management-policy.md" "knowledge/policies/reporting-policy.md"
  check_reference "knowledge/policies/reporting-policy.md" "knowledge/policies/filesystem-safety-policy.md"
  check_reference "knowledge/policies/filesystem-safety-policy.md" "knowledge/policies/media-curation-policy.md"
  check_reference "knowledge/policies/media-curation-policy.md" "knowledge/policies/architecture-knowledge-policy.md"

  for term in "${CORE_POLICY_TERMS[@]}"; do
    check_term_in_corpus "$term"
  done

  check_path_references_exist
  check_repeated_lines
  run_primary_validator
  check_git_diff_check
  check_git_status
  write_policy_listing
  write_report_summary

  log "Toolbox knowledge policies consistency validation completed."
  log "Report: $REPORT"
  log "TSV: $TSV"

  if [ "$FAIL_COUNT" -gt 0 ]; then
    fail "Policy consistency validation failed with $FAIL_COUNT failure(s)."
  fi

  return 0
}

main "$@"
