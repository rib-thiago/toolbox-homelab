#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

TOOLBOX="/srv/toolbox"
APP="/srv/toolbox/app"
OUT_DIR="$HOME/relatorios-disco"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/toolbox-structure-audit-$TS.txt"

mkdir -p "$OUT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "===== TOOLBOX STRUCTURE AUDIT ====="
echo "Data: $(date)"
echo "Host: $(hostname)"
echo

echo "===== 1. Diretórios principais ====="
for d in "$TOOLBOX" "$APP" "$TOOLBOX/jobs" "$TOOLBOX/shared" "$TOOLBOX/models" "$TOOLBOX/secrets"; do
  echo "--- $d ---"
  stat -c '%U:%G %u:%g %a %A %n' "$d" 2>/dev/null || true
  du -sh "$d" 2>/dev/null || true
done
echo

echo "===== 2. Estrutura da Toolbox ====="
find "$TOOLBOX" -maxdepth 3 -type d -printf '%p\n' 2>/dev/null | sort
echo

echo "===== 3. Git da Toolbox ====="
if [ -d "$APP/.git" ]; then
  cd "$APP"
  git status --short
  echo
  git branch --show-current
  echo
  git remote -v
else
  echo "Sem .git em $APP"
fi
echo

echo "===== 4. Binários públicos ====="
find "$APP/bin" -maxdepth 2 -type f -printf '%m %u:%g %p\n' 2>/dev/null | sort || true
echo

echo "===== 5. Scripts helpers/pipelines/lib ====="
find "$APP/scripts" -maxdepth 4 -type f -printf '%m %u:%g %p\n' 2>/dev/null | sort || true
echo

echo "===== 6. Docs/manpages ====="
find "$APP/docs" -maxdepth 4 -type f -printf '%m %u:%g %p\n' 2>/dev/null | sort || true
echo

echo "===== 7. Possíveis locais para admin scripts ====="
for d in \
  "$APP/scripts/admin" \
  "$APP/scripts/ops" \
  "$APP/docs/admin" \
  "$TOOLBOX/shared/admin-scripts"
do
  echo "--- $d ---"
  if [ -e "$d" ]; then
    stat -c '%U:%G %u:%g %a %A %n' "$d"
    find "$d" -maxdepth 2 -type f -printf '%m %u:%g %p\n' 2>/dev/null | sort
  else
    echo "não existe"
  fi
done
echo

echo "===== 8. Compose da Toolbox ====="
find /srv/compose -maxdepth 3 -type f \( -iname "*toolbox*" -o -iname "docker-compose.yml" -o -iname "compose.yml" \) \
  -printf '%p\n' 2>/dev/null | sort
echo

echo "===== 9. Containers Toolbox ====="
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Mounts}}' | grep -i toolbox || true
echo

echo "===== 10. Recomendação preliminar ====="
echo "A decisão será entre:"
echo "- versionar scripts operacionais dentro de /srv/toolbox/app, se forem parte oficial da Toolbox;"
echo "- guardar relatórios e artefatos gerados fora do git, em /srv/toolbox/shared ou /srv/admin;"
echo "- documentar o baseline em docs/admin ou docs/man7."
echo
echo "Relatório salvo em:"
echo "$REPORT"
