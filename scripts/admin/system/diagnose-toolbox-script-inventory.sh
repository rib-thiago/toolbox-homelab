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

REPORT="$REPORT_DIR/toolbox_script_inventory_report_$STAMP.txt"
TSV="$RAW_DIR/toolbox_script_inventory_$STAMP.tsv"

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

write_header() {
  {
    printf '# Toolbox script inventory\n\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'App dir: %s\n' "$APP_DIR"
    printf 'Shared dir: %s\n' "$SHARED_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n\n' "$TSV"
    printf '## Purpose\n\n'
    printf 'This read-only diagnostic inventories Toolbox scripts, helpers, libraries, pipelines, and public commands.\n\n'
    printf 'It does not execute apply workflows, change files, change permissions, modify Git state, or inspect service state.\n\n'
  } > "$REPORT"
}

run_inventory() {
  python3 - "$APP_DIR" "$TSV" "$REPORT" <<'PY'
from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
import os
import re
import sys

app = Path(sys.argv[1])
tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

scan_roots = [
    app / "bin",
    app / "scripts",
]

phase_prefixes = [
    "diagnose",
    "plan",
    "apply",
    "validate",
    "analyze",
    "build",
    "extract",
    "import",
    "repair",
    "resume",
    "check",
    "list",
    "run",
    "sync",
    "convert",
    "ocr",
    "translate",
]

skip_suffixes = {
    ".pyc",
    ".pyo",
    ".swp",
    ".tmp",
    ".bak",
}

skip_parts = {
    "__pycache__",
    ".git",
}

def tsv_escape(value: object) -> str:
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")

def relpath(path: Path) -> str:
    return str(path.relative_to(app))

def is_skipped(path: Path) -> bool:
    if any(part in skip_parts for part in path.parts):
        return True
    if path.suffix in skip_suffixes:
        return True
    return False

def classify_kind(path: Path, text: str) -> str:
    first = text.splitlines()[0] if text.splitlines() else ""
    if first.startswith("#!") and "bash" in first:
        return "shell"
    if first.startswith("#!") and "sh" in first:
        return "shell"
    if first.startswith("#!") and "python" in first:
        return "python"
    if path.suffix == ".sh":
        return "shell"
    if path.suffix == ".py":
        return "python"
    if path.suffix in {".md", ".markdown"}:
        return "markdown"
    if path.parent.name == "bin":
        return "command"
    return "other"

def classify_domain(path: Path) -> str:
    parts = path.relative_to(app).parts

    if not parts:
        return "unknown"

    if parts[0] == "bin":
        return "bin"

    if len(parts) >= 3 and parts[0] == "scripts":
        if parts[1] in {"admin", "media"}:
            return "/".join(parts[:3])
        if parts[1] in {"lib", "helpers", "pipelines"}:
            return "/".join(parts[:2])

    if len(parts) >= 2 and parts[0] == "scripts":
        return "/".join(parts[:2])

    return parts[0]

def classify_phase(path: Path) -> str:
    name = path.name

    for prefix in phase_prefixes:
        if name == prefix or name.startswith(prefix + "-") or name.startswith(prefix + "_"):
            return prefix

    if "diagnose" in name:
        return "diagnose"
    if "validate" in name:
        return "validate"
    if "apply" in name:
        return "apply"
    if "plan" in name:
        return "plan"

    return "other"

def first_description(text: str) -> str:
    lines = text.splitlines()

    for line in lines[:40]:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#!"):
            continue
        if stripped.startswith("#"):
            desc = stripped.lstrip("#").strip()
            if desc:
                return desc[:180]

    return ""

def read_text(path: Path) -> str:
    try:
        return path.read_text(errors="replace")
    except Exception:
        return ""

def detect_features(path: Path, text: str) -> dict[str, str]:
    executable = "yes" if os.access(path, os.X_OK) else "no"
    lines = text.splitlines()
    shebang = lines[0] if lines and lines[0].startswith("#!") else ""

    has_set_u = "yes" if re.search(r"(^|\n)\s*set\s+[^#\n]*\bu\b", text) else "no"
    has_log_func = "yes" if re.search(r"(^|\n)\s*log\(\)\s*\{", text) else "no"
    has_fail_func = "yes" if re.search(r"(^|\n)\s*fail\(\)\s*\{", text) else "no"
    uses_log = "yes" if re.search(r"(^|\n)\s*log\s+['\"]?", text) or has_log_func == "yes" else "no"
    uses_fail = "yes" if re.search(r"(^|\n)\s*fail\s+['\"]?", text) or has_fail_func == "yes" else "no"

    sources_lib = "yes" if (
        "scripts/lib" in text
        or "LIB_DIR=" in text
        or re.search(r"(^|\n)\s*source\s+.*logging\.sh", text)
        or re.search(r"(^|\n)\s*source\s+.*timestamps\.sh", text)
        or re.search(r"(^|\n)\s*source\s+.*paths\.sh", text)
    ) else "no"

    mentions_report = "yes" if re.search(r"\bREPORT\b|reports/", text) else "no"
    mentions_tsv = "yes" if re.search(r"\bTSV\b|\.tsv|library-db/raw", text, re.IGNORECASE) else "no"
    mentions_snapshot = "yes" if "snapshot" in text.lower() or "snapshots/" in text else "no"
    mentions_log = "yes" if re.search(r"\bLOG\b|logs/|nohup|tail -f|nflog|tblive", text) else "no"
    mentions_run_job = "yes" if "run-job" in text or "run_job" in text or "/toolbox/jobs" in text or "/srv/toolbox/jobs" in text else "no"
    mentions_pipeline = "yes" if "scripts/pipelines" in text or "pipeline" in text.lower() else "no"
    mentions_nohup = "yes" if "nohup" in text or "nf " in text or "nflog" in text or "tblive" in text else "no"

    return {
        "executable": executable,
        "shebang": shebang,
        "has_set_u": has_set_u,
        "has_log_func": has_log_func,
        "has_fail_func": has_fail_func,
        "uses_log": uses_log,
        "uses_fail": uses_fail,
        "sources_lib": sources_lib,
        "mentions_report": mentions_report,
        "mentions_tsv": mentions_tsv,
        "mentions_snapshot": mentions_snapshot,
        "mentions_log": mentions_log,
        "mentions_run_job": mentions_run_job,
        "mentions_pipeline": mentions_pipeline,
        "mentions_nohup": mentions_nohup,
    }

rows: list[dict[str, object]] = []

for root in scan_roots:
    if not root.exists():
        continue

    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if is_skipped(path):
            continue

        text = read_text(path)
        kind = classify_kind(path, text)
        features = detect_features(path, text)

        row = {
            "path": relpath(path),
            "domain": classify_domain(path),
            "phase": classify_phase(path),
            "kind": kind,
            "line_count": len(text.splitlines()),
            "description": first_description(text),
        }
        row.update(features)
        rows.append(row)

columns = [
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

with tsv.open("w", encoding="utf-8") as fh:
    fh.write("\t".join(columns) + "\n")
    for row in rows:
        fh.write("\t".join(tsv_escape(row.get(col, "")) for col in columns) + "\n")

by_domain = Counter(str(row["domain"]) for row in rows)
by_phase = Counter(str(row["phase"]) for row in rows)
by_kind = Counter(str(row["kind"]) for row in rows)

shell_rows = [row for row in rows if row["kind"] == "shell"]
shell_without_set_u = [row for row in shell_rows if row["has_set_u"] == "no"]
shell_without_evidence = [
    row for row in shell_rows
    if row["mentions_report"] == "no" and row["mentions_tsv"] == "no"
]
run_job_rows = [row for row in rows if row["mentions_run_job"] == "yes"]
pipeline_rows = [row for row in rows if row["domain"] == "scripts/pipelines" or row["mentions_pipeline"] == "yes"]

with report.open("a", encoding="utf-8") as fh:
    fh.write("## Summary\n\n")
    fh.write(f"Total inventory rows: {len(rows)}\n")
    fh.write(f"Shell scripts: {len(shell_rows)}\n")
    fh.write(f"Shell scripts without detected set -u: {len(shell_without_set_u)}\n")
    fh.write(f"Shell scripts without detected report/TSV references: {len(shell_without_evidence)}\n")
    fh.write(f"Rows mentioning run-job/job directories: {len(run_job_rows)}\n")
    fh.write(f"Rows related to pipelines: {len(pipeline_rows)}\n\n")

    fh.write("## Counts by domain\n\n")
    for domain, count in sorted(by_domain.items()):
        fh.write(f"- {domain}: {count}\n")
    fh.write("\n")

    fh.write("## Counts by phase\n\n")
    for phase, count in sorted(by_phase.items()):
        fh.write(f"- {phase}: {count}\n")
    fh.write("\n")

    fh.write("## Counts by kind\n\n")
    for kind, count in sorted(by_kind.items()):
        fh.write(f"- {kind}: {count}\n")
    fh.write("\n")

    fh.write("## Run-job and pipeline related rows\n\n")
    if run_job_rows or pipeline_rows:
        seen = set()
        for row in run_job_rows + pipeline_rows:
            p = str(row["path"])
            if p in seen:
                continue
            seen.add(p)
            fh.write(f"- {p}\n")
    else:
        fh.write("No run-job or pipeline references detected.\n")
    fh.write("\n")

    fh.write("## Shell scripts without detected set -u\n\n")
    if shell_without_set_u:
        for row in shell_without_set_u[:80]:
            fh.write(f"- {row['path']}\n")
        if len(shell_without_set_u) > 80:
            fh.write(f"- ... {len(shell_without_set_u) - 80} more\n")
    else:
        fh.write("No shell scripts without detected set -u.\n")
    fh.write("\n")

    fh.write("## Notes\n\n")
    fh.write("- This is a read-only inventory.\n")
    fh.write("- Missing feature detection is diagnostic, not automatically a failure.\n")
    fh.write("- Some scripts may intentionally omit reports, TSVs, or set -u depending on age or role.\n")
    fh.write("- Use the TSV for filtering and deeper review.\n")
PY
}

write_footer() {
  {
    printf '\n## Generated artifacts\n\n'
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
  } >> "$REPORT"
}

main() {
  require_lib_contract
  ensure_output_dirs
  write_header

  log "Starting Toolbox script inventory diagnosis."

  run_inventory
  write_footer

  log "Toolbox script inventory diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"

  return 0
}

main "$@"
