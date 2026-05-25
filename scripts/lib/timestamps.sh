#!/usr/bin/env bash
set -u

# Toolbox shared timestamp helpers.
#
# This file is intended to be sourced by Toolbox scripts.
# It must not execute actions, print output, create files, or modify state when sourced.

toolbox_timestamp() {
  date '+%Y%m%d-%H%M%S'
}

toolbox_now() {
  date '+%Y-%m-%d %H:%M:%S'
}
