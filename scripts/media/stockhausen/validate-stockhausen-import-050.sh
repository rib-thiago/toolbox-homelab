#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

PLAN="$(ls -t /srv/toolbox/shared/library-db/raw/stockhausen_import_050_plan_*.tsv 2>/dev/null | head -1)"
ROOT="/srv/media/music/Karlheinz Stockhausen/1991-2003: Licht pt. 2/050 Stockhausen - Freitag aus Licht"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

VALIDATION_TSV="$RAW_DIR/stockhausen_import_050_validation_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_import_050_validation_report_$STAMP.txt"

[[ -f "$PLAN" ]] || fail "Plano 050 não encontrado."
[[ -d "$ROOT" ]] || fail "Root 050 não encontrado: $ROOT"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

log "Validando import 050..."
log "Plan: $PLAN"
log "Root: $ROOT"

python3 - "$PLAN" "$ROOT" "$VALIDATION_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import subprocess
import sys
from pathlib import Path

plan = Path(sys.argv[1])
root = Path(sys.argv[2])
validation_tsv = Path(sys.argv[3])
report = Path(sys.argv[4])

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

rows = []

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        path = root / row["destination_path"]
        file_exists = path.exists()

        actual = {}

        if file_exists:
            for tag in [
                "TRACKNUMBER",
                "DISCNUMBER",
                "ALBUM",
                "TITLE",
                "ALBUMARTIST",
                "ARTIST",
                "COMPOSER",
                "GROUPING",
                "DATE",
            ]:
                actual[tag] = get_tag(path, tag)
        else:
            actual = {k: "" for k in [
                "TRACKNUMBER",
                "DISCNUMBER",
                "ALBUM",
                "TITLE",
                "ALBUMARTIST",
                "ARTIST",
                "COMPOSER",
                "GROUPING",
                "DATE",
            ]}

        checks = {
            "file_exists": file_exists,
            "tracknumber_ok": actual["TRACKNUMBER"] == row["tracknumber"],
            "discnumber_ok": actual["DISCNUMBER"] == row["discnumber"],
            "album_ok": actual["ALBUM"] == row["album"],
            "title_ok": actual["TITLE"] == row["title"],
            "albumartist_ok": actual["ALBUMARTIST"] == row["albumartist"],
            "artist_ok": actual["ARTIST"] == row["artist"],
            "composer_ok": actual["COMPOSER"] == row["composer"],
            "grouping_ok": actual["GROUPING"] == row["grouping"],
            "date_ok": actual["DATE"] == row["date"],
        }

        flags = [name.upper() for name, ok in checks.items() if not ok]
        status = "OK" if not flags else "ERROR"

        rows.append({
            "destination_path": row["destination_path"],
            "discnumber": row["discnumber"],
            "tracknumber": row["tracknumber"],
            "expected_title": row["title"],
            "actual_title": actual["TITLE"],
            "file_exists": "yes" if file_exists else "no",
            "tracknumber_ok": "yes" if checks["tracknumber_ok"] else "no",
            "discnumber_ok": "yes" if checks["discnumber_ok"] else "no",
            "album_ok": "yes" if checks["album_ok"] else "no",
            "title_ok": "yes" if checks["title_ok"] else "no",
            "albumartist_ok": "yes" if checks["albumartist_ok"] else "no",
            "artist_ok": "yes" if checks["artist_ok"] else "no",
            "composer_ok": "yes" if checks["composer_ok"] else "no",
            "grouping_ok": "yes" if checks["grouping_ok"] else "no",
            "date_ok": "yes" if checks["date_ok"] else "no",
            "status": status,
            "flags": ";".join(flags),
        })

with validation_tsv.open("w", encoding="utf-8", newline="") as f:
    fieldnames = [
        "destination_path",
        "discnumber",
        "tracknumber",
        "expected_title",
        "actual_title",
        "file_exists",
        "tracknumber_ok",
        "discnumber_ok",
        "album_ok",
        "title_ok",
        "albumartist_ok",
        "artist_ok",
        "composer_ok",
        "grouping_ok",
        "date_ok",
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

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen import validation — 050 Freitag aus Licht\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Input plan:\n")
    f.write(str(plan) + "\n\n")

    f.write("Root:\n")
    f.write(str(root) + "\n\n")

    f.write("Output:\n")
    f.write(str(validation_tsv) + "\n\n")

    f.write("Summary:\n")
    f.write(f"Rows validated: {len(rows)}\n")
    f.write(f"OK: {ok}\n")
    f.write(f"ERROR: {err}\n\n")

    f.write("Check summaries:\n")
    for col in [
        "file_exists",
        "tracknumber_ok",
        "discnumber_ok",
        "album_ok",
        "title_ok",
        "albumartist_ok",
        "artist_ok",
        "composer_ok",
        "grouping_ok",
        "date_ok",
    ]:
        f.write(f"{col}: {count(col, 'yes')}\n")

    f.write("\nFailure samples:\n")
    shown = 0
    for r in rows:
        if r["status"] != "OK":
            f.write(
                f"- {r['destination_path']} :: {r['flags']} :: "
                f"expected=[{r['expected_title']}] actual=[{r['actual_title']}]\n"
            )
            shown += 1
            if shown >= 80:
                break

    f.write("\nNotes:\n")
    f.write("- This script does not modify files.\n")
    f.write("- MBID/PERFORMER are intentionally not validated here.\n")
    f.write("- This validates the imported delta album 050.\n")

print(validation_tsv)
print(report)
PY

log "Validation TSV: $VALIDATION_TSV"
log "Report: $REPORT"
log "Concluído."
