#!/usr/bin/env bash
set -u

APP_DIR="${APP_DIR:-/srv/toolbox/app}"
LIB_DIR="$APP_DIR/scripts/lib"
GENERATOR_SCRIPT="scripts/admin/system/generate-toolbox-inventory.sh"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
GENERATED_AT="$(toolbox_now)"
SHARED_DIR="$(toolbox_shared_dir)"

SOURCE_DIR="$SHARED_DIR/library-db/raw/system"
REPORT_DIR="$SHARED_DIR/reports/system"
INVENTORY_DIR="$SHARED_DIR/inventory/toolbox"

OUT_TSV="$INVENTORY_DIR/toolbox_inventory_$STAMP.tsv"
OUT_REPORT="$REPORT_DIR/toolbox_inventory_report_$STAMP.txt"

usage() {
  cat <<'EOF'
Usage:
  generate-toolbox-inventory.sh
  generate-toolbox-inventory.sh SOURCE_TSV
  generate-toolbox-inventory.sh --help

Generate toolbox_inventory_v0 from an existing Toolbox script inventory TSV.

Without SOURCE_TSV, the latest matching source is selected from:
  /srv/toolbox/shared/library-db/raw/system/toolbox_script_inventory_*.tsv
EOF
}

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

latest_source_tsv() {
  find "$SOURCE_DIR" -maxdepth 1 -type f -name 'toolbox_script_inventory_*.tsv' -printf '%T@ %p\n' 2>/dev/null \
    | sort -n \
    | tail -n 1 \
    | cut -d' ' -f2-
}

infer_source_report() {
  local source_tsv="$1"
  local base
  local source_stamp
  local candidate

  base="$(basename "$source_tsv")"
  source_stamp="${base#toolbox_script_inventory_}"
  source_stamp="${source_stamp%.tsv}"
  candidate="$REPORT_DIR/toolbox_script_inventory_report_$source_stamp.txt"

  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "unknown"
  fi
}

git_branch_value() {
  if git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$APP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s\n' "unknown"
  else
    printf '%s\n' "unknown"
  fi
}

git_commit_value() {
  if git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$APP_DIR" rev-parse HEAD 2>/dev/null || printf '%s\n' "unknown"
  else
    printf '%s\n' "unknown"
  fi
}

git_status_value() {
  local status_out

  if ! git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' "unknown"
    return 0
  fi

  status_out="$(git -C "$APP_DIR" status --short 2>/dev/null)"
  if [ $? -ne 0 ]; then
    printf '%s\n' "unknown"
  elif [ -n "$status_out" ]; then
    printf '%s\n' "dirty"
  else
    printf '%s\n' "clean"
  fi
}

ensure_output_dirs() {
  mkdir -p "$INVENTORY_DIR" "$REPORT_DIR" || fail "Unable to create output directories"
}

