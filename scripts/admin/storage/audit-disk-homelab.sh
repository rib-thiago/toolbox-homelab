#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/disk-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== HOMELAB DISK AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Filesystems ====="
df -hT
echo

echo "===== 2. Uso geral de /srv ====="
sudo du -xh --max-depth=2 /srv 2>/dev/null | sort -h
echo

echo "===== 3. Maiores diretórios em /srv ====="
sudo du -xh --max-depth=1 /srv 2>/dev/null | sort -h
echo

echo "===== 4. Maiores diretórios em /srv/media ====="
sudo du -xh --max-depth=2 /srv/media 2>/dev/null | sort -h
echo

echo "===== 5. Maiores diretórios em /srv/data ====="
sudo du -xh --max-depth=2 /srv/data 2>/dev/null | sort -h
echo

echo "===== 6. Maiores diretórios Docker ====="
sudo du -xh --max-depth=2 /var/lib/docker 2>/dev/null | sort -h
echo

echo "===== 7. Docker system df ====="
docker system df
echo

echo "===== 8. Docker system df verbose ====="
docker system df -v
echo

echo "===== 9. Volumes Docker ====="
docker volume ls
echo

echo "===== 10. Imagens Docker ====="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
echo

echo "===== 11. Containers parados ====="
docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo

echo "===== 12. Logs grandes de containers ====="
sudo find /var/lib/docker/containers -name "*-json.log" -type f -printf "%s %p\n" 2>/dev/null \
  | sort -nr \
  | head -30 \
  | awk '{printf "%.2f MB  %s\n", $1/1024/1024, $2}'
echo

echo "===== 13. APT cache ====="
sudo du -sh /var/cache/apt /var/lib/apt/lists 2>/dev/null || true
echo

echo "===== 14. Pacotes órfãos APT ====="
apt-mark showauto >/tmp/apt-auto.txt 2>/dev/null || true
sudo apt autoremove --dry-run || true
echo

echo "===== 15. Snap ====="
if command -v snap >/dev/null 2>&1; then
  snap list
  echo
  sudo du -sh /var/lib/snapd 2>/dev/null || true
else
  echo "Snap não instalado."
fi
echo

echo "===== 16. Flatpak ====="
if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application,version,installation
  echo
  flatpak uninstall --unused --dry-run || true
  echo
  sudo du -sh /var/lib/flatpak ~/.local/share/flatpak 2>/dev/null || true
else
  echo "Flatpak não instalado."
fi
echo

echo "===== 17. Caches de usuário ====="
du -sh ~/.cache ~/.local/share/Trash 2>/dev/null || true
echo

echo "===== 18. Arquivos grandes em /srv ====="
sudo find /srv -xdev -type f -size +1G -printf "%s %p\n" 2>/dev/null \
  | sort -nr \
  | head -50 \
  | awk '{printf "%.2f GB  %s\n", $1/1024/1024/1024, $2}'
echo

echo "===== 19. Arquivos grandes em /home/thiago ====="
find "$HOME" -xdev -type f -size +1G -printf "%s %p\n" 2>/dev/null \
  | sort -nr \
  | head -50 \
  | awk '{printf "%.2f GB  %s\n", $1/1024/1024/1024, $2}'
echo

echo "===== RELATÓRIO SALVO EM ====="
echo "$REPORT"
