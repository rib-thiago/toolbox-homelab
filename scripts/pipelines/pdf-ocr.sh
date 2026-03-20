#!/usr/bin/env bash
set -euo pipefail

JOB_ROOT="${1:?missing JOB_ROOT}"
INPUT_DIR="${JOB_ROOT}/input"
WORK_DIR="${JOB_ROOT}/work"
OUTPUT_DIR="${JOB_ROOT}/output"
LOG_FILE="${JOB_ROOT}/log.txt"
STATUS_FILE="${JOB_ROOT}/status"

TESSERACT_OCR_LANG="${TESSERACT_OCR_LANG:-eng}"

log() {
    local level="$1"
    shift
    printf '[%s] [%s] %s\n' "$(date '+%F %T')" "${level}" "$*"
}

fail() {
    log "ERROR" "$*"
    echo "failed" > "${STATUS_FILE}"
    exit 1
}

echo "running" > "${STATUS_FILE}"

[[ -x /toolbox/app/bin/pdf-images ]] || fail "pdf-images command not found or not executable"
[[ -x /toolbox/app/bin/ocr ]] || fail "ocr command not found or not executable"

PDF_FILE="$(find "${INPUT_DIR}" -maxdepth 1 -type f -name '*.pdf' | head -n1 || true)"
[[ -n "${PDF_FILE}" ]] || fail "no PDF found in input"

log "INFO" "Starting pdf-ocr pipeline"
log "INFO" "PDF file: ${PDF_FILE}"
log "INFO" "OCR language: ${TESSERACT_OCR_LANG}"

log "STEP" "Extracting pages with pdf-images"
/toolbox/app/bin/pdf-images -o "${WORK_DIR}" "${PDF_FILE}"
log "STEP" "PDF pages extracted to ${WORK_DIR}"

shopt -s nullglob
for img in "${WORK_DIR}"/*.png "${WORK_DIR}"/*.jpg; do
    [[ -f "${img}" ]] || continue
    base="$(basename "${img}")"
    stem="${base%.*}"
    log "STEP" "Running OCR for ${base}"
    /toolbox/app/bin/ocr -l "${TESSERACT_OCR_LANG}" -o "${WORK_DIR}/${stem}.txt" "${img}"
done

TXT_COUNT="$(find "${WORK_DIR}" -maxdepth 1 -type f -name '*.txt' | wc -l)"
[[ "${TXT_COUNT}" -gt 0 ]] || fail "no OCR text files were generated"

: > "${OUTPUT_DIR}/text.txt"
while IFS= read -r -d '' txt; do
    cat "${txt}" >> "${OUTPUT_DIR}/text.txt"
done < <(find "${WORK_DIR}" -maxdepth 1 -type f -name '*.txt' -print0 | sort -z)

[[ -s "${OUTPUT_DIR}/text.txt" ]] || fail "final text output is empty"

log "SUCCESS" "Final text written to ${OUTPUT_DIR}/text.txt"

echo "success" > "${STATUS_FILE}"
log "SUCCESS" "pdf-ocr completed successfully"
