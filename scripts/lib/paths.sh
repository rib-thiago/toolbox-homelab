#!/usr/bin/env bash
set -u

# Toolbox shared path helpers.
#
# This file is intended to be sourced by Toolbox scripts.
# It must not execute actions, print output, create files, or modify state when sourced.
#
# Some output paths below are provisional and inherited from recent Toolbox practice.
# They must not be treated as final universal output policy.

toolbox_app_dir() {
  printf '%s\n' "/srv/toolbox/app"
}

toolbox_shared_dir() {
  printf '%s\n' "/srv/toolbox/shared"
}

toolbox_reports_dir() {
  # Provisional legacy path used by recent scripts.
  # Not a universal final policy for every human report.
  printf '%s\n' "/srv/toolbox/shared/reports/media"
}

toolbox_raw_dir() {
  # Provisional legacy path used by recent scripts.
  # Not a universal final policy for every TSV.
  printf '%s\n' "/srv/toolbox/shared/library-db/raw"
}

toolbox_snapshots_dir() {
  # Provisional legacy path used by recent scripts.
  # Not a universal final policy for every snapshot.
  printf '%s\n' "/srv/toolbox/shared/library-db/snapshots"
}
