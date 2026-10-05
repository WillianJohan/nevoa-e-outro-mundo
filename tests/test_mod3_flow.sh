#!/usr/bin/env bash
# mod3: núcleo da névoa fluida (FlowGrid, Java puro, sem o jogo) e compilação dos shaders.
# Precisa de um JDK >= 25 (o mesmo do scripts/build-mod3.sh). Exit code 0 = tudo passou.
set -euo pipefail
cd "$(dirname "$0")/.."
JDK="${JAVA_HOME:-/home/linuxbrew/.linuxbrew/opt/openjdk}"
JAVAC="$JDK/bin/javac"; JAVA="$JDK/bin/java"
[ -x "$JAVAC" ] || JAVAC="$(command -v javac)"
[ -x "$JAVA" ] || JAVA="$(command -v java)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

"$JAVAC" --release 25 -nowarn -d "$TMP" mod3/java/nom/render/FlowGrid.java mod3/java/nom/render/FogBanks.java mod3/java/nom/render/Wind.java \
    tests/java/FlowGridTest.java tests/java/FlowTravelTest.java tests/java/FlowScaleTest.java tests/java/FlowContourTest.java
"$JAVA" -ea -cp "$TMP" FlowGridTest
"$JAVA" -ea -cp "$TMP" FlowTravelTest
"$JAVA" -ea -cp "$TMP" FlowScaleTest
"$JAVA" -ea -cp "$TMP" FlowContourTest

# Shaders: o RenderContext.init monta cabeçalho + "#line 1" + passe; compila igual.
if command -v glslangValidator >/dev/null; then
    SH=mod3/42/media/shaders
    for frag in "$SH"/NOM_*.frag; do
        out="$TMP/$(basename "$frag")"
        { cat "$SH/NOM_RenderContext.glsl"; printf '\n#line 1\n'; cat "$frag"; } > "$out"
        glslangValidator "$out" >"$TMP/glsl.log" || { cat "$TMP/glsl.log"; echo "FALHOU: $frag não compila"; exit 1; }
    done
    glslangValidator "$SH/NOM_Fullscreen.vert" >"$TMP/glsl.log" || { cat "$TMP/glsl.log"; exit 1; }
    echo "mod3 shaders compilam (glslangValidator)"
else
    echo "mod3 shaders: glslangValidator ausente, compilação pulada"
fi
