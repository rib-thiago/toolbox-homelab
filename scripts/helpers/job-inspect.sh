#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: job-inspect TARGET

Inspect a toolbox job.

TARGET may be:
  - a job type, such as pdf-ocr or image-ocr-translate
  - a container job path, such as /toolbox/jobs/2026-03-17-234942-image-ocr-translate
  - a host job path, such as /srv/toolbox/jobs/2026-03-17-234942-image-ocr-translate

Examples:
  job-inspect pdf-ocr
  job-inspect image-ocr-translate
  job-inspect /toolbox/jobs/2026-03-17-234942-image-ocr-translate
  job-inspect /srv/toolbox/jobs/2026-03-17-234942-image-ocr-translate
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

if [[ -t 1 ]]; then
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    YELLOW=$'\033[33m'
    MAGENTA=$'\033[35m'
    CYAN=$'\033[36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    GREEN=""
    RED=""
    YELLOW=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    RESET=""
fi

section() {
    printf '\n%s============================================================%s\n'
    printf '%s%s%s\n' "${BOLD}" "$1" "${RESET}"
    printf '%s============================================================%s\n\n'
}

print_status() {
    local status_value
    status_value="$(cat "$1")"

    case "${status_value}" in
        success)
            printf '%s%s%s\n' "${GREEN}" "${status_value}" "${RESET}"
            ;;
        failed)
            printf '%s%s%s\n' "${RED}" "${status_value}" "${RESET}"
            ;;
        running)
            printf '%s%s%s\n' "${YELLOW}" "${status_value}" "${RESET}"
            ;;
        *)
            printf '%s\n' "${status_value}"
            ;;
    esac
}

print_log() {
    local logfile="$1"

    while IFS= read -r line; do
        case "${line}" in
            *"[ERROR]"*)
                printf '%s%s%s\n' "${RED}" "${line}" "${RESET}"
                ;;
            *"[SUCCESS]"*)
                printf '%s%s%s\n' "${GREEN}" "${line}" "${RESET}"
                ;;
            *"[STEP]"*)
                printf '%s%s%s\n' "${CYAN}" "${line}" "${RESET}"
                ;;
            *"[INFO]"*)
                printf '%s%s%s\n' "${MAGENTA}" "${line}" "${RESET}"
                ;;
            *)
                printf '%s\n' "${line}"
                ;;
        esac
    done < <(sed -n '1,200p' "${logfile}")
}

while getopts ":h" opt; do
    case "${opt}" in
        h)
            usage
            exit 0
            ;;
        \?)
            fail "unknown option: -${OPTARG}"
            ;;
    esac
done

shift $((OPTIND - 1))

TARGET="${1:-}"
[[ -n "${TARGET}" ]] || {
    usage
    exit 1
}

normalize_job_path() {
    local path="$1"

    case "${path}" in
        /toolbox/jobs/*)
            printf '%s\n' "${path}"
            ;;
        /srv/toolbox/jobs/*)
            printf '%s\n' "${path#/srv}"
            ;;
        *)
            printf '%s\n' "${path}"
            ;;
    esac
}

if [[ "${TARGET}" == /* ]]; then
    JOB_DIR="$(normalize_job_path "${TARGET}")"
else
    JOB_DIR="$(ls -dt /toolbox/jobs/*"${TARGET}" 2>/dev/null | head -n1 || true)"
fi

[[ -n "${JOB_DIR:-}" ]] || fail "job not found for target: ${TARGET}"
[[ -d "${JOB_DIR}" ]] || fail "job directory does not exist: ${JOB_DIR}"

section "JOB"
printf '%s\n' "${JOB_DIR}"

section "STATUS"
print_status "${JOB_DIR}/status"

section "LOG (first 200 lines)"
print_log "${JOB_DIR}/log.txt"

section "OUTPUT FILES"
find "${JOB_DIR}/output" -maxdepth 1 -type f | sort

echo ""
