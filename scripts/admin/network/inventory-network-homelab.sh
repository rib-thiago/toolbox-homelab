#!/usr/bin/env bash
set -euo pipefail

DATA="$(date +%F-%H%M%S)"
OUT_DIR="$HOME/relatorios-backup"
OUT_FILE="$OUT_DIR/inventario-rede-homelab-$DATA.md"

mkdir -p "$OUT_DIR"

{
echo "# Inventário formal da rede do homelab"
echo
echo "**Data:** $(date)"
echo "**Host:** $(hostname)"
echo
echo "## 1. Política atual"
echo
echo "- Acesso LAN/browser via \`*.lab\`."
echo "- Entrada web centralizada pelo Nginx Proxy Manager."
echo "- Serviços internos conectados à \`lab_net\`."
echo "- Acesso móvel/remoto via Tailscale MagicDNS: \`homelab:porta\`."
echo "- UFW ativo com entrada bloqueada por padrão."
echo
echo "## 2. URLs oficiais"
echo
cat <<'EOF'
| Serviço | URL LAN/browser | Acesso Tailscale |
|---|---|---|
| Homepage | http://homepage.lab | — |
| Grafana | http://grafana.lab | — |
| Prometheus | http://metrics.lab | — |
| Backrest | http://backup.lab | — |
| Portainer | http://portainer.lab | — |
| Filebrowser | http://file.lab | — |
| Navidrome | http://music.lab | http://homelab:4533 |
| Jellyfin | http://video.lab | http://homelab:8096 |
| Immich | http://photo.lab | http://homelab:2283 |
| Kavita | http://book.lab | http://homelab:5000 |
| Calibre-Web | http://calibre.lab | http://homelab:8083 |
| NPM Admin | http://proxy.lab | — |
EOF
echo
echo "## 3. Portas intencionalmente expostas na LAN"
echo
cat <<'EOF'
| Porta | Serviço | Motivo |
|---:|---|---|
| 22 | SSH | Administração |
| 80 | Nginx Proxy Manager | Gateway HTTP |
| 81 | Nginx Proxy Manager Admin | Administração do proxy |
| 443 | Nginx Proxy Manager | Gateway HTTPS futuro |
| 139 | Samba | Compartilhamento SMB |
| 445 | Samba | Compartilhamento SMB |
EOF
echo
echo "## 4. UFW"
echo
sudo ufw status verbose || true
echo
echo "## 5. Containers, portas e redes"
echo
docker ps --format "| {{.Names}} | {{.Ports}} | {{.Networks}} |" | sed '1i| Container | Portas | Redes |\n|---|---|---|'
echo
echo "## 6. Redes Docker"
echo
docker network ls
echo
echo "## 7. lab_net"
echo
docker network inspect lab_net --format '{{json .Containers}}' | python3 -m json.tool || true
echo
echo "## 8. Portas escutando no host"
echo
sudo ss -tulpn
echo
echo "## 9. Tailscale"
echo
tailscale status || true
echo
echo
echo "### IP Tailscale"
tailscale ip -4 || true
echo
echo "## 10. Samba"
docker exec samba smbstatus 2>/dev/null || true
echo
echo "## 11. Arquivos Compose"
find /srv/compose -maxdepth 3 -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) | sort
echo
echo "## 12. Homepage services.yaml"
echo
echo '```yaml'
cat /srv/data/homepage/services.yaml 2>/dev/null || true
echo '```'
echo
echo "## 13. Windows hosts esperado"
echo
cat <<'EOF'
192.168.15.6 homepage.lab
192.168.15.6 portainer.lab
192.168.15.6 music.lab
192.168.15.6 book.lab
192.168.15.6 photo.lab
192.168.15.6 calibre.lab
192.168.15.6 video.lab
192.168.15.6 file.lab
192.168.15.6 grafana.lab
192.168.15.6 backup.lab
192.168.15.6 proxy.lab
192.168.15.6 metrics.lab
EOF
echo
echo "## 14. Observações arquiteturais"
echo
echo "- Immich server deve permanecer em \`lab_net\` e \`immich_default/default\` para falar com Redis/Postgres."
echo "- Serviços administrativos devem permanecer atrás do NPM."
echo "- Serviços multimídia usam modelo híbrido: \`.lab\` no navegador/LAN e \`homelab:porta\` no Tailscale."
echo "- cAdvisor deve permanecer localhost-only."
echo "- Próximas frentes possíveis: DNS interno real, regras DOCKER-USER, documentação de restore de rede, automações Toolbox."
} > "$OUT_FILE"

echo "Inventário gerado em:"
echo "$OUT_FILE"
