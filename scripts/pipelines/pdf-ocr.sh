#!/usr/bin/env bash
set -euo pipefail

JOB_ROOT="${1:?missing JOB_ROOT}"
INPUT_DIR="${JOB_ROOT}/input"
WORK_DIR="${JOB_ROOT}/work"
OUTPUT_DIR="${JOB_ROOT}/output"

PDF_FILE="$(find "${INPUT_DIR}" -maxdepth 1 -type f -name '*.pdf' | head -n1 || true)"
[[ -n "${PDF_FILE}" ]] || { echo "no PDF found in input"; exit 1; }

pdftoppm "${PDF_FILE}" "${WORK_DIR}/page" -png

shopt -s nullglob
for img in "${WORK_DIR}"/page-*.png; do
  base="$(basename "${img}" .png)"
  tesseract "${img}" "${WORK_DIR}/${base}" -l eng
done

cat "${WORK_DIR}"/page-*.txt > "${OUTPUT_DIR}/text.txt"
