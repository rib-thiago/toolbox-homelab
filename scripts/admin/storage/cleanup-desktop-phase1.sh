#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"

BEFORE="$OUT_DIR/desktop-cleanup-before-$TS.txt"
AFTER="$OUT_DIR/desktop-cleanup-after-$TS.txt"
ACTION_LOG="$OUT_DIR/desktop-cleanup-actions-$TS.txt"

mkdir -p "$OUT_DIR"

report() {
  local target="$1"

  {
    echo "===== DESKTOP CLEANUP REPORT ====="
    echo "Data: $(date)"
    echo

    echo "===== DISK ====="
    df -hT
    echo

    echo "===== INSTALLED DESKTOP APPS ====="

    dpkg -l \
      thunderbird \
      libreoffice\* \
      picard \
      rhythmbox \
      totem \
      cheese \
      shotwell \
      transmission-gtk \
      simple-scan \
      cups\* \
      hplip\* \
      sane\* \
      aisleriot \
      gnome-mahjongg \
      gnome-mines \
      gnome-sudoku \
      2>/dev/null \
      | awk '/^ii/{print $2, $3}'

    echo

    echo "===== SNAP ====="
    snap list || true
    echo

    echo "===== AUTOREMOVE DRY RUN ====="
    sudo apt autoremove --purge --dry-run || true

  } > "$target"
}

echo "===== GERANDO RELATÓRIO ANTES ====="
report "$BEFORE"

exec > >(tee "$ACTION_LOG") 2>&1

echo "===== DESKTOP CLEANUP PHASE 1 ====="
echo "Data: $(date)"
echo

echo "===== 1. REMOVENDO APLICAÇÕES DESKTOP ====="

sudo apt purge -y \
  thunderbird \
  picard \
  rhythmbox \
  totem \
  cheese \
  shotwell \
  transmission-gtk \
  simple-scan \
  aisleriot \
  gnome-mahjongg \
  gnome-mines \
  gnome-sudoku

echo
echo "===== 2. REMOVENDO LIBREOFFICE ====="

sudo apt purge -y \
  libreoffice\* || true

echo
echo "===== 3. REMOVENDO IMPRESSÃO/SCANNER ====="

sudo apt purge -y \
  cups\* \
  hplip\* \
  sane\* || true

echo
echo "===== 4. AUTOREMOVE CONTROLADO ====="

sudo apt autoremove --purge -y

echo
echo "===== 5. LIMPEZA APT ====="

sudo apt clean

echo
echo "===== GERANDO RELATÓRIO DEPOIS ====="

report "$AFTER"

echo
echo "===== RESULTADO ====="

echo "Relatório ANTES:"
echo "$BEFORE"
echo

echo "Relatório DEPOIS:"
echo "$AFTER"
echo

echo "Log de ações:"
echo "$ACTION_LOG"
echo

echo "===== DISK FINAL ====="
df -hT
