#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"

BEFORE="$OUT_DIR/light-cleanup-before-$TS.txt"
AFTER="$OUT_DIR/light-cleanup-after-$TS.txt"
ACTION_LOG="$OUT_DIR/light-cleanup-actions-$TS.txt"

mkdir -p "$OUT_DIR"

report() {
  local target="$1"

  {
    echo "===== LIGHT CLEANUP REPORT ====="
    echo "Data: $(date)"
    echo

    echo "===== DISK ====="
    df -hT
    echo

    echo "===== SNAP ====="
    sudo du -sh /var/lib/snapd 2>/dev/null || true
    echo

    if command -v snap >/dev/null 2>&1; then
      snap list --all
    fi

    echo
    echo "===== FLATPAK ====="
    sudo du -sh /var/lib/flatpak 2>/dev/null || true
    echo

    if command -v flatpak >/dev/null 2>&1; then
      flatpak list
    fi

    echo
    echo "===== CACHE ====="
    du -sh "$HOME/.cache" 2>/dev/null || true
    sudo du -sh /var/cache/apt 2>/dev/null || true

  } > "$target"
}

echo "===== GERANDO RELATÓRIO ANTES ====="
report "$BEFORE"

echo "===== INICIANDO LIMPEZA =====" | tee "$ACTION_LOG"

echo
echo "--- Flatpak apps ---" | tee -a "$ACTION_LOG"

if flatpak list | grep -q org.nicotine_plus.Nicotine; then
  echo "Removendo Nicotine+" | tee -a "$ACTION_LOG"
  flatpak uninstall -y org.nicotine_plus.Nicotine | tee -a "$ACTION_LOG"
fi

if flatpak list | grep -q org.strawberrymusicplayer.strawberry; then
  echo "Removendo Strawberry" | tee -a "$ACTION_LOG"
  flatpak uninstall -y org.strawberrymusicplayer.strawberry | tee -a "$ACTION_LOG"
fi

echo
echo "--- Flatpak runtimes órfãos ---" | tee -a "$ACTION_LOG"

flatpak uninstall -y --unused | tee -a "$ACTION_LOG" || true

echo
echo "--- Snap disabled revisions ---" | tee -a "$ACTION_LOG"

if command -v snap >/dev/null 2>&1; then

  snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do

    if [ -n "${snapname:-}" ] && [ -n "${revision:-}" ]; then
      echo "Removendo revisão disabled: $snapname rev $revision" | tee -a "$ACTION_LOG"
      sudo snap remove "$snapname" --revision="$revision" | tee -a "$ACTION_LOG" || true
    fi

  done
fi

echo
echo "--- Cache apt ---" | tee -a "$ACTION_LOG"

sudo apt clean | tee -a "$ACTION_LOG"

echo
echo "--- Cache usuário ---" | tee -a "$ACTION_LOG"

rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true

echo
echo "===== GERANDO RELATÓRIO DEPOIS ====="

report "$AFTER"

echo
echo "===== RESULTADO ====="

echo "Antes:"
echo "$BEFORE"
echo

echo "Depois:"
echo "$AFTER"
echo

echo "Ações:"
echo "$ACTION_LOG"
echo

echo "===== COMPARAÇÃO RÁPIDA ====="

df -hT
