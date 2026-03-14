#!/usr/bin/env bash
set -euo pipefail

FORMAT="png"
OUTPUT_DIR="."
PREFIX=""

usage() {
    cat <<EOF
Usage: pdf-images [-f FORMAT] [-o DIR] [-p PREFIX] PDF

Options:
  -f FORMAT   output format: png or jpeg (default: png)
  -o DIR      output directory (default: current directory)
  -p PREFIX   output filename prefix (default: PDF basename)
  -h          show help

Examples:
  pdf-images livro.pdf
  pdf-images -f jpeg livro.pdf
  pdf-images -o /toolbox/shared/out livro.pdf
  pdf-images -p pagina livro.pdf
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while getopts ":f:o:p:h" opt; do
    case "${opt}" in
        f) FORMAT="${OPTARG}" ;;
        o) OUTPUT_DIR="${OPTARG}" ;;
        p) PREFIX="${OPTARG}" ;;
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

command -v pdftoppm >/dev/null 2>&1 || fail "pdftoppm not found"

case "${FORMAT}" in
    png|jpeg)
        ;;
    *)
        fail "unsupported format: ${FORMAT} (use png or jpeg)"
        ;;
esac

mkdir -p "${OUTPUT_DIR}"

if [[ -z "${PREFIX}" ]]; then
    BASENAME="$(basename "${PDF_PATH}")"
    PREFIX="${BASENAME%.*}"
fi

OUTPUT_PREFIX="${OUTPUT_DIR}/${PREFIX}"

case "${FORMAT}" in
    png)
        pdftoppm -png "${PDF_PATH}" "${OUTPUT_PREFIX}"
        ;;
    jpeg)
        pdftoppm -jpeg "${PDF_PATH}" "${OUTPUT_PREFIX}"
        ;;
esac

find "${OUTPUT_DIR}" -maxdepth 1 -type f \( -name "${PREFIX}-*.png" -o -name "${PREFIX}-*.jpg" \) | sort
