#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

ROOT="/srv/media/music/Karlheinz Stockhausen/1977-95: Licht pt. 1"

PLAN_TSV="$(ls -t /srv/toolbox/shared/library-db/raw/stockhausen_local_normalization_plan_1977-95_MEDIUM_*.tsv 2>/dev/null | head -1)"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
REPORT_DIR="/srv/toolbox/shared/reports/media"
STAMP="$(date +%Y%m%d-%H%M%S)"

OUT_TSV="$RAW_DIR/stockhausen_local_resume_apply_1977-95_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_local_resume_apply_report_1977-95_$STAMP.txt"

[[ -d "$ROOT" ]] || fail "Root não encontrado."
[[ -f "$PLAN_TSV" ]] || fail "Plano LOCAL_HIGH não encontrado."

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

python3 - "$PLAN_TSV" "$ROOT" "$OUT_TSV" "$REPORT" <<'PY'
import csv
import datetime as dt
import subprocess
import sys
from pathlib import Path

plan = Path(sys.argv[1])
root = Path(sys.argv[2])
out_tsv = Path(sys.argv[3])
report = Path(sys.argv[4])

rows = []

renamed = 0
skipped = 0
tagged_only = 0
errors = 0

def run(cmd):
    return subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

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

with plan.open("r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        album_dir = row["album_dir"]

        src_rel = row["relative_path"]
        dst_rel_original = row["proposed_filename"]
        dst_rel = shorten_filename(dst_rel_original)

        src = root / album_dir / src_rel
        dst = root / album_dir / dst_rel

        proposed_albumartist = row["proposed_albumartist"]
        proposed_artist = row["proposed_artist"]
        proposed_composer = row["proposed_composer"]
        proposed_grouping = row["proposed_grouping"]

        # CASE 1:
        # arquivo já renomeado anteriormente
        if dst.exists():
            target = dst

            status = "SKIPPED_ALREADY_RENAMED"
            skipped += 1

        # CASE 2:
        # arquivo original ainda existe
        elif src.exists():
            target = src

            rename_result = run(["mv", str(src), str(dst)])

            if rename_result.returncode != 0:
                rows.append([
                    album_dir,
                    src_rel,
                    dst_rel,
                    "ERROR_RENAME",
                    rename_result.stderr.strip(),
                ])
                errors += 1
                continue

            target = dst
            status = "RENAMED"
            renamed += 1

        # CASE 3:
        # estado inconsistente
        else:
            rows.append([
                album_dir,
                src_rel,
                dst_rel,
                "ERROR_MISSING_BOTH",
                "",
            ])
            errors += 1
            continue

        cmds = [
            ["metaflac", "--remove-tag=ALBUMARTIST", f"--set-tag=ALBUMARTIST={proposed_albumartist}", str(target)],
            ["metaflac", "--remove-tag=ARTIST", f"--set-tag=ARTIST={proposed_artist}", str(target)],
            ["metaflac", "--remove-tag=COMPOSER", f"--set-tag=COMPOSER={proposed_composer}", str(target)],
            ["metaflac", "--remove-tag=GROUPING", f"--set-tag=GROUPING={proposed_grouping}", str(target)],
        ]

        tag_error = None

        for cmd in cmds:
            r = run(cmd)
            if r.returncode != 0:
                tag_error = r.stderr.strip()
                break

        if tag_error:
            rows.append([
                album_dir,
                src_rel,
                dst_rel,
                "ERROR_TAGGING",
                tag_error,
            ])
            errors += 1
            continue

        tagged_only += 1

        rows.append([
            album_dir,
            src_rel,
            dst_rel,
            status,
            "OK",
        ])

with out_tsv.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow([
        "album_dir",
        "source_relative_path",
        "target_relative_path",
        "status",
        "detail",
    ])
    writer.writerows(rows)

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen LOCAL resume apply — 1977-95\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Root:\n")
    f.write(str(root) + "\n\n")

    f.write("Plan:\n")
    f.write(str(plan) + "\n\n")

    f.write("Outputs:\n")
    f.write(str(out_tsv) + "\n\n")

    f.write("Summary:\n")
    f.write(f"Rows processed: {len(rows)}\n")
    f.write(f"Renamed now: {renamed}\n")
    f.write(f"Already renamed/skipped: {skipped}\n")
    f.write(f"Tagged successfully: {tagged_only}\n")
    f.write(f"Errors: {errors}\n\n")

    f.write("Notes:\n")
    f.write("- Resume-safe execution.\n")
    f.write("- Already renamed files are skipped safely.\n")
    f.write("- Remaining split-track files are resumed.\n")
    f.write("- Performer/MBID remain deferred.\n")

print(out_tsv)
print(report)
PY
