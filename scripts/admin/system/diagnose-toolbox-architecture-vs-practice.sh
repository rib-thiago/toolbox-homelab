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

REPORT_FILE="${PROVISIONAL_REPORT_DIR}/toolbox_architecture_vs_practice_review_report_${STAMP}.txt"
TSV_FILE="${PROVISIONAL_RAW_DIR}/toolbox_architecture_vs_practice_review_${STAMP}.tsv"

DOC_DEVELOPMENT_GUIDE="${TOOLBOX_APP}/docs/toolbox_development_guide.md"
DOC_PIPELINE_SPEC="${TOOLBOX_APP}/docs/toolbox_pipeline_spec.md"
DOC_DIRECTORY_LAYOUT="${TOOLBOX_APP}/docs/toolbox_directory_layout.md"
DOC_CLI_CONVENTIONS="${TOOLBOX_APP}/docs/toolbox_cli_conventions.md"
DOC_ARCHITECTURE="${TOOLBOX_APP}/docs/architecture.md"
DOC_MAN7_TOOLBOX="${TOOLBOX_APP}/docs/man7/toolbox.7"
DOC_STORAGE_POLICY="${TOOLBOX_APP}/docs/operations/toolbox_storage_policy.md"

SCRIPT_LIB_DIR="${TOOLBOX_APP}/scripts/lib"
STOCKHAUSEN_SCRIPTS_DIR="${TOOLBOX_APP}/scripts/media/stockhausen"
OPERATIONS_DOCS_DIR="${TOOLBOX_APP}/docs/operations"

