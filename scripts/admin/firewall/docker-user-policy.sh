#!/usr/bin/env bash
set -euo pipefail

LAN_IF="${LAN_IF:-enp5s0}"
TAILSCALE_IF="${TAILSCALE_IF:-tailscale0}"

BACKUP_DIR="/home/thiago/iptables-backups"
mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/iptables-before-docker-user-$(date +%Y%m%d-%H%M%S).rules"

apply_policy() {
  echo "[1/5] Salvando backup em: $BACKUP_FILE"
  sudo iptables-save > "$BACKUP_FILE"

  echo "[2/5] Limpando DOCKER-USER"
  sudo iptables -F DOCKER-USER

  echo "[3/5] Aplicando política base"

  # Permite conexões já estabelecidas
  sudo iptables -A DOCKER-USER \
    -m conntrack --ctstate RELATED,ESTABLISHED \
    -j RETURN

  # Permite tráfego originado dos containers Docker
  sudo iptables -A DOCKER-USER -i docker0 -j RETURN
  sudo iptables -A DOCKER-USER -i br+ -j RETURN

  # Permite acesso vindo da Tailscale para containers publicados
  if ip link show "$TAILSCALE_IF" >/dev/null 2>&1; then
    sudo iptables -A DOCKER-USER -i "$TAILSCALE_IF" -j RETURN
  else
    echo "Aviso: interface $TAILSCALE_IF não encontrada; regra Tailscale ignorada."
  fi

  echo "[4/5] Permitindo portas Docker autorizadas vindas da LAN"

  # Nginx Proxy Manager e Samba
  for port in 80 81 443 139 445; do
    sudo iptables -A DOCKER-USER \
      -i "$LAN_IF" \
      -p tcp \
      -m conntrack --ctorigdstport "$port" \
      -j RETURN
  done

  echo "[5/5] Bloqueando demais acessos LAN -> Docker bridge"

  # Bloqueia LAN acessando containers Docker em portas não autorizadas
  sudo iptables -A DOCKER-USER -i "$LAN_IF" -o docker0 -j DROP
  sudo iptables -A DOCKER-USER -i "$LAN_IF" -o br+ -j DROP

  # Mantém comportamento padrão para o que não foi coberto
  sudo iptables -A DOCKER-USER -j RETURN

  echo
  echo "Política aplicada."
  echo "Backup salvo em:"
  echo "$BACKUP_FILE"
}

rollback_latest() {
  LATEST_BACKUP="$(ls -1t "$BACKUP_DIR"/iptables-before-docker-user-*.rules 2>/dev/null | head -n 1 || true)"

  if [ -z "$LATEST_BACKUP" ]; then
    echo "Nenhum backup encontrado em $BACKUP_DIR"
    exit 1
  fi

  echo "Restaurando backup:"
  echo "$LATEST_BACKUP"
  sudo iptables-restore < "$LATEST_BACKUP"
  echo "Rollback concluído."
}

status_policy() {
  echo "=== DOCKER-USER ==="
  sudo iptables -L DOCKER-USER -n -v --line-numbers
  echo
  echo "=== DOCKER-USER raw ==="
  sudo iptables -S DOCKER-USER
}

case "${1:-}" in
  apply)
    apply_policy
    ;;
  rollback)
    rollback_latest
    ;;
  status)
    status_policy
    ;;
  *)
    echo "Uso:"
    echo "  $0 apply"
    echo "  $0 status"
    echo "  $0 rollback"
    exit 1
    ;;
esac
