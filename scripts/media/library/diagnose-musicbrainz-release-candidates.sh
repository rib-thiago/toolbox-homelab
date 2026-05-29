#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/tsv.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

STAGING_DIR="/srv/media/music-staging/reviewing"
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
ALBUM_DIR="${1:-$DEFAULT_ALBUM}"
ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/musicbrainz_release_candidates_diagnosis_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$RAW_DIR/musicbrainz_release_candidates_diagnosis_${SAFE_ALBUM_NAME}_$STAMP.tsv"

USER_AGENT="ToolboxHomelab/0.1 (https://github.com/rib-thiago/toolbox-homelab)"

require_function() {
  local fn="$1"

  if ! declare -F "$fn" >/dev/null 2>&1; then
    printf '%s\n' "[ERRO] Required function not found: $fn" >&2
    exit 1
  fi
}

require_lib_contract() {
  require_function log
  require_function fail
  require_function toolbox_timestamp
  require_function toolbox_now
  require_function toolbox_shared_dir
}

latest_file() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

main() {
  local diagnosis_tsv

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  diagnosis_tsv="$(latest_file "$RAW_DIR" "music_staging_album_tags_diagnosis_${SAFE_ALBUM_NAME}_*.tsv")"

  if [ -z "$diagnosis_tsv" ] || [ ! -f "$diagnosis_tsv" ]; then
    fail "No album tags diagnosis TSV found for: $SAFE_ALBUM_NAME"
  fi

  log "Starting MusicBrainz release candidates diagnosis."

  python3 - "$diagnosis_tsv" "$REPORT" "$TSV" "$ALBUM_DIR" "$ALBUM_NAME" "$USER_AGENT" <<'PY'
import csv
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

diagnosis_tsv = Path(sys.argv[1])
report_path = Path(sys.argv[2])
tsv_path = Path(sys.argv[3])
album_dir = sys.argv[4]
album_name = sys.argv[5]
user_agent = sys.argv[6]

MB_BASE = "https://musicbrainz.org/ws/2"
REQUEST_SLEEP_SECONDS = 1.1
SEARCH_LIMIT = 25

ERRORS: list[str] = []


def now_line() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


def normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFKD", value or "")
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def parse_duration(value: str) -> float | None:
    if not value:
        return None
    value = value.replace(",", ".")
    try:
        return float(value)
    except ValueError:
        return None


def read_local_tracks(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            rows.append(row)
    return rows


def unique_values(rows: list[dict[str, Any]], key: str) -> list[str]:
    values = sorted({(row.get(key) or "").strip() for row in rows if (row.get(key) or "").strip()})
    return values


def local_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    tracks = []
    for row in rows:
        title = row.get("title", "")
        tracknumber = row.get("tracknumber", "")
        duration = parse_duration(row.get("ffprobe_duration_seconds", ""))
        tracks.append(
            {
                "tracknumber": tracknumber,
                "title": title,
                "title_norm": normalize_text(title),
                "duration": duration,
                "file_name": row.get("file_name", ""),
            }
        )

    return {
        "track_count": len(rows),
        "albums": unique_values(rows, "album"),
        "artists": unique_values(rows, "artist"),
        "albumartists": unique_values(rows, "albumartist"),
        "dates": unique_values(rows, "date"),
        "tracks": tracks,
    }


def mb_get_json(endpoint: str, params: dict[str, str]) -> dict[str, Any]:
    url = f"{MB_BASE}/{endpoint}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": user_agent,
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read().decode("utf-8")
        return json.loads(data)


def search_releases(query: str) -> list[dict[str, Any]]:
    try:
        result = mb_get_json(
            "release/",
            {
                "query": query,
                "fmt": "json",
                "limit": str(SEARCH_LIMIT),
            },
        )
        time.sleep(REQUEST_SLEEP_SECONDS)
        return result.get("releases", []) or []
    except Exception as exc:
        ERRORS.append(f"search failed for query={query!r}: {exc}")
        return []


def lookup_release(release_id: str) -> dict[str, Any] | None:
    try:
        result = mb_get_json(
            f"release/{release_id}",
            {
                "inc": "media+recordings+artist-credits+labels",
                "fmt": "json",
            },
        )
        time.sleep(REQUEST_SLEEP_SECONDS)
        return result
    except Exception as exc:
        ERRORS.append(f"lookup failed for release_id={release_id}: {exc}")
        return None


def artist_credit_name(release: dict[str, Any]) -> str:
    parts = []
    for item in release.get("artist-credit", []) or []:
        if isinstance(item, dict):
            artist = item.get("artist", {}) or {}
            parts.append(artist.get("name") or item.get("name") or "")
            if item.get("joinphrase"):
                parts.append(item.get("joinphrase", ""))
        elif isinstance(item, str):
            parts.append(item)
    return "".join(parts).strip()


def release_tracks(release: dict[str, Any]) -> list[dict[str, Any]]:
    tracks: list[dict[str, Any]] = []

    for medium in release.get("media", []) or []:
        medium_position = medium.get("position", "")
        for track in medium.get("tracks", []) or []:
            title = track.get("title", "")
            length_ms = track.get("length")
            duration = None
            if isinstance(length_ms, int):
                duration = length_ms / 1000.0
            recording = track.get("recording", {}) or {}
            tracks.append(
                {
                    "medium_position": medium_position,
                    "position": track.get("position", ""),
                    "number": track.get("number", ""),
                    "title": title,
                    "title_norm": normalize_text(title),
                    "duration": duration,
                    "recording_id": recording.get("id", ""),
                }
            )

    return tracks


def compare_titles(local_tracks: list[dict[str, Any]], mb_tracks: list[dict[str, Any]]) -> tuple[int, str]:
    local_titles = [track["title_norm"] for track in local_tracks]
    mb_titles = [track["title_norm"] for track in mb_tracks]

    matched = 0
    comparisons = []

    for idx, local_title in enumerate(local_titles):
        mb_title = mb_titles[idx] if idx < len(mb_titles) else ""
        ok = local_title == mb_title and bool(local_title)
        if ok:
            matched += 1
        comparisons.append(f"{idx + 1}:{'OK' if ok else 'DIFF'} local={local_title!r} mb={mb_title!r}")

    return matched, " | ".join(comparisons)


def compare_durations(local_tracks: list[dict[str, Any]], mb_tracks: list[dict[str, Any]]) -> tuple[str, str]:
    deltas = []
    total_abs_delta = 0.0
    comparable = 0

    for idx, local_track in enumerate(local_tracks):
        local_duration = local_track.get("duration")
        mb_duration = mb_tracks[idx].get("duration") if idx < len(mb_tracks) else None

        if local_duration is None or mb_duration is None:
            deltas.append(f"{idx + 1}:NA")
            continue

        delta = float(local_duration) - float(mb_duration)
        comparable += 1
        total_abs_delta += abs(delta)
        deltas.append(f"{idx + 1}:{delta:.1f}s")

    if comparable == 0:
        return "", "no comparable durations"

    return f"{total_abs_delta:.1f}", " | ".join(deltas)


def first_release_date(release: dict[str, Any]) -> str:
    return release.get("date", "") or ""


def format_media(release: dict[str, Any]) -> str:
    values = []
    for medium in release.get("media", []) or []:
        fmt = medium.get("format", "")
        if fmt:
            values.append(fmt)
    return ";".join(sorted(set(values)))


def label_info(release: dict[str, Any]) -> str:
    infos = []
    for label_info_item in release.get("label-info", []) or []:
        label = label_info_item.get("label", {}) or {}
        name = label.get("name", "")
        catalog_number = label_info_item.get("catalog-number", "")
        if name or catalog_number:
            infos.append(f"{name} {catalog_number}".strip())
    return "; ".join(infos)


def score_candidate(search_release: dict[str, Any], full_release: dict[str, Any], local: dict[str, Any]) -> dict[str, Any]:
    mb_tracks = release_tracks(full_release)
    local_tracks = local["tracks"]

    track_count_match = len(mb_tracks) == local["track_count"]
    title_matches, title_comparison = compare_titles(local_tracks, mb_tracks)
    duration_delta_sum, duration_comparison = compare_durations(local_tracks, mb_tracks)

    score = 0
    if track_count_match:
        score += 40
    score += min(title_matches * 8, 48)

    if duration_delta_sum:
        try:
            delta = float(duration_delta_sum)
            if delta <= 10:
                score += 12
            elif delta <= 30:
                score += 8
            elif delta <= 60:
                score += 4
        except ValueError:
            pass

    release_date = first_release_date(full_release)
    local_dates = local["dates"]
    date_relation = ""
    if local_dates and release_date:
        if any(release_date.startswith(d) or d.startswith(release_date) for d in local_dates):
            date_relation = "local_date_matches_release_date"
            score += 5
        else:
            date_relation = f"local_date_differs local={';'.join(local_dates)} mb={release_date}"
    elif local_dates:
        date_relation = f"local_date={';'.join(local_dates)} mb_date_missing"
    else:
        date_relation = f"local_date_missing mb={release_date}"

    return {
        "candidate_score": score,
        "mbid": full_release.get("id", ""),
        "mb_score": search_release.get("score", ""),
        "title": full_release.get("title", ""),
        "artist_credit": artist_credit_name(full_release),
        "date": release_date,
        "country": full_release.get("country", ""),
        "status": full_release.get("status", ""),
        "barcode": full_release.get("barcode", ""),
        "format": format_media(full_release),
        "label_info": label_info(full_release),
        "track_count": str(len(mb_tracks)),
        "track_count_match": "yes" if track_count_match else "no",
        "title_matches": str(title_matches),
        "duration_delta_sum_seconds": duration_delta_sum,
        "duration_comparison": duration_comparison,
        "title_comparison": title_comparison,
        "date_relation": date_relation,
    }


def build_queries(local: dict[str, Any]) -> list[str]:
    artists = local["albumartists"] or local["artists"] or ["Pharoah Sanders"]
    albums = local["albums"] or ["Thembi"]

    queries = []

    for artist in artists:
        for album in albums:
            queries.append(f'artist:"{artist}" AND release:"{album}"')
            queries.append(f'artist:"{artist}" AND release:{album}')

    for album in albums:
        queries.append(f'release:"{album}"')
        queries.append(album)

    # Preserve order while deduplicating.
    seen = set()
    unique = []
    for query in queries:
        if query not in seen:
            seen.add(query)
            unique.append(query)
    return unique


def write_tsv(path: Path, rows: list[dict[str, Any]]) -> None:
    fieldnames = [
        "rank",
        "candidate_score",
        "mbid",
        "mb_score",
        "title",
        "artist_credit",
        "date",
        "country",
        "status",
        "barcode",
        "format",
        "label_info",
        "track_count",
        "track_count_match",
        "title_matches",
        "duration_delta_sum_seconds",
        "date_relation",
        "duration_comparison",
        "title_comparison",
    ]

    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, delimiter="\t", fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for idx, row in enumerate(rows, start=1):
            out = dict(row)
            out["rank"] = str(idx)
            writer.writerow(out)


def write_report(path: Path, local: dict[str, Any], queries: list[str], candidates: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8") as f:
        f.write("# MusicBrainz Release Candidates Diagnosis\n\n")
        f.write(f"Generated at: {now_line()}\n")
        f.write(f"Album directory: {album_dir}\n")
        f.write(f"Album name: {album_name}\n")
        f.write(f"Diagnosis TSV: {diagnosis_tsv}\n")
        f.write(f"Report: {report_path}\n")
        f.write(f"TSV: {tsv_path}\n\n")
        f.write("Safety: diagnosis only. This script queries MusicBrainz and does not write tags, run Beets, move files, copy files or modify staging/library.\n\n")

        f.write("## Local summary\n\n")
        f.write("```text\n")
        f.write(f"Track count: {local['track_count']}\n")
        f.write(f"ALBUM: {';'.join(local['albums'])}\n")
        f.write(f"ARTIST: {';'.join(local['artists'])}\n")
        f.write(f"ALBUMARTIST: {';'.join(local['albumartists'])}\n")
        f.write(f"DATE: {';'.join(local['dates'])}\n")
        for track in local["tracks"]:
            f.write(f"{track['tracknumber']} | {track['title']} | {track['duration']}s\n")
        f.write("```\n\n")

        f.write("## Queries\n\n")
        f.write("```text\n")
        for query in queries:
            f.write(f"{query}\n")
        f.write("```\n\n")

        f.write("## Candidate ranking\n\n")
        f.write("```text\n")
        if not candidates:
            f.write("No candidates found.\n")
        else:
            for idx, candidate in enumerate(candidates, start=1):
                f.write(
                    f"{idx}. score={candidate['candidate_score']} "
                    f"mbid={candidate['mbid']} "
                    f"title={candidate['title']} "
                    f"artist={candidate['artist_credit']} "
                    f"date={candidate['date']} "
                    f"country={candidate['country']} "
                    f"tracks={candidate['track_count']} "
                    f"track_count_match={candidate['track_count_match']} "
                    f"title_matches={candidate['title_matches']} "
                    f"duration_delta={candidate['duration_delta_sum_seconds']}\n"
                )
        f.write("```\n\n")

        f.write("## Errors / warnings\n\n")
        f.write("```text\n")
        if ERRORS:
            for error in ERRORS:
                f.write(error + "\n")
        else:
            f.write("No request errors recorded.\n")
        f.write("```\n\n")

        f.write("## Interpretation hints\n\n")
        f.write("- Prefer candidates with track_count_match=yes, high title_matches and low duration_delta_sum_seconds.\n")
        f.write("- DATE mismatch is not automatically fatal; it may indicate original release vs reissue.\n")
        f.write("- The next phase should plan a Beets dry-run using the best candidate MBID, still with -C -W.\n\n")

        f.write("Generated artifacts:\n")
        f.write(f"- Report: {report_path}\n")
        f.write(f"- TSV: {tsv_path}\n")


local_rows = read_local_tracks(diagnosis_tsv)
local = local_summary(local_rows)
queries = build_queries(local)

search_results_by_id: dict[str, dict[str, Any]] = {}

for query in queries:
    for release in search_releases(query):
        release_id = release.get("id")
        if release_id and release_id not in search_results_by_id:
            search_results_by_id[release_id] = release

candidate_rows: list[dict[str, Any]] = []

for release_id, search_release in search_results_by_id.items():
    full_release = lookup_release(release_id)
    if not full_release:
        continue
    candidate_rows.append(score_candidate(search_release, full_release, local))

candidate_rows.sort(
    key=lambda row: (
        int(row.get("candidate_score") or 0),
        int(row.get("mb_score") or 0) if str(row.get("mb_score") or "").isdigit() else 0,
    ),
    reverse=True,
)

write_tsv(tsv_path, candidate_rows)
write_report(report_path, local, queries, candidate_rows)

print(f"Candidates found: {len(candidate_rows)}")
print(f"Report: {report_path}")
print(f"TSV: {tsv_path}")
PY

  log "MusicBrainz release candidates diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