REPORTS_MEDIA_DIR="${TOOLBOX_SHARED}/reports/media"
RAW_DIR="${TOOLBOX_SHARED}/library-db/raw"
SNAPSHOT_DIR="${TOOLBOX_SHARED}/library-db/snapshots"

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
  local document_path
  local document_exists
  local section_count
  local matched_terms
  local historical_role
  local practice_alignment
  local detected_gaps
  local classification
  local recommended_action
  local patch_priority
  local notes

  document_path="$1"
  document_exists="$2"
  section_count="$3"
  matched_terms="$4"
  historical_role="$5"
  practice_alignment="$6"
  detected_gaps="$7"
  classification="$8"
  recommended_action="$9"
  patch_priority="${10}"
  notes="${11}"

  {
    tsv_escape "$document_path"
    printf '\t'
    tsv_escape "$document_exists"
    printf '\t'
    tsv_escape "$section_count"
    printf '\t'
    tsv_escape "$matched_terms"
    printf '\t'
    tsv_escape "$historical_role"
    printf '\t'
    tsv_escape "$practice_alignment"
    printf '\t'
    tsv_escape "$detected_gaps"
    printf '\t'
    tsv_escape "$classification"
    printf '\t'
    tsv_escape "$recommended_action"
    printf '\t'
    tsv_escape "$patch_priority"
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

relpath() {
  local path
  path="$1"

  case "$path" in
    "$TOOLBOX_APP"/*)
      printf '%s\n' "${path#$TOOLBOX_APP/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

count_regex() {
  local file
  local pattern
  local count

  file="$1"
  pattern="$2"

  if [ ! -f "$file" ]; then
    printf '0\n'
    return 0
  fi

  count="$(
    grep -Ei "$pattern" "$file" 2>/dev/null \
      | wc -l \
      | tr -d ' '
  )"

  if [ -z "$count" ]; then
    count="0"
  fi

  printf '%s\n' "$count"
}

has_regex() {
  local file
  local pattern

  file="$1"
  pattern="$2"

  if [ ! -f "$file" ]; then
    return 1
  fi

  grep -Eiq "$pattern" "$file" 2>/dev/null
}

section_count_for_doc() {
  local file
  local count

  file="$1"

  if [ ! -f "$file" ]; then
    printf '0\n'
    return 0
  fi

  case "$file" in
    *.md)
      count="$(grep -Ec '^[[:space:]]*#{1,6}[[:space:]]+' "$file" 2>/dev/null || printf '0')"
      ;;
    *.7|*.1)
      count="$(grep -Ec '^\.(SH|SS|TH)[[:space:]]+' "$file" 2>/dev/null || printf '0')"
      ;;
    *)
      count="$(grep -Ec '^[[:space:]]*#{1,6}[[:space:]]+|^\.(SH|SS|TH)[[:space:]]+' "$file" 2>/dev/null || printf '0')"
      ;;
  esac

  printf '%s\n' "$count"
}

matched_terms_for_doc() {
  local file
  local terms

  file="$1"
  terms=""

  [ "$(count_regex "$file" 'run-job|run_job')" -gt 0 ] && terms="${terms}run-job,"
  [ "$(count_regex "$file" 'scripts/lib|/lib/')" -gt 0 ] && terms="${terms}scripts/lib,"
  [ "$(count_regex "$file" 'helpers?')" -gt 0 ] && terms="${terms}helpers,"
  [ "$(count_regex "$file" 'pipelines?')" -gt 0 ] && terms="${terms}pipelines,"
  [ "$(count_regex "$file" 'jobs?')" -gt 0 ] && terms="${terms}jobs,"
  [ "$(count_regex "$file" 'reports?')" -gt 0 ] && terms="${terms}reports,"
  [ "$(count_regex "$file" 'logs?')" -gt 0 ] && terms="${terms}logs,"
  [ "$(count_regex "$file" 'tee')" -gt 0 ] && terms="${terms}tee,"
  [ "$(count_regex "$file" 'nohup')" -gt 0 ] && terms="${terms}nohup,"
  [ "$(count_regex "$file" '(^|[^[:alnum:]_])nf([^[:alnum:]_]|$)')" -gt 0 ] && terms="${terms}nf,"
  [ "$(count_regex "$file" 'git')" -gt 0 ] && terms="${terms}Git,"
  [ "$(count_regex "$file" 'git status')" -gt 0 ] && terms="${terms}git status,"
  [ "$(count_regex "$file" 'commit')" -gt 0 ] && terms="${terms}commit,"
  [ "$(count_regex "$file" 'shared')" -gt 0 ] && terms="${terms}shared,"
  [ "$(count_regex "$file" 'outputs?')" -gt 0 ] && terms="${terms}outputs,"
  [ "$(count_regex "$file" 'architecture|arquitetura')" -gt 0 ] && terms="${terms}architecture,"
  [ "$(count_regex "$file" 'roadmap')" -gt 0 ] && terms="${terms}roadmap,"
  [ "$(count_regex "$file" 'HTTP')" -gt 0 ] && terms="${terms}HTTP,"
  [ "$(count_regex "$file" 'CLI')" -gt 0 ] && terms="${terms}CLI,"
  [ "$(count_regex "$file" 'dashboard')" -gt 0 ] && terms="${terms}dashboard,"
  [ "$(count_regex "$file" 'TUI')" -gt 0 ] && terms="${terms}TUI,"
  [ "$(count_regex "$file" 'docs/operations')" -gt 0 ] && terms="${terms}docs/operations,"
  [ "$(count_regex "$file" 'diagnose')" -gt 0 ] && terms="${terms}diagnose,"
  [ "$(count_regex "$file" '(^|[^[:alpha:]])plan([^[:alpha:]]|$)')" -gt 0 ] && terms="${terms}plan,"
  [ "$(count_regex "$file" '(^|[^[:alpha:]])apply([^[:alpha:]]|$)')" -gt 0 ] && terms="${terms}apply,"
  [ "$(count_regex "$file" 'validate')" -gt 0 ] && terms="${terms}validate,"
  [ "$(count_regex "$file" 'snapshots?')" -gt 0 ] && terms="${terms}snapshots,"
  [ "$(count_regex "$file" 'raw')" -gt 0 ] && terms="${terms}raw,"
  [ "$(count_regex "$file" 'media')" -gt 0 ] && terms="${terms}media,"
  [ "$(count_regex "$file" 'Stockhausen')" -gt 0 ] && terms="${terms}Stockhausen,"

  if [ -z "$terms" ]; then
    printf 'none\n'
  else
    printf '%s\n' "${terms%,}"
  fi
}

historical_role_for_doc() {
  local file
  file="$1"

  case "$file" in
    "$DOC_DEVELOPMENT_GUIDE")
      printf 'initial development workflow and contribution discipline\n'
      ;;
    "$DOC_PIPELINE_SPEC")
      printf 'original pipeline execution model and job-oriented processing design\n'
      ;;
    "$DOC_DIRECTORY_LAYOUT")
      printf 'original filesystem and repository layout specification\n'
      ;;
    "$DOC_CLI_CONVENTIONS")
      printf 'original command taxonomy and CLI/wrapper conventions\n'
      ;;
    "$DOC_ARCHITECTURE")
      printf 'original architectural vision and Unix-like design rationale\n'
      ;;
    "$DOC_MAN7_TOOLBOX")
      printf 'operator-facing conceptual manual for the Toolbox system\n'
      ;;
    "$DOC_STORAGE_POLICY")
      printf 'storage-layer policy connecting homelab, media, cold archive, snapshots and operational storage\n'
      ;;
    *)
      printf 'unknown historical role\n'
      ;;
  esac
}

practice_alignment_for_doc() {
  local file
  local alignment

  file="$1"
  alignment=""

  if has_regex "$file" 'pipelines?|jobs?|run-job'; then
    alignment="${alignment}aligns with original pipeline/job vision; "
  fi

  if has_regex "$file" 'scripts/lib|helpers?|pipelines?'; then
    alignment="${alignment}mentions original helpers/pipelines/lib model; "
  fi

  if has_regex "$file" 'reports?|outputs?|shared|raw|snapshots?'; then
    alignment="${alignment}touches output/auditability concerns; "
  fi

  if has_regex "$file" 'Stockhausen|artwork|FLAC|snapshots?|cold'; then
    alignment="${alignment}connects strongly with archival/media practice; "
  fi

  if has_regex "$file" 'diagnose|plan|apply|validate|dry-run'; then
    alignment="${alignment}partially matches emergent controlled workflow; "
  fi

  if has_regex "$file" 'tee'; then
    alignment="${alignment}contains older internal tee/log-file approach needing review; "
  fi

  if has_regex "$file" 'git|commit'; then
    alignment="${alignment}mentions Git/commit but may lack operational git status routine; "
  fi

  if [ -z "$alignment" ]; then
    alignment="limited direct alignment detected by keyword scan"
  fi

  printf '%s\n' "$alignment"
}

detected_gaps_for_doc() {
  local file
  local gaps

  file="$1"
  gaps=""

  if has_regex "$file" 'scripts/lib' && [ -d "$SCRIPT_LIB_DIR" ]; then
    local nonempty_lib_count
    nonempty_lib_count="$(find "$SCRIPT_LIB_DIR" -maxdepth 1 -type f -size +0c 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$nonempty_lib_count" -eq 0 ]; then
      gaps="${gaps}mentions scripts/lib but current scripts/lib appears placeholder; "
    fi
  fi

  if has_regex "$file" 'tee'; then
    gaps="${gaps}mentions tee/internal log file approach that conflicts or needs distinction from current nf/nohup external logging preference; "
  fi

  if has_regex "$file" 'git|commit' && ! has_regex "$file" 'git status'; then
    gaps="${gaps}mentions Git/commit without git status operational routine; "
  fi

  if has_regex "$file" 'reports/media|library-db/raw'; then
    gaps="${gaps}may encode current/provisional output paths without full domain distinction; "
  fi

  if ! has_regex "$file" 'diagnose' && has_regex "$file" 'plan|apply|validate|dry-run'; then
    gaps="${gaps}workflow mentions plan/apply/validate or dry-run but not diagnose as first-class phase; "
  fi

  if has_regex "$file" 'dashboard|TUI|HTTP|roadmap' && ! has_regex "$file" 'Stockhausen|reports|snapshots|validation|search'; then
    gaps="${gaps}future interface vision may not yet incorporate Stockhausen lessons; "
  fi

  if [ -z "$gaps" ]; then
    gaps="no major gap detected by heuristic scan"
  fi

  printf '%s\n' "$gaps"
}

classification_for_doc() {
  local file
  local classification

  file="$1"

  case "$file" in
    "$DOC_ARCHITECTURE")
      classification="ainda válido como base conceitual; deve ser usado como fonte para nova política"
      ;;
    "$DOC_DIRECTORY_LAYOUT")
      classification="válido, mas precisa de atualização; deve ser usado como fonte para nova política"
      ;;
    "$DOC_CLI_CONVENTIONS")
      classification="válido, mas precisa de atualização; parcialmente superado pela prática"
      ;;
    "$DOC_PIPELINE_SPEC")
      classification="parcialmente superado pela prática; deve ser usado como fonte para nova política"
      ;;
    "$DOC_DEVELOPMENT_GUIDE")
      classification="válido, mas precisa de atualização; deve ser usado como fonte para nova política"
      ;;
    "$DOC_MAN7_TOOLBOX")
      classification="ainda válido como base conceitual; preservar com nota histórica"
      ;;
    "$DOC_STORAGE_POLICY")
      classification="válido, mas precisa de atualização; deve ser usado como fonte para nova política"
      ;;
    *)
      classification="não classificado"
      ;;
  esac

  if has_regex "$file" 'tee'; then
    classification="${classification}; contém prática antiga a reconciliar"
  fi

  if has_regex "$file" 'scripts/lib'; then
    classification="${classification}; descreve intenção arquitetural ainda não consolidada"
  fi

  printf '%s\n' "$classification"
}

recommended_action_for_doc() {
  local file
  local action

  file="$1"

  case "$file" in
    "$DOC_ARCHITECTURE")
      action="preservar como base conceitual; adicionar futuramente nota de evolução operacional apontando para docs/operations"
      ;;
    "$DOC_DIRECTORY_LAYOUT")
      action="patchar depois da política operacional; atualizar layout real admin/media/stockhausen/reports/library-db sem apagar intenção original"
      ;;
    "$DOC_CLI_CONVENTIONS")
      action="patchar depois; distinguir comandos ativos, intenção futura de scripts/lib e práticas emergentes"
      ;;
    "$DOC_PIPELINE_SPEC")
      action="preservar com nota histórica e patchar depois; distinguir pipeline run-job clássico de scripts operacionais diagnose/plan/apply/validate"
      ;;
    "$DOC_DEVELOPMENT_GUIDE")
      action="usar como fonte para toolbox_git_routine e atualizar exemplos antigos de logging"
      ;;
    "$DOC_MAN7_TOOLBOX")
      action="revisar depois que políticas principais forem atualizadas; manter como manual conceitual sintético"
      ;;
    "$DOC_STORAGE_POLICY")
      action="usar como fonte para política de outputs/cold archive/snapshots; patchar com cautela"
      ;;
    *)
      action="revisar depois"
      ;;
  esac

  printf '%s\n' "$action"
}

patch_priority_for_doc() {
  local file
  local priority

  file="$1"

  case "$file" in
    "$DOC_DIRECTORY_LAYOUT")
      priority="high_after_core_policies"
      ;;
    "$DOC_PIPELINE_SPEC")
      priority="high_after_core_policies"
      ;;
    "$DOC_DEVELOPMENT_GUIDE")
      priority="high_after_core_policies"
      ;;
    "$DOC_STORAGE_POLICY")
      priority="medium_high_after_reports_policy"
      ;;
    "$DOC_CLI_CONVENTIONS")
      priority="medium_after_script_policy"
      ;;
    "$DOC_ARCHITECTURE")
      priority="medium_annotation_after_policy"
      ;;
    "$DOC_MAN7_TOOLBOX")
      priority="low_after_docs_stabilize"
      ;;
    *)
      priority="unknown"
      ;;
  esac

  printf '%s\n' "$priority"
}

notes_for_doc() {
  local file
  local notes

  file="$1"
  notes=""

  [ "$(count_regex "$file" 'scripts/lib')" -gt 0 ] && notes="${notes}scripts/lib appears in document; current lib should be treated as placeholder until separate plan; "
  [ "$(count_regex "$file" 'tee')" -gt 0 ] && notes="${notes}contains tee examples; reconcile with nf/nohup external live log preference; "
  [ "$(count_regex "$file" 'run-job|jobs?')" -gt 0 ] && notes="${notes}important for preserving original run-job/jobs architecture; "
  [ "$(count_regex "$file" 'HTTP|dashboard|TUI|roadmap')" -gt 0 ] && notes="${notes}future interface ideas should be reinterpreted through Stockhausen lessons; "
  [ "$(count_regex "$file" 'Stockhausen|artwork|FLAC|cold|snapshots?')" -gt 0 ] && notes="${notes}strong relation to archival/media practice; "
  [ "$(count_regex "$file" 'git|commit')" -gt 0 ] && notes="${notes}source material for future Git routine; "

  if [ -z "$notes" ]; then
    notes="no special notes"
  fi

  printf '%s\n' "$notes"
}

write_header() {
  {
    printf 'Toolbox architecture vs practice comparative diagnosis\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Toolbox shared: %s\n' "$TOOLBOX_SHARED"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope: comparative diagnosis only. No mkdir, no chmod, no mv, no rm, no git writes, no doc edits.\n'
    printf '\n'
    printf 'Important note:\n'
    printf '  This script writes its own artifacts to inherited/provisional locations:\n'
    printf '    human report: %s\n' "$PROVISIONAL_REPORT_DIR"
    printf '    structured TSV: %s\n' "$PROVISIONAL_RAW_DIR"
    printf '  This is NOT a final output policy. These locations are used only to record this diagnosis.\n'
    printf '\n'
    printf 'Method:\n'
    printf '  Compare original architectural/design documents with operational practice that emerged during the Toolbox/Stockhausen work.\n'
    printf '  This diagnosis supports a later plan phase. It is not a patch.\n'
  } > "$REPORT_FILE"

  {
    printf 'document_path\tdocument_exists\tsection_count\tmatched_terms\thistorical_role\tpractice_alignment\tdetected_gaps\tclassification\trecommended_action\tpatch_priority\tnotes\n'
  } > "$TSV_FILE"
}

write_executive_summary() {
  section "1. EXECUTIVE SUMMARY"

  {
    printf 'This report compares seven historical Toolbox documents against the current operational practice.\n'
    printf '\n'
    printf 'Original design layer:\n'
    printf '  - Unix-like Toolbox architecture;\n'
    printf '  - atomic CLI tools;\n'
    printf '  - helpers/pipelines/lib structure;\n'
    printf '  - run-job/jobs model;\n'
    printf '  - manpages and documentation-first design;\n'
    printf '  - future HTTP/CLI/dashboard/TUI direction.\n'
    printf '\n'
    printf 'Emergent practice layer:\n'
    printf '  - diagnose -> plan -> apply -> validate;\n'
    printf '  - scripts as operational documentation;\n'
    printf '  - set -u, log(), fail();\n'
    printf '  - external nf/nohup logs for long-running jobs;\n'
    printf '  - reports, TSVs, snapshots and freezes as audit artifacts;\n'
    printf '  - Stockhausen scripts under scripts/media/stockhausen;\n'
    printf '  - scripts/lib still appears placeholder;\n'
    printf '  - output policy still provisional and historically mixed;\n'
    printf '  - need for Git routine and git status discipline.\n'
    printf '\n'
    printf 'This diagnosis does not replace original architecture with current practice.\n'
    printf 'It identifies what should be preserved, updated, annotated, split, or reused as source for new policy.\n'
  } >> "$REPORT_FILE"
}

write_status_overview() {
  local doc
  local exists

  section "2. SEVEN HISTORICAL DOCUMENTS AND STATUS"

  for doc in \
    "$DOC_DEVELOPMENT_GUIDE" \
    "$DOC_PIPELINE_SPEC" \
    "$DOC_DIRECTORY_LAYOUT" \
    "$DOC_CLI_CONVENTIONS" \
    "$DOC_ARCHITECTURE" \
    "$DOC_MAN7_TOOLBOX" \
    "$DOC_STORAGE_POLICY"
  do
    if [ -f "$doc" ]; then
      exists="yes"
    else
      exists="no"
    fi

    printf '%s\t%s\n' "$(relpath "$doc")" "$exists" >> "$REPORT_FILE"
  done
}

write_current_practice_evidence() {
  section "3. CURRENT PRACTICE EVIDENCE"

  append_shell "scripts/lib state" "find '$SCRIPT_LIB_DIR' -maxdepth 1 -type f 2>/dev/null | sort | while read -r f; do stat -c '%n | size=%s bytes | %y' \"\$f\"; done || true"
  append_shell "scripts/lib non-empty file count" "find '$SCRIPT_LIB_DIR' -maxdepth 1 -type f -size +0c 2>/dev/null | wc -l || true"
  append_shell "Stockhausen scripts state" "find '$STOCKHAUSEN_SCRIPTS_DIR' -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sed 's#^.*/##' | sort || true"
  append_shell "Operations docs state" "find '$OPERATIONS_DOCS_DIR' -maxdepth 2 -type f 2>/dev/null | sort || true"
  append_shell "Recent reports/media examples" "find '$REPORTS_MEDIA_DIR' -maxdepth 2 -type f 2>/dev/null | sed 's#^.*/##' | sort | tail -80 || true"
  append_shell "Recent raw TSV examples" "find '$RAW_DIR' -maxdepth 1 -type f 2>/dev/null | sed 's#^.*/##' | sort | tail -80 || true"
  append_shell "Recent snapshots examples" "find '$SNAPSHOT_DIR' -maxdepth 1 -type f 2>/dev/null | sed 's#^.*/##' | sort | tail -40 || true"
  append_shell "Git status summary" "cd '$TOOLBOX_APP' && git rev-parse --show-toplevel 2>/dev/null && git branch --show-current 2>/dev/null && git status --short 2>/dev/null | sed -n '1,140p' || true"
}

write_findings_by_document() {
  local doc
  local exists
  local sections
  local terms
  local historical_role
  local alignment
  local gaps
  local classification
  local action
  local priority
  local notes

  section "4. FINDINGS BY DOCUMENT"

  for doc in \
    "$DOC_DEVELOPMENT_GUIDE" \
    "$DOC_PIPELINE_SPEC" \
    "$DOC_DIRECTORY_LAYOUT" \
    "$DOC_CLI_CONVENTIONS" \
    "$DOC_ARCHITECTURE" \
    "$DOC_MAN7_TOOLBOX" \
    "$DOC_STORAGE_POLICY"
  do
    subsection "$(relpath "$doc")"

    if [ -f "$doc" ]; then
      exists="yes"
    else
      exists="no"
    fi

    sections="$(section_count_for_doc "$doc")"
    terms="$(matched_terms_for_doc "$doc")"
    historical_role="$(historical_role_for_doc "$doc")"
    alignment="$(practice_alignment_for_doc "$doc")"
    gaps="$(detected_gaps_for_doc "$doc")"
    classification="$(classification_for_doc "$doc")"
    action="$(recommended_action_for_doc "$doc")"
    priority="$(patch_priority_for_doc "$doc")"
    notes="$(notes_for_doc "$doc")"

    {
      printf 'Exists: %s\n' "$exists"
      printf 'Section count: %s\n' "$sections"
      printf 'Historical role: %s\n' "$historical_role"
      printf 'Matched terms: %s\n' "$terms"
      printf 'Practice alignment: %s\n' "$alignment"
      printf 'Detected gaps: %s\n' "$gaps"
      printf 'Classification: %s\n' "$classification"
      printf 'Recommended action: %s\n' "$action"
      printf 'Patch priority: %s\n' "$priority"
      printf 'Notes: %s\n' "$notes"
      printf '\n'
    } >> "$REPORT_FILE"

    if [ "$exists" = "yes" ]; then
      printf 'Sections/titles:\n' >> "$REPORT_FILE"
      case "$doc" in
        *.md)
          grep -En '^[[:space:]]*#{1,6}[[:space:]]+' "$doc" 2>/dev/null >> "$REPORT_FILE" || true
          ;;
        *.7|*.1)
          grep -En '^\.(TH|SH|SS)[[:space:]]+' "$doc" 2>/dev/null >> "$REPORT_FILE" || true
          ;;
      esac
    else
      printf 'Document missing; no section extraction performed.\n' >> "$REPORT_FILE"
    fi

    tsv_row \
      "$(relpath "$doc")" \
      "$exists" \
      "$sections" \
      "$terms" \
      "$historical_role" \
      "$alignment" \
      "$gaps" \
      "$classification" \
      "$action" \
      "$priority" \
      "$notes"
  done
}

