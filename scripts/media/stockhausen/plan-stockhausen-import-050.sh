#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

SRC="/srv/media/music-staging/incoming/050 Stockhausen - Freitag aus Licht"
DEST_ROOT="/srv/media/music/Karlheinz Stockhausen/1991-2003: Licht pt. 2"
ALBUM_DIR="050 Stockhausen - Freitag aus Licht"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN="$RAW_DIR/stockhausen_import_050_plan_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_import_050_plan_report_$STAMP.txt"

[[ -d "$SRC" ]] || fail "Origem não encontrada: $SRC"
[[ -d "$DEST_ROOT" ]] || fail "Destino raiz não encontrado: $DEST_ROOT"
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$SRC" "$DEST_ROOT" "$ALBUM_DIR" "$PLAN" "$REPORT" <<'PY'
import csv
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

src = Path(sys.argv[1])
dest_root = Path(sys.argv[2])
album_dir = sys.argv[3]
plan = Path(sys.argv[4])
report = Path(sys.argv[5])

ALBUM = "Freitag aus Licht"
ALBUMARTIST = "Karlheinz Stockhausen"
ARTIST = "Karlheinz Stockhausen"
COMPOSER = "Karlheinz Stockhausen"
GROUPING = "1991-2003: Licht pt. 2"
DATE = "1996"

def sanitize_filename(text: str) -> str:
    text = text.replace("/", "-")
    text = text.replace("\0", "")
    text = re.sub(r"\s+", " ", text).strip()
    return text

def shorten_name(name: str, max_bytes: int = 180) -> str:
    if len(name.encode("utf-8")) <= max_bytes:
        return name

    path = Path(name)
    stem = path.stem
    suffix = path.suffix
    max_stem = max_bytes - len(suffix.encode("utf-8"))

    encoded = stem.encode("utf-8")[:max_stem]

    while True:
        try:
            decoded = encoded.decode("utf-8")
            break
        except UnicodeDecodeError:
            encoded = encoded[:-1]

    return decoded.rstrip(" -_.") + suffix

def cue_titles(cue_path: Path) -> list[str]:
    text = cue_path.read_text(encoding="utf-8", errors="replace")
    titles = []

    current = None

    for line in text.splitlines():
        if re.match(r"^\s*TRACK\s+\d+\s+AUDIO\b", line):
            if current is not None:
                titles.append(current)
            current = ""

        elif current is not None:
            m = re.match(r'^\s*TITLE\s+"(.*)"\s*$', line)
            if m:
                current = m.group(1).strip()

    if current is not None:
        titles.append(current)

    return titles

rows = []

# CD1 single-track
rows.append({
    "source_path": "CDimage1.flac",
    "discnumber": "1",
    "tracknumber": "1",
    "title": "Freitags-Gruss: Elektronische Musik",
})

# CD2 split tracks from CUE
titles2 = cue_titles(src / "CDimage2.cue")
for idx, title in enumerate(titles2, start=1):
    rows.append({
        "source_path": f"split/CDimage2/split-track{idx:02d}.flac",
        "discnumber": "2",
        "tracknumber": str(idx),
        "title": title or f"CD2 Track {idx}",
    })

# CD3 split tracks from CUE
titles3 = cue_titles(src / "CDimage3.cue")
for idx, title in enumerate(titles3, start=1):
    rows.append({
        "source_path": f"split/CDimage3/split-track{idx:02d}.flac",
        "discnumber": "3",
        "tracknumber": str(idx),
        "title": title or f"CD3 Track {idx}",
    })

# CD4 single-track
rows.append({
    "source_path": "CDimage4.flac",
    "discnumber": "4",
    "tracknumber": "1",
    "title": "Freitags-Abschied: Elektronische Musik",
})

for row in rows:
    disc = int(row["discnumber"])
    track = int(row["tracknumber"])
    title = sanitize_filename(row["title"])

    filename = f"CD{disc}/{track:02d} - {title}.flac"
    filename = str(Path(filename).with_name(shorten_name(Path(filename).name)))

    row["album_dir"] = album_dir
    row["destination_path"] = filename
    row["album"] = ALBUM
    row["albumartist"] = ALBUMARTIST
    row["artist"] = ARTIST
    row["composer"] = COMPOSER
    row["grouping"] = GROUPING
    row["date"] = DATE
    row["totaldiscs"] = "4"
    row["confidence"] = "LOCAL_HIGH"
    row["flags"] = "NO_MBID_LOCAL_POLICY;PERFORMER_DEFERRED;IMPORT_DELTA_050"

with plan.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "album_dir",
        "source_path",
        "destination_path",
        "discnumber",
        "tracknumber",
        "totaldiscs",
        "title",
        "album",
        "albumartist",
        "artist",
        "composer",
        "grouping",
        "date",
        "confidence",
        "flags",
    ]

    writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

missing_sources = []
for row in rows:
    if not (src / row["source_path"]).exists():
        missing_sources.append(row["source_path"])

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen import plan — 050 Freitag aus Licht\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Source:\n")
    f.write(str(src) + "\n\n")

    f.write("Destination:\n")
    f.write(str(dest_root / album_dir) + "\n\n")

    f.write("Output:\n")
    f.write(str(plan) + "\n\n")

    f.write("Summary:\n")
    f.write(f"Rows planned: {len(rows)}\n")
    f.write(f"CD1 single tracks: 1\n")
    f.write(f"CD2 cue tracks: {len(titles2)}\n")
    f.write(f"CD3 cue tracks: {len(titles3)}\n")
    f.write(f"CD4 single tracks: 1\n")
    f.write(f"Missing sources: {len(missing_sources)}\n\n")

    f.write("Policy:\n")
    f.write(f"ALBUM={ALBUM}\n")
    f.write(f"ALBUMARTIST={ALBUMARTIST}\n")
    f.write(f"ARTIST={ARTIST}\n")
    f.write(f"COMPOSER={COMPOSER}\n")
    f.write(f"GROUPING={GROUPING}\n")
    f.write("PERFORMER deferred\n")
    f.write("MBID deferred\n\n")

    f.write("Missing sources:\n")
    for p in missing_sources:
        f.write(f"- {p}\n")

    f.write("\nSample rows:\n")
    for row in rows[:20]:
        f.write(
            f"- {row['source_path']} -> {row['destination_path']} :: {row['title']}\n"
        )

print(plan)
print(report)
PY
