#!/usr/bin/env bash
set -euo pipefail

OUTPUT_MODE="stdout"

usage() {
    cat <<EOF
Usage: pdf-text [-o FILE] PDF

Options:
  -o FILE   write extracted text to FILE instead of stdout
  -h        show help

Examples:
  pdf-text documento.pdf
  pdf-text documento.pdf > texto.txt
  pdf-text -o texto.txt documento.pdf
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while getopts ":o:h" opt; do
    case "${opt}" in
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

PDF_PATH="${1:-}"
[[ -n "${PDF_PATH}" ]] || {
    usage
    exit 1
}

[[ -f "${PDF_PATH}" ]] || fail "file not found: ${PDF_PATH}"

command -v pdftotext >/dev/null 2>&1 || fail "pdftotext not found"

if [[ "${OUTPUT_MODE}" == "stdout" ]]; then
    pdftotext "${PDF_PATH}" -
else
    pdftotext "${PDF_PATH}" "${OUTPUT_MODE}"
    echo "${OUTPUT_MODE}"
fi