write_terms_by_document() {
  local doc
  local relative

  section "5. TERMS FOUND BY DOCUMENT"

  for doc in \
    "$DOC_DEVELOPMENT_GUIDE" \
    "$DOC_PIPELINE_SPEC" \
    "$DOC_DIRECTORY_LAYOUT" \
    "$DOC_CLI_CONVENTIONS" \
    "$DOC_ARCHITECTURE" \
    "$DOC_MAN7_TOOLBOX" \
    "$DOC_STORAGE_POLICY"
  do
    relative="$(relpath "$doc")"
    subsection "$relative"

    if [ ! -f "$doc" ]; then
      printf 'Document missing.\n' >> "$REPORT_FILE"
      continue
    fi

    {
      printf 'run-job: %s\n' "$(count_regex "$doc" 'run-job|run_job')"
      printf 'scripts/lib: %s\n' "$(count_regex "$doc" 'scripts/lib|/lib/')"
      printf 'helpers: %s\n' "$(count_regex "$doc" 'helpers?')"
      printf 'pipelines: %s\n' "$(count_regex "$doc" 'pipelines?')"
      printf 'jobs: %s\n' "$(count_regex "$doc" 'jobs?')"
      printf 'reports: %s\n' "$(count_regex "$doc" 'reports?')"
      printf 'logs: %s\n' "$(count_regex "$doc" 'logs?')"
      printf 'tee: %s\n' "$(count_regex "$doc" 'tee')"
      printf 'nohup: %s\n' "$(count_regex "$doc" 'nohup')"
      printf 'nf: %s\n' "$(count_regex "$doc" '(^|[^[:alnum:]_])nf([^[:alnum:]_]|$)')"
      printf 'Git: %s\n' "$(count_regex "$doc" 'git')"
      printf 'git status: %s\n' "$(count_regex "$doc" 'git status')"
      printf 'commit: %s\n' "$(count_regex "$doc" 'commit')"
      printf 'shared: %s\n' "$(count_regex "$doc" 'shared')"
      printf 'outputs: %s\n' "$(count_regex "$doc" 'outputs?')"
      printf 'architecture: %s\n' "$(count_regex "$doc" 'architecture|arquitetura')"
      printf 'roadmap: %s\n' "$(count_regex "$doc" 'roadmap')"
      printf 'HTTP: %s\n' "$(count_regex "$doc" 'HTTP')"
      printf 'CLI: %s\n' "$(count_regex "$doc" 'CLI')"
      printf 'dashboard: %s\n' "$(count_regex "$doc" 'dashboard')"
      printf 'TUI: %s\n' "$(count_regex "$doc" 'TUI')"
      printf 'docs/operations: %s\n' "$(count_regex "$doc" 'docs/operations')"
      printf 'diagnose: %s\n' "$(count_regex "$doc" 'diagnose')"
      printf 'plan: %s\n' "$(count_regex "$doc" '(^|[^[:alpha:]])plan([^[:alpha:]]|$)')"
      printf 'apply: %s\n' "$(count_regex "$doc" '(^|[^[:alpha:]])apply([^[:alpha:]]|$)')"
      printf 'validate: %s\n' "$(count_regex "$doc" 'validate')"
      printf 'snapshots: %s\n' "$(count_regex "$doc" 'snapshots?')"
      printf 'raw: %s\n' "$(count_regex "$doc" 'raw')"
      printf 'media: %s\n' "$(count_regex "$doc" 'media')"
      printf 'Stockhausen: %s\n' "$(count_regex "$doc" 'Stockhausen')"
    } >> "$REPORT_FILE"
  done
}

