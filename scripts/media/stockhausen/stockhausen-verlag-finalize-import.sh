#!/usr/bin/env bash

set -euo pipefail

SOURCE_ROOT="$HOME/Música/Avant-Garde/Karlheinz Stockhausen/Stockhausen Verlag"
DEST_ROOT="/srv/media/music/Karlheinz Stockhausen"
REPORT_DIR="$HOME/Música/Avant-Garde/Karlheinz Stockhausen/relatorios-limpeza"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$REPORT_DIR"

MANIFEST_BEFORE="$REPORT_DIR/manifesto_antes_limpeza_$TIMESTAMP.tsv"
DELETE_MANIFEST="$REPORT_DIR/arquivos_removidos_audio_bruto_$TIMESTAMP.tsv"
MOVE_LOG="$REPORT_DIR/movidos_artwork_docs_$TIMESTAMP.log"

echo "Origem : $SOURCE_ROOT"
echo "Destino: $DEST_ROOT"
echo "Relatórios: $REPORT_DIR"
echo

if [[ ! -d "$SOURCE_ROOT" ]]; then
    echo "[ERRO] Diretório de origem não encontrado: $SOURCE_ROOT"
    exit 1
fi

if [[ ! -d "$DEST_ROOT" ]]; then
    echo "[ERRO] Diretório de destino não encontrado: $DEST_ROOT"
    exit 1
fi

echo "Tamanho antes:"
du -sh "$SOURCE_ROOT"
echo

echo "[1/7] Gerando manifesto completo antes da limpeza..."
find "$SOURCE_ROOT" -type f -printf '%s\t%p\n' | sort -k2 > "$MANIFEST_BEFORE"
echo "Manifesto salvo em:"
echo "$MANIFEST_BEFORE"
echo

echo "[2/7] Movendo Artwork, imagens, PDFs e textos para a biblioteca em /srv/media/music..."
echo "Log de movimentação: $MOVE_LOG"
echo > "$MOVE_LOG"

find "$SOURCE_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | while read -r collection_dir; do
    collection_name="$(basename "$collection_dir")"
    dest_collection="$DEST_ROOT/$collection_name"

    mkdir -p "$dest_collection"

    find "$collection_dir" -mindepth 1 -maxdepth 1 -type d | sort | while read -r album_dir; do
        album_name="$(basename "$album_dir")"
        dest_album="$dest_collection/$album_name"

        mkdir -p "$dest_album"

        # Move diretório Artwork inteiro, se existir.
        if [[ -d "$album_dir/Artwork" ]]; then
            if [[ -e "$dest_album/Artwork" ]]; then
                echo "[MERGE ARTWORK] $album_dir/Artwork -> $dest_album/Artwork" | tee -a "$MOVE_LOG"
                mkdir -p "$dest_album/Artwork"
                find "$album_dir/Artwork" -mindepth 1 -maxdepth 1 -exec mv -n {} "$dest_album/Artwork/" \;
                rmdir "$album_dir/Artwork" 2>/dev/null || true
            else
                echo "[MOVE ARTWORK] $album_dir/Artwork -> $dest_album/Artwork" | tee -a "$MOVE_LOG"
                mv "$album_dir/Artwork" "$dest_album/"
            fi
        fi

        # Move imagens/documentos soltos na raiz do álbum.
        find "$album_dir" -maxdepth 1 -type f \
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
        | while IFS= read -r -d '' file; do
            echo "[MOVE DOC] $file -> $dest_album/" | tee -a "$MOVE_LOG"
            mv -n "$file" "$dest_album/"
        done
    done
done

echo
echo "[3/7] Removendo subpastas vazias dentro de split/..."
find "$SOURCE_ROOT" -type d -path "*/split/*" -depth | sort | while read -r dir; do
    if [[ -d "$dir" ]] && [[ -z "$(find "$dir" -mindepth 1 -print -quit)" ]]; then
        echo "[RMDIR] $dir"
        rmdir "$dir"
    fi
done

echo
echo "[4/7] Removendo pastas split/ vazias..."
find "$SOURCE_ROOT" -type d -name "split" | sort | while read -r split_dir; do
    if [[ -z "$(find "$split_dir" -mindepth 1 -print -quit)" ]]; then
        echo "[RMDIR] $split_dir"
        rmdir "$split_dir"
    fi
done

echo
echo "[5/7] Gerando manifesto dos arquivos brutos que serão removidos..."
find "$SOURCE_ROOT" -type f \
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
    -printf '%s\t%p\n' \
    | sort -k2 > "$DELETE_MANIFEST"

echo "Manifesto de remoção salvo em:"
echo "$DELETE_MANIFEST"
echo

echo "Tamanho dos arquivos brutos que serão removidos:"
cut -f1 "$DELETE_MANIFEST" | awk '
BEGIN { total=0 }
{ total += $1 }
END {
    split("B KB MB GB TB", u)
    i=1
    while (total >= 1024 && i < 5) { total/=1024; i++ }
    printf "%.2f %s\n", total, u[i]
}'
echo

echo "[6/7] Removendo áudio bruto, CUE e logs..."
find "$SOURCE_ROOT" -type f \
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
    -print \
    -delete

echo
echo "[7/7] Removendo diretórios vazios restantes..."
find "$SOURCE_ROOT" -type d -empty -depth -print -delete

echo
echo "Tamanho depois:"
du -sh "$SOURCE_ROOT" || true

echo
echo "Pastas split ainda existentes:"
find "$SOURCE_ROOT" -type d -name "split" | sort | tee "$REPORT_DIR/splits_restantes_$TIMESTAMP.txt"

echo
remaining_splits="$(find "$SOURCE_ROOT" -type d -name "split" | wc -l)"
echo "Total de pastas split restantes: $remaining_splits"

echo
echo "Concluído."
echo
echo "Relatórios importantes:"
echo "$MANIFEST_BEFORE"
echo "$DELETE_MANIFEST"
echo "$MOVE_LOG"
