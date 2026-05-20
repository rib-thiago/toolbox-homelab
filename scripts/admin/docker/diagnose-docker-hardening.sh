#!/usr/bin/env bash
set -euo pipefail

OUT="$HOME/relatorios-backup/diagnostico-docker-hardening-$(date +%F-%H%M%S).txt"
mkdir -p "$HOME/relatorios-backup"

{
echo "============================================================"
echo "DIAGNÓSTICO DOCKER / DOCKER-USER / HARDENING"
echo "============================================================"
echo "Data: $(date)"
echo "Host: $(hostname)"

echo
echo "1. Containers, portas e redes"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Networks}}"

echo
echo "2. Docker networks"
docker network ls

echo
echo "3. lab_net inspect"
docker network inspect lab_net --format '{{json .Containers}}' | python3 -m json.tool || true

echo
echo "4. iptables DOCKER-USER"
sudo iptables -L DOCKER-USER -n -v --line-numbers || true

echo
echo "5. iptables DOCKER"
sudo iptables -L DOCKER -n -v --line-numbers || true

echo
echo "6. iptables FORWARD"
sudo iptables -L FORWARD -n -v --line-numbers || true

echo
echo "7. NAT Docker"
sudo iptables -t nat -L DOCKER -n -v --line-numbers || true

echo
echo "8. Containers privilegiados / host network / host pid"
for c in $(docker ps --format '{{.Names}}'); do
  echo
  echo "----- $c -----"
  docker inspect "$c" --format \
'Image={{.Config.Image}}
User={{.Config.User}}
Privileged={{.HostConfig.Privileged}}
NetworkMode={{.HostConfig.NetworkMode}}
PidMode={{.HostConfig.PidMode}}
IpcMode={{.HostConfig.IpcMode}}
ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}}
CapAdd={{.HostConfig.CapAdd}}
CapDrop={{.HostConfig.CapDrop}}
RestartPolicy={{.HostConfig.RestartPolicy.Name}}'
done

echo
echo "9. Mounts dos containers"
for c in $(docker ps --format '{{.Names}}'); do
  echo
  echo "----- $c -----"
  docker inspect "$c" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Mode}}){{println}}{{end}}'
done

echo
echo "10. Busca por padrões sensíveis em compose"
grep -RInE 'privileged:|network_mode:|pid:|cap_add:|devices:|/var/run/docker.sock|/dev/|:rw|:ro|0.0.0.0|127.0.0.1|100.105.132.65|host-gateway' /srv/compose 2>/dev/null || true

echo
echo "11. Portas LAN que deveriam estar fechadas"
for port in 3000 3001 9000 9090 9898 4533 8096 2283 5000 8083 8088; do
  nc -z -w 2 192.168.15.6 "$port" && echo "REVIEW aberto 192.168.15.6:$port" || echo "OK fechado 192.168.15.6:$port"
done

echo
echo "12. Portas LAN intencionais"
for port in 22 80 81 443 139 445; do
  nc -z -w 2 192.168.15.6 "$port" && echo "OK aberto 192.168.15.6:$port" || echo "FALHA fechado 192.168.15.6:$port"
done

echo
echo "13. UFW"
sudo ufw status verbose || true

echo
echo "14. Classificação inicial"
cat <<'EOF'
REVIEW esperado:
- node-exporter com network_mode host e pid host
- cadvisor privileged e mounts sensíveis
- NPM com docker.sock, se existir
- Portainer com docker.sock
- Samba exposto em 139/445
- NPM exposto em 80/81/443
- DOCKER-USER vazio

Objetivo:
- entender antes de bloquear
- evitar quebrar NPM, Prometheus, Tailscale e lab_net
- propor política mínima de DOCKER-USER somente depois da análise
EOF

echo
echo "============================================================"
echo "FIM"
echo "============================================================"

} | tee "$OUT"

echo
echo "Relatório salvo em:"
echo "$OUT"
