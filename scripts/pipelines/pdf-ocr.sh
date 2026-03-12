#!/usr/bin/env bash
set -euo pipefail

JOB_ROOT="${1:?missing JOB_ROOT}"
INPUT_DIR="${JOB_ROOT}/input"
WORK_DIR="${JOB_ROOT}/work"
OUTPUT_DIR="${JOB_ROOT}/output"
LOG_FILE="${JOB_ROOT}/log.txt"
STATUS_FILE="${JOB_ROOT}/status"

OCR_LANG="${OCR_LANG:-eng}"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

fail() {
    log "ERROR: $*"
    echo "failed" > "${STATUS_FILE}"
    exit 1
}

echo "running" > "${STATUS_FILE}"

command -v pdftoppm >/dev/null 2>&1 || fail "pdftoppm not found"
[[ -x /toolbox/app/bin/ocr ]] || fail "ocr command not found or not executable"

PDF_FILE="$(find "${INPUT_DIR}" -maxdepth 1 -type f -name '*.pdf' | head -n1 || true)"
[[ -n "${PDF_FILE}" ]] || fail "no PDF found in input"

log "Starting pdf-ocr pipeline"
log "PDF file: ${PDF_FILE}"
log "OCR language: ${OCR_LANG}"

pdftoppm "${PDF_FILE}" "${WORK_DIR}/page" -png
log "PDF converted to PNG pages"

shopt -s nullglob
for img in "${WORK_DIR}"/page-*.png; do
    base="$(basename "${img}" .png)"
    log "Running OCR for ${base}.png"
    /toolbox/app/bin/ocr -l "${OCR_LANG}" -o "${WORK_DIR}/${base}.txt" "${img}" >> "${LOG_FILE}" 2>&1
done

cat "${WORK_DIR}"/page-*.txt > "${OUTPUT_DIR}/text.txt"
log "Final text written to ${OUTPUT_DIR}/text.txt"

echo "success" > "${STATUS_FILE}"
log "pdf-ocr completed successfully"
