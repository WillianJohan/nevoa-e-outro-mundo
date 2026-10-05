#!/usr/bin/env bash
# Monta a pasta de upload do Workshop a partir do repositório:
#
#   ~/Zomboid/Workshop/NevoaEOutroMundo/
#     Contents/mods/NevoaEOutroMundo/   ← cópia de mod/ (42/ e common/)
#     preview.png                       ← docs/workshop/preview.png
#     workshop.txt                      ← gerado de docs/workshop/description-*.txt
#
# Idempotente: apaga e recopia o mod (arquivo que saiu do repo some do upload).
# Preserva o id= e o visibility= que o jogo grava no workshop.txt depois do
# primeiro upload (WorkshopSubmitScreen.lua:351, 1157-1158): sem o id=, o
# próximo upload criaria um item novo no Steam.
#
# Uso: scripts/build-workshop.sh [--dry-run]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MOD_ID="NevoaEOutroMundo"
TITLE="Névoa e Outro Mundo"
TAGS="Build 42;Hardmode;Multiplayer" # permitidas em media/WorkshopTags.txt do jogo
DEFAULT_VISIBILITY="unlisted"        # primeiro upload: só com o link, até o teste da instalação limpa
DEST="$HOME/Zomboid/Workshop/$MOD_ID"
SRC_MOD="$REPO/mod"
PREVIEW="$REPO/docs/workshop/preview.png"
DESC_EN="$REPO/docs/workshop/description-en.txt"
DESC_PT="$REPO/docs/workshop/description-ptbr.txt"
# Steam aceita 8000 caracteres e o jogo anexa "Workshop ID"/"Mod ID" (getSubmitDescription)
MAX_DESC_BYTES=7900
# SteamWorkshopItem.validatePreviewImage: < 1 024 000 bytes, PNG quadrado 256 ou 512
MAX_PREVIEW_BYTES=1024000

DRY=0
case "${1:-}" in
    --dry-run) DRY=1 ;;
    "") ;;
    *) echo "uso: $0 [--dry-run]" >&2; exit 2 ;;
esac

die() { echo "erro: $*" >&2; exit 1; }
say() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else echo "$*"; fi; }

# --- conferências antes de escrever qualquer coisa ---
for f in "$SRC_MOD/42/mod.info" "$SRC_MOD/common" "$PREVIEW" "$DESC_EN" "$DESC_PT"; do
    [ -e "$f" ] || die "falta $f"
done
grep -qx "id=$MOD_ID" "$SRC_MOD/42/mod.info" || die "mod/42/mod.info sem id=$MOD_ID"

size=$(wc -c <"$PREVIEW")
[ "$size" -lt "$MAX_PREVIEW_BYTES" ] || die "preview.png com $size bytes (o jogo recusa a partir de $MAX_PREVIEW_BYTES)"
dims="$(file -b "$PREVIEW")"
[[ "$dims" =~ ^PNG\ image\ data,\ (256\ x\ 256|512\ x\ 512), ]] ||
    die "preview.png precisa ser PNG 256x256 ou 512x512 (é: $dims)"

desc_bytes=$(($(wc -c <"$DESC_EN") + $(wc -c <"$DESC_PT") + 1))
[ "$desc_bytes" -le "$MAX_DESC_BYTES" ] ||
    die "descrição do Workshop com $desc_bytes bytes (máximo $MAX_DESC_BYTES: o Steam corta em 8000)"

# --- o que o jogo gravou no workshop.txt anterior ---
id_line=""
visibility="$DEFAULT_VISIBILITY"
if [ -f "$DEST/workshop.txt" ]; then
    id_line="$(grep -m1 '^id=' "$DEST/workshop.txt" || true)"
    old_vis="$(grep -m1 '^visibility=' "$DEST/workshop.txt" | cut -d= -f2- || true)"
    [ -n "$old_vis" ] && visibility="$old_vis"
fi

say "destino: $DEST"
say "Contents/mods/$MOD_ID/ <- mod/ ($(find "$SRC_MOD" -type f | wc -l) arquivos, cópia limpa)"
say "preview.png <- docs/workshop/preview.png ($size bytes)"
say "workshop.txt <- docs/workshop/description-en.txt + description-ptbr.txt ($desc_bytes bytes);" \
    "${id_line:-sem id (primeiro upload)}, visibility=$visibility"
[ "$DRY" = 1 ] && exit 0

# --- escrita ---
mkdir -p "$DEST"
rm -rf "$DEST/Contents"
mkdir -p "$DEST/Contents/mods/$MOD_ID"
cp -R "$SRC_MOD/." "$DEST/Contents/mods/$MOD_ID/"
cp "$PREVIEW" "$DEST/preview.png"

# Formato lido por SteamWorkshopItem.readWorkshopTxt: uma linha description= por
# linha do texto (o jogo junta com \n), tags separadas por ';'.
{
    echo "version=1"
    [ -n "$id_line" ] && echo "$id_line"
    echo "title=$TITLE"
    sed 's/^/description=/' "$DESC_EN"
    echo "description="
    sed 's/^/description=/' "$DESC_PT"
    echo "tags=$TAGS"
    echo "visibility=$visibility"
} >"$DEST/workshop.txt.new"
mv "$DEST/workshop.txt.new" "$DEST/workshop.txt"

echo "pronto. Abra o jogo: menu principal > Workshop > $TITLE."