write_architecture_vs_practice() {
  section "6. ARCHITECTURE ORIGINAL VS EMERGENT PRACTICE"

  {
    printf 'Original architecture patterns detected:\n'
    printf '  - helper/pipeline/lib separation;\n'
    printf '  - run-job/jobs as structured execution;\n'
    printf '  - manpage-based documentation;\n'
    printf '  - CLI and wrapper conventions;\n'
    printf '  - future HTTP/CLI/dashboard/TUI ideas in roadmap/design docs when present.\n'
    printf '\n'
    printf 'Emergent operational practice detected from current Toolbox state:\n'
    printf '  - scripts/media/stockhausen contains a large corpus of diagnose/plan/apply/repair/validate/freeze scripts;\n'
    printf '  - scripts/lib exists but is not yet a real shared library if files are empty;\n'
    printf '  - outputs are mixed across reports/media, reports/<domain>, library-db/raw and snapshots;\n'
    printf '  - reports/media has been used provisionally for non-media diagnostics;\n'
    printf '  - library-db/raw has been used provisionally for structured TSVs;\n'
    printf '  - practice requires git status discipline and untracked classification;\n'
    printf '  - scripts themselves act as operational documentation.\n'
    printf '\n'
    printf 'Interpretation:\n'
    printf '  The original architecture should not be discarded.\n'
    printf '  The Stockhausen-era practice should not blindly overwrite it.\n'
    printf '  The next documentation layer should preserve original intent, annotate drift, and define current operational policy.\n'
  } >> "$REPORT_FILE"
}

