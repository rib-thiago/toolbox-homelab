#!/usr/bin/env bash
set -euo pipefail

MODE="show"
TAGS_ONLY="false"

usage() {
    cat <<EOF
Usage:
  exif IMAGE
  exif -tags IMAGE
  exif -remove-all INPUT OUTPUT

Options:
  -tags         show only a subset of common tags
  -remove-all   remove all metadata and write cleaned image to OUTPUT
  -h            show help

Examples:
  exif foto.jpg
  exif -tags foto.jpg
  exif -remove-all foto.jpg foto-clean.jpg
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -tags)
            TAGS_ONLY="true"
            shift
            ;;
        -remove-all)
            MODE="remove-all"
            shift
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

command -v exiftool >/dev/null 2>&1 || fail "exiftool not found"

case "${MODE}" in
    show)
        IMAGE_PATH="${1:-}"
        [[ -n "${IMAGE_PATH}" ]] || {
            usage
            exit 1
        }
        [[ -f "${IMAGE_PATH}" ]] || fail "file not found: ${IMAGE_PATH}"

        if [[ "${TAGS_ONLY}" == "true" ]]; then
            exiftool \
                -FileName \
                -FileType \
                -MIMEType \
                -ImageWidth \
                -ImageHeight \
                -ColorSpace \
                -CreateDate \
                -ModifyDate \
                -Orientation \
                "${IMAGE_PATH}"
        else
            exiftool "${IMAGE_PATH}"
        fi
        ;;
    remove-all)
        INPUT_PATH="${1:-}"
        OUTPUT_PATH="${2:-}"

        [[ -n "${INPUT_PATH}" ]] || {
            usage
            exit 1
        }
        [[ -n "${OUTPUT_PATH}" ]] || {
            usage
            exit 1
        }

        [[ -f "${INPUT_PATH}" ]] || fail "file not found: ${INPUT_PATH}"

        cp "${INPUT_PATH}" "${OUTPUT_PATH}"
        exiftool -overwrite_original -all= "${OUTPUT_PATH}" >/dev/null
        echo "${OUTPUT_PATH}"
        ;;
    *)
        fail "invalid mode: ${MODE}"
        ;;
esac
