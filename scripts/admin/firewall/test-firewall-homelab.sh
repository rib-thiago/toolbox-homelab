#!/usr/bin/env bash
set -euo pipefail

SERVER_IP="192.168.15.6"
TAILSCALE_HOST="homelab"

ok() {
  echo "[OK] $1"
}

fail() {
  echo "[FALHA] $1"
}

test_http_should_work() {
  local url="$1"
  if curl -I --max-time 8 "$url" >/dev/null 2>&1; then
    ok "$url respondeu"
  else
    fail "$url NÃO respondeu"
  fi
}

test_http_should_fail() {
  local url="$1"
  if curl -I --max-time 5 "$url" >/dev/null 2>&1; then
    fail "$url respondeu, mas deveria estar fechado"
  else
    ok "$url falhou como esperado"
  fi
}

echo "============================================================"
echo "TESTE FIREWALL HOMELAB"
echo "============================================================"

echo
echo "1. UFW"
sudo ufw status verbose

echo
echo "2. URLs .lab que DEVEM funcionar"
for url in \
  http://homepage.lab \
  http://grafana.lab \
  http://metrics.lab \
  http://backup.lab \
  http://portainer.lab \
  http://file.lab \
  http://music.lab \
  http://video.lab \
  http://photo.lab \
  http://book.lab \
  http://calibre.lab
do
  test_http_should_work "$url"
done

echo
echo "3. Portas LAN diretas que DEVEM falhar"
for port in \
  3000 \
  3001 \
  9090 \
  9898 \
  9000 \
  8080 \
  4533 \
  8096 \
  2283 \
  5000 \
  8083
do
  test_http_should_fail "http://${SERVER_IP}:${port}"
done

echo
echo "4. Portas públicas necessárias que DEVEM responder"
for port in 80 81 443
do
  if nc -z -w 3 "$SERVER_IP" "$port"; then
    ok "$SERVER_IP:$port aberto"
  else
    fail "$SERVER_IP:$port não respondeu"
  fi
done

echo
echo "5. Samba"
for port in 139 445
do
  if nc -z -w 3 "$SERVER_IP" "$port"; then
    ok "Samba $SERVER_IP:$port aberto"
  else
    fail "Samba $SERVER_IP:$port não respondeu"
  fi
done

echo
echo "6. Tailscale/MagicDNS local"
for port in 4533 8096 2283 5000 8083
do
  test_http_should_work "http://${TAILSCALE_HOST}:${port}"
done

echo
echo "7. Portas ainda escutando"
sudo ss -tulpn | grep -E ':(22|80|81|443|139|445|8088|4533|8096|2283|5000|8083|3000|3001|9000|9090|9898)' || true

echo
echo "============================================================"
echo "TESTE CONCLUÍDO"
echo "============================================================"
