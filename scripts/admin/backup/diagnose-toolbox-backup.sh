#!/usr/bin/env bash
set -euo pipefail

DATA="$(date +%F-%H%M%S)"
OUT_DIR="$HOME/relatorios-backup"
OUT_FILE="$OUT_DIR/diagnostico-toolbox-backup-$DATA.txt"

mkdir -p "$OUT_DIR"

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

{
section "DIAGNÓSTICO TOOLBOX PARA POLÍTICA DE BACKUP"
echo "Data: $(date)"
echo "Host: $(hostname)"
echo "Usuário: $(whoami)"

section "TAMANHO GERAL DA TOOLBOX"
sudo du -sh /srv/toolbox 2>/dev/null || true
sudo du -sh /srv/toolbox/* 2>/dev/null || true

section "ESTRUTURA DE DIRETÓRIOS - MAXDEPTH 3"
find /srv/toolbox -maxdepth 3 -type d 2>/dev/null | sort

section "APP - CÓDIGO E DOCUMENTAÇÃO"
sudo du -sh /srv/toolbox/app/* 2>/dev/null || true
find /srv/toolbox/app -maxdepth 4 -type f 2>/dev/null | sort

section "JOBS - MAIORES DIRETÓRIOS"
sudo du -sh /srv/toolbox/jobs/* 2>/dev/null | sort -h | tail -50 || true

section "SHARED - MAIORES DIRETÓRIOS/ARQUIVOS"
sudo du -sh /srv/toolbox/shared/* 2>/dev/null | sort -h | tail -50 || true

section "MODELS"
sudo du -sh /srv/toolbox/models/* 2>/dev/null || true
find /srv/toolbox/models -maxdepth 3 -type f 2>/dev/null | sort || true

section "SECRETS"
sudo du -sh /srv/toolbox/secrets/* 2>/dev/null || true
find /srv/toolbox/secrets -maxdepth 2 -type f 2>/dev/null | sort || true

section "ARQUIVOS GRANDES ACIMA DE 50MB"
find /srv/toolbox -type f -size +50M -printf "%s\t%p\n" 2>/dev/null | sort -n

section "ARQUIVOS TEMPORÁRIOS, LOGS E CACHE"
find /srv/toolbox \( \
  -iname "*.log" -o \
  -iname "*.tmp" -o \
  -iname "*.cache" -o \
  -iname "*.bak" -o \
  -iname "*~" \
\) -type f 2>/dev/null | sort

section "CANDIDATOS A ENTRAR NO BACKUP"
echo "/srv/toolbox/app"
echo "/srv/toolbox/secrets"
echo "/srv/toolbox/models  # apenas se contiver modelos próprios ou difíceis de baixar"

section "CANDIDATOS A EXCLUIR DO BACKUP"
echo "/srv/toolbox/jobs"
echo "/srv/toolbox/shared"
echo "*.log"
echo "*.tmp"
echo "*.cache"

section "RESUMO"
echo "Relatório gerado em: $OUT_FILE"

} | tee "$OUT_FILE"

echo
echo "Relatório salvo em:"
echo "$OUT_FILE"
