#!/usr/bin/env bash

set -euo pipefail

ROOT="$HOME/Música/Avant-Garde/Karlheinz Stockhausen/Stockhausen Verlag"

echo "Diretório analisado:"
echo "$ROOT"
echo

if [[ ! -d "$ROOT" ]]; then
    echo "[ERRO] Diretório não encontrado."
    exit 1
fi

echo "========================================"
echo "TAMANHO TOTAL"
echo "========================================"
du -sh "$ROOT"
echo

echo "========================================"
echo "ÁUDIO BRUTO / ARQUIVOS GRANDES REMOVÍVEIS"
echo "========================================"

find "$ROOT" -type f \
    \( \
        -iname "*.flac" -o \
        -iname "*.wav"  -o \
        -iname "*.ape"  -o \
        -iname "*.wv"   -o \
        -iname "*.m4a"  -o \
        -iname "*.mp3"  -o \
        -iname "*.cue"  -o \
        -iname "*.log"  \
    \) \
    -print0 \
| du --files0-from=- -ch 2>/dev/null \
| tail -n 1

echo

echo "========================================"
echo "MATERIAL A PRESERVAR: ARTWORK / IMAGENS / PDF / TEXTO"
echo "========================================"

find "$ROOT" -type f \
    \( \
        -iname "*.jpg"  -o \
        -iname "*.jpeg" -o \
        -iname "*.png"  -o \
        -iname "*.webp" -o \
        -iname "*.tif"  -o \
        -iname "*.tiff" -o \
        -iname "*.pdf"  -o \
        -iname "*.txt"  -o \
        -iname "*.nfo"  \
    \) \
    -print0 \
| du --files0-from=- -ch 2>/dev/null \
| tail -n 1

echo

echo "========================================"
echo "TAMANHO POR COLEÇÃO"
echo "========================================"

du -sh "$ROOT"/* | sort -h

echo

echo "========================================"
echo "TOP 30 MAIORES ARQUIVOS"
echo "========================================"

find "$ROOT" -type f -printf '%s\t%p\n' \
| sort -nr \
| head -n 30 \
| awk '
function human(x) {
    split("B KB MB GB TB", unit)
    i=1
    while (x>=1024 && i<5) {x/=1024; i++}
    return sprintf("%.2f %s", x, unit[i])
}
{
    size=$1
    $1=""
    sub(/^\t/, "")
    print human(size) "\t" $0
}'

echo

echo "========================================"
echo "CONTAGEM POR EXTENSÃO"
echo "========================================"

find "$ROOT" -type f \
| awk '
{
    n=split($0,a,".")
    if (n > 1) {
        ext=tolower(a[n])
    } else {
        ext="[sem_extensao]"
    }
    count[ext]++
}
END {
    for (e in count) print count[e], e
}' \
| sort -nr

echo

echo "========================================"
echo "SIMULAÇÃO CONCEITUAL"
echo "========================================"
echo "Se você preservar Artwork/imagens/PDFs e remover FLAC/CUE/logs brutos,"
echo "o espaço recuperável aproximado é o total listado em:"
echo "'ÁUDIO BRUTO / ARQUIVOS GRANDES REMOVÍVEIS'."
echo
echo "Nada foi apagado."
