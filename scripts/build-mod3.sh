#!/usr/bin/env bash
# Compila o jar do mod3 (NevoaEOutroMundo_Volumetrica) contra o jogo e o ZombieBuddy instalados.
# Precisa de um JDK >= 25 (o jogo roda no Zulu 25): `brew install openjdk`.
# Saída: mod3/42/media/java/client/NevoaEOutroMundo_Volumetrica.jar (fora do git).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PZ="${PZ_DIR:-/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid}"
ZB="${ZB_JAR:-$PZ/ZombieBuddy.jar}"
JDK="${JAVA_HOME:-/home/linuxbrew/.linuxbrew/opt/openjdk}"
OUT="$REPO/mod3/42/media/java/client/NevoaEOutroMundo_Volumetrica.jar"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

"$JDK/bin/javac" --release 25 -nowarn -d "$TMP" -cp "$PZ/projectzomboid.jar:$ZB" \
    $(find "$REPO/mod3/java" -name '*.java')
mkdir -p "$(dirname "$OUT")"
"$JDK/bin/jar" --create --file "$OUT" -C "$TMP" .
echo "jar: $OUT ($(stat -c %s "$OUT") bytes)"
