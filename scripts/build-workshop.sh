#!/usr/bin/env bash
# Monta a pasta de upload do Workshop a partir do repositório:
#
#   <pasta do jogo>/Workshop/NevoaEOutroMundo/ (~/Zomboid, ou a da Steam Flatpak)
#     Contents/mods/NevoaEOutroMundo/   ← mod/ como está no último commit (git archive)
#     Contents/mods/NevoaEOutroMundo_Shader/  ← mod2/ (shader opcional, sprint 0013)
#     preview.png                       ← docs/workshop/preview.png
#     workshop.txt                      ← gerado de docs/workshop/description-*.txt
#
# Idempotente: apaga e recopia o mod (arquivo que saiu do repo some do upload).
# Só vai o que está commitado: mudança não commitada em mod/ ou docs/workshop/ é
# recusada (o upload tem de ser o commit que leva a tag) e arquivo não rastreado em
# mod/ fica de fora, com aviso.
# Preserva o id= e o visibility= que o jogo grava no workshop.txt depois do
# primeiro upload (WorkshopSubmitScreen.lua:351, 1157-1158): sem o id=, o
# próximo upload criaria um item novo no Steam. O ID publicado também fica no
# repo (docs/workshop/workshop-id.txt): sem id= local, o build usa o do repo.
#
# Uso: scripts/build-workshop.sh [--dry-run]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MOD_ID="NevoaEOutroMundo"
SHADER_ID="NevoaEOutroMundo_Shader" # segundo mod do mesmo item (validateModsFolder valida cada pasta)
TITLE="Névoa e Outro Mundo"
TAGS="Build 42;Hardmode;Multiplayer" # permitidas em media/WorkshopTags.txt do jogo
DEFAULT_VISIBILITY="unlisted"        # primeiro upload: só com o link, até o teste da instalação limpa
# Pasta de dados do jogo: ZOMBOID_DIR manda; senão a da Steam Flatpak, se existir
# (o jogo roda em sandbox e usa ~/.var/app/...); senão ~/Zomboid.
FLATPAK_ZOMBOID="$HOME/.var/app/com.valvesoftware.Steam/Zomboid"
if [ -n "${ZOMBOID_DIR:-}" ]; then
    :
elif [ -d "$FLATPAK_ZOMBOID" ]; then
    ZOMBOID_DIR="$FLATPAK_ZOMBOID"
else
    ZOMBOID_DIR="$HOME/Zomboid"
fi
DEST="$ZOMBOID_DIR/Workshop/$MOD_ID"
SRC_MOD="$REPO/mod"
SRC_SHADER="$REPO/mod2"
PREVIEW="$REPO/docs/workshop/preview.png"
DESC_EN="$REPO/docs/workshop/description-en.txt"
DESC_PT="$REPO/docs/workshop/description-ptbr.txt"
ID_FILE="$REPO/docs/workshop/workshop-id.txt" # existe depois do primeiro upload
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
warn() { echo "AVISO: $*" >&2; }
say() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else echo "$*"; fi; }

# --- conferências antes de escrever qualquer coisa ---
for f in "$SRC_MOD/42/mod.info" "$SRC_MOD/common" "$SRC_SHADER/42/mod.info" "$SRC_SHADER/common" "$PREVIEW" "$DESC_EN" "$DESC_PT"; do
    [ -e "$f" ] || die "falta $f"
done
grep -qx "id=$MOD_ID" "$SRC_MOD/42/mod.info" || die "mod/42/mod.info sem id=$MOD_ID"
grep -qx "id=$SHADER_ID" "$SRC_SHADER/42/mod.info" || die "mod2/42/mod.info sem id=$SHADER_ID"

size=$(wc -c <"$PREVIEW")
[ "$size" -le "$MAX_PREVIEW_BYTES" ] || die "preview.png com $size bytes (o jogo recusa acima de $MAX_PREVIEW_BYTES)"
dims="$(file -b "$PREVIEW")"
[[ "$dims" =~ ^PNG\ image\ data,\ (256\ x\ 256|512\ x\ 512), ]] ||
    die "preview.png precisa ser PNG 256x256 ou 512x512 (é: $dims)"

