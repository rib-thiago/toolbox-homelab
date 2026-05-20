#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/homelab-identity-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== HOMELAB IDENTITY AUDIT ====="
echo "Data: $(date)"
echo "Host atual: $(hostname)"
echo

echo "===== 1. Hostname ====="

hostnamectl || true

echo
echo "===== 2. Usuário atual ====="

whoami
id
groups

echo
echo "===== 3. Usuários locais ====="

getent passwd | awk -F: '
{
  printf "%-20s UID=%-6s GID=%-6s SHELL=%-25s HOME=%s\n",
  $1, $3, $4, $7, $6
}
'

echo
echo "===== 4. Usuários humanos prováveis ====="

awk -F: '$3 >= 1000 && $1 != "nobody" {
  printf "%-20s UID=%-6s GID=%-6s HOME=%s SHELL=%s\n",
  $1, $3, $4, $6, $7
}' /etc/passwd

echo
echo "===== 5. Grupos importantes ====="

for grp in sudo docker sambashare adm video audio render plugdev netdev; do
  echo "--- $grp ---"
  getent group "$grp" || true
done

echo
echo "===== 6. Memberships detalhadas ====="

for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
  echo
  echo "USER: $user"
  id "$user"
done

echo
echo "===== 7. Ownership /srv ====="

sudo find /srv \
  -maxdepth 2 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -300

echo
echo "===== 8. Ownership media ====="

sudo find /srv/media \
  -maxdepth 2 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -300

echo
echo "===== 9. Ownership compose ====="

sudo find /srv/compose \
  -maxdepth 2 \
  -printf '%u:%g %m %p\n' \
  2>/dev/null \
  | sort \
  | head -300

echo
echo "===== 10. ACLs não triviais ====="

sudo getfacl -R /srv 2>/dev/null \
  | grep -E '^# file:|^user:|^group:' \
  | head -400 || true

echo
echo "===== 11. Docker socket ====="

ls -lah /var/run/docker.sock
echo

stat /var/run/docker.sock || true

echo
echo "===== 12. Serviços escutando como root ====="

sudo ss -tulpn

echo
echo "===== 13. Sudoers ====="

sudo grep -R . /etc/sudoers /etc/sudoers.d 2>/dev/null || true

echo
echo "===== 14. Samba ====="

test -f /etc/samba/smb.conf && cat /etc/samba/smb.conf || true

echo
echo "===== 15. UIDs/GIDs relevantes ====="

for path in \
  /srv/media \
  /srv/compose \
  /srv/toolbox \
  /home/thiago
do
  echo
  echo "--- $path ---"
  stat -c '%U:%G %u:%g %a %n' "$path" 2>/dev/null || true
done

echo
echo "===== 16. Home do usuário ====="

du -sh "$HOME" 2>/dev/null || true

find "$HOME" \
  -maxdepth 1 \
  -printf '%u:%g %m %p\n' \
  | sort

echo
echo "===== 17. Shell atual ====="

echo "$SHELL"

echo
echo "===== 18. Bash startup ====="

ls -lah ~/.bashrc ~/.bash_aliases ~/.profile ~/.config/starship.toml 2>/dev/null || true

echo
echo "===== RELATÓRIO ====="
echo "$REPORT"
