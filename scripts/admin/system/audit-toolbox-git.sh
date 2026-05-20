#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

APP="/srv/toolbox/app"
OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/toolbox-git-audit-$TS.txt"

mkdir -p "$OUT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "===== TOOLBOX GIT AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo "Repo: $APP"
echo

if [ ! -d "$APP/.git" ]; then
  echo "ERRO: não há repositório Git em $APP"
  exit 1
fi

cd "$APP"

echo "===== 1. Status geral ====="
git status
echo

echo "===== 2. Branch atual ====="
git branch --show-current
echo

echo "===== 3. Remotes ====="
git remote -v || true
echo

echo "===== 4. Arquivos não rastreados ====="
git ls-files --others --exclude-standard
echo

echo "===== 5. Arquivos modificados ====="
git diff --name-status
echo

echo "===== 6. Arquivos staged ====="
git diff --cached --name-status
echo

echo "===== 7. Últimos commits ====="
git log --oneline --decorate --graph -20
echo

echo "===== 8. .gitignore ====="
if [ -f .gitignore ]; then
  cat .gitignore
else
  echo "Sem .gitignore"
fi
echo

echo "===== 9. Itens suspeitos no root do repo ====="
find "$APP" -maxdepth 1 -mindepth 1 \
  ! -name ".git" \
  -printf '%M %u:%g %s %p\n' \
  | sort
echo

echo "===== 10. Tamanho por diretório ====="
du -sh "$APP"/* "$APP"/.[!.]* 2>/dev/null | sort -h
echo

echo "===== 11. Arquivos grandes no repo ====="
find "$APP" -type f \
  ! -path "$APP/.git/*" \
  -size +5M \
  -printf '%s %p\n' \
  | sort -nr \
  | awk '{printf "%.2f MB\t%s\n", $1/1024/1024, $2}'
echo

echo "===== 12. Candidatos a ignorar ====="
find "$APP" -type f \
  \( \
    -name "*.log" -o \
    -name "*.tmp" -o \
    -name "*.bak" -o \
    -name "*.swp" -o \
    -name "*.pyc" -o \
    -name ".DS_Store" \
  \) \
  ! -path "$APP/.git/*" \
  -printf '%p\n' \
  | sort
echo

echo "===== 13. Diretórios candidatos a artefato ====="
find "$APP" -maxdepth 3 -type d \
  \( \
    -name "git-reports" -o \
    -name "reports" -o \
    -name "logs" -o \
    -name "tmp" -o \
    -name "__pycache__" \
  \) \
  -printf '%p\n' \
  | sort
echo

echo "===== 14. Estrutura esperada futura ====="
echo "/srv/toolbox/app/scripts/admin     -> scripts administrativos versionados"
echo "/srv/toolbox/shared/reports        -> relatórios fora do Git"
echo "/srv/toolbox/shared/firewall-backups -> backups iptables fora do Git"
echo

echo "===== RELATÓRIO ====="
echo "$REPORT"
