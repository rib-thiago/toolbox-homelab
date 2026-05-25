#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

PLAN_TSV="${1:-}"
ROOT="${2:-}"
CONFIRM_TOKEN="${3:-}"

[[ -n "$PLAN_TSV" ]] || fail "Uso: apply-stockhausen-batch-normalization-safe.sh PLAN_TSV ROOT CONFIRM_TOKEN"
[[ -n "$ROOT" ]] || fail "ROOT ausente."
[[ -n "$CONFIRM_TOKEN" ]] || fail "CONFIRM_TOKEN ausente."
[[ -f "$PLAN_TSV" ]] || fail "Plano não encontrado: $PLAN_TSV"
[[ -d "$ROOT" ]] || fail "Root não encontrado: $ROOT"

command -v metaflac >/dev/null 2>&1 || fail "metaflac não encontrado."
command -v python3 >/dev/null 2>&1 || fail "python3 não encontrado."

echo
echo "Type $CONFIRM_TOKEN to continue:"
read -r CONFIRM
[[ "$CONFIRM" == "$CONFIRM_TOKEN" ]] || fail "Operação cancelada."


python3 - "$PLAN_TSV" "$ROOT" "$CONFIRM_TOKEN" <<'PY'
import csv
import datetime as dt
import os
import subprocess
import sys
from pathlib import Path

plan_tsv = Path(sys.argv[1])
root = Path(sys.argv[2])
confirm_token = sys.argv[3]

raw_dir = Path("/srv/toolbox/shared/library-db/raw")
report_dir = Path("/srv/toolbox/shared/reports/media")
snapshot_dir = Path("/srv/toolbox/shared/library-db/snapshots")

stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")

snapshot_tsv = snapshot_dir / f"stockhausen_batch_safe_pre_apply_snapshot_{stamp}.tsv"
apply_tsv = raw_dir / f"stockhausen_batch_safe_apply_{stamp}.tsv"
report = report_dir / f"stockhausen_batch_safe_apply_report_{stamp}.txt"

raw_dir.mkdir(parents=True, exist_ok=True)
report_dir.mkdir(parents=True, exist_ok=True)
snapshot_dir.mkdir(parents=True, exist_ok=True)

def log(msg: str) -> None:
    now = dt.datetime.now().strftime("%H:%M:%S")
    print(f"[{now}] {msg}", flush=True)

def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

with plan_tsv.open("r", encoding="utf-8", newline="") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))

if not rows:
    raise SystemExit("Plano vazio.")

allowed_confidences = {"HIGH", "LOCAL_HIGH"}
allowed_flags = {"", "NO_MBID_LOCAL_POLICY;PERFORMER_DEFERRED"}

non_high = [r for r in rows if r.get("confidence") not in allowed_confidences]
flagged = [r for r in rows if r.get("flags", "") not in allowed_flags]

renames = [
    r for r in rows
    if r.get("relative_path") != r.get("proposed_filename")
]

print()
print("Stockhausen safe batch apply")
print()
print(f"Plan:  {plan_tsv}")
print(f"Root:  {root}")
print()
print("Operations summary:")
print(f"- Tracks:       {len(rows)}")
print(f"- Renames:      {len(renames)}")
print(f"- Non-HIGH:     {len(non_high)}")
print(f"- Flagged rows: {len(flagged)}")
print()
print("IMPORTANT:")
print("- This WILL modify real FLAC files.")
print("- It reads TSV columns safely using Python csv.DictReader.")
print("- It writes AlbumArtist/Artist/Composer/Grouping by column name.")
print("- It preserves Performer and MusicBrainz tags.")
print("- It renames files according to proposed_filename.")
print()

if non_high or flagged:
    raise SystemExit("Plano contém confidence/flags não permitidos para aplicação segura. Revise antes de aplicar.")

log("Criando snapshot pré-aplicação...")

with snapshot_tsv.open("w", encoding="utf-8", newline="") as out:
    writer = csv.writer(out, delimiter="\t")
    writer.writerow(["album_dir", "relative_path", "absolute_path", "tags_before"])

    for r in rows:
        album_dir = r["album_dir"]
        rel = r["relative_path"]
        path = root / album_dir / rel

        if not path.exists():
            writer.writerow([album_dir, rel, str(path), "MISSING_FILE"])
            continue

        tags = subprocess.run(
            ["metaflac", "--export-tags-to=-", str(path)],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.replace("\n", "|").rstrip("|")

        writer.writerow([album_dir, rel, str(path), tags])

log(f"Snapshot salvo: {snapshot_tsv}")

log("Aplicando tags e renames...")

summary = {"TAGGED_ONLY": 0, "RENAMED": 0, "ERROR": 0}

with apply_tsv.open("w", encoding="utf-8", newline="") as out:
    writer = csv.writer(out, delimiter="\t")
    writer.writerow(["album_dir", "old_relative_path", "new_relative_path", "status", "detail"])

    for r in rows:
        album_dir = r["album_dir"]
        old_rel = r["relative_path"]
        new_rel = r["proposed_filename"]

        old_abs = root / album_dir / old_rel
        new_abs = root / album_dir / new_rel

        if not old_abs.exists():
            writer.writerow([album_dir, old_rel, new_rel, "ERROR", "missing source file"])
            summary["ERROR"] += 1
            log(f"ERROR missing: {old_abs}")
            continue

        metadata = {
            "ALBUMARTIST": r["proposed_albumartist"],
            "ARTIST": r["proposed_artist"],
            "COMPOSER": r["proposed_composer"],
            "GROUPING": r["proposed_grouping"],
        }

        for tag, value in metadata.items():
            run(["metaflac", f"--remove-tag={tag}", f"--set-tag={tag}={value}", str(old_abs)])

        if old_rel != new_rel:
            new_abs.parent.mkdir(parents=True, exist_ok=True)

            if new_abs.exists():
                writer.writerow([album_dir, old_rel, new_rel, "ERROR", "target exists"])
                summary["ERROR"] += 1
                log(f"ERROR target exists: {new_abs}")
                continue

            os.rename(old_abs, new_abs)
            writer.writerow([album_dir, old_rel, new_rel, "RENAMED", "OK"])
            summary["RENAMED"] += 1
            log(f"RENAMED: {album_dir} :: {old_rel} -> {new_rel}")
        else:
            writer.writerow([album_dir, old_rel, new_rel, "TAGGED_ONLY", "OK"])
            summary["TAGGED_ONLY"] += 1

with report.open("w", encoding="utf-8") as out:
    out.write("Stockhausen safe batch apply report\n")
    out.write(f"Generated: {dt.datetime.now().isoformat()}\n\n")
    out.write("Root:\n")
    out.write(str(root) + "\n\n")
    out.write("Plan:\n")
    out.write(str(plan_tsv) + "\n\n")
    out.write("Outputs:\n")
    out.write(str(snapshot_tsv) + "\n")
    out.write(str(apply_tsv) + "\n\n")
    out.write("Summary:\n")
    out.write(f"Tracks in plan: {len(rows)}\n")
    out.write(f"Tagged only: {summary['TAGGED_ONLY']}\n")
    out.write(f"Renamed: {summary['RENAMED']}\n")
    out.write(f"Errors: {summary['ERROR']}\n\n")
    out.write("Notes:\n")
    out.write("- TSV parsed safely by Python csv.DictReader.\n")
    out.write("- Metadata written with metaflac.\n")
    out.write("- Performer tags were preserved.\n")
    out.write("- MusicBrainz tags were preserved.\n")

log("Aplicação segura concluída.")
log(f"Apply TSV: {apply_tsv}")
log(f"Relatório: {report}")
PY
