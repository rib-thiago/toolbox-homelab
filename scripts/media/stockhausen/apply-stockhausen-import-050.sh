#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

PLAN="$(ls -t /srv/toolbox/shared/library-db/raw/stockhausen_import_050_plan_*.tsv | head -1)"

SRC_ROOT="/srv/media/music-staging/incoming/050 Stockhausen - Freitag aus Licht"

DEST_ROOT="/srv/media/music/Karlheinz Stockhausen/1991-2003: Licht pt. 2/050 Stockhausen - Freitag aus Licht"

RAW_DIR="/srv/toolbox/shared/library-db/raw"
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"
REPORT_DIR="/srv/toolbox/shared/reports/media"

STAMP="$(date +%Y%m%d-%H%M%S)"

OPS_TSV="$RAW_DIR/stockhausen_import_050_apply_$STAMP.tsv"
SNAPSHOT="$SNAPSHOT_DIR/stockhausen_import_050_pre_apply_snapshot_$STAMP.tsv"
REPORT="$REPORT_DIR/stockhausen_import_050_apply_report_$STAMP.txt"
LIVE_LOG="$REPORT_DIR/stockhausen_import_050_apply_live_$STAMP.log"

mkdir -p "$RAW_DIR"
mkdir -p "$SNAPSHOT_DIR"
mkdir -p "$REPORT_DIR"

[[ -f "$PLAN" ]] || fail "Plano não encontrado."
[[ -d "$SRC_ROOT" ]] || fail "Origem não encontrada."
[[ -d "$DEST_ROOT" ]] || fail "Destino não encontrado."

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

echo "Stockhausen import apply — 050 Freitag aus Licht"
echo
echo "Plan:"
echo "$PLAN"
echo
echo "Source:"
echo "$SRC_ROOT"
echo
echo "Destination:"
echo "$DEST_ROOT"
echo
echo "Outputs:"
echo "$OPS_TSV"
echo "$SNAPSHOT"
echo "$REPORT"
echo "$LIVE_LOG"
echo

TRACKS=$(tail -n +2 "$PLAN" | wc -l)

echo "Tracks planned: $TRACKS"
echo

echo "IMPORTANT:"
echo "- This WILL modify the real collection."
echo "- Files will be copied into the canonical corpus."
echo "- Tags will be rewritten."
echo "- Existing cover.jpg will be preserved."
echo "- MBID/PERFORMER remain deferred by policy."
echo

CONFIRM="APPLY-IMPORT-050"

echo "Type $CONFIRM to continue:"
read -r ANSWER

[[ "$ANSWER" == "$CONFIRM" ]] || fail "Operação cancelada."

exec > >(tee -a "$LIVE_LOG") 2>&1

python3 - "$PLAN" "$SRC_ROOT" "$DEST_ROOT" "$OPS_TSV" "$SNAPSHOT" "$REPORT" <<'PY'
import csv
import datetime as dt
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

plan = Path(sys.argv[1])
src_root = Path(sys.argv[2])
dest_root = Path(sys.argv[3])
ops_tsv = Path(sys.argv[4])
snapshot = Path(sys.argv[5])
report = Path(sys.argv[6])

def run(cmd):
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

def sha256(path: Path) -> str:
    h = hashlib.sha256()

    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)

    return h.hexdigest()

def tag(path: Path, key: str, value: str):
    run([
        "metaflac",
        f"--remove-tag={key}",
        str(path)
    ])

    run([
        "metaflac",
        f"--set-tag={key}={value}",
        str(path)
    ])

ops = []
snapshots = []

errors = 0
copied = 0

dest_root.mkdir(parents=True, exist_ok=True)

existing = sorted(dest_root.rglob("*.flac"))

for flac in existing:
    snapshots.append({
        "path": str(flac.relative_to(dest_root)),
        "sha256": sha256(flac),
        "size_bytes": flac.stat().st_size,
    })

with snapshot.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(
        f,
        delimiter="\t",
        fieldnames=["path", "sha256", "size_bytes"]
    )
    w.writeheader()
    w.writerows(snapshots)

with plan.open("r", encoding="utf-8") as f:
    reader = csv.DictReader(f, delimiter="\t")

    for row in reader:
        src = src_root / row["source_path"]
        dst = dest_root / row["destination_path"]

        try:
            dst.parent.mkdir(parents=True, exist_ok=True)

            shutil.copy2(src, dst)

            tag(dst, "TRACKNUMBER", row["tracknumber"])
            tag(dst, "DISCNUMBER", row["discnumber"])
            tag(dst, "ALBUM", row["album"])
            tag(dst, "TITLE", row["title"])
            tag(dst, "ALBUMARTIST", row["albumartist"])
            tag(dst, "ARTIST", row["artist"])
            tag(dst, "COMPOSER", row["composer"])
            tag(dst, "GROUPING", row["grouping"])
            tag(dst, "DATE", row["date"])

            copied += 1

            ops.append({
                "status": "OK",
                "source": str(src),
                "destination": str(dst),
                "sha256": sha256(dst),
            })

            print(f"[OK] {dst.relative_to(dest_root)}")

        except Exception as e:
            errors += 1

            ops.append({
                "status": "ERROR",
                "source": str(src),
                "destination": str(dst),
                "sha256": "",
            })

            print(f"[ERROR] {src} -> {dst}: {e}")

with ops_tsv.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(
        f,
        delimiter="\t",
        fieldnames=[
            "status",
            "source",
            "destination",
            "sha256",
        ]
    )

    w.writeheader()
    w.writerows(ops)

with report.open("w", encoding="utf-8") as f:
    f.write("Stockhausen import apply — 050 Freitag aus Licht\n")
    f.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")

    f.write("Plan:\n")
    f.write(str(plan) + "\n\n")

    f.write("Source:\n")
    f.write(str(src_root) + "\n\n")

    f.write("Destination:\n")
    f.write(str(dest_root) + "\n\n")

    f.write("Outputs:\n")
    f.write(str(ops_tsv) + "\n")
    f.write(str(snapshot) + "\n")
    f.write(str(report) + "\n\n")

    f.write("Summary:\n")
    f.write(f"Copied: {copied}\n")
    f.write(f"Errors: {errors}\n")
    f.write(f"Snapshot entries: {len(snapshots)}\n\n")

    f.write("Policy:\n")
    f.write("- MBID deferred\n")
    f.write("- PERFORMER deferred\n")
    f.write("- Existing artwork preserved\n")
    f.write("- Canonical grouping enforced\n")

print()
print("DONE")
print(report)
PY

echo
echo "Finished."
echo "Live log:"
echo "$LIVE_LOG"