desc_bytes=$(($(wc -c <"$DESC_EN") + $(wc -c <"$DESC_PT") + 1))
[ "$desc_bytes" -le "$MAX_DESC_BYTES" ] ||
    die "descrição do Workshop com $desc_bytes bytes (máximo $MAX_DESC_BYTES: o Steam corta em 8000)"

git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "$REPO não é um repositório git"
# o mod sai do HEAD (git archive): sem estes no commit, a pasta sairia pela metade
for f in mod/42/mod.info mod/common/.gitkeep mod2/42/mod.info mod2/common/.gitkeep; do
    git -C "$REPO" cat-file -e "HEAD:$f" 2>/dev/null || die "o HEAD não tem $f: commite antes (o upload sai do último commit)"
done
# texto, preview e ID do Workshop também têm de ser os do commit que leva a tag
untracked=()
while IFS= read -r line; do
    case "$line" in
        "?? mod/"* | "?? mod2/"*) untracked+=("${line#?? }") ;;
        *) die "mudança não commitada em mod/, mod2/ ou docs/workshop/ ($line): commite antes, o upload é o último commit" ;;
    esac
done < <(git -C "$REPO" status --porcelain --untracked-files=all -- mod mod2 docs/workshop)
for f in ${untracked[@]+"${untracked[@]}"}; do warn "$f não está no git: fica fora do upload"; done

repo_id=""
if [ -f "$ID_FILE" ]; then
    repo_id="$(tr -d '[:space:]' <"$ID_FILE")"
    [[ "$repo_id" =~ ^[0-9]+$ ]] || die "docs/workshop/workshop-id.txt devia ter só o ID numérico (tem: $repo_id)"
fi

# --- o que o jogo gravou no workshop.txt anterior ---
id_line=""
visibility="$DEFAULT_VISIBILITY"
if [ -f "$DEST/workshop.txt" ]; then
    id_line="$(grep -m1 '^id=' "$DEST/workshop.txt" || true)"
    old_vis="$(grep -m1 '^visibility=' "$DEST/workshop.txt" | cut -d= -f2- || true)"
    [ -n "$old_vis" ] && visibility="$old_vis"
fi
if [ -n "$repo_id" ]; then
    if [ -z "$id_line" ]; then
        warn "workshop.txt local sem id=: usando o ID publicado do repo, $repo_id (sem ele o jogo criaria outro item)"
        id_line="id=$repo_id"
    elif [ "$id_line" != "id=$repo_id" ]; then
        warn "workshop.txt local tem ${id_line#id=}, o repo registra $repo_id: mantido o local; confira qual é o item certo antes de enviar"
    fi
fi

say "destino: $DEST"
say "Contents/mods/$MOD_ID/ <- mod/ do commit $(git -C "$REPO" rev-parse --short HEAD) ($(git -C "$REPO" ls-files mod | wc -l) arquivos, cópia limpa)"
say "Contents/mods/$SHADER_ID/ <- mod2/ do mesmo commit ($(git -C "$REPO" ls-files mod2 | wc -l) arquivos)"
say "preview.png <- docs/workshop/preview.png ($size bytes)"
say "workshop.txt <- docs/workshop/description-en.txt + description-ptbr.txt ($desc_bytes bytes);" \
    "${id_line:-sem id (primeiro upload)}, visibility=$visibility"
[ "$DRY" = 1 ] && exit 0

# --- escrita ---
mkdir -p "$DEST"
rm -rf "$DEST/Contents"
mkdir -p "$DEST/Contents/mods/$MOD_ID"
git -C "$REPO" archive HEAD mod | tar -x -C "$DEST/Contents/mods/$MOD_ID" --strip-components=1
mkdir -p "$DEST/Contents/mods/$SHADER_ID"
git -C "$REPO" archive HEAD mod2 | tar -x -C "$DEST/Contents/mods/$SHADER_ID" --strip-components=1
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
