#!/usr/bin/env bash
set -u

# Toolbox shared TSV helpers.
#
# This file is intended to be sourced by Toolbox scripts.
# It must not execute actions, print output, create files, or modify state when sourced.

tsv_escape() {
  local raw

  raw="$1"
  raw="${raw//$'\t'/ }"
  raw="${raw//$'\n'/ }"
  raw="${raw//$'\r'/ }"

  printf '%s' "$raw"
}

tsv_row() {
  local first
  local field

  if [ "$#" -eq 0 ]; then
    printf '\n'
    return 0
  fi

  first="yes"

  for field in "$@"; do
    if [ "$first" = "yes" ]; then
      first="no"
    else
      printf '\t'
    fi

    tsv_escape "$field"
  done

  printf '\n'
}
