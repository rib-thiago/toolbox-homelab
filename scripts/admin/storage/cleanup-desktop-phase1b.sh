#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"

BEFORE="$OUT_DIR/desktop-cleanup-phase1b-before-$TS.txt"
AFTER="$OUT_DIR/desktop-cleanup-phase1b-after-$TS.txt"
ACTION_LOG="$OUT_DIR/desktop-cleanup-phase1b-actions-$TS.txt"

mkdir -p "$OUT_DIR"

report() {
  local target="$1"

  {
    echo "===== DESKTOP CLEANUP PHASE 1B ====="
    echo "Data: $(date)"
    echo

    echo "===== DISK ====="
    df -hT /
    echo

    echo "===== Impressão / scanner ====="

    dpkg-query -W \
      -f='${db:Status-Abbrev}\t${Package}\t${Version}\n' \
      'cups*' \
      'hplip*' \
      'sane*' \
      'printer-driver*' \
      'foomatic*' \
      'lpr' \
      'paps' \
      'libpaps0' \
      'system-config-printer*' \
      'python3-cups*' \
      'libcups*' \
      'libsane*' \
      2>/dev/null \
      | sort || true

    echo

    echo "===== RC residual ====="

    dpkg-query -W \
      -f='${db:Status-Abbrev}\t${Package}\t${Version}\n' \
      2>/dev/null \
      | awk '$1 ~ /^rc/ {print}' \
      | sort || true

    echo

    echo "===== Serviços ====="

    for svc in cups cups-browsed bluetooth saned; do
      echo "--- $svc ---"
      systemctl is-enabled "$svc" 2>/dev/null || true
      systemctl is-active "$svc" 2>/dev/null || true
    done

    echo

    echo "===== AUTOREMOVE DRY RUN ====="
    sudo apt autoremove --purge --dry-run || true

  } > "$target"
}

echo "===== GERANDO RELATÓRIO ANTES ====="
report "$BEFORE"

exec > >(tee "$ACTION_LOG") 2>&1

echo "===== DESKTOP CLEANUP PHASE 1B ====="
echo "Data: $(date)"
echo

echo "===== 1. REMOVENDO STACK DE IMPRESSÃO ====="

sudo apt purge -y \
  lpr \
  paps \
  libpaps0 \
  foomatic-filters \
  foomatic-db-compressed-ppds \
  printer-driver-brlaser \
  printer-driver-c2esp \
  printer-driver-foo2zjs \
  printer-driver-foo2zjs-common \
  printer-driver-m2300w \
  printer-driver-min12xxw \
  printer-driver-pnm2ppa \
  printer-driver-ptouch \
  printer-driver-sag-gdi \
  system-config-printer \
  system-config-printer-common \
  system-config-printer-udev \
  python3-cups \
  python3-cupshelpers

echo
echo "===== 2. REMOVENDO LIBS RESIDUAIS ====="

sudo apt purge -y \
  libsane1 \
  libsane-common \
  libcups2 \
  libcupsfilters1 || true

echo
echo "===== 3. PURGE DOS ESTADOS RC ====="

RC_PACKAGES="$(
  dpkg-query -W \
    -f='${db:Status-Abbrev} ${Package}\n' \
    2>/dev/null \
    | awk '$1 ~ /^rc/ {print $2}'
)"

if [ -n "$RC_PACKAGES" ]; then
  sudo apt purge -y $RC_PACKAGES
else
  echo "Nenhum pacote rc encontrado."
fi

echo
echo "===== 4. AUTOREMOVE ====="

sudo apt autoremove --purge -y

echo
echo "===== 5. APT CLEAN ====="

sudo apt clean

echo
echo "===== GERANDO RELATÓRIO DEPOIS ====="

report "$AFTER"

echo
echo "===== RESULTADO ====="

echo "ANTES:"
echo "$BEFORE"
echo

echo "DEPOIS:"
echo "$AFTER"
echo

echo "AÇÕES:"
echo "$ACTION_LOG"
echo

echo "===== DISK FINAL ====="

df -hT /