run_transform() {
  local source_tsv="$1"
  local source_report="$2"
  local git_branch="$3"
  local git_commit="$4"
  local git_status="$5"

  python3 - "$source_tsv" "$source_report" "$OUT_TSV" "$OUT_REPORT" "$APP_DIR" "$GENERATOR_SCRIPT" "$GENERATED_AT" "$git_branch" "$git_commit" "$git_status" <<'PY'
from __future__ import annotations

from collections import Counter
import csv
import sys
from pathlib import Path

source_tsv = Path(sys.argv[1])
source_report = sys.argv[2]
out_tsv = Path(sys.argv[3])
out_report = Path(sys.argv[4])
repo_root = sys.argv[5]
generator_script = sys.argv[6]
generated_at = sys.argv[7]
git_branch = sys.argv[8] or "unknown"
git_commit = sys.argv[9] or "unknown"
git_status = sys.argv[10] or "unknown"

schema_version = "toolbox_inventory_v0"

source_columns = [
    "path",
    "domain",
    "phase",
    "kind",
    "executable",
    "shebang",
    "has_set_u",
    "has_log_func",
    "has_fail_func",
    "uses_log",
    "uses_fail",
    "sources_lib",
    "mentions_report",
    "mentions_tsv",
    "mentions_snapshot",
    "mentions_log",
    "mentions_run_job",
    "mentions_pipeline",
    "mentions_nohup",
    "line_count",
    "description",
]

output_columns = [
    "inventory_schema_version",
    "timestamp",
    "domain",
    "subdomain",
    "entity_type",
    "entity_id",
    "path",
    "name",
    "category",
    "phase",
    "kind",
    "runtime",
    "automation_type",
    "executable",
    "status",
    "description",
    "notes",
    "shebang",
    "has_set_u",
    "has_log_func",
    "has_fail_func",
    "uses_log",
    "uses_fail",
    "sources_lib",
    "mentions_report",
    "mentions_tsv",
    "mentions_snapshot",
    "mentions_log",
    "mentions_run_job",
    "mentions_pipeline",
    "mentions_nohup",
    "line_count",
    "relation_hint_type",
    "related_entity_type",
    "related_entity_id",
    "related_path",
    "relation_basis",
    "relation_scope",
    "relation_direction",
    "relation_notes",
    "evidence_type",
    "confidence",
    "source_inventory",
    "source_report",
    "source_tsv",
    "generator_script",
    "repo_root",
    "git_branch",
    "git_commit",
    "git_status",
]

def value(row: dict[str, str], key: str) -> str:
    raw = row.get(key, "")
    raw = raw.strip()
    return raw if raw else "unknown"

def entity_type_for(path: str) -> str:
    if path.startswith("bin/"):
        return "command"
    if path.startswith("scripts/pipelines/"):
        return "pipeline"
    if path.startswith("scripts/lib/"):
        return "library_module"
    if path.startswith("scripts/helpers/"):
        return "helper"
    return "script"

def relation_hints(row: dict[str, str]) -> list[str]:
    hints: list[str] = []
    checks = [
        ("mentions_report", "script_may_generate_or_reference_report"),
        ("mentions_tsv", "script_may_generate_or_reference_tsv"),
        ("sources_lib", "script_may_use_library"),
        ("mentions_snapshot", "script_mentions_snapshot"),
        ("mentions_log", "script_mentions_log"),
        ("mentions_run_job", "script_mentions_run_job"),
        ("mentions_pipeline", "script_mentions_pipeline"),
        ("mentions_nohup", "script_mentions_nohup"),
    ]
    for column, hint in checks:
        if value(row, column).lower() == "yes":
            hints.append(hint)
    return hints or ["none"]

def mapped_row(row: dict[str, str]) -> dict[str, str]:
    path = value(row, "path")
    entity_type = entity_type_for(path)
    hints = relation_hints(row)
    has_hints = hints != ["none"]
    is_pipeline_path = path.startswith("scripts/pipelines/")

    automation_type = "run-job pipeline" if is_pipeline_path else "unknown"
    confidence = "medium" if is_pipeline_path else "high"

    return {
        "inventory_schema_version": schema_version,
        "timestamp": generated_at,
        "domain": "toolbox",
        "subdomain": value(row, "domain"),
        "entity_type": entity_type,
        "entity_id": f"{entity_type}:{path}",
        "path": path,
        "name": Path(path).name if path != "unknown" else "unknown",
        "category": value(row, "domain"),
        "phase": value(row, "phase"),
        "kind": value(row, "kind"),
        "runtime": "unknown",
        "automation_type": automation_type,
        "executable": value(row, "executable"),
        "status": "present",
        "description": value(row, "description"),
        "notes": "relation hints are non-authoritative" if has_hints else "unknown",
        "shebang": value(row, "shebang"),
        "has_set_u": value(row, "has_set_u"),
        "has_log_func": value(row, "has_log_func"),
        "has_fail_func": value(row, "has_fail_func"),
        "uses_log": value(row, "uses_log"),
        "uses_fail": value(row, "uses_fail"),
        "sources_lib": value(row, "sources_lib"),
        "mentions_report": value(row, "mentions_report"),
        "mentions_tsv": value(row, "mentions_tsv"),
        "mentions_snapshot": value(row, "mentions_snapshot"),
        "mentions_log": value(row, "mentions_log"),
        "mentions_run_job": value(row, "mentions_run_job"),
        "mentions_pipeline": value(row, "mentions_pipeline"),
        "mentions_nohup": value(row, "mentions_nohup"),
        "line_count": value(row, "line_count"),
        "relation_hint_type": ";".join(hints),
        "related_entity_type": "unknown",
        "related_entity_id": "unknown",
        "related_path": "unknown",
        "relation_basis": "source_feature_flags" if has_hints else "unknown",
        "relation_scope": schema_version if has_hints else "unknown",
        "relation_direction": "unknown",
        "relation_notes": "hints only; not graph edges" if has_hints else "unknown",
        "evidence_type": "generated",
        "confidence": confidence,
        "source_inventory": str(source_tsv),
        "source_report": source_report,
        "source_tsv": str(source_tsv),
        "generator_script": generator_script,
        "repo_root": repo_root,
        "git_branch": git_branch,
        "git_commit": git_commit,
        "git_status": git_status,
    }

with source_tsv.open("r", encoding="utf-8", newline="") as source_file:
    reader = csv.DictReader(source_file, delimiter="\t")
    missing = [column for column in source_columns if column not in (reader.fieldnames or [])]
    if missing:
        print(f"[ERRO] Source TSV missing required columns: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    rows = [mapped_row(row) for row in reader]

validation_errors: list[str] = []
for index, row in enumerate(rows, start=2):
    if row["path"] == "unknown":
        validation_errors.append(f"source line {index}: path is empty")
    if row["entity_id"] != f"{row['entity_type']}:{row['path']}":
        validation_errors.append(f"source line {index}: entity_id rule mismatch")
    if row["status"] != "present":
        validation_errors.append(f"source line {index}: status is not present")
    if row["evidence_type"] != "generated":
        validation_errors.append(f"source line {index}: evidence_type is not generated")
    if row["confidence"] not in {"high", "medium", "low"}:
        validation_errors.append(f"source line {index}: invalid confidence")
    if row["git_status"] not in {"clean", "dirty", "unknown"}:
        validation_errors.append(f"source line {index}: invalid git_status")

if validation_errors:
    for error in validation_errors:
        print(f"[ERRO] {error}", file=sys.stderr)
    sys.exit(1)

with out_tsv.open("w", encoding="utf-8", newline="") as inventory_file:
    writer = csv.DictWriter(inventory_file, fieldnames=output_columns, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)

entity_counts = Counter(row["entity_type"] for row in rows)
subdomain_counts = Counter(row["subdomain"] for row in rows)
hint_rows = sum(1 for row in rows if row["relation_hint_type"] != "none")
runtime_unknown = sum(1 for row in rows if row["runtime"] == "unknown")
automation_unknown = sum(1 for row in rows if row["automation_type"] == "unknown")

with out_report.open("w", encoding="utf-8") as report_file:
    report_file.write("# Toolbox inventory report\n\n")
    report_file.write(f"Generated at: {generated_at}\n")
    report_file.write(f"Inventory schema version: {schema_version}\n")
    report_file.write(f"Generator script: {generator_script}\n")
    report_file.write(f"Repo root: {repo_root}\n")
    report_file.write(f"Git branch: {git_branch}\n")
    report_file.write(f"Git commit: {git_commit}\n")
    report_file.write(f"Git status: {git_status}\n")
    report_file.write(f"Source TSV: {source_tsv}\n")
    report_file.write(f"Source report: {source_report}\n")
    report_file.write(f"Output TSV: {out_tsv}\n")
    report_file.write(f"Output report: {out_report}\n\n")

    report_file.write("## Purpose\n\n")
    report_file.write("Generate toolbox_inventory_v0 from the existing Toolbox script inventory TSV.\n\n")

    report_file.write("## Summary\n\n")
    report_file.write(f"Total inventory rows: {len(rows)}\n")
    report_file.write(f"Rows with relation hints: {hint_rows}\n")
    report_file.write(f"Rows with runtime=unknown: {runtime_unknown}\n")
    report_file.write(f"Rows with automation_type=unknown: {automation_unknown}\n\n")

    report_file.write("## Counts by entity type\n\n")
    for key in sorted(entity_counts):
        report_file.write(f"- {key}: {entity_counts[key]}\n")
    report_file.write("\n")

    report_file.write("## Counts by source subdomain\n\n")
    for key in sorted(subdomain_counts):
        report_file.write(f"- {key}: {subdomain_counts[key]}\n")
    report_file.write("\n")

    report_file.write("## Validation summary\n\n")
    report_file.write("- Source TSV exists and was readable: yes\n")
    report_file.write("- Source TSV required columns present: yes\n")
    report_file.write("- Output TSV written: yes\n")
    report_file.write("- Output report written: yes\n")
    report_file.write("- Row validation errors: 0\n\n")

    report_file.write("## Notes\n\n")
    report_file.write("- Relation hints are non-authoritative and are not graph edges.\n")
    report_file.write("- Reports and TSVs remain evidence fields in toolbox_inventory_v0.\n")
    report_file.write("- Source inventory may be stale relative to current repository state.\n")
    report_file.write("- Dirty Git status is recorded but is not a generator failure.\n")

print(f"Inventory TSV: {out_tsv}")
print(f"Inventory report: {out_report}")
PY
}

main() {
  local source_tsv
  local source_report
  local git_branch
  local git_commit
  local git_status

  require_lib_contract

  if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
  fi

  if [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  if [ "$#" -eq 1 ]; then
    source_tsv="$1"
  else
    source_tsv="$(latest_source_tsv)"
  fi

  if [ -z "$source_tsv" ]; then
    fail "No source TSV found under $SOURCE_DIR"
  fi

  if [ ! -r "$source_tsv" ]; then
    fail "Source TSV is not readable: $source_tsv"
  fi

  source_report="$(infer_source_report "$source_tsv")"
  git_branch="$(git_branch_value)"
  git_commit="$(git_commit_value)"
  git_status="$(git_status_value)"

  ensure_output_dirs
  run_transform "$source_tsv" "$source_report" "$git_branch" "$git_commit" "$git_status"
}

main "$@"
