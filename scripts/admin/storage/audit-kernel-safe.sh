#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/kernel-audit-safe-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== SAFE KERNEL AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Kernel atualmente em uso ====="
CURRENT_KERNEL="$(uname -r)"
echo "$CURRENT_KERNEL"
echo

echo "===== 2. Espaço atual ====="
df -hT
echo

echo "===== 3. Imagens de kernel instaladas ====="
dpkg -l 'linux-image*' 2>/dev/null | awk '/^ii/{print $2, $3}' | sort -V
echo

echo "===== 4. Módulos de kernel instalados ====="
dpkg -l 'linux-modules-*' 'linux-modules-extra-*' 2>/dev/null | awk '/^ii/{print $2, $3}' | sort -V
echo

echo "===== 5. Headers de kernel instalados ====="
dpkg -l 'linux-headers-*' 2>/dev/null | awk '/^ii/{print $2, $3}' | sort -V
echo

echo "===== 6. Diretórios /boot ====="
ls -lh /boot
echo

echo "===== 7. Uso de /usr/src ====="
sudo du -sh /usr/src 2>/dev/null || true
sudo du -sh /usr/src/* 2>/dev/null | sort -h || true
echo

echo "===== 8. Uso de /lib/modules ====="
sudo du -sh /lib/modules 2>/dev/null || true
sudo du -sh /lib/modules/* 2>/dev/null | sort -h || true
echo

echo "===== 9. Meta-pacotes HWE instalados ====="
dpkg -l 'linux-generic*' 'linux-image-generic*' 'linux-headers-generic*' 2>/dev/null | awk '/^ii/{print $2, $3}' | sort -V
echo

echo "===== 10. Candidatos possíveis a remoção MANUAL — NÃO EXECUTAR AINDA ====="
echo "Regra conservadora:"
echo "- manter kernel atual: $CURRENT_KERNEL"
echo "- manter também o kernel imediatamente anterior como fallback"
echo "- remover só versões bem antigas depois de revisão humana"
echo

dpkg -l 'linux-image-[0-9]*' 2>/dev/null \
  | awk '/^ii/{print $2}' \
  | sed 's/linux-image-//' \
  | sort -V \
  > /tmp/kernel-versions-installed.txt

echo "Versões de kernel detectadas:"
cat /tmp/kernel-versions-installed.txt
echo

echo "Últimas duas versões detectadas, que em princípio devem ser mantidas:"
tail -n 2 /tmp/kernel-versions-installed.txt
echo

echo "Versões mais antigas, candidatas teóricas:"
head -n -2 /tmp/kernel-versions-installed.txt || true
echo

echo "===== 11. Pacotes associados às versões candidatas teóricas ====="

for version in $(head -n -2 /tmp/kernel-versions-installed.txt || true); do
  echo
  echo "--- Kernel antigo candidato: $version ---"
  dpkg -l \
    "linux-image-$version" \
    "linux-modules-$version" \
    "linux-modules-extra-$version" \
    "linux-headers-$version" \
    2>/dev/null \
    | awk '/^ii/{print $2, $3}'
done

echo
echo "===== 12. Simulação apt autoremove ====="
sudo apt autoremove --purge --dry-run || true
echo

echo "===== 13. Relatório salvo em ====="
echo "$REPORT"
