#!/usr/bin/env bash
# Copia mod/ pra pasta de mods do jogo (cópia real, não symlink).
# Por quê: com symlink o ScriptManager do jogo monta o caminho errado e não lê
# media/scripts/*.txt (visto no console.txt: FileNotFoundException em
# .../Zomboid/mods/var/home/.../nom_clothing.txt). Lua e texturas carregavam,
# os itens de visual não. Rode de novo depois de cada mudança e recarregue o save.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLATPAK_ZOMBOID="$HOME/.var/app/com.valvesoftware.Steam/Zomboid"
if [ -n "${ZOMBOID_DIR:-}" ]; then :
elif [ -d "$FLATPAK_ZOMBOID" ]; then ZOMBOID_DIR="$FLATPAK_ZOMBOID"
else ZOMBOID_DIR="$HOME/Zomboid"; fi
DEST="$ZOMBOID_DIR/mods/NevoaEOutroMundo"
mkdir -p "$ZOMBOID_DIR/mods"
[ -L "$DEST" ] && rm "$DEST" && echo "symlink antigo removido"
mkdir -p "$DEST"
rsync -a --delete "$REPO/mod/" "$DEST/"
echo "mod copiado: $REPO/mod -> $DEST ($(find "$DEST" -type f | wc -l) arquivos)"
