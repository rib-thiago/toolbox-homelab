#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/storage-investigation-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== HOMELAB STORAGE INVESTIGATION ====="
echo "Data: $(date)"
echo

echo "===== 1. Estado atual do disco ====="
df -hT
echo

echo "===== 2. music-staging/.deleted ====="

if [ -d /srv/media/music-staging/.deleted ]; then
  sudo du -xh --max-depth=3 /srv/media/music-staging/.deleted 2>/dev/null | sort -h
else
  echo "Diretório inexistente."
fi

echo
echo "===== 3. Arquivos gigantes em music-staging/.deleted ====="

if [ -d /srv/media/music-staging/.deleted ]; then
  sudo find /srv/media/music-staging/.deleted \
    -type f \
    -printf "%s %p\n" 2>/dev/null \
    | sort -nr \
    | head -100 \
    | awk '{printf "%.2f GB  %s\n", $1/1024/1024/1024, $2}'
else
  echo "Diretório inexistente."
fi

echo
echo "===== 4. WAL do Navidrome ====="

if [ -d /srv/data/navidrome ]; then
  ls -lh /srv/data/navidrome/navidrome.db*
else
  echo "Diretório Navidrome inexistente."
fi

echo
echo "===== 5. Processo usando WAL ====="

sudo lsof /srv/data/navidrome/navidrome.db* 2>/dev/null || true

echo
echo "===== 6. SQLite integrity check ====="

if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 /srv/data/navidrome/navidrome.db "PRAGMA integrity_check;" || true
else
  echo "sqlite3 não instalado."
fi

echo
echo "===== 7. Docker images dangling ====="

docker images -f "dangling=true"

echo
echo "===== 8. Docker build cache detalhado ====="

docker builder prune --dry-run 2>/dev/null || true

echo
echo "===== 9. Snap revisions ====="

if command -v snap >/dev/null 2>&1; then
  snap list --all
else
  echo "snap não instalado."
fi

echo
echo "===== 10. Snap disabled revisions ====="

if command -v snap >/dev/null 2>&1; then
  snap list --all | awk '/disabled/{print $1, $3}'
else
  echo "snap não instalado."
fi

echo
echo "===== 11. Flatpak runtimes ====="

if command -v flatpak >/dev/null 2>&1; then
  flatpak list
else
  echo "flatpak não instalado."
fi

echo
echo "===== 12. Flatpak unused ====="

if command -v flatpak >/dev/null 2>&1; then
  flatpak uninstall --unused --assumeno || true
else
  echo "flatpak não instalado."
fi

echo
echo "===== 13. Caches grandes ====="

find "$HOME/.cache" \
  -maxdepth 2 \
  -mindepth 1 \
  -type d \
  -exec du -sh {} + 2>/dev/null \
  | sort -h \
  | tail -50

echo
echo "===== 14. Journald ====="

journalctl --disk-usage || true

echo
echo "===== 15. Pacotes não atualizados ====="

apt list --upgradable 2>/dev/null || true

echo
echo "===== RELATÓRIO SALVO EM ====="
echo "$REPORT"