write_contradictions_and_gaps() {
  section "7. CONTRADICTIONS, MISALIGNMENTS AND DOCUMENTATION GAPS"

  {
    printf 'Potential contradictions or misalignments:\n'
    printf '  - Documents may describe scripts/lib as architectural infrastructure, while current scripts/lib appears placeholder.\n'
    printf '  - Older docs may use tee-based internal logging, while current practice prefers external nf/nohup logs unless deliberate.\n'
    printf '  - Original pipeline/job design may not fully describe diagnose -> plan -> apply -> validate.\n'
    printf '  - reports/media and library-db/raw appear in current practice, but output policy is not final.\n'
    printf '  - Git/commit may be mentioned, but git status routine is a distinct operational need.\n'
    printf '\n'
    printf 'Documentation gaps:\n'
    printf '  - Explicit architecture-vs-practice narrative.\n'
    printf '  - Git routine document.\n'
    printf '  - Output policy distinguishing general, admin, media, Stockhausen, logs, raw data and snapshots.\n'
    printf '  - scripts/lib maturity policy.\n'
    printf '  - TUI/dashboard/search vision derived from real reports/TSVs/snapshots/jobs.\n'
  } >> "$REPORT_FILE"
}

write_classification_summary() {
  section "8. DOCUMENT CLASSIFICATION SUMMARY"

  {
    printf 'docs/architecture.md\n'
    printf '  Classification: still valid as conceptual basis; source for new policy.\n'
    printf '  Action: preserve; later add operational evolution note.\n'
    printf '\n'
    printf 'docs/toolbox_directory_layout.md\n'
    printf '  Classification: valid but needs update; source for new policy.\n'
    printf '  Action: patch after core policies to reflect real admin/media/stockhausen/shared layout.\n'
    printf '\n'
    printf 'docs/toolbox_cli_conventions.md\n'
    printf '  Classification: valid but needs update; partially surpassed by practice.\n'
    printf '  Action: distinguish active commands from intended future scripts/lib model.\n'
    printf '\n'
    printf 'docs/toolbox_pipeline_spec.md\n'
    printf '  Classification: partially surpassed by practice; source for new policy.\n'
    printf '  Action: preserve and annotate pipeline vs operational scripts distinction.\n'
    printf '\n'
    printf 'docs/toolbox_development_guide.md\n'
    printf '  Classification: valid but needs update; source for Git routine and logging corrections.\n'
    printf '  Action: use as source for toolbox_git_routine and update legacy tee examples later.\n'
    printf '\n'
    printf 'docs/man7/toolbox.7\n'
    printf '  Classification: still valid as conceptual/operator manual; preserve with historical note.\n'
    printf '  Action: revise after policy docs stabilize.\n'
    printf '\n'
    printf 'docs/operations/toolbox_storage_policy.md\n'
    printf '  Classification: valid but needs update; source for outputs/cold archive/snapshots policy.\n'
    printf '  Action: use as source for reports/storage/cold archive policy.\n'
  } >> "$REPORT_FILE"
}

