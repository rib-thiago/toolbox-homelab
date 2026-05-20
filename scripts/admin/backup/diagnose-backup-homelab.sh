#!/usr/bin/env bash
set -euo pipefail

DATA="$(date +%F-%H%M%S)"
OUT_DIR="$HOME/relatorios-backup"
OUT_FILE="$OUT_DIR/diagnostico-backup-homelab-$DATA.txt"

mkdir -p "$OUT_DIR"

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

{
section "DIAGNÓSTICO DE BACKUP DO HOMELAB"
echo "Data: $(date)"
echo "Host: $(hostname)"
echo "Usuário: $(whoami)"

section "ESPAÇO GERAL"
df -h

section "ESPAÇO DOCKER"
docker system df || true

section "CONTAINERS ATIVOS"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true

section "DIRETÓRIOS PRINCIPAIS EM /srv"
sudo du -sh /srv/* 2>/dev/null || true

section "DIRETÓRIOS DE MÍDIA"
sudo du -sh /srv/media/* 2>/dev/null || true

section "DIRETÓRIOS DE COMPOSE"
sudo du -sh /srv/compose/* 2>/dev/null || true

section "DIRETÓRIOS DE DADOS"
sudo du -sh /srv/data/* 2>/dev/null || true

section "TOOLBOX"
sudo du -sh /srv/toolbox/* 2>/dev/null || true

section "ARQUIVOS DE CONFIGURAÇÃO IMPORTANTES"
find /srv/compose -maxdepth 3 -type f \( \
  -name "docker-compose.yml" -o \
  -name "compose.yml" -o \
  -name ".env" -o \
  -name "*.yml" -o \
  -name "*.yaml" \
\) 2>/dev/null | sort

section "CONFIGURAÇÕES DO HOMEPAGE"
find /srv/data/homepage -maxdepth 2 -type f 2>/dev/null | sort || true

section "CONFIGURAÇÕES DO MONITORING"
find /srv/compose/monitoring -maxdepth 2 -type f 2>/dev/null | sort || true

section "CONFIGURAÇÕES DO SAMBA"
find /srv/compose/samba -maxdepth 2 -type f 2>/dev/null | sort || true

section "INVENTÁRIO TEXTUAL DE /srv/media"
find /srv/media -maxdepth 4 -type d 2>/dev/null | sort | head -n 5000

section "POSSÍVEIS PLANILHAS, CATÁLOGOS E DOCUMENTOS"
find /srv /home/thiago -type f \( \
  -iname "*.xlsx" -o \
  -iname "*.ods" -o \
  -iname "*.csv" -o \
  -iname "*.txt" -o \
  -iname "*.md" -o \
  -iname "*.pdf" \
\) 2>/dev/null | sort | head -n 5000

section "RESUMO FINAL"
echo "Relatório gerado em: $OUT_FILE"

} | tee "$OUT_FILE"

echo
echo "Relatório salvo em:"
echo "$OUT_FILE"
