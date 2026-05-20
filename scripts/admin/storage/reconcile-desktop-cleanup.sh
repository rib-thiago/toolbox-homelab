#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/desktop-cleanup-reconcile-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== DESKTOP CLEANUP RECONCILE ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Espaço atual ====="
df -hT /
echo

echo "===== 2. Estado dos grupos removidos ====="

PACKAGES=(
  thunderbird
  thunderbird-gnome-support
  thunderbird-locale-en
  thunderbird-locale-en-us
  thunderbird-locale-pt
  thunderbird-locale-pt-br
  picard
  rhythmbox
  rhythmbox-plugins
  rhythmbox-plugin-alternative-toolbar
  totem
  totem-plugins
  cheese
  shotwell
  simple-scan
  transmission-gtk
  aisleriot
  gnome-mahjongg
  gnome-mines
  gnome-sudoku
)

for pkg in "${PACKAGES[@]}"; do
  state="$(dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2>/dev/null || echo 'not-installed')"
  version="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo '-')"
  printf "%-45s %-12s %s\n" "$pkg" "$state" "$version"
done

echo
echo "Legenda:"
echo "ii  = instalado"
echo "rc  = removido, mas com configuração residual"
echo "not-installed = removido completamente ou nunca instalado"
echo

echo "===== 3. LibreOffice remanescente ====="

dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\t${Version}\n' 'libreoffice*' 2>/dev/null \
  | sort \
  || true

echo
echo "===== 4. Impressão / scanner remanescente ====="

dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\t${Version}\n' \
  'cups*' 'hplip*' 'sane*' 'printer-driver*' 'lpr' 'paps' 'foomatic*' \
  2>/dev/null \
  | sort \
  || true

echo
echo "===== 5. Pacotes instalados inesperados de impressão legada ====="

for pkg in lpr paps foomatic-filters libpaps0; do
  state="$(dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2>/dev/null || echo 'not-installed')"
  version="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo '-')"
  printf "%-25s %-12s %s\n" "$pkg" "$state" "$version"
done

echo
echo "===== 6. Pacotes rc — configuração residual ====="

dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\t${Version}\n' 2>/dev/null \
  | awk '$1 ~ /^rc/ {print}' \
  | sort \
  || true

echo
echo "===== 7. Autoremove dry-run ====="

sudo apt autoremove --purge --dry-run || true

echo
echo "===== 8. Pacotes desktop ainda instalados ====="

PATTERN='thunderbird|libreoffice|picard|rhythmbox|totem|cheese|shotwell|simple-scan|transmission|aisleriot|gnome-mahjongg|gnome-mines|gnome-sudoku|cups|hplip|sane|printer|lpr|paps|foomatic'

dpkg-query -W -f='${Installed-Size}\t${db:Status-Abbrev}\t${Package}\t${Version}\n' 2>/dev/null \
  | grep -Ei "$PATTERN" \
  | sort -nr \
  | awk '{
      printf "%.1f MB\t%-4s\t%-45s\t%s\n", $1/1024, $2, $3, $4
    }' \
  || true

echo
echo "===== 9. Verificação de serviços relacionados ====="

for svc in cups cups-browsed bluetooth saned; do
  echo "--- $svc ---"
  systemctl is-enabled "$svc" 2>/dev/null || true
  systemctl is-active "$svc" 2>/dev/null || true
done

echo
echo "===== 10. Integridade APT ====="

sudo apt check || true

echo
echo "===== 11. Próximas ações sugeridas — NÃO EXECUTADAS ====="

echo
echo "A. Se houver pacotes rc:"
echo "sudo apt purge \$(dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\n' | awk '\$1 ~ /^rc/ {print \$2}')"
echo

echo "B. Se lpr/paps/foomatic ficaram instalados e você não quer impressão:"
echo "sudo apt purge lpr paps foomatic-filters libpaps0"
echo

echo "C. Se o autoremove listar apenas dependências abandonadas:"
echo "sudo apt autoremove --purge"
echo

echo "D. Depois:"
echo "sudo apt clean"
echo

echo "===== RELATÓRIO ====="
echo "$REPORT"
