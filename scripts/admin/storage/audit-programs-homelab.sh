#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/programs-audit-$TS.txt"

mkdir -p "$OUT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "===== HOMELAB PROGRAMS AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Espaço geral ====="
df -hT
echo

echo "===== 2. Ocupação por ecossistema ====="
sudo du -sh \
  /usr \
  /opt \
  /var/cache/apt \
  /var/lib/apt/lists \
  /var/lib/snapd \
  /var/lib/flatpak \
  "$HOME/.local/share/flatpak" \
  "$HOME/.cache" \
  2>/dev/null || true
echo

echo "===== 3. Programas de interesse ====="
for cmd in nicotine nicotine-plus picard strawberry flatpak snap apt dpkg; do
  echo "--- $cmd ---"
  command -v "$cmd" || true
done
echo

echo "===== 4. APT: pacotes explicitamente instalados ====="
apt-mark showmanual | sort
echo

echo "===== 5. APT: candidatos relacionados a música/mídia/desktop ====="
dpkg-query -W -f='${Installed-Size}\t${Package}\t${Version}\n' \
  | sort -nr \
  | grep -Ei 'picard|musicbrainz|nicotine|strawberry|vlc|rhythmbox|audacious|clementine|deadbeef|media|audio|flac|mp3|gstreamer|pipewire|pulseaudio|ffmpeg|chromium|firefox|libreoffice|thunderbird|snap|flatpak' \
  || true
echo

echo "===== 6. APT: maiores pacotes instalados ====="
dpkg-query -W -f='${Installed-Size}\t${Package}\t${Version}\n' \
  | sort -nr \
  | head -80 \
  | awk '{printf "%.1f MB\t%s\t%s\n", $1/1024, $2, $3}'
echo

echo "===== 7. APT: autoremove dry-run ====="
sudo apt autoremove --purge --dry-run || true
echo

echo "===== 8. APT: pacotes atualizáveis ====="
apt list --upgradable 2>/dev/null || true
echo

echo "===== 9. Snap: lista completa ====="
if command -v snap >/dev/null 2>&1; then
  snap list --all
else
  echo "Snap não instalado."
fi
echo

echo "===== 10. Snap: revisões disabled ====="
if command -v snap >/dev/null 2>&1; then
  snap list --all | awk '/disabled/{print}'
else
  echo "Snap não instalado."
fi
echo

echo "===== 11. Flatpak: apps ====="
if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application,name,version,installation
else
  echo "Flatpak não instalado."
fi
echo

echo "===== 12. Flatpak: runtimes ====="
if command -v flatpak >/dev/null 2>&1; then
  flatpak list --runtime --columns=application,name,version,branch,installation
else
  echo "Flatpak não instalado."
fi
echo

echo "===== 13. Flatpak: unused check ====="
if command -v flatpak >/dev/null 2>&1; then
  flatpak uninstall --unused --assumeno || true
else
  echo "Flatpak não instalado."
fi
echo

echo "===== 14. AppImages e binários manuais no home ====="
find "$HOME" \
  -xdev \
  \( -iname '*.AppImage' -o -iname '*picard*' -o -iname '*nicotine*' -o -iname '*strawberry*' \) \
  -printf "%s\t%p\n" 2>/dev/null \
  | sort -nr \
  | awk '{printf "%.2f MB\t%s\n", $1/1024/1024, $2}'
echo

echo "===== 15. Entradas desktop do usuário e sistema ====="
find "$HOME/.local/share/applications" /usr/share/applications \
  -iname '*picard*' -o -iname '*nicotine*' -o -iname '*strawberry*' \
  2>/dev/null || true
echo

echo "===== 16. Resumo interpretativo bruto ====="
echo "Relatório salvo em:"
echo "$REPORT"