write_patch_candidates() {
  section "9. PATCH CANDIDATES AND NEW DOCUMENTS SUGGESTED"

  {
    printf 'Priority patch candidates after this diagnosis:\n'
    printf '  1. docs/operations/toolbox_reports_policy.md\n'
    printf '     Reason: output policy must distinguish domain reports, media, Stockhausen, raw TSVs, logs and snapshots.\n'
    printf '\n'
    printf '  2. docs/operations/toolbox_logging_policy.md\n'
    printf '     Reason: align nf/nohup external logs with legacy tee/internal logging examples.\n'
    printf '\n'
    printf '  3. docs/operations/toolbox_script_conventions.md\n'
    printf '     Reason: formalize diagnose -> plan -> apply -> validate, set -u, log(), fail(), scripts as documentation.\n'
    printf '\n'
    printf '  4. docs/operations/toolbox_git_routine.md [new]\n'
    printf '     Reason: no stable operational Git routine exists for git status, untracked classification, bashcheck and commits.\n'
    printf '\n'
    printf '  5. docs/operations/toolbox_architecture_vs_practice_review.md [possible new]\n'
    printf '     Reason: preserve history and explicitly compare original design with emergent practice.\n'
    printf '\n'
    printf 'Future documents or sections:\n'
    printf '  - general output policy;\n'
    printf '  - scripts/lib maturity policy;\n'
    printf '  - TUI/dashboard/search lessons from Stockhausen;\n'
    printf '  - legacy outputs policy with no retroactive moves unless planned.\n'
  } >> "$REPORT_FILE"
}

