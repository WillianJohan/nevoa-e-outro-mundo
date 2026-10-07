#!/usr/bin/env bash
# Testa scripts/dev-sync.sh com ZOMBOID_DIR temporário (nunca toca o Zomboid de verdade): a cópia
# vira o mod de staging (AGENTS.md, "Desenvolvimento x lançado"), o repo não muda.
# Exit code 0 = tudo passou.
cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

# cópia do repo só com o que o script lê; o jar do mod3 é de mentira (no repo de verdade é fora do git)
fake_repo() {
    local r
    r="$(mktemp -d "$TMP/repo.XXXX")"
    mkdir -p "$r/docs"
    cp -R "$REPO/mod" "$REPO/mod2" "$REPO/mod3" "$REPO/scripts" "$r/"
    cp -R "$REPO/docs/art" "$r/docs/"
    rm -rf "$r/mod3/42/media/java"
    echo "$r"
}
with_jar() { mkdir -p "$1/mod3/42/media/java/client" && echo "jar" >"$1/mod3/42/media/java/client/NoiseOfMist_Volumetrica.jar"; }

CLEAN="$(fake_repo)"
with_jar "$CLEAN"

# roda o dev-sync de um repo (padrão: a cópia com jar) numa pasta de jogo nova; ecoa a pasta
sync() {
    local repo="${1:-$CLEAN}" z="${Z_FOR:-}"
    [ -n "$z" ] || z="$(mktemp -d "$TMP/zomboid.XXXX")"
    ZOMBOID_DIR="$z" bash "$repo/scripts/dev-sync.sh" >"$z/out.txt" 2>&1
    local status=$?
    echo "$z"
    return $status
}

tree_hash() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum); }

