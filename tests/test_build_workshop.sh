#!/usr/bin/env bash
# Testa scripts/build-workshop.sh com HOME temporário (nunca toca o ~/Zomboid de verdade).
# Exit code 0 = tudo passou.
cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
DEST_REL="Zomboid/Workshop/NevoaEOutroMundo"

# roda o build de um repo (padrão: este) com um HOME novo; ecoa o HOME
build() {
    local repo="${1:-$REPO}" home
    home="$(mktemp -d "$TMP/home.XXXX")"
    HOME="$home" bash "$repo/scripts/build-workshop.sh" "${@:2}" >"$home/out.txt" 2>&1
    local status=$?
    echo "$home"
    return $status
}

# cópia do repo só com o que o build lê, pra estragar sem medo
fake_repo() {
    local r
    r="$(mktemp -d "$TMP/repo.XXXX")"
    mkdir -p "$r/docs"
    cp -R "$REPO/mod" "$REPO/scripts" "$r/"
    cp -R "$REPO/docs/workshop" "$r/docs/"
    echo "$r"
}

tree_hash() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum); }

check() { # nome, comando
    local name="$1"
    shift
    # fora de if: dentro de condição o bash ignora o set -e
    ( set -e; "$@" )
    if [ $? -eq 0 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL tests/test_build_workshop.sh :: $name"
    fi
}

build_creates_layout() {
    local h d
    h="$(build)"
    d="$h/$DEST_REL"
    test -f "$d/Contents/mods/NevoaEOutroMundo/42/mod.info"
    test -f "$d/Contents/mods/NevoaEOutroMundo/42/poster.png"
    test -d "$d/Contents/mods/NevoaEOutroMundo/common"
    test -f "$d/Contents/mods/NevoaEOutroMundo/42/media/lua/shared/Translate/PTBR/Mod.json"
    cmp -s "$d/preview.png" "$REPO/docs/workshop/preview.png"
    local w="$d/workshop.txt"
    test "$(head -1 "$w")" = "version=1"
    grep -qx "title=Névoa e Outro Mundo" "$w"
    grep -qx "tags=Build 42;Hardmode;Multiplayer" "$w"
    grep -qx "visibility=unlisted" "$w"
    test "$(grep -c '^id=' "$w")" -eq 0
    grep -qxF "description=$(head -1 "$REPO/docs/workshop/description-en.txt")" "$w"
    grep -qxF "description=$(tail -1 "$REPO/docs/workshop/description-ptbr.txt")" "$w"
    # cada linha das descrições vira uma linha description= (o jogo junta com \n)
    local want
    want=$(($(wc -l <"$REPO/docs/workshop/description-en.txt") + $(wc -l <"$REPO/docs/workshop/description-ptbr.txt") + 1))
    test "$(grep -c '^description=' "$w")" -eq "$want"
}

build_excludes_repo_only() {
    local h d
    h="$(build)"
    d="$h/$DEST_REL"
    test "$(ls "$d" | tr '\n' ' ')" = "Contents preview.png workshop.txt "
    test "$(ls "$d/Contents")" = "mods"
    test "$(ls "$d/Contents/mods/NevoaEOutroMundo" | tr '\n' ' ')" = "42 common "
    # SteamWorkshopItem.validateFileTypes recusa estes
    test -z "$(find "$d" -type f \( -name '*.sh' -o -name '*.zip' -o -name '*.exe' -o -name '*.dll' \
        -o -name '*.bat' -o -name '*.app' -o -name '*.dylib' -o -name '*.so' \))"
}

build_is_idempotent() {
    local h d first
    h="$(build)"
    d="$h/$DEST_REL"
    first="$(tree_hash "$d")"
    HOME="$h" bash scripts/build-workshop.sh >/dev/null
    test "$(tree_hash "$d")" = "$first"
}

# o jogo grava id= e a visibilidade escolhida (WorkshopSubmitScreen.lua:351, 1157-1158)
build_preserves_id_and_visibility() {
    local h w
    h="$(build)"
    w="$h/$DEST_REL/workshop.txt"
    sed -i 's/^visibility=.*/visibility=public/' "$w"
    sed -i '1a id=3412345678' "$w"
    HOME="$h" bash scripts/build-workshop.sh >/dev/null
    grep -qx "id=3412345678" "$w"
    grep -qx "visibility=public" "$w"
    test "$(grep -c '^id=' "$w")" -eq 1
}

build_removes_stale_files() {
    local h m
    h="$(build)"
    m="$h/$DEST_REL/Contents/mods/NevoaEOutroMundo/42/media/lua/client"
    touch "$m/NOM_Velho.lua"
    HOME="$h" bash scripts/build-workshop.sh >/dev/null
    test ! -e "$m/NOM_Velho.lua"
}

build_dry_run_writes_nothing() {
    local h
    h="$(build "$REPO" --dry-run)"
    test ! -e "$h/Zomboid"
    grep -q "dry-run" "$h/out.txt"
}

build_prints_what_it_did() {
    local h
    h="$(build)"
    grep -q "Contents/mods/NevoaEOutroMundo" "$h/out.txt"
    grep -q "preview.png" "$h/out.txt"
    grep -q "workshop.txt" "$h/out.txt"
}

build_refuses_long_description() {
    local r h
    r="$(fake_repo)"
    python3 -c "print('x' * 8000)" >>"$r/docs/workshop/description-en.txt"
    if h="$(build "$r")"; then return 1; fi # tem que falhar
    test ! -e "$h/Zomboid"
    grep -q "descrição" "$h/out.txt"
}

build_refuses_bad_preview() {
    local r h
    r="$(fake_repo)"
    python3 -c "from PIL import Image; Image.new('RGB', (300, 200)).save('$r/docs/workshop/preview.png')"
    if h="$(build "$r")"; then return 1; fi # tem que falhar
    test ! -e "$h/Zomboid"
    grep -q "preview" "$h/out.txt"
}

build_refuses_missing_source() {
    local r
    r="$(fake_repo)"
    rm "$r/mod/42/mod.info"
    if build "$r" >/dev/null; then return 1; fi
}

for t in build_creates_layout build_excludes_repo_only build_is_idempotent build_preserves_id_and_visibility \
    build_removes_stale_files build_dry_run_writes_nothing build_prints_what_it_did \
    build_refuses_long_description build_refuses_bad_preview build_refuses_missing_source; do
    check "$t" "$t"
done

echo "build total=$((pass + fail)) passou=$pass falhou=$fail"
test "$fail" -eq 0
