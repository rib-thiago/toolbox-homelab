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

OUT_TSV="$RAW_DIR/stockhausen_medium_albums_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_medium_albums_1977-95_report_$STAMP.txt"

[[ -f "$PLAN_TSV" ]] || fail "Plano 1977-95 não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$PLAN_TSV" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import sys
from collections import defaultdict
from pathlib import Path

plan = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

albums = {}

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        if row.get("confidence") != "MEDIUM":
            continue

        album = row["album_dir"]

        if album not in albums:
            albums[album] = {
                "track_count": 0,
                "missing_mbid_tracks": 0,
                "performer_candidate_tracks": 0,
                "current_albumartists": set(),
                "current_artists": set(),
                "current_composers": set(),
                "current_groupings": set(),
                "sample_titles": [],
            }

        item = albums[album]
        flags = row.get("flags", "")

        item["track_count"] += 1

        if "MISSING_MBID" in flags:
            item["missing_mbid_tracks"] += 1

        if "PERFORMER_CANDIDATE_FROM_ARTIST_FIELDS" in flags:
            item["performer_candidate_tracks"] += 1

        for key, col in [
            ("current_albumartists", "current_albumartist"),
            ("current_artists", "current_artist"),
            ("current_composers", "current_composer"),
            ("current_groupings", "current_grouping"),
        ]:
            value = row.get(col, "")
            if value:
                item[key].add(value)

        if len(item["sample_titles"]) < 5:
            item["sample_titles"].append(row.get("title", ""))

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow([
        "album_dir",
        "track_count",
        "missing_mbid_tracks",
        "performer_candidate_tracks",
        "current_albumartists",
        "current_artists",
        "current_composers",
        "current_groupings",
        "sample_titles",
    ])

    for album in sorted(albums):
        item = albums[album]
        writer.writerow([
            album,
            item["track_count"],
            item["missing_mbid_tracks"],
            item["performer_candidate_tracks"],
            " | ".join(sorted(item["current_albumartists"])),
            " | ".join(sorted(item["current_artists"])),
            " | ".join(sorted(item["current_composers"])),
            " | ".join(sorted(item["current_groupings"])),
            " | ".join(item["sample_titles"]),
        ])

medium_tracks = sum(item["track_count"] for item in albums.values())
missing_mbids = sum(item["missing_mbid_tracks"] for item in albums.values())
performer_candidates = sum(item["performer_candidate_tracks"] for item in albums.values())

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen MEDIUM albums analysis — 1977-95\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")
    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")
    f.write("Summary:\n")
    f.write(f"MEDIUM albums: {len(albums)}\n")
    f.write(f"MEDIUM tracks: {medium_tracks}\n")
    f.write(f"Tracks missing MBID: {missing_mbids}\n")
    f.write(f"Performer candidate tracks: {performer_candidates}\n\n")
    f.write("Albums:\n")

    for album in sorted(albums):
        item = albums[album]
        f.write("\n")
        f.write(f"- {album}\n")
        f.write(f"  tracks: {item['track_count']}\n")
        f.write(f"  missing_mbid_tracks: {item['missing_mbid_tracks']}\n")
        f.write(f"  performer_candidate_tracks: {item['performer_candidate_tracks']}\n")
        f.write(f"  current_albumartists: {' | '.join(sorted(item['current_albumartists']))}\n")
        f.write(f"  current_artists: {' | '.join(sorted(item['current_artists']))}\n")
        f.write(f"  current_composers: {' | '.join(sorted(item['current_composers']))}\n")
        f.write(f"  current_groupings: {' | '.join(sorted(item['current_groupings']))}\n")
        f.write(f"  sample_titles: {' | '.join(item['sample_titles'])}\n")

    f.write("\nInterpretation:\n")
    f.write("- This script does not modify files.\n")
    f.write("- MEDIUM rows are isolated from the 1977-95 planner.\n")
    f.write("- These albums should not be batch-applied until MBID/performer strategy is decided.\n")
    f.write("- Next step: reconcile against PDF / Stockhausen-Verlag catalog / MusicBrainz.\n")

print(out_tsv)
print(report)
PY