check() { # nome, comando
    local name="$1"
    shift
    ( set -e; "$@" )
    if [ $? -eq 0 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL tests/test_dev_sync.sh :: $name"
    fi
}

value() { sed -n "s/^$2=//p" "$1"; } # mod.info, chave

sync_creates_staging_folders() {
    local z
    z="$(sync)"
    test "$(ls "$z/mods" | tr '\n' ' ')" = "NoiseOfMist_Shader_Staging NoiseOfMist_Staging NoiseOfMist_Volumetrica_Staging "
    test -f "$z/mods/NoiseOfMist_Staging/42/media/lua/shared/NOM_Rules.lua"
    test -f "$z/mods/NoiseOfMist_Shader_Staging/42/media/shaders/screen.frag"
    test -f "$z/mods/NoiseOfMist_Volumetrica_Staging/42/media/java/client/NoiseOfMist_Volumetrica.jar"
}

sync_staging_ids_and_require() {
    local z m
    z="$(sync)"
    m="$z/mods"
    test "$(value "$m/NoiseOfMist_Staging/42/mod.info" id)" = "NoiseOfMist_Staging"
    test "$(value "$m/NoiseOfMist_Shader_Staging/42/mod.info" id)" = "NoiseOfMist_Shader_Staging"
    test "$(value "$m/NoiseOfMist_Volumetrica_Staging/42/mod.info" id)" = "NoiseOfMist_Volumetrica_Staging"
    test -z "$(value "$m/NoiseOfMist_Staging/42/mod.info" require)"
    test "$(value "$m/NoiseOfMist_Shader_Staging/42/mod.info" require)" = "NoiseOfMist_Staging"
    test "$(value "$m/NoiseOfMist_Volumetrica_Staging/42/mod.info" require)" = 'NoiseOfMist_Staging,\ZombieBuddy'
}

sync_staging_names() {
    local z
    z="$(sync)"
    test "$(value "$z/mods/NoiseOfMist_Staging/42/mod.info" name)" = "[STAGING] NOM: Noise of Mist"
    test "$(value "$z/mods/NoiseOfMist_Shader_Staging/42/mod.info" name)" = "[STAGING] $(value "$CLEAN/mod2/42/mod.info" name)"
    test "$(value "$z/mods/NoiseOfMist_Volumetrica_Staging/42/mod.info" name)" = "[STAGING] $(value "$CLEAN/mod3/42/mod.info" name)"
    # o Mod.json do mod2 troca o nome do mod.info (Translator.readModTranslation): também ganha o [STAGING]
    local lang
    for lang in EN PTBR; do
        python3 - "$z/mods/NoiseOfMist_Shader_Staging/42/media/lua/shared/Translate/$lang/Mod.json" \
            "$CLEAN/mod2/42/media/lua/shared/Translate/$lang/Mod.json" <<'PY'
import json, sys
got, want = (json.load(open(p, encoding="utf-8")) for p in sys.argv[1:])
assert got["name"] == "[STAGING] " + want["name"], got["name"]
assert got["description"] == want["description"]
PY
    done
}

# os dois instalados juntos, nunca ativos no mesmo save: os arquivos Lua têm os mesmos nomes
sync_staging_incompatible_with_official() {
    local z
    z="$(sync)"
    test "$(value "$z/mods/NoiseOfMist_Staging/42/mod.info" incompatible)" = '\NoiseOfMist'
    test "$(value "$z/mods/NoiseOfMist_Shader_Staging/42/mod.info" incompatible)" = '\ShadowZ,\NoiseOfMist_Shader'
    test "$(value "$z/mods/NoiseOfMist_Volumetrica_Staging/42/mod.info" incompatible)" = '\NoiseOfMist_Volumetrica'
}

sync_staging_images() {
    local z d
    z="$(sync)"
    for d in NoiseOfMist_Staging NoiseOfMist_Shader_Staging NoiseOfMist_Volumetrica_Staging; do
        cmp -s "$z/mods/$d/42/poster.png" "$REPO/docs/art/staging/poster.png"
        cmp -s "$z/mods/$d/42/icon.png" "$REPO/docs/art/staging/icon.png"
    done
}

# o resto do mod.info fica como no repo, e cada linha casa com a própria chave na cadeia de
# contains do readModInfoAux (bytecode 152–1325, a mesma regra do tests/test_credits.lua)
sync_staging_modinfo_rest_and_key_order() {
    local z pair
    z="$(sync)"
    for pair in mod:NoiseOfMist_Staging mod2:NoiseOfMist_Shader_Staging mod3:NoiseOfMist_Volumetrica_Staging; do
        local src="$CLEAN/${pair%%:*}/42/mod.info" dst="$z/mods/${pair#*:}/42/mod.info"
        local strip='^(id|name|require|incompatible)='
        diff <(sed -E "/$strip/d" "$src") <(sed -E "/$strip/d" "$dst") >/dev/null
        python3 - "$dst" <<'PY'
import sys
ORDER = ["name=", "poster=", "description=", "require=", "incompatible=", "loadModAfter=", "loadModBefore=",
         "id=", "author=", "modversion=", "icon=", "category=", "url=", "pack=", "type=", "tiledef=",
         "versionMax=", "versionMin="]
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    own = line.split("=", 1)[0] + "="
    first = next((k for k in ORDER if k in line), own)
    assert first == own, line
PY
    done
}

sync_leaves_repo_untouched() {
    local before
    before="$(tree_hash "$CLEAN")"
    sync >/dev/null
    test "$(tree_hash "$CLEAN")" = "$before"
}

sync_is_idempotent() {
    local z first
    z="$(sync)"
    first="$(tree_hash "$z/mods")"
    Z_FOR="$z" sync >/dev/null
    test "$(tree_hash "$z/mods")" = "$first"
    test "$(value "$z/mods/NoiseOfMist_Staging/42/mod.info" name)" = "[STAGING] NOM: Noise of Mist"
}

sync_replaces_symlink() {
    local z
    z="$(mktemp -d "$TMP/zomboid.XXXX")"
    mkdir -p "$z/mods"
    ln -s /tmp "$z/mods/NoiseOfMist_Staging"
    Z_FOR="$z" sync >/dev/null
    test ! -L "$z/mods/NoiseOfMist_Staging"
    test -f "$z/mods/NoiseOfMist_Staging/42/mod.info"
}

sync_removes_stale_files() {
    local z
    z="$(sync)"
    touch "$z/mods/NoiseOfMist_Staging/42/media/lua/client/NOM_Velho.lua"
    Z_FOR="$z" sync >/dev/null
    test ! -e "$z/mods/NoiseOfMist_Staging/42/media/lua/client/NOM_Velho.lua"
}

# saves antigos pedem o ID antigo: o script só avisa, não apaga
sync_warns_about_old_folders() {
    local z
    z="$(mktemp -d "$TMP/zomboid.XXXX")"
    mkdir -p "$z/mods/NevoaEOutroMundo/42" "$z/mods/NevoaEOutroMundo_Shader/42"
    echo "id=NevoaEOutroMundo" >"$z/mods/NevoaEOutroMundo/42/mod.info"
    Z_FOR="$z" sync >/dev/null
    test "$(cat "$z/mods/NevoaEOutroMundo/42/mod.info")" = "id=NevoaEOutroMundo"
    test -d "$z/mods/NevoaEOutroMundo_Shader"
    grep -q "AVISO.*NevoaEOutroMundo_Shader" "$z/out.txt"
    grep -q "AVISO.*mods/NevoaEOutroMundo " "$z/out.txt"
}

sync_no_warning_without_old_folders() {
    local z
    z="$(sync)"
    test "$(grep -c AVISO "$z/out.txt")" -eq 0
}

sync_skips_volumetric_without_jar() {
    local r z
    r="$(fake_repo)"
    z="$(sync "$r")"
    test ! -e "$z/mods/NoiseOfMist_Volumetrica_Staging"
    test -d "$z/mods/NoiseOfMist_Staging"
}

for t in sync_creates_staging_folders sync_staging_ids_and_require sync_staging_names \
    sync_staging_incompatible_with_official sync_staging_images sync_staging_modinfo_rest_and_key_order \
    sync_leaves_repo_untouched sync_is_idempotent sync_replaces_symlink sync_removes_stale_files \
    sync_warns_about_old_folders sync_no_warning_without_old_folders sync_skips_volumetric_without_jar; do
    check "$t" "$t"
done

echo "dev-sync total=$((pass + fail)) passou=$pass falhou=$fail"
test "$fail" -eq 0
