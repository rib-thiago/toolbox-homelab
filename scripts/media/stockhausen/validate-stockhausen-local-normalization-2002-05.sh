#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen/2002-05: Licht pt. 3"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

PLAN_TSV="$(ls -t "$RAW_DIR"/stockhausen_local_normalization_plan_2002-05_LOCAL_*.tsv 2>/dev/null | head -1)"
VALIDATION_TSV="$RAW_DIR/stockhausen_local_normalization_validation_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_local_normalization_validation_report_1977-95_$STAMP.txt"

[[ -f "$PLAN_TSV" ]] || fail "Plano local 1977-95 não encontrado."
[[ -d "$ROOT" ]] || fail "Root não encontrado: $ROOT"
command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$PLAN_TSV" "$ROOT" "$VALIDATION_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import subprocess
import sys
from pathlib import Path

plan = Path(sys.argv[1])
root = Path(sys.argv[2])
validation_tsv = Path(sys.argv[3])
report = Path(sys.argv[4])

def find_by_track_prefix(album_path: Path, rel: str) -> Path | None:
    path = Path(rel)
    parent = album_path / path.parent
    name = path.name

    if not parent.exists():
        return None

    prefix = name[:3]  # "01 ", "23 ", etc.

    matches = sorted(parent.glob(f"{prefix}*.flac"))

    if len(matches) == 1:
        return matches[0]

    return None

