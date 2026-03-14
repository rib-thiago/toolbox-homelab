#!/usr/bin/env bash
set -euo pipefail

LANG_CODE="eng"
OUTPUT_MODE="stdout"

usage() {
    cat <<EOF
Usage: ocr [-l LANG] [-o FILE] IMAGE

Options:
  -l LANG   OCR language (default: eng)
  -o FILE   Write output to FILE instead of stdout
  -h        Show this help message

Examples:
  ocr image.png
  ocr -l rus newspaper.png
  ocr -l por -o result.txt page.png
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while getopts ":l:o:h" opt; do
    case "${opt}" in
        l) LANG_CODE="${OPTARG}" ;;
        o) OUTPUT_MODE="${OPTARG}" ;;
        h)
            usage
            exit 0
            ;;
        \?)
            fail "unknown option: -${OPTARG}"
            ;;
        :)
            fail "missing argument for -${OPTARG}"
            ;;
    esac
done

shift $((OPTIND - 1))

IMAGE_PATH="${1:-}"
[[ -n "${IMAGE_PATH}" ]] || {
    usage
    exit 1
}

[[ -f "${IMAGE_PATH}" ]] || fail "file not found: ${IMAGE_PATH}"

command -v tesseract >/dev/null 2>&1 || fail "tesseract not found"

if [[ "${OUTPUT_MODE}" == "stdout" ]]; then
    tesseract "${IMAGE_PATH}" stdout -l "${LANG_CODE}"
else
    TMP_BASE="$(mktemp -u)"
    tesseract "${IMAGE_PATH}" "${TMP_BASE}" -l "${LANG_CODE}"
    mv "${TMP_BASE}.txt" "${OUTPUT_MODE}"
    echo "${OUTPUT_MODE}"
fi
