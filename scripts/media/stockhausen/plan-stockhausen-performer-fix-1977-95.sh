#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

PLAN_TSV="$(ls -t /srv/toolbox/shared/library-db/raw/stockhausen_batch_normalization_plan_1977-95_[0-9]*.tsv 2>/dev/null | head -1)"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_performer_fix_plan_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_performer_fix_plan_1977-95_$STAMP.txt"

[[ -f "$PLAN_TSV" ]] || fail "Plano completo 1977-95 não encontrado."

python3 - "$PLAN_TSV" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import sys
from pathlib import Path

plan = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

target_albums = {
    "027 Stockhausen - In Freundschaft, Traum-Formel, Amour (1993) {Stockhausen-Verlag No. 27}",
    "028 Stockhausen - Musik für Flöte (1992) {2CD Set Stockhausen-Verlag No. 28}",
    "032 Stockhausen - Musik für Klarinette, Baßklarinette, Bassetthorn (1994) {3CD Set Stockhausen-Verlag No. 32}",
    "033 Stockhausen - Aries & Klavierstuck XIII (1994) {Stockhausen-Verlag No. 33}",
}

def split_people(value: str) -> list[str]:
    if not value:
        return []

    normalized = (
        value
        .replace(";", "|")
        .replace(",", "|")
    )

    parts = []

    for chunk in normalized.split("|"):
        clean = chunk.strip()

        if not clean:
            continue

        parts.append(clean)

    return parts

def performer_from_fields(albumartist: str, artist: str, current_performer: str) -> str:
    existing = split_people(current_performer)
    candidates = split_people(albumartist) + split_people(artist)

    result = []
    seen = set()

    for name in existing + candidates:
        clean = name.strip()
        if not clean:
            continue
        if clean == "Karlheinz Stockhausen":
            continue
        if clean not in seen:
            result.append(clean)
            seen.add(clean)

    return ";".join(result)

rows = []

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        if row.get("album_dir") not in target_albums:
            continue

        proposed_performer = performer_from_fields(
            row.get("current_albumartist", ""),
            row.get("current_artist", ""),
            row.get("current_performer", ""),
        )

        rows.append({
            "album_dir": row["album_dir"],
            "relative_path": row["relative_path"],
            "proposed_filename": row["proposed_filename"],
            "current_albumartist": row.get("current_albumartist", ""),
            "proposed_albumartist": "Karlheinz Stockhausen",
            "current_artist": row.get("current_artist", ""),
            "proposed_artist": "Karlheinz Stockhausen",
            "current_composer": row.get("current_composer", ""),
            "proposed_composer": "Karlheinz Stockhausen",
            "current_grouping": row.get("current_grouping", ""),
            "proposed_grouping": "1977-95: Licht pt. 1",
            "current_performer": row.get("current_performer", ""),
            "proposed_performer": proposed_performer,
            "mb_albumid": row.get("mb_albumid", ""),
            "mb_trackid": row.get("mb_trackid", ""),
            "confidence": "HIGH",
            "flags": "",
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
performer_values = sorted({r["proposed_performer"] for r in rows if r["proposed_performer"]})

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen performer fix plan — 1977-95\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")
    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")
    f.write("Summary:\n")
    f.write(f"Albums targeted: {len(albums)}\n")
    f.write(f"Tracks planned: {len(rows)}\n")
    f.write(f"Distinct proposed performer values: {len(performer_values)}\n\n")

    f.write("Albums:\n")
    for album in albums:
        f.write(f"- {album}\n")

    f.write("\nProposed performer values:\n")
    for performer in performer_values[:80]:
        f.write(f"- {performer}\n")

    f.write("\nNotes:\n")
    f.write("- This script does not modify files.\n")
    f.write("- It targets only 027, 028, 032, 033.\n")
    f.write("- It preserves MBIDs.\n")
    f.write("- It proposes moving non-Stockhausen artists into PERFORMER.\n")

print(out_tsv)
print(report)
PY
