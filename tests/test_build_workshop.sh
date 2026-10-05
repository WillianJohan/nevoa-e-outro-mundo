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

# cópia do repo só com o que o build lê, num git próprio (o build só manda o que
# está commitado em mod/), pra estragar sem medo
fake_repo() {
    local r
    r="$(mktemp -d "$TMP/repo.XXXX")"
    mkdir -p "$r/docs"
    cp -R "$REPO/mod" "$REPO/scripts" "$r/"
    cp -R "$REPO/docs/workshop" "$r/docs/"
    rm -f "$r/docs/workshop/workshop-id.txt"
    git -C "$r" init -q
    commit_all "$r"
    echo "$r"
}

commit_all() { git -C "$1" add -A && git -C "$1" -c user.name=t -c user.email=t@t commit -qm t --allow-empty; }
# commita tudo menos um caminho (que fica no disco, fora do git)
commit_all_but() { echo "/$2" >>"$1/.git/info/exclude" && commit_all "$1"; }

CLEAN="$(fake_repo)"

# roda o build de um repo (padrão: a cópia limpa) num HOME (padrão: novo); ecoa o HOME
build() {
    local repo="${1:-$CLEAN}" home="${HOME_FOR:-}"
    [ -n "$home" ] || home="$(mktemp -d "$TMP/home.XXXX")"
    HOME="$home" bash "$repo/scripts/build-workshop.sh" "${@:2}" >"$home/out.txt" 2>&1
    local status=$?
    echo "$home"
    return $status
}

# de novo no mesmo HOME
rebuild() { HOME_FOR="$1" build "${2:-$CLEAN}" >/dev/null; }

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
    rebuild "$h"
    test "$(tree_hash "$d")" = "$first"
}

# o jogo grava id= e a visibilidade escolhida (WorkshopSubmitScreen.lua:351, 1157-1158)
build_preserves_id_and_visibility() {
    local h w
    h="$(build)"
    w="$h/$DEST_REL/workshop.txt"
    sed -i 's/^visibility=.*/visibility=public/' "$w"
    sed -i '1a id=3412345678' "$w"
    rebuild "$h"
    grep -qx "id=3412345678" "$w"
    grep -qx "visibility=public" "$w"
    test "$(grep -c '^id=' "$w")" -eq 1
}

build_removes_stale_files() {
    local h m
    h="$(build)"
    m="$h/$DEST_REL/Contents/mods/NevoaEOutroMundo/42/media/lua/client"
    touch "$m/NOM_Velho.lua"
    rebuild "$h"
    test ! -e "$m/NOM_Velho.lua"
}

build_dry_run_writes_nothing() {
    local h
    h="$(build "$CLEAN" --dry-run)"
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
    commit_all "$r"
    if h="$(build "$r")"; then return 1; fi # tem que falhar
    test ! -e "$h/Zomboid"
    grep -q "descrição" "$h/out.txt"
}

build_refuses_bad_preview() {
    local r h
    r="$(fake_repo)"
    python3 -c "from PIL import Image; Image.new('RGB', (300, 200)).save('$r/docs/workshop/preview.png')"
    commit_all "$r"
    if h="$(build "$r")"; then return 1; fi # tem que falhar
    test ! -e "$h/Zomboid"
    grep -q "preview" "$h/out.txt"
}

build_refuses_missing_source() {
    local r
    r="$(fake_repo)"
    rm "$r/mod/42/mod.info"
    commit_all "$r"
    if build "$r" >/dev/null; then return 1; fi
}

# o tamanho exato do limite passa (Files.size > 1024000 recusa); um byte a mais, não
build_preview_size_limit_inclusive() {
    local r h
    r="$(fake_repo)"
    python3 - "$r/docs/workshop/preview.png" <<'PY'
import sys
from PIL import Image
p = sys.argv[1]
Image.new("RGB", (256, 256)).save(p)
data = open(p, "rb").read()
open(p, "wb").write(data + b"\0" * (1024000 - len(data)))
PY
    commit_all "$r"
    h="$(build "$r")"
    truncate -s 1024001 "$r/docs/workshop/preview.png"
    commit_all "$r"
    if h="$(build "$r")"; then return 1; fi
    grep -q "preview" "$h/out.txt"
}

