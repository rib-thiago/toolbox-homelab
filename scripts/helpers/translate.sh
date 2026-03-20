#!/usr/bin/env bash
set -euo pipefail

SOURCE_LANG="${GOOGLE_TRANSLATE_SOURCE_LANG:-auto}"
TARGET_LANG="${GOOGLE_TRANSLATE_TARGET_LANG:-en}"

usage() {
    cat <<EOF
Usage: translate [-s SOURCE] [-t TARGET] "TEXT"

Options:
  -s LANG   source language (default from env, fallback: auto)
  -t LANG   target language (default from env, fallback: en)
  -h        show help

Examples:
  translate "privet mir"
  translate -s ru -t en "Привет мир"
  translate -s ru -t pt "Привет мир"
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while getopts ":s:t:h" opt; do
    case "${opt}" in
        s) SOURCE_LANG="${OPTARG}" ;;
        t) TARGET_LANG="${OPTARG}" ;;
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

TEXT="${1:-}"
[[ -n "${TEXT}" ]] || {
    usage
    exit 1
}

: "${GOOGLE_APPLICATION_CREDENTIALS:?missing GOOGLE_APPLICATION_CREDENTIALS}"

python3 - "$TEXT" "$SOURCE_LANG" "$TARGET_LANG" <<'PY'
import sys
from google.cloud import translate_v2 as translate

text = sys.argv[1]
source = sys.argv[2]
target = sys.argv[3]

client = translate.Client()

result = client.translate(
    text,
    target_language=target,
    source_language=None if source == "auto" else source,
)

print(result["translatedText"])
PY
