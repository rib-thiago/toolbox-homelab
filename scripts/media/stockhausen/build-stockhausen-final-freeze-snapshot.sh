#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"
REPORT_DIR="/srv/toolbox/shared/reports/media"

STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$SNAPSHOT_DIR/stockhausen_final_freeze_snapshot_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_final_freeze_snapshot_report_$STAMP.txt"

[[ -d "$ROOT" ]] || fail "Root não encontrado."

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$ROOT" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import hashlib
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

def get_tag(path: Path, tag: str) -> str:
    result = subprocess.run(
        ["metaflac", f"--show-tag={tag}", str(path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    values = []

    prefix = f"{tag}="

    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            values.append(line[len(prefix):])

    return ";".join(values)

def sha256(path: Path) -> str:
    h = hashlib.sha256()

    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)

    return h.hexdigest()

rows = []

flacs = sorted(root.rglob("*.flac"))

for path in flacs:
    rel = path.relative_to(root)

    rows.append({
        "relative_path": str(rel),
        "size_bytes": path.stat().st_size,
        "sha256": sha256(path),
        "albumartist": get_tag(path, "ALBUMARTIST"),
        "artist": get_tag(path, "ARTIST"),
        "composer": get_tag(path, "COMPOSER"),
        "grouping": get_tag(path, "GROUPING"),
        "album": get_tag(path, "ALBUM"),
        "title": get_tag(path, "TITLE"),
        "tracknumber": get_tag(path, "TRACKNUMBER"),
        "date": get_tag(path, "DATE"),
        "performer": get_tag(path, "PERFORMER"),
        "mb_albumid": get_tag(path, "MUSICBRAINZ_ALBUMID"),
        "mb_trackid": get_tag(path, "MUSICBRAINZ_TRACKID"),
    })

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "relative_path",
        "size_bytes",
        "sha256",
        "albumartist",
        "artist",
        "composer",
        "grouping",
        "album",
        "title",
        "tracknumber",
        "date",
        "performer",
        "mb_albumid",
        "mb_trackid",
    ]

    writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

groupings = sorted({r["grouping"] for r in rows if r["grouping"]})

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen final freeze snapshot\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Root:\n")
    f.write(str(root) + "\n\n")

    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")

    f.write("Summary:\n")
    f.write(f"FLAC files: {len(rows)}\n")
    f.write(f"Distinct groupings: {len(groupings)}\n\n")

    f.write("Groupings:\n")
    for g in groupings:
        count = sum(1 for r in rows if r["grouping"] == g)
        f.write(f"- {g}: {count} tracks\n")

    missing_grouping = sum(1 for r in rows if not r["grouping"])
    missing_title = sum(1 for r in rows if not r["title"])
    split_tracks = sum(
        1 for r in rows
        if "split-track" in r["relative_path"]
    )

    f.write("\nIntegrity checks:\n")
    f.write(f"Missing grouping: {missing_grouping}\n")
    f.write(f"Missing title: {missing_title}\n")
    f.write(f"Residual split-track files: {split_tracks}\n")

    f.write("\nNotes:\n")
    f.write("- This is a structural freeze snapshot.\n")
    f.write("- Intended for rollback, auditing and future enrichment.\n")
    f.write("- SHA256 hashes included.\n")
    f.write("- MBID/PERFORMER may still be partially incomplete by policy.\n")

print(out_tsv)
print(report)
PY
