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

REPORT="$REPORT_DIR/knowledge_architecture_candidates_report_$STAMP.txt"
TSV="$RAW_DIR/knowledge_architecture_candidates_$STAMP.tsv"

mkdir -p "$REPORT_DIR" "$RAW_DIR"

log "Starting knowledge architecture candidates diagnosis."

printf 'timestamp\tcategory\tpath\tline\tmatch\n' > "$TSV"

write_match_block() {
  local title="$1"
  local category="$2"
  local pattern="$3"
  shift 3
  local roots=("$@")

  {
    printf '\n## %s\n\n' "$title"
    printf 'Pattern: `%s`\n\n' "$pattern"
  } >> "$REPORT"

  grep -RInE "$pattern" "${roots[@]}" 2>/dev/null | sort | while IFS= read -r line; do
    printf '%s\n' "$line" >> "$REPORT"

    local path lineno match
    path="${line%%:*}"
    rest="${line#*:}"
    lineno="${rest%%:*}"
    match="${rest#*:}"

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(toolbox_now)" \
      "$category" \
      "$path" \
      "$lineno" \
      "$(printf '%s' "$match" | tr '\t' ' ')" \
      >> "$TSV"
  done
}

{
  printf '# Knowledge architecture candidates diagnosis\n\n'
  printf 'Generated at: %s\n' "$(toolbox_now)"
  printf 'App dir: %s\n' "$APP_DIR"
  printf 'Shared dir: %s\n' "$SHARED_DIR"
  printf 'Report: %s\n' "$REPORT"
  printf 'TSV: %s\n\n' "$TSV"

  printf '## Purpose\n\n'
  printf 'This read-only diagnostic finds candidate material for:\n\n'
  printf -- '- knowledge/architecture/historical-operational-lessons.md\n'
  printf -- '- knowledge/architecture/open-questions.md\n'
  printf -- '- future ADRs\n'
  printf -- '- future inventory/graph diagnostics\n\n'
  printf 'It does not modify files, inspect live services, or infer decisions.\n'
} > "$REPORT"

cd "$APP_DIR" || exit 1

ROOTS=(knowledge docs scripts)

write_match_block \
  "Graph and inventory references" \
  "graph_inventory" \
  'knowledge/graph|entities.yaml|relations.yaml|inventory/|observed state|estado observado|source of truth|fonte de verdade|relationship graph|dependency|dependencies|impact' \
  "${ROOTS[@]}"

write_match_block \
  "ADR and architecture references" \
  "adr_architecture" \
  'ADR|Architecture Decision|architecture/|why|por que|decision|decisão|trade-off|rationale|racional' \
  "${ROOTS[@]}"

write_match_block \
  "Historical lessons references" \
  "historical_lessons" \
  'historical lessons|Known historical lessons|lessons learned|aprendemos|lição|lessons|historical-operational-lessons' \
  "${ROOTS[@]}"

write_match_block \
  "Open questions and future clarification references" \
  "open_questions" \
  'Open questions|open-questions|Current known areas|future clarification|future Codex|future local-agent|pending|pendente|TODO|FIXME|deferred|needs diagnosis|needs operator decision|candidate ADR' \
  "${ROOTS[@]}"

write_match_block \
  "Operational workflow references" \
  "workflow" \
  'diagnose|plan|apply|validate|repair|resume|freeze|snapshot|purge|import|split|run-job|pipeline|report|TSV|snapshot|logs' \
  knowledge docs scripts

write_match_block \
  "Risk and approval references" \
  "risk_approval" \
  'approval|required approval|human approval|sensitive|must not|must verify|must be verified|do not|não deve|risk|risco|danger|perigo' \
  knowledge docs scripts

{
  printf '\n## Candidate files\n\n'
  find knowledge docs scripts -type f \
    | sort \
    | grep -E 'knowledge/(context|policies|services|architecture|graph|runbooks)|docs/operations|docs/media|scripts/admin|scripts/media|scripts/pipelines|scripts/lib' \
    || true

  printf '\n## Git status\n\n'
  git status --short

  printf '\n## Generated artifacts\n\n'
  printf 'Report: %s\n' "$REPORT"
  printf 'TSV: %s\n' "$TSV"
} >> "$REPORT"

log "Knowledge architecture candidates diagnosis completed."
log "Report: $REPORT"
log "TSV: $TSV"
