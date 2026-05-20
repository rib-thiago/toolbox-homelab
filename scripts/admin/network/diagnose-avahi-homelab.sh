#!/usr/bin/env bash
set -euo pipefail

OUT="$HOME/relatorios-backup/diagnostico-avahi-$(date +%F-%H%M%S).txt"
mkdir -p "$HOME/relatorios-backup"

{
echo "============================================================"
echo "DIAGNÓSTICO AVAHI / MDNS"
echo "============================================================"

echo
echo "1. Status do Avahi"
systemctl status avahi-daemon --no-pager || true

echo
echo "2. Portas mDNS"
sudo ss -ulpn | grep ':5353' || true

echo
echo "3. Configuração Avahi"
cat /etc/avahi/avahi-daemon.conf || true

echo
echo "4. Serviços publicados via Avahi"
avahi-browse -a -t 2>/dev/null || true

echo
echo "5. Dependências systemd"
systemctl list-dependencies avahi-daemon --no-pager || true

echo
echo "6. Pacotes Avahi instalados"
dpkg -l | grep avahi || true

echo
echo "7. Serviços relacionados"
systemctl --type=service --state=running --no-pager | grep -Ei 'avahi|cups|samba|bluetooth|network|resolved|tailscale' || true

echo
echo "8. Interfaces de rede"
ip -br addr

echo
echo "9. Testes funcionais atuais"
echo "- homepage.lab, grafana.lab etc. dependem de hosts/NPM, não de Avahi."
echo "- homelab:porta no iPhone depende de Tailscale MagicDNS, não de Avahi."
echo "- Samba por IP não depende de Avahi."
echo "- Descoberta automática .local/Bonjour pode depender de Avahi."

echo
echo "============================================================"
echo "FIM"
echo "============================================================"
} | tee "$OUT"

echo
echo "Relatório salvo em:"
echo "$OUT"
