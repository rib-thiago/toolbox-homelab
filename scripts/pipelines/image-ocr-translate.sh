#!/usr/bin/env bash
set -euo pipefail

JOB_ROOT="${1:?missing JOB_ROOT}"

INPUT_DIR="${JOB_ROOT}/input"
WORK_DIR="${JOB_ROOT}/work"
OUTPUT_DIR="${JOB_ROOT}/output"
LOG_FILE="${JOB_ROOT}/log.txt"
STATUS_FILE="${JOB_ROOT}/status"

TESSERACT_OCR_LANG="${TESSERACT_OCR_LANG:-eng}"
GOOGLE_TRANSLATE_SOURCE_LANG="${GOOGLE_TRANSLATE_SOURCE_LANG:-auto}"
GOOGLE_TRANSLATE_TARGET_LANG="${GOOGLE_TRANSLATE_TARGET_LANG:-pt}"

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

normalize_translate_lang() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        auto) echo "auto" ;;
        en) echo "en" ;;
        pt) echo "pt" ;;
        ru) echo "ru" ;;
        *) printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' ;;
    esac
}

echo "running" > "${STATUS_FILE}"

[[ -x /toolbox/app/bin/ocr ]] || fail "ocr command not found"
[[ -x /toolbox/app/bin/translate ]] || fail "translate command not found"

IMAGE_FILE="$(find "${INPUT_DIR}" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.tif' -o -name '*.tiff' \) | head -n1 || true)"
[[ -n "${IMAGE_FILE}" ]] || fail "no image file found in input"

SOURCE_LANG_NORM="$(normalize_translate_lang "${GOOGLE_TRANSLATE_SOURCE_LANG}")"
TARGET_LANG_NORM="$(normalize_translate_lang "${GOOGLE_TRANSLATE_TARGET_LANG}")"

if [[ "${SOURCE_LANG_NORM}" != "auto" && "${SOURCE_LANG_NORM}" == "${TARGET_LANG_NORM}" ]]; then
    fail "source and target languages are equivalent (${GOOGLE_TRANSLATE_SOURCE_LANG} -> ${GOOGLE_TRANSLATE_TARGET_LANG}); refusing redundant translation"
fi

log "INFO" "Starting image-ocr-translate pipeline"
log "INFO" "Image file: ${IMAGE_FILE}"
log "INFO" "OCR language: ${TESSERACT_OCR_LANG}"
log "INFO" "Translation source language: ${GOOGLE_TRANSLATE_SOURCE_LANG}"
log "INFO" "Target language: ${GOOGLE_TRANSLATE_TARGET_LANG}"

log "STEP" "Running OCR"
/toolbox/app/bin/ocr -l "${TESSERACT_OCR_LANG}" -o "${WORK_DIR}/text-original.txt" "${IMAGE_FILE}"

[[ -f "${WORK_DIR}/text-original.txt" ]] || fail "OCR output not generated"
[[ -s "${WORK_DIR}/text-original.txt" ]] || fail "OCR output is empty"

log "STEP" "Running translation"
TRANSLATED_TEXT="$(
    /toolbox/app/bin/translate \
        -s "${GOOGLE_TRANSLATE_SOURCE_LANG}" \
        -t "${GOOGLE_TRANSLATE_TARGET_LANG}" \
        "$(cat "${WORK_DIR}/text-original.txt")"
)"

printf '%s\n' "${TRANSLATED_TEXT}" > "${OUTPUT_DIR}/text-translated.txt"
cp "${WORK_DIR}/text-original.txt" "${OUTPUT_DIR}/text-original.txt"

[[ -f "${OUTPUT_DIR}/text-translated.txt" ]] || fail "translated output not generated"

log "SUCCESS" "Original text written to ${OUTPUT_DIR}/text-original.txt"
log "SUCCESS" "Translated text written to ${OUTPUT_DIR}/text-translated.txt"

echo "success" > "${STATUS_FILE}"
log "SUCCESS" "image-ocr-translate completed successfully"
