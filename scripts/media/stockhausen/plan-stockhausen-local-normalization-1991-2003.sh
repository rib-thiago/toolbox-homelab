#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

PLAN_TSV="$(ls -t /srv/toolbox/shared/library-db/raw/stockhausen_batch_normalization_plan_1991-2003_*.tsv 2>/dev/null | head -1)"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_local_normalization_plan_1991-2003_LOCAL_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_local_normalization_plan_1991-2003_LOCAL_$STAMP.txt"

[[ -f "$PLAN_TSV" ]] || fail "Plano completo 1977-95 não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$PLAN_TSV" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import sys
from pathlib import Path

plan = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

target_prefixes = tuple(f"{i:03d}" for i in range(48, 67))

rows = []

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        album = row["album_dir"]

        if not album.startswith(target_prefixes):
            continue

        rows.append({
            "album_dir": album,
            "relative_path": row["relative_path"],
            "proposed_filename": row["proposed_filename"],
            "current_albumartist": row.get("current_albumartist", ""),
            "proposed_albumartist": "Karlheinz Stockhausen",
            "current_artist": row.get("current_artist", ""),
            "proposed_artist": "Karlheinz Stockhausen",
            "current_composer": row.get("current_composer", ""),
            "proposed_composer": "Karlheinz Stockhausen",
            "current_grouping": row.get("current_grouping", ""),
            "proposed_grouping": "1991-2003: Licht pt. 2",
            "current_performer": row.get("current_performer", ""),
            "proposed_performer": row.get("current_performer", ""),
            "mb_albumid": row.get("mb_albumid", ""),
            "mb_trackid": row.get("mb_trackid", ""),
            "confidence": "LOCAL_HIGH",
            "flags": "NO_MBID_LOCAL_POLICY;PERFORMER_DEFERRED",
        })

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "album_dir",
        "relative_path",
        "proposed_filename",
        "current_albumartist",
        "proposed_albumartist",
        "current_artist",
        "proposed_artist",
        "current_composer",
        "proposed_composer",
        "current_grouping",
        "proposed_grouping",
        "current_performer",
        "proposed_performer",
        "mb_albumid",
        "mb_trackid",
        "confidence",
        "flags",
    ]

    writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

albums = sorted({r["album_dir"] for r in rows})

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen local normalization plan — 1977-95 MEDIUM / 039-047\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")
    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")
    f.write("Policy:\n")
    f.write("ALBUMARTIST=Karlheinz Stockhausen\n")
    f.write("ARTIST=Karlheinz Stockhausen\n")
    f.write("COMPOSER=Karlheinz Stockhausen\n")
    f.write("GROUPING=1991-2003: Licht pt. 2\n")
    f.write("PERFORMER deferred\n")
    f.write("MBID deferred\n\n")
    f.write("Summary:\n")
    f.write(f"Albums targeted: {len(albums)}\n")
    f.write(f"Tracks planned: {len(rows)}\n")
    f.write("Confidence: LOCAL_HIGH\n")
    f.write("Flags: NO_MBID_LOCAL_POLICY;PERFORMER_DEFERRED\n\n")

    f.write("Albums:\n")
    for album in albums:
        count = sum(1 for r in rows if r["album_dir"] == album)
        f.write(f"- {album} ({count} tracks)\n")

    f.write("\nNotes:\n")
    f.write("- This script does not modify files.\n")
    f.write("- It intentionally does not invent MBIDs.\n")
    f.write("- It intentionally defers performer enrichment.\n")
    f.write("- It prepares local structural normalization only.\n")

print(out_tsv)
print(report)
PY
