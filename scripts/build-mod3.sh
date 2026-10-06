#!/usr/bin/env bash
# Compila o jar do mod3 (NevoaEOutroMundo_Volumetrica) contra o jogo e o ZombieBuddy instalados.
# Precisa de um JDK >= 25 (o jogo roda no Zulu 25): `brew install openjdk`.
# Saída: mod3/42/media/java/client/NevoaEOutroMundo_Volumetrica.jar (fora do git).
# O build do Workshop troca a origem e a saída (MOD3_SRC, MOD3_OUT) e fixa a data das
# entradas do jar (MOD3_DATE, ISO-8601): o mesmo commit dá o mesmo jar, byte a byte.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PZ="${PZ_DIR:-/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid}"
ZB="${ZB_JAR:-$PZ/ZombieBuddy.jar}"
JDK="${JAVA_HOME:-/home/linuxbrew/.linuxbrew/opt/openjdk}"
SRC="${MOD3_SRC:-$REPO/mod3/java}"
OUT="${MOD3_OUT:-$REPO/mod3/42/media/java/client/NevoaEOutroMundo_Volumetrica.jar}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

"$JDK/bin/javac" --release 25 -nowarn -d "$TMP/classes" -cp "$PZ/projectzomboid.jar:$ZB" \
    $(find "$SRC" -name '*.java')
mkdir -p "$(dirname "$OUT")"
"$JDK/bin/jar" --create --file "$OUT" ${MOD3_DATE:+--date="$MOD3_DATE"} -C "$TMP/classes" .
echo "jar: $OUT ($(stat -c %s "$OUT") bytes)"

# Assinatura ZBS (ZBSVerifier do ZombieBuddy): sidecar .jar.zbs com 3 linhas, e a
# assinatura Ed25519 da string "ZBS:<SteamID64>:<sha256 do jar>". A chave privada
# fica fora do repo; a pública vai no perfil Steam como JavaModZBS:<hex>.
KEY="${NOM_ZBS_KEY:-$HOME/.signing/nom-zbs-ed25519.pem}"
SID="${NOM_ZBS_STEAMID:-76561198119764604}"
if [ -f "$KEY" ]; then
    SHA="$(sha256sum "$OUT" | cut -d' ' -f1)"
    printf 'ZBS:%s:%s' "$SID" "$SHA" > "$TMP/msg"
    SIG="$(openssl pkeyutl -sign -rawin -inkey "$KEY" -in "$TMP/msg" | od -An -tx1 | tr -d ' \n')"
    printf 'ZBS\nSteamID64:%s\nSignature:%s\n' "$SID" "$SIG" > "$OUT.zbs"
    echo "assinado: $OUT.zbs (perfil Steam: JavaModZBS:$(openssl pkey -in "$KEY" -pubout -outform DER | tail -c 32 | od -An -tx1 | tr -d ' \n'))"
else
    rm -f "$OUT.zbs"; echo "sem chave em $KEY: jar NÃO assinado"
fi
