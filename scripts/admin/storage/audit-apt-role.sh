#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/apt-role-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== APT ROLE AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Estado geral ====="
df -hT
echo

echo "===== 2. Desktop base ====="

dpkg -l \
  ubuntu-desktop \
  ubuntu-desktop-minimal \
  ubuntu-session \
  gnome-shell \
  gdm3 \
  network-manager \
  firefox \
  2>/dev/null \
  | awk '/^ii/{print $2, $3}'

echo

echo "===== 3. Aplicações desktop instaladas ====="

PATTERN='
libreoffice|
thunderbird|
rhythmbox|
totem|
cheese|
simple-scan|
shotwell|
remmina|
transmission|
vlc|
audacious|
clementine|
deadbeef|
picard|
musicbrainz|
brasero|
evolution|
aisleriot|
gnome-games|
steam|
discord|
telegram|
obs-studio|
kdenlive|
gimp|
inkscape|
blender|
virtualbox
'

dpkg-query -W -f='${Installed-Size}\t${Package}\t${Version}\n' \
  | grep -Ei "$PATTERN" \
  | sort -nr \
  | awk '{
      printf "%.1f MB\t%-40s\t%s\n",
      $1/1024,
      $2,
      $3
    }'

echo

echo "===== 4. Infraestrutura/Homelab ====="

PATTERN_INFRA='
docker|
containerd|
tailscale|
openssh|
python3|
pip|
git|
curl|
wget|
ffmpeg|
samba|
sqlite|
build-essential|
gcc|
make|
nodejs|
npm|
tesseract|
imagemagick|
poppler|
ghostscript|
jq|
tmux|
ripgrep|
fd-find|
rsync|
restic|
smartmontools|
lm-sensors|
nfs|
ufw
'

dpkg-query -W -f='${Installed-Size}\t${Package}\t${Version}\n' \
  | grep -Ei "$PATTERN_INFRA" \
  | sort -nr \
  | awk '{
      printf "%.1f MB\t%-40s\t%s\n",
      $1/1024,
      $2,
      $3
    }'

echo

echo "===== 5. Navegador e GUI mínima ====="

dpkg-query -W -f='${Installed-Size}\t${Package}\t${Version}\n' \
  | grep -Ei '
firefox|
nautilus|
gnome-terminal|
gnome-control-center|
network-manager|
gdm3|
xorg|
wayland|
mutter|
mesa
' \
  | sort -nr \
  | awk '{
      printf "%.1f MB\t%-40s\t%s\n",
      $1/1024,
      $2,
      $3
    }'

echo

echo "===== 6. Snap ativos ====="

if command -v snap >/dev/null 2>&1; then
  snap list
else
  echo "Snap não instalado."
fi

echo

echo "===== 7. Pacotes manuais (top 150 maiores) ====="

apt-mark showmanual \
  | while read pkg; do

      size="$(dpkg-query -W -f='${Installed-Size}' "$pkg" 2>/dev/null || echo 0)"
      version="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo '?')"

      printf "%s\t%s\t%s\n" "$size" "$pkg" "$version"

    done \
  | sort -nr \
  | head -150 \
  | awk '{
      printf "%.1f MB\t%-45s\t%s\n",
      $1/1024,
      $2,
      $3
    }'

echo

echo "===== 8. Pacotes órfãos potenciais ====="

sudo apt autoremove --purge --dry-run || true

echo

echo "===== 9. Serviços systemd habilitados ====="

systemctl list-unit-files --state=enabled --type=service

echo

echo "===== 10. Resumo conceitual ====="

echo "Objetivo declarado:"
echo "- notebook otimizado para homelab/servidor"
echo "- desktop apenas residual/emergencial"
echo "- manter GUI mínima de fallback"
echo "- remover aplicações desktop não essenciais"

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
