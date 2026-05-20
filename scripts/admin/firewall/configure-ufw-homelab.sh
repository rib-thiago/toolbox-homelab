#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "CONFIGURANDO UFW HOMELAB"
echo "============================================================"

echo
echo "[1/8] Garantindo instalação..."
sudo apt update
sudo apt install -y ufw

echo
echo "[2/8] Resetando regras antigas..."
sudo ufw --force reset

echo
echo "[3/8] Políticas padrão..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo
echo "[4/8] Permitindo SSH..."
sudo ufw allow 22/tcp comment 'SSH'

echo
echo "[5/8] Permitindo Nginx Proxy Manager..."
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 81/tcp comment 'NPM Admin'
sudo ufw allow 443/tcp comment 'HTTPS'

echo
echo "[6/8] Permitindo Samba..."
sudo ufw allow 139/tcp comment 'Samba'
sudo ufw allow 445/tcp comment 'Samba'

echo
echo "[7/8] Habilitando UFW..."
sudo ufw --force enable

echo
echo "[8/8] Status final..."
sudo ufw status verbose

echo
echo "============================================================"
echo "TESTES ESPERADOS"
echo "============================================================"

cat <<EOF

DEVEM FUNCIONAR:
- http://homepage.lab
- http://grafana.lab
- http://music.lab
- http://video.lab
- http://photo.lab
- Samba
- SSH
- Tailscale

DEVEM FALHAR:
- 192.168.15.6:3001
- 192.168.15.6:9090
- 192.168.15.6:9898
- 192.168.15.6:4533
- 192.168.15.6:8096
- 192.168.15.6:2283
- etc

EOF

echo "============================================================"
echo "CONCLUÍDO"
echo "============================================================"
