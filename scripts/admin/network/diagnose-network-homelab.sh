#!/usr/bin/env bash
set -euo pipefail

DATA="$(date +%F-%H%M%S)"
OUT_DIR="$HOME/relatorios-backup"
OUT_FILE="$OUT_DIR/diagnostico-rede-homelab-$DATA.txt"

mkdir -p "$OUT_DIR"

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

{
section "DIAGNÓSTICO DE REDE / VPN / NGINX DO HOMELAB"
echo "Data: $(date)"
echo "Host: $(hostname)"
echo "Usuário: $(whoami)"

section "HOSTNAME E IPs"
hostnamectl || true
ip -br addr || true
ip route || true

section "PORTAS ESCUTANDO NO HOST"
sudo ss -tulpen || true

section "CONTAINERS E PORTAS PUBLICADAS"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true

section "REDES DOCKER"
docker network ls || true

section "INSPEÇÃO RESUMIDA DAS REDES DOCKER"
for net in $(docker network ls --format '{{.Name}}'); do
  echo
  echo "----- $net -----"
  docker network inspect "$net" \
    --format 'Driver={{.Driver}} Scope={{.Scope}} Internal={{.Internal}} Containers={{len .Containers}}' 2>/dev/null || true
done

section "COMPOSES EXISTENTES"
find /srv/compose -maxdepth 3 -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) | sort || true

section "NGINX PROXY MANAGER - DIRETÓRIO"
sudo find /srv/compose/npm /srv/data/npm -maxdepth 3 -type f 2>/dev/null | sort || true

section "HOMEPAGE - SERVICES"
cat /srv/data/homepage/services.yaml 2>/dev/null || true

section "HOMEPAGE - BOOKMARKS"
cat /srv/data/homepage/bookmarks.yaml 2>/dev/null || true

section "TAILSCALE"
tailscale status 2>/dev/null || echo "tailscale status indisponível"
tailscale ip -4 2>/dev/null || true

section "SAMBA"
docker exec samba smbstatus 2>/dev/null || true

section "FIREWALL / UFW"
sudo ufw status verbose 2>/dev/null || true
sudo iptables -S 2>/dev/null | head -200 || true

section "HOSTS LOCAIS DO SERVIDOR"
cat /etc/hosts || true

section "TESTES HTTP LOCAIS"
for url in \
  "http://127.0.0.1:3000" \
  "http://127.0.0.1:3001" \
  "http://127.0.0.1:9898" \
  "http://127.0.0.1:9000" \
  "http://127.0.0.1:81" \
  "http://127.0.0.1:4533" \
  "http://127.0.0.1:2283" \
  "http://127.0.0.1:8083" \
  "http://127.0.0.1:5000" \
  "http://127.0.0.1:8080" \
  "http://127.0.0.1:9090" \
; do
  echo
  echo "----- $url -----"
  curl -I --max-time 5 "$url" 2>/dev/null | head -5 || echo "falhou"
done

section "SUGESTÃO INICIAL DE NOMES .LAB"
cat <<'EOF'
home.lab       -> Homepage
music.lab      -> Navidrome
photo.lab      -> Immich
book.lab       -> Kavita
calibre.lab    -> Calibre-Web
files.lab      -> Filebrowser
grafana.lab    -> Grafana
backup.lab     -> Backrest
docker.lab     -> Portainer
proxy.lab      -> Nginx Proxy Manager
metrics.lab    -> Prometheus
EOF

section "RESUMO"
echo "Relatório gerado em: $OUT_FILE"

} | tee "$OUT_FILE"

echo
echo "Relatório salvo em:"
echo "$OUT_FILE"
