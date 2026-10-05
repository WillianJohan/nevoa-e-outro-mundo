#!/usr/bin/env bash
# Copia mod/ pra pasta de mods do jogo (cópia real, não symlink).
# Por quê: com symlink o ScriptManager do jogo monta o caminho errado e não lê
# media/scripts/*.txt (visto no console.txt: FileNotFoundException em
# .../Zomboid/mods/var/home/.../nom_clothing.txt). Lua e texturas carregavam,
# os itens de visual não. Rode de novo depois de cada mudança e recarregue o save.
# mod2/ (shader opcional, sprint 0013) vai junto como NevoaEOutroMundo_Shader: só
# fica disponível na lista de mods; ativar é escolha (não com ShadowZ).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLATPAK_ZOMBOID="$HOME/.var/app/com.valvesoftware.Steam/Zomboid"
if [ -n "${ZOMBOID_DIR:-}" ]; then :
elif [ -d "$FLATPAK_ZOMBOID" ]; then ZOMBOID_DIR="$FLATPAK_ZOMBOID"
else ZOMBOID_DIR="$HOME/Zomboid"; fi
mkdir -p "$ZOMBOID_DIR/mods"
sync_mod() { # pasta do repo, id do mod
    local dest="$ZOMBOID_DIR/mods/$2"
    if [ -L "$dest" ]; then rm "$dest" && echo "symlink antigo removido ($2)"; fi
    mkdir -p "$dest"
    rsync -a --delete "$REPO/$1/" "$dest/"
    echo "mod copiado: $REPO/$1 -> $dest ($(find "$dest" -type f | wc -l) arquivos)"
}
sync_mod mod NevoaEOutroMundo
sync_mod mod2 NevoaEOutroMundo_Shader
# mod3/ (spike volumétrica, Java via ZombieBuddy): rode scripts/build-mod3.sh antes.
if [ -f "$REPO/mod3/42/media/java/client/NevoaEOutroMundo_Volumetrica.jar" ]; then sync_mod mod3 NevoaEOutroMundo_Volumetrica; fi
