#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen/1977-95: Licht pt. 1"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$(ls -t "$RAW_DIR"/stockhausen_performer_fix_plan_1977-95_*.tsv 2>/dev/null | head -1)"
VALIDATION_TSV="$RAW_DIR/stockhausen_performer_fix_validation_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_performer_fix_validation_report_1977-95_$STAMP.txt"

[[ -f "$PLAN_TSV" ]] || fail "Plano performer fix não encontrado."
[[ -d "$ROOT" ]] || fail "Root não encontrado: $ROOT"
command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$PLAN_TSV" "$ROOT" "$VALIDATION_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import subprocess
import sys
from pathlib import Path

plan = Path(sys.argv[1])
root = Path(sys.argv[2])
validation_tsv = Path(sys.argv[3])
report = Path(sys.argv[4])

def get_tag(path: Path, tag: str) -> str:
    result = subprocess.run(
        ["metaflac", f"--show-tag={tag}", str(path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    values = []
    for line in result.stdout.splitlines():
        prefix = f"{tag}="
        if line.startswith(prefix):
            values.append(line[len(prefix):])
    return ";".join(values)

rows = []

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        album_dir = row["album_dir"]
        rel = row["proposed_filename"]
        path = root / album_dir / rel

        expected_performer = row.get("proposed_performer", "")
        expected_albumartist = row.get("proposed_albumartist", "Karlheinz Stockhausen")
        expected_artist = row.get("proposed_artist", "Karlheinz Stockhausen")
        expected_composer = row.get("proposed_composer", "Karlheinz Stockhausen")
        expected_grouping = row.get("proposed_grouping", "1977-95: Licht pt. 1")

        file_exists = path.exists()

        actual_performer = ""
        actual_albumartist = ""
        actual_artist = ""
        actual_composer = ""
        actual_grouping = ""

        if file_exists:
            actual_performer = get_tag(path, "PERFORMER")
            actual_albumartist = get_tag(path, "ALBUMARTIST")
            actual_artist = get_tag(path, "ARTIST")
            actual_composer = get_tag(path, "COMPOSER")
            actual_grouping = get_tag(path, "GROUPING")

        flags = []

        if not file_exists:
            flags.append("MISSING_FILE")
        if actual_performer != expected_performer:
            flags.append("BAD_PERFORMER")
        if actual_albumartist != expected_albumartist:
            flags.append("BAD_ALBUMARTIST")
        if actual_artist != expected_artist:
            flags.append("BAD_ARTIST")
        if actual_composer != expected_composer:
            flags.append("BAD_COMPOSER")
        if actual_grouping != expected_grouping:
            flags.append("BAD_GROUPING")

        status = "OK" if not flags else "ERROR"

        rows.append({
            "album_dir": album_dir,
            "relative_path": rel,
            "file_exists": "yes" if file_exists else "no",
            "expected_performer": expected_performer,
            "actual_performer": actual_performer,
            "albumartist_ok": "yes" if actual_albumartist == expected_albumartist else "no",
            "artist_ok": "yes" if actual_artist == expected_artist else "no",
            "composer_ok": "yes" if actual_composer == expected_composer else "no",
            "grouping_ok": "yes" if actual_grouping == expected_grouping else "no",
            "status": status,
            "flags": ";".join(flags),
        })

with validation_tsv.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "album_dir",
        "relative_path",
        "file_exists",
        "expected_performer",
        "actual_performer",
        "albumartist_ok",
        "artist_ok",
        "composer_ok",
        "grouping_ok",
        "status",
        "flags",
    ]
    writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

ok = sum(1 for r in rows if r["status"] == "OK")
err = sum(1 for r in rows if r["status"] == "ERROR")
performers = sorted({r["actual_performer"] for r in rows if r["actual_performer"]})

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen performer fix validation — 1977-95\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")
    f.write("Output:\n")
    f.write(str(validation_tsv) + "\n\n")
    f.write("Summary:\n")
    f.write(f"Rows validated: {len(rows)}\n")
    f.write(f"OK: {ok}\n")
    f.write(f"ERROR: {err}\n\n")
    f.write("Actual performer values:\n")
    for p in performers:
        f.write(f"- {p}\n")

    f.write("\nFailure samples:\n")
    for r in rows:
        if r["status"] != "OK":
            f.write(f"- {r['album_dir']} :: {r['relative_path']} :: {r['flags']} :: expected=[{r['expected_performer']}] actual=[{r['actual_performer']}]\n")

print(validation_tsv)
print(report)
PY
