#!/usr/bin/env bash
set -euo pipefail

ROOT="/srv/media/music-staging/incoming/050 Stockhausen - Freitag aus Licht"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"

TS="$(date +%Y%m%d-%H%M%S)"

TSV="$RAW_DIR/stockhausen_import_050_split_inventory_${TS}.tsv"
REPORT="$REPORT_DIR/stockhausen_import_050_split_inventory_report_${TS}.txt"

mkdir -p "$RAW_DIR"
mkdir -p "$REPORT_DIR"

python3 - "$ROOT" "$TSV" "$REPORT" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path
from datetime import datetime

root = Path(sys.argv[1])
tsv_path = Path(sys.argv[2])
report_path = Path(sys.argv[3])

rows = []

for flac in sorted(root.glob("split/**/*.flac")):
    rel = flac.relative_to(root)

    disc = rel.parts[1]

    duration = ""

    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                str(flac)
            ],
            capture_output=True,
            text=True,
            check=True
        )

        seconds = float(result.stdout.strip())

        m = int(seconds // 60)
        s = int(seconds % 60)

        duration = f"{m:02d}:{s:02d}"

    except Exception:
        duration = "ERROR"

    rows.append({
        "disc": disc,
        "file": flac.name,
        "duration": duration,
        "path": str(rel)
    })

with open(tsv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=["disc", "file", "duration", "path"],
        delimiter="\t"
    )

    writer.writeheader()

    for row in rows:
        writer.writerow(row)

disc_counts = {}

for row in rows:
    disc_counts.setdefault(row["disc"], 0)
    disc_counts[row["disc"]] += 1

with open(report_path, "w", encoding="utf-8") as f:
    f.write("Stockhausen import 050 split inventory\n")
    f.write(f"Generated: {datetime.now().isoformat()}\n\n")

    f.write(f"Root:\n{root}\n\n")

    f.write("Outputs:\n")
    f.write(f"{tsv_path}\n")
    f.write(f"{report_path}\n\n")

    f.write("Disc summary:\n")

    for disc in sorted(disc_counts):
        f.write(f"- {disc}: {disc_counts[disc]} tracks\n")

    f.write(f"\nTotal tracks: {len(rows)}\n")

print(tsv_path)
print(report_path)
PY

echo
echo "Generated:"
echo "$TSV"
echo "$REPORT"
