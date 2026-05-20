#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/home-admin-assets-audit-$TS.txt"

mkdir -p "$OUT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "===== HOME ADMIN ASSETS AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo "Home: $HOME"
echo

echo "===== 1. Scripts soltos na HOME ====="
find "$HOME" -maxdepth 1 -type f -name "*.sh" -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort
echo

echo "===== 2. Relatórios criados ====="
du -sh "$HOME"/relatorios-* 2>/dev/null || true
find "$HOME" -maxdepth 2 -type f \( -path "$HOME/relatorios-disco/*" -o -path "$HOME/relatorios-backup/*" \) \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -200
echo

echo "===== 3. Arquivos administrativos prováveis ====="
find "$HOME" -maxdepth 2 -type f \( \
  -name "*audit*" -o \
  -name "*cleanup*" -o \
  -name "*policy*" -o \
  -name "*docker*" -o \
  -name "*backup*" -o \
  -name "*homelab*" -o \
  -name "*reconcile*" -o \
  -name "*iptables*" \
\) -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort
echo

echo "===== 4. Backups e regras iptables ====="
find "$HOME" -maxdepth 3 -type f \( -name "*.rules" -o -name "*iptables*" \) \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort
echo

echo "===== 5. Git na HOME ====="
find "$HOME" -maxdepth 3 -type d -name ".git" -printf '%p\n' 2>/dev/null | sed 's|/.git$||' | sort
echo

echo "===== 6. Configs shell relevantes ====="
ls -lah "$HOME"/.bashrc "$HOME"/.bash_aliases "$HOME"/.profile "$HOME"/.tmux.conf "$HOME"/.config/starship.toml 2>/dev/null || true
echo

echo "===== 7. Sugestão bruta de itens migráveis ====="
echo "Scripts .sh em \$HOME, relatórios em relatorios-disco, backups iptables e documentação operacional são candidatos."
echo
echo "Relatório salvo em:"
echo "$REPORT"
