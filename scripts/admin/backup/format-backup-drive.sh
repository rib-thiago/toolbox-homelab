#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:-}"
LABEL="HOMELAB_BKP"

if [[ -z "$DEVICE" ]]; then
  echo "Uso:"
  echo "  sudo $0 /dev/sdX"
  echo
  echo "Exemplo:"
  echo "  sudo $0 /dev/sdb"
  echo
  echo "Discos disponíveis:"
  lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Erro: execute com sudo."
  exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
  echo "Erro: $DEVICE não é um dispositivo de bloco."
  exit 1
fi

BASENAME="$(basename "$DEVICE")"

if [[ ! -f "/sys/block/$BASENAME/removable" ]]; then
  echo "Erro: $DEVICE não parece ser um disco removível simples."
  exit 1
fi

REMOVABLE="$(cat "/sys/block/$BASENAME/removable")"

if [[ "$REMOVABLE" != "1" ]]; then
  echo "Erro: $DEVICE não está marcado como removível."
  echo "Abortando para evitar apagar o SSD do sistema."
  exit 1
fi

echo
echo "ATENÇÃO: isto apagará COMPLETAMENTE:"
echo
lsblk "$DEVICE"
echo
echo "Digite exatamente FORMATAR para continuar:"
read -r CONFIRM

if [[ "$CONFIRM" != "FORMATAR" ]]; then
  echo "Abortado."
  exit 1
fi

echo "Desmontando partições..."
for part in $(lsblk -ln -o NAME "$DEVICE" | tail -n +2); do
  umount "/dev/$part" 2>/dev/null || true
done

echo "Limpando assinaturas antigas..."
wipefs -a "$DEVICE"

echo "Criando tabela GPT..."
parted -s "$DEVICE" mklabel gpt

echo "Criando partição ext4..."
parted -s "$DEVICE" mkpart primary ext4 1MiB 100%

sleep 2
partprobe "$DEVICE"

PARTITION="${DEVICE}1"

if [[ ! -b "$PARTITION" ]]; then
  echo "Erro: partição $PARTITION não encontrada."
  echo "Verifique com lsblk."
  exit 1
fi

echo "Formatando $PARTITION como ext4..."
mkfs.ext4 -F -L "$LABEL" "$PARTITION"

echo
echo "Concluído."
echo
lsblk -f "$DEVICE"