# só o que está commitado em mod/ vai pro upload
build_ships_only_tracked_files() {
    local r h
    r="$(fake_repo)"
    echo "rascunho" >"$r/mod/42/media/lua/client/NOM_Rascunho.lua"
    h="$(build "$r")"
    test ! -e "$h/$DEST_REL/Contents/mods/NevoaEOutroMundo/42/media/lua/client/NOM_Rascunho.lua"
    grep -q "AVISO.*NOM_Rascunho.lua" "$h/out.txt"
}

build_refuses_uncommitted_change_in_mod() {
    local r h
    r="$(fake_repo)"
    echo "-- mudança" >>"$r/mod/42/media/lua/shared/NOM_Rules.lua"
    if h="$(build "$r")"; then return 1; fi
    test ! -e "$h/Zomboid"
    grep -q "NOM_Rules.lua" "$h/out.txt"
}

# docs/workshop/workshop-id.txt guarda o ID publicado; a pasta local perdeu o id=
build_fills_missing_id_from_repo() {
    local r h
    r="$(fake_repo)"
    echo "3412345678" >"$r/docs/workshop/workshop-id.txt"
    commit_all "$r"
    h="$(build "$r")"
    grep -qx "id=3412345678" "$h/$DEST_REL/workshop.txt"
    grep -q "AVISO.*3412345678" "$h/out.txt"
}

build_warns_on_id_mismatch() {
    local r h w
    r="$(fake_repo)"
    echo "3412345678" >"$r/docs/workshop/workshop-id.txt"
    commit_all "$r"
    h="$(build "$r")"
    w="$h/$DEST_REL/workshop.txt"
    sed -i 's/^id=.*/id=999/' "$w"
    rebuild "$h" "$r"
    grep -qx "id=999" "$w" # o que o jogo gravou fica; quem decide é o Johan
    grep -q "AVISO.*999.*3412345678" "$h/out.txt"
}

build_no_warning_when_ids_match() {
    local r h
    r="$(fake_repo)"
    echo "3412345678" >"$r/docs/workshop/workshop-id.txt"
    commit_all "$r"
    h="$(build "$r")"
    rebuild "$h" "$r"
    test "$(grep -c AVISO "$h/out.txt")" -eq 0
}

# o upload sai do HEAD: arquivo que só existe no working tree não conta
build_refuses_head_without_modinfo() {
    local r h
    r="$(fake_repo)"
    git -C "$r" rm -q --cached mod/42/mod.info
    commit_all_but "$r" mod/42/mod.info
    if h="$(build "$r")"; then return 1; fi
    test ! -e "$h/Zomboid"
    grep -q "HEAD.*mod/42/mod.info" "$h/out.txt"
}

build_refuses_head_without_common() {
    local r h
    r="$(fake_repo)"
    git -C "$r" rm -q --cached mod/common/.gitkeep
    commit_all_but "$r" mod/common/.gitkeep
    if h="$(build "$r")"; then return 1; fi
    test ! -e "$h/Zomboid"
    grep -q "HEAD.*mod/common/.gitkeep" "$h/out.txt"
}

# texto, preview e ID do upload também são os do commit que leva a tag
build_refuses_uncommitted_workshop_docs() {
    local r h
    r="$(fake_repo)"
    echo "linha nova" >>"$r/docs/workshop/description-en.txt"
    if h="$(build "$r")"; then return 1; fi
    test ! -e "$h/Zomboid"
    grep -q "description-en.txt" "$h/out.txt"
}

build_refuses_uncommitted_workshop_id() {
    local r h
    r="$(fake_repo)"
    echo "3412345678" >"$r/docs/workshop/workshop-id.txt"
    if h="$(build "$r")"; then return 1; fi
    grep -q "workshop-id.txt" "$h/out.txt"
}

for t in build_creates_layout build_excludes_repo_only build_is_idempotent build_preserves_id_and_visibility \
    build_removes_stale_files build_dry_run_writes_nothing build_prints_what_it_did \
    build_refuses_long_description build_refuses_bad_preview build_refuses_missing_source \
    build_preview_size_limit_inclusive build_ships_only_tracked_files build_refuses_uncommitted_change_in_mod \
    build_fills_missing_id_from_repo build_warns_on_id_mismatch build_no_warning_when_ids_match \
    build_refuses_head_without_modinfo build_refuses_head_without_common \
    build_refuses_uncommitted_workshop_docs build_refuses_uncommitted_workshop_id; do
    check "$t" "$t"
done

echo "build total=$((pass + fail)) passou=$pass falhou=$fail"
test "$fail" -eq 0
