#!/usr/bin/env bash
# Copia mod/, mod2/ e mod3/ pra pasta de mods do jogo como o mod de STAGING (cópia real, não symlink).
# Por que cópia: com symlink o ScriptManager do jogo monta o caminho errado e não lê
# media/scripts/*.txt (visto no console.txt: FileNotFoundException em
# .../Zomboid/mods/var/home/.../nom_clothing.txt). Lua e texturas carregavam,
# os itens de visual não. Rode de novo depois de cada mudança e reinicie o jogo.
#
# Staging (AGENTS.md, "Desenvolvimento x lançado", decisão do Johan, 2026-10-06): na cópia, e só nela,
# o ID ganha _Staging (também no require=), o nome ganha [STAGING] (no mod.info e no Mod.json, que
# troca o nome), o pôster e o ícone viram os de docs/art/staging/ e o incompatible= marca o oficial
# correspondente. Assim o mod do Workshop e o de staging ficam instalados juntos, nunca ativos no mesmo
# save. O repo nunca muda.
#   mod/  -> mods/NoiseOfMist_Staging
#   mod2/ -> mods/NoiseOfMist_Shader_Staging (shader opcional; não com ShadowZ)
#   mod3/ -> mods/NoiseOfMist_Volumetrica_Staging (Java via ZombieBuddy; rode scripts/build-mod3.sh antes)
# Pasta do jogo: ZOMBOID_DIR manda; senão a da Steam Flatpak, se existir; senão ~/Zomboid.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAGING_ART="$REPO/docs/art/staging"
FLATPAK_ZOMBOID="$HOME/.var/app/com.valvesoftware.Steam/Zomboid"
if [ -n "${ZOMBOID_DIR:-}" ]; then :
elif [ -d "$FLATPAK_ZOMBOID" ]; then ZOMBOID_DIR="$FLATPAK_ZOMBOID"
else ZOMBOID_DIR="$HOME/Zomboid"; fi
mkdir -p "$ZOMBOID_DIR/mods"

sync_mod() { # pasta do repo, id oficial do mod
    local id="$2" dest="$ZOMBOID_DIR/mods/$2_Staging"
    if [ -L "$dest" ]; then rm "$dest" && echo "symlink antigo removido ($id)"; fi
    mkdir -p "$dest"
    rsync -a --delete "$REPO/$1/" "$dest/"
    local info="$dest/42/mod.info"
    sed -i -E -e "s/^id=.*/id=${id}_Staging/" -e 's/^name=/name=[STAGING] /' \
        -e '/^require=/ s/(NoiseOfMist[A-Za-z_]*)/\1_Staging/g' "$info"
    if grep -q '^incompatible=' "$info"; then
        sed -i "/^incompatible=/ s/\$/,\\\\$id/" "$info"
    else
        printf 'incompatible=\\%s\n' "$id" >>"$info"
    fi
    find "$dest" -name Mod.json -path '*/Translate/*' -exec sed -i -E 's/^(\s*"name": ")/\1[STAGING] /' {} +
    cp "$STAGING_ART/poster.png" "$dest/42/$(sed -n 's/^poster=//p' "$info")"
    cp "$STAGING_ART/icon.png" "$dest/42/$(sed -n 's/^icon=//p' "$info")"
    echo "mod copiado como staging: $REPO/$1 -> $dest ($(find "$dest" -type f | wc -l) arquivos)"
}
sync_mod mod NoiseOfMist
sync_mod mod2 NoiseOfMist_Shader
if [ -f "$REPO/mod3/42/media/java/client/NoiseOfMist_Volumetrica.jar" ]; then sync_mod mod3 NoiseOfMist_Volumetrica; fi

# IDs de antes da 0037b: saves criados com eles pedem o ID antigo pra abrir, então ficam
for old in "$ZOMBOID_DIR"/mods/NevoaEOutroMundo*; do
    [ -e "$old" ] || continue
    echo "AVISO: $old é do ID antigo (Névoa e Outro Mundo) e ficou onde estava; save antigo pede esse ID." \
        "Pode apagar a pasta quando não precisar mais desses saves." >&2
done