def get_tag(path: Path, tag: str) -> str:
    result = subprocess.run(
        ["metaflac", f"--show-tag={tag}", str(path)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    values = []
    prefix = f"{tag}="

    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            values.append(line[len(prefix):])

    return ";".join(values)

def shorten_filename(rel: str, max_name_len: int = 180) -> str:
    path = Path(rel)
    name = path.name

    if len(name.encode("utf-8")) <= max_name_len:
        return rel

    stem = path.stem
    suffix = path.suffix
    max_stem_bytes = max_name_len - len(suffix.encode("utf-8"))

    encoded = stem.encode("utf-8")[:max_stem_bytes]

    while True:
        try:
            short_stem = encoded.decode("utf-8")
            break
        except UnicodeDecodeError:
            encoded = encoded[:-1]

    short_name = short_stem.rstrip(" -_.") + suffix
    return str(path.with_name(short_name))

rows = []

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        album_dir = row["album_dir"]

        proposed_filename_original = row["proposed_filename"]
        proposed_filename = shorten_filename(proposed_filename_original)

        path_short = root / album_dir / proposed_filename
        path_original = root / album_dir / proposed_filename_original

        album_path = root / album_dir

        if path_short.exists():
            path = path_short
        elif path_original.exists():
            path = path_original
        else:
            fallback = find_by_track_prefix(album_path, proposed_filename_original)
            path = fallback if fallback is not None else path_short

        expected_albumartist = row["proposed_albumartist"]
        expected_artist = row["proposed_artist"]
        expected_composer = row["proposed_composer"]
        expected_grouping = row["proposed_grouping"]

        file_exists = path.exists()
        filename_ok = (
            file_exists
            and path.name.endswith(".flac")
            and len(path.name.encode("utf-8")) <= 255
        )

        actual_albumartist = ""
        actual_artist = ""
        actual_composer = ""
        actual_grouping = ""
        mb_albumid = ""
        mb_trackid = ""
        performer = ""

        if file_exists:
            actual_albumartist = get_tag(path, "ALBUMARTIST")
            actual_artist = get_tag(path, "ARTIST")
            actual_composer = get_tag(path, "COMPOSER")
            actual_grouping = get_tag(path, "GROUPING")
            mb_albumid = get_tag(path, "MUSICBRAINZ_ALBUMID")
            mb_trackid = get_tag(path, "MUSICBRAINZ_TRACKID")
            performer = get_tag(path, "PERFORMER")

        flags = []

        if not file_exists:
            flags.append("MISSING_EXPECTED_FILE")
        if not filename_ok:
            flags.append("BAD_FILENAME_OR_TOO_LONG")
        if actual_albumartist != expected_albumartist:
            flags.append("BAD_ALBUMARTIST")
        if actual_artist != expected_artist:
            flags.append("BAD_ARTIST")
        if actual_composer != expected_composer:
            flags.append("BAD_COMPOSER")
        if actual_grouping != expected_grouping:
            flags.append("BAD_GROUPING")

        # Política local: MBID e PERFORMER são deliberadamente diferidos.
        # Não são erros aqui.
        status = "OK" if not flags else "ERROR"

        rows.append({
            "album_dir": album_dir,
            "expected_relative_path": proposed_filename,
            "original_proposed_relative_path": proposed_filename_original,
            "file_exists": "yes" if file_exists else "no",
            "filename_ok": "yes" if filename_ok else "no",
            "albumartist_ok": "yes" if actual_albumartist == expected_albumartist else "no",
            "artist_ok": "yes" if actual_artist == expected_artist else "no",
            "composer_ok": "yes" if actual_composer == expected_composer else "no",
            "grouping_ok": "yes" if actual_grouping == expected_grouping else "no",
            "mb_albumid_present": "yes" if mb_albumid else "no",
            "mb_trackid_present": "yes" if mb_trackid else "no",
            "performer_present": "yes" if performer else "no",
            "status": status,
            "flags": ";".join(flags),
        })

with validation_tsv.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "album_dir",
        "expected_relative_path",
        "original_proposed_relative_path",
        "file_exists",
        "filename_ok",
        "albumartist_ok",
        "artist_ok",
        "composer_ok",
        "grouping_ok",
        "mb_albumid_present",
        "mb_trackid_present",
        "performer_present",
        "status",
        "flags",
    ]
    writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

def count(col: str, value: str) -> int:
    return sum(1 for r in rows if r[col] == value)

ok = count("status", "OK")
err = count("status", "ERROR")

albums = sorted({r["album_dir"] for r in rows})
errors_by_album = {}
for album in albums:
    errors_by_album[album] = sum(
        1 for r in rows
        if r["album_dir"] == album and r["status"] == "ERROR"
    )

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen local normalization validation — 1977-95 MEDIUM / 039-047\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")

    f.write("Output:\n")
    f.write(str(validation_tsv) + "\n\n")

    f.write("Policy:\n")
    f.write("- Validate local structural metadata only.\n")
    f.write("- MBID intentionally deferred.\n")
    f.write("- PERFORMER intentionally deferred.\n")
    f.write("- Filename shortening is accepted when required by filesystem limits.\n\n")

    f.write("Summary:\n")
    f.write(f"Rows validated: {len(rows)}\n")
    f.write(f"OK: {ok}\n")
    f.write(f"ERROR: {err}\n\n")

    f.write("Check summaries:\n")
    f.write(f"Files exist: {count('file_exists', 'yes')}\n")
    f.write(f"Filename OK: {count('filename_ok', 'yes')}\n")
    f.write(f"AlbumArtist OK: {count('albumartist_ok', 'yes')}\n")
    f.write(f"Artist OK: {count('artist_ok', 'yes')}\n")
    f.write(f"Composer OK: {count('composer_ok', 'yes')}\n")
    f.write(f"Grouping OK: {count('grouping_ok', 'yes')}\n")
    f.write(f"MB AlbumId present: {count('mb_albumid_present', 'yes')} / deferred\n")
    f.write(f"MB TrackId present: {count('mb_trackid_present', 'yes')} / deferred\n")
    f.write(f"Performer present: {count('performer_present', 'yes')} / deferred\n\n")

    f.write("Errors by album:\n")
    for album in albums:
        f.write(f"- {album}: {errors_by_album[album]}\n")

    f.write("\nFailure samples:\n")
    shown = 0
    for r in rows:
        if r["status"] != "OK":
            f.write(
                f"- {r['album_dir']} :: {r['expected_relative_path']} :: {r['flags']}\n"
            )
            shown += 1
            if shown >= 120:
                break

    f.write("\nNotes:\n")
    f.write("- This script does not modify files.\n")
    f.write("- This validator is specific to LOCAL_HIGH 039-047 normalization.\n")

print(validation_tsv)
print(report)
PY
