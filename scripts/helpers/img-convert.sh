#!/usr/bin/env bash
set -euo pipefail

RESIZE=""

usage() {
    cat <<EOF
Usage: img-convert [-resize SIZE] INPUT OUTPUT

Options:
  -resize SIZE   resize image (examples: 50%, 1200x1600)
  -h             show help

Examples:
  img-convert input.tiff output.png
  img-convert -resize 50% input.jpg output.jpg
  img-convert -resize 1200x1600 input.png output.png
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

# parse options manually
while [[ $# -gt 0 ]]; do
    case "$1" in
        -resize)
            RESIZE="${2:-}"
            [[ -n "${RESIZE}" ]] || fail "missing argument for -resize"
            shift 2
            ;;
        -h)
            usage
            exit 0
            ;;
        -*)
            fail "unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

INPUT="${1:-}"
OUTPUT="${2:-}"

[[ -n "${INPUT}" ]] || {
    usage
    exit 1
}

[[ -n "${OUTPUT}" ]] || {
    usage
    exit 1
}

[[ -f "${INPUT}" ]] || fail "file not found: ${INPUT}"

command -v magick >/dev/null 2>&1 || fail "ImageMagick not found"

if [[ -n "${RESIZE}" ]]; then
    magick "${INPUT}" -resize "${RESIZE}" "${OUTPUT}"
else
    magick "${INPUT}" "${OUTPUT}"
fi

echo "${OUTPUT}"