write_next_step() {
  section "10. NEXT STEP RECOMMENDED AFTER THIS DIAGNOSIS"

  {
    printf 'Recommended next step:\n'
    printf '  Analyze this report and TSV, then produce a Plan documental.\n'
    printf '\n'
    printf 'The plan should not patch files yet.\n'
    printf 'It should define which docs will be modified or created, in what order, and why.\n'
    printf '\n'
    printf 'Do not yet:\n'
    printf '  - move outputs;\n'
    printf '  - create scripts/lib;\n'
    printf '  - create newbash;\n'
    printf '  - change aliases;\n'
    printf '  - create TUI/dashboard;\n'
    printf '  - commit to Git;\n'
    printf '  - rewrite old historical docs as if they were mistakes.\n'
  } >> "$REPORT_FILE"
}

main() {
  require_writable_dir "$PROVISIONAL_REPORT_DIR" "provisional report dir"
  require_writable_dir "$PROVISIONAL_RAW_DIR" "provisional raw dir"

  write_header

  log "Writing provisional human report: $REPORT_FILE"
  log "Writing provisional structured TSV: $TSV_FILE"
  log "Note: output destinations are provisional for this diagnosis, not final policy."

  write_executive_summary
  write_status_overview
  write_current_practice_evidence
  write_findings_by_document
  write_terms_by_document
  write_architecture_vs_practice
  write_contradictions_and_gaps
  write_classification_summary
  write_patch_candidates
  write_next_step

  log "Architecture vs practice diagnosis completed."
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
