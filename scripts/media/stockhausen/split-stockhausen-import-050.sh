#!/usr/bin/env bash
set -euo pipefail

SRC="/srv/media/music-staging/incoming/050 Stockhausen - Freitag aus Licht"

split_disc() {
  local disc="$1"

  mkdir -p "$SRC/split/$disc"

  (
    cd "$SRC"

    cuebreakpoints "${disc}.cue" | \
      shnsplit \
        -o flac \
        -d "$SRC/split/$disc" \
        "${disc}.flac"
  )
}

echo "Splitting CDimage2..."
split_disc "CDimage2"

echo "Splitting CDimage3..."
split_disc "CDimage3"

echo
echo "Result summary:"

find "$SRC/split" -type f -iname '*.flac' | wc -l

echo
echo "CD2:"
find "$SRC/split/CDimage2" -type f -iname '*.flac' | wc -l

echo
echo "CD3:"
find "$SRC/split/CDimage3" -type f -iname '*.flac' | wc -l
