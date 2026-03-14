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

[[ -x /toolbox/app/bin/pdf-images ]] || fail "pdf-images command not found or not executable"
[[ -x /toolbox/app/bin/ocr ]] || fail "ocr command not found or not executable"

PDF_FILE="$(find "${INPUT_DIR}" -maxdepth 1 -type f -name '*.pdf' | head -n1 || true)"
[[ -n "${PDF_FILE}" ]] || fail "no PDF found in input"

log "Starting pdf-ocr pipeline"
log "PDF file: ${PDF_FILE}"
log "OCR language: ${OCR_LANG}"

log "Extracting pages with pdf-images"
/toolbox/app/bin/pdf-images -o "${WORK_DIR}" "${PDF_FILE}" >> "${LOG_FILE}" 2>&1
log "PDF pages extracted to ${WORK_DIR}"

shopt -s nullglob
for img in "${WORK_DIR}"/*.png "${WORK_DIR}"/*.jpg; do
    [[ -f "${img}" ]] || continue
    base="$(basename "${img}")"
    stem="${base%.*}"
    log "Running OCR for ${base}"
    /toolbox/app/bin/ocr -l "${OCR_LANG}" -o "${WORK_DIR}/${stem}.txt" "${img}" >> "${LOG_FILE}" 2>&1
done

TXT_COUNT="$(find "${WORK_DIR}" -maxdepth 1 -type f -name '*.txt' | wc -l)"
[[ "${TXT_COUNT}" -gt 0 ]] || fail "no OCR text files were generated"

find "${WORK_DIR}" -maxdepth 1 -type f -name '*.txt' | sort | xargs cat > "${OUTPUT_DIR}/text.txt"
log "Final text written to ${OUTPUT_DIR}/text.txt"

echo "success" > "${STATUS_FILE}"
log "pdf-ocr completed successfully"
