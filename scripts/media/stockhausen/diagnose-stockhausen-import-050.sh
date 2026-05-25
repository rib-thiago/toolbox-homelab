#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

SRC="/srv/media/music-staging/incoming/050 Stockhausen - Freitag aus Licht"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_import_050_diagnosis_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_import_050_diagnosis_report_$STAMP.txt"

[[ -d "$SRC" ]] || fail "Diretório de origem não encontrado: $SRC"

command -v ffprobe >/dev/null 2>&1 || fail "ffprobe não encontrado."
command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$SRC" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

src = Path(sys.argv[1])
out_tsv = Path(sys.argv[2])
report = Path(sys.argv[3])

def run(cmd):
    return subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

def ffprobe_duration(path: Path) -> str:
    r = run([
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(path),
    ])

    if r.returncode != 0:
        return ""

    try:
        seconds = float(r.stdout.strip())
    except ValueError:
        return ""

    minutes = int(seconds // 60)
    secs = seconds - minutes * 60
    return f"{minutes:02d}:{secs:05.2f}"

def flac_tags(path: Path) -> dict[str, str]:
    r = run(["metaflac", "--export-tags-to=-", str(path)])
    tags = {}

    for line in r.stdout.splitlines():
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        tags.setdefault(k, v)

    return tags

def cue_track_count(path: Path) -> int:
    text = path.read_text(encoding="utf-8", errors="replace")
    return len(re.findall(r"^\s*TRACK\s+\d+\s+AUDIO\b", text, flags=re.MULTILINE))

def cue_file_refs(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    refs = re.findall(r'^\s*FILE\s+"([^"]+)"\s+\w+', text, flags=re.MULTILINE)
    return refs

flacs = sorted(src.glob("*.flac"))
cues = sorted(src.glob("*.cue"))

cue_by_stem = {p.stem: p for p in cues}

rows = []

for flac in flacs:
    cue = cue_by_stem.get(flac.stem)
    tags = flac_tags(flac)

    rows.append({
        "kind": "flac",
        "name": flac.name,
        "size_bytes": flac.stat().st_size,
        "duration": ffprobe_duration(flac),
        "matching_cue": cue.name if cue else "",
        "cue_track_count": cue_track_count(cue) if cue else "",
        "album": tags.get("ALBUM", ""),
        "title": tags.get("TITLE", ""),
        "tracknumber": tags.get("TRACKNUMBER", ""),
        "artist": tags.get("ARTIST", ""),
        "albumartist": tags.get("ALBUMARTIST", ""),
        "status": "HAS_CUE" if cue else "NO_CUE",
    })

for cue in cues:
    refs = cue_file_refs(cue)

    rows.append({
        "kind": "cue",
        "name": cue.name,
        "size_bytes": cue.stat().st_size,
        "duration": "",
        "matching_cue": "",
        "cue_track_count": cue_track_count(cue),
        "album": "",
        "title": "",
        "tracknumber": "",
        "artist": "",
        "albumartist": "",
        "status": "CUE_FILE_REFS=" + " | ".join(refs),
    })

other_files = sorted(
    p for p in src.iterdir()
    if p.is_file() and p.suffix.lower() not in {".flac", ".cue"}
)

for p in other_files:
    rows.append({
        "kind": "other",
        "name": p.name,
        "size_bytes": p.stat().st_size,
        "duration": "",
        "matching_cue": "",
        "cue_track_count": "",
        "album": "",
        "title": "",
        "tracknumber": "",
        "artist": "",
        "albumartist": "",
        "status": "OTHER_FILE",
    })

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "kind",
        "name",
        "size_bytes",
        "duration",
        "matching_cue",
        "cue_track_count",
        "album",
        "title",
        "tracknumber",
        "artist",
        "albumartist",
        "status",
    ]
    writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen import diagnosis — 050 Freitag aus Licht\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Source:\n")
    f.write(str(src) + "\n\n")

    f.write("Output:\n")
    f.write(str(out_tsv) + "\n\n")

    f.write("Summary:\n")
    f.write(f"FLAC files: {len(flacs)}\n")
    f.write(f"CUE files: {len(cues)}\n")
    f.write(f"Other files: {len(other_files)}\n\n")

    f.write("FLAC/CUE matrix:\n")
    for r in rows:
        if r["kind"] != "flac":
            continue
        f.write(
            f"- {r['name']} | duration={r['duration']} | "
            f"cue={r['matching_cue'] or 'MISSING'} | "
            f"cue_tracks={r['cue_track_count'] or 'N/A'} | "
            f"tags_album={r['album'] or '-'} | "
            f"tags_title={r['title'] or '-'}\n"
        )

    f.write("\nCUE details:\n")
    for cue in cues:
        refs = cue_file_refs(cue)
        f.write(f"- {cue.name}: tracks={cue_track_count(cue)} refs={', '.join(refs)}\n")

    f.write("\nOther files:\n")
    for p in other_files:
        f.write(f"- {p.name} ({p.stat().st_size} bytes)\n")

    f.write("\nInterpretation guide:\n")
    f.write("- HAS_CUE means the FLAC can probably be split with cuebreakpoints/shnsplit.\n")
    f.write("- NO_CUE means either single-track disc or missing cue; inspect duration and context before importing.\n")
    f.write("- This script does not modify files.\n")

print(out_tsv)
print(report)
PY
