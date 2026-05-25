#!/usr/bin/env bash
set -euo pipefail

RAW="/srv/toolbox/shared/library-db/raw"
DB_DIR="/srv/toolbox/shared/library-db/sqlite"
DB="$DB_DIR/music-library.sqlite"

mkdir -p "$DB_DIR"

echo "===== INIT MUSIC LIBRARY SQLITE ====="
echo "DB: $DB"
echo

rm -f "$DB"

sqlite3 "$DB" <<SQL
.mode tabs
.headers on

CREATE TABLE artists (
  artist_id INTEGER PRIMARY KEY,
  artist_name TEXT NOT NULL,
  path TEXT NOT NULL,
  album_count INTEGER,
  size_bytes INTEGER
);

CREATE TABLE albums (
  album_id INTEGER PRIMARY KEY,
  artist_id INTEGER,
  artist_name TEXT,
  album_title TEXT,
  path TEXT NOT NULL,
  file_count INTEGER,
  audio_count INTEGER,
  size_bytes INTEGER
);

CREATE TABLE files (
  file_id INTEGER PRIMARY KEY,
  album_id INTEGER,
  artist_name TEXT,
  album_title TEXT,
  path TEXT NOT NULL,
  extension TEXT,
  size_bytes INTEGER,
  kind TEXT
);

CREATE TABLE staging (
  item_id INTEGER PRIMARY KEY,
  stage TEXT,
  path TEXT NOT NULL,
  depth INTEGER,
  file_count INTEGER,
  audio_count INTEGER,
  size_bytes INTEGER
);

.import --skip 1 $RAW/artists.tsv artists
.import --skip 1 $RAW/albums.tsv albums
.import --skip 1 $RAW/files.tsv files
.import --skip 1 $RAW/staging.tsv staging

CREATE INDEX idx_albums_artist ON albums(artist_name);
CREATE INDEX idx_files_album ON files(album_id);
CREATE INDEX idx_files_kind ON files(kind);
CREATE INDEX idx_staging_stage ON staging(stage);
SQL

echo "===== CONTAGENS ====="

sqlite3 "$DB" <<SQL
SELECT 'artists', COUNT(*) FROM artists;
SELECT 'albums', COUNT(*) FROM albums;
SELECT 'files', COUNT(*) FROM files;
SELECT 'audio_files', COUNT(*) FROM files WHERE kind = 'audio';
SELECT 'staging_items', COUNT(*) FROM staging;
SQL

echo
echo "===== TOP 10 ARTISTAS POR TAMANHO ====="

sqlite3 -header -column "$DB" <<SQL
SELECT artist_name,
       album_count,
       ROUND(size_bytes / 1024.0 / 1024.0 / 1024.0, 2) AS size_gb
FROM artists
ORDER BY size_bytes DESC
LIMIT 10;
SQL

echo
echo "===== TOP 10 ÁLBUNS POR TAMANHO ====="

sqlite3 -header -column "$DB" <<SQL
SELECT artist_name,
       album_title,
       audio_count,
       ROUND(size_bytes / 1024.0 / 1024.0 / 1024.0, 2) AS size_gb
FROM albums
ORDER BY size_bytes DESC
LIMIT 10;
SQL

echo
echo "Banco criado em:"
echo "$DB"
