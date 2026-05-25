#!/usr/bin/env bash
set -euo pipefail

ROOT="/srv/media/music/Karlheinz Stockhausen"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_navidrome_album_count_diagnosis_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_navidrome_album_count_diagnosis_$STAMP.txt"

python3 - "$ROOT" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import subprocess
import sys
from pathlib import Path
from collections import defaultdict

root = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

def tag(path, name):
    r = subprocess.run(
        ["metaflac", f"--show-tag={name}", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    vals = []
    prefix = f"{name}="
    for line in r.stdout.splitlines():
        if line.startswith(prefix):
            vals.append(line[len(prefix):])
    return ";".join(vals)

album_dirs = sorted(p for p in root.glob("*/*") if p.is_dir())
rows = []

for d in album_dirs:
    flacs = sorted(d.rglob("*.flac"))
    if not flacs:
        continue

    sample = flacs[0]
    rows.append({
        "album_dir": str(d.relative_to(root)),
        "file_count": len(flacs),
        "albumartist": tag(sample, "ALBUMARTIST"),
        "album": tag(sample, "ALBUM"),
        "grouping": tag(sample, "GROUPING"),
        "sample_file": str(sample.relative_to(root)),
    })

pairs = defaultdict(list)
albums = defaultdict(list)

for r in rows:
    pairs[(r["albumartist"], r["album"])].append(r["album_dir"])
    albums[r["album"]].append(r["album_dir"])

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, delimiter="\t", fieldnames=rows[0].keys())
    w.writeheader()
    w.writerows(rows)

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen Navidrome album count diagnosis\n\n")
    f.write(f"Album directories with FLAC: {len(rows)}\n")
    f.write(f"Distinct ALBUM tags: {len(albums)}\n")
    f.write(f"Distinct ALBUMARTIST+ALBUM pairs: {len(pairs)}\n\n")

    f.write("Duplicate ALBUMARTIST+ALBUM pairs:\n")
    for (aa, al), dirs in sorted(pairs.items()):
        if len(dirs) > 1:
            f.write(f"\nALBUMARTIST={aa}\nALBUM={al}\n")
            for d in dirs:
                f.write(f"- {d}\n")

    f.write("\nDuplicate ALBUM tags regardless of albumartist:\n")
    for al, dirs in sorted(albums.items()):
        if len(dirs) > 1:
            f.write(f"\nALBUM={al}\n")
            for d in dirs:
                f.write(f"- {d}\n")

print(out_tsv)
print(report)
PY
