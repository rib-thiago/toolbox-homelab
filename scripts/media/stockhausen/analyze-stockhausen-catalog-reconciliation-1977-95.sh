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

OUT_TSV="$RAW_DIR/stockhausen_catalog_reconciliation_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_catalog_reconciliation_1977-95_report_$STAMP.txt"

[[ -d "$ROOT" ]] || fail "Root não encontrado."
command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$ROOT" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

root = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

targets = [f"{i:03d}" for i in range(39, 48)]

def tag(path: Path, name: str) -> str:
    p = subprocess.run(
        ["metaflac", f"--show-tag={name}", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    vals = []
    for line in p.stdout.splitlines():
        prefix = f"{name}="
        if line.startswith(prefix):
            vals.append(line[len(prefix):])
    return ";".join(vals)

albums = {}

for album_dir in sorted(p for p in root.iterdir() if p.is_dir()):
    if not any(album_dir.name.startswith(n) for n in targets):
        continue

    flacs = sorted(album_dir.rglob("*.flac"))
    if not flacs:
        continue

    m = re.match(r"^(\d{3})\s+Stockhausen\s+-\s+(.+?)(?:\s+\((\d{4})\))?$", album_dir.name)
    catalog_no = m.group(1) if m else album_dir.name[:3]
    folder_title = m.group(2) if m else album_dir.name
    folder_year = m.group(3) if m and m.group(3) else ""

    data = {
        "album_dir": album_dir.name,
        "catalog_no": catalog_no,
        "folder_title": folder_title,
        "folder_year": folder_year,
        "flac_count": len(flacs),
        "disc_dirs": set(),
        "albums": set(),
        "artists": set(),
        "albumartists": set(),
        "composers": set(),
        "dates": set(),
        "labels": set(),
        "catalognumbers": set(),
        "mb_albumids": set(),
        "mb_trackids": set(),
        "sample_titles": [],
        "first_file": str(flacs[0]),
    }

    for f in flacs:
        rel = f.relative_to(album_dir)
        if len(rel.parts) > 1:
            data["disc_dirs"].add(rel.parts[0])

        for key, tagname in [
            ("albums", "ALBUM"),
            ("artists", "ARTIST"),
            ("albumartists", "ALBUMARTIST"),
            ("composers", "COMPOSER"),
            ("dates", "DATE"),
            ("labels", "LABEL"),
            ("catalognumbers", "CATALOGNUMBER"),
            ("mb_albumids", "MUSICBRAINZ_ALBUMID"),
            ("mb_trackids", "MUSICBRAINZ_TRACKID"),
        ]:
            v = tag(f, tagname)
            if v:
                data[key].add(v)

        if len(data["sample_titles"]) < 8:
            title = tag(f, "TITLE")
            track = tag(f, "TRACKNUMBER")
            data["sample_titles"].append(f"{track} - {title}")

    albums[album_dir.name] = data

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow([
        "catalog_no",
        "album_dir",
        "folder_title",
        "folder_year",
        "flac_count",
        "disc_dirs",
        "album_tags",
        "artist_tags",
        "albumartist_tags",
        "composer_tags",
        "date_tags",
        "label_tags",
        "catalognumber_tags",
        "mb_albumid_count",
        "mb_trackid_count",
        "first_file",
        "sample_titles",
    ])

    for album in sorted(albums):
        d = albums[album]
        writer.writerow([
            d["catalog_no"],
            d["album_dir"],
            d["folder_title"],
            d["folder_year"],
            d["flac_count"],
            " | ".join(sorted(d["disc_dirs"])),
            " | ".join(sorted(d["albums"])),
            " | ".join(sorted(d["artists"])),
            " | ".join(sorted(d["albumartists"])),
            " | ".join(sorted(d["composers"])),
            " | ".join(sorted(d["dates"])),
            " | ".join(sorted(d["labels"])),
            " | ".join(sorted(d["catalognumbers"])),
            len(d["mb_albumids"]),
            len(d["mb_trackids"]),
            d["first_file"],
            " | ".join(d["sample_titles"]),
        ])

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen catalog reconciliation analysis — 1977-95 / 039-047\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    f.write("Root:\n")
    f.write(str(root) + "\n\n")
    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")
    f.write("Summary:\n")
    f.write(f"Albums analyzed: {len(albums)}\n")
    f.write(f"Tracks analyzed: {sum(d['flac_count'] for d in albums.values())}\n\n")

    for album in sorted(albums):
        d = albums[album]
        f.write(f"## {d['catalog_no']} — {d['album_dir']}\n")
        f.write(f"folder_title: {d['folder_title']}\n")
        f.write(f"folder_year: {d['folder_year']}\n")
        f.write(f"flac_count: {d['flac_count']}\n")
        f.write(f"disc_dirs: {' | '.join(sorted(d['disc_dirs']))}\n")
        f.write(f"album_tags: {' | '.join(sorted(d['albums']))}\n")
        f.write(f"artist_tags: {' | '.join(sorted(d['artists']))}\n")
        f.write(f"albumartist_tags: {' | '.join(sorted(d['albumartists']))}\n")
        f.write(f"composer_tags: {' | '.join(sorted(d['composers']))}\n")
        f.write(f"date_tags: {' | '.join(sorted(d['dates']))}\n")
        f.write(f"label_tags: {' | '.join(sorted(d['labels']))}\n")
        f.write(f"catalognumber_tags: {' | '.join(sorted(d['catalognumbers']))}\n")
        f.write(f"mb_albumid_count: {len(d['mb_albumids'])}\n")
        f.write(f"mb_trackid_count: {len(d['mb_trackids'])}\n")
        f.write("sample_titles:\n")
        for t in d["sample_titles"]:
            f.write(f"- {t}\n")
        f.write("\n")

    f.write("Interpretation:\n")
    f.write("- This script does not modify files.\n")
    f.write("- These albums require catalog/PDF/MusicBrainz reconciliation before normalization.\n")
    f.write("- The next step is to build a manual/catalog decision table for 039-047.\n")

print(out_tsv)
print(report)
PY
