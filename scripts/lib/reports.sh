#!/usr/bin/env bash
set -u

# Toolbox shared report path helpers.
#
# This file is intended to be sourced by Toolbox scripts.
# It must not execute actions, print output, create files, or modify state when sourced.
#
# These helpers build timestamped artifact paths.
# Some base paths are provisional and inherited from recent Toolbox practice.

toolbox_report_path() {
  local context="$1"
  local kind="$2"
  local stamp="$3"
  local base_dir

  base_dir="/srv/toolbox/shared/reports/media"

  printf '%s/%s_%s_report_%s.txt\n' "$base_dir" "$context" "$kind" "$stamp"
}

toolbox_tsv_path() {
  local context="$1"
  local kind="$2"
  local stamp="$3"
  local base_dir

  base_dir="/srv/toolbox/shared/library-db/raw"

  printf '%s/%s_%s_%s.tsv\n' "$base_dir" "$context" "$kind" "$stamp"
}

toolbox_live_log_path() {
  local context="$1"
  local kind="$2"
  local stamp="$3"
  local base_dir

  base_dir="/srv/toolbox/shared/reports/media"

  printf '%s/%s_%s_live_%s.log\n' "$base_dir" "$context" "$kind" "$stamp"
}

toolbox_snapshot_path() {
  local context="$1"
  local kind="$2"
  local stamp="$3"
  local base_dir

  base_dir="/srv/toolbox/shared/library-db/snapshots"

  printf '%s/%s_%s_snapshot_%s.tsv\n' "$base_dir" "$context" "$kind" "$stamp"
}
