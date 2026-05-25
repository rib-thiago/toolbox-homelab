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
OUT_TSV="$RAW_DIR/stockhausen_performer_fix_repair_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_performer_fix_repair_report_1977-95_$STAMP.txt"

[[ -f "$PLAN_TSV" ]] || fail "Plano performer fix não encontrado."
[[ -d "$ROOT" ]] || fail "Root não encontrado."
command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$PLAN_TSV" "$ROOT" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import subprocess
import sys
from pathlib import Path

plan = Path(sys.argv[1])
root = Path(sys.argv[2])
out_tsv = Path(sys.argv[3])
report = Path(sys.argv[4])

rows = []

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

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        album_dir = row["album_dir"]
        rel = row["proposed_filename"]
        performer = row["proposed_performer"]
        path = root / album_dir / rel

        if not path.exists():
            rows.append([album_dir, rel, performer, "", "ERROR", "missing file"])
            continue

        old = get_tag(path, "PERFORMER")

        subprocess.run(
            ["metaflac", "--remove-tag=PERFORMER", f"--set-tag=PERFORMER={performer}", str(path)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        rows.append([album_dir, rel, performer, old, "OK", ""])

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(["album_dir", "relative_path", "new_performer", "old_performer", "status", "detail"])
    writer.writerows(rows)

ok = sum(1 for r in rows if r[4] == "OK")
err = sum(1 for r in rows if r[4] == "ERROR")
performers = sorted({r[2] for r in rows if r[2]})

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen performer fix repair — 1977-95\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")
    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")
    f.write("Summary:\n")
    f.write(f"Rows repaired: {len(rows)}\n")
    f.write(f"OK: {ok}\n")
    f.write(f"ERROR: {err}\n\n")
    f.write("Performer values applied:\n")
    for p in performers:
        f.write(f"- {p}\n")

print(out_tsv)
print(report)
PY
