#!/usr/bin/env python3
"""Auditoria dos sprites de chão do Outro Mundo (sprints 0021 e 0023): mede, só lendo o pack
do jogo instalado, onde o conteúdo de cada sprite cai e escreve tests/floor_sprites.lua.
Nenhum pixel é copiado: sai só número. Os testes conferem os pools de NOM_DressingRules contra
a tabela.

Sprint 0023: o sprite vai anexado ao piso (IsoObject.addAttachedAnimSpriteByName) e o jogo o
desenha no lugar do piso (IsoObject.renderAttachedSprites → IsoSprite.render com a posição do
objeto), como a erosão vanilla. O quadro do pack já está alinhado com o tile: o que importa é
se o conteúdo fica deitado no diamante do chão (não flutua) e quanto sobe acima dele.

Geometria (pack Tiles2x, quadro 128x256): o diamante do chão tem centro em (64, 224),
meia-largura 64, meia-altura 32; o topo dele está em y = 192.

Uso: scripts/audit_floor_sprites.py [pasta do jogo]
"""
import io
import os
import re
import struct
import sys

from PIL import Image

GAME = sys.argv[1] if len(sys.argv) > 1 else \
    "/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid"
PACKS = ["Tiles2x.pack", "Tiles2x.floor.pack"]
PREFIXES = ["overlay_blood_floor_01_", "overlay_grime_floor_01_", "d_streetcracks_1_", "d_plants_1_",
            "d_floorleaves_1_", "floors_burnt_01_"]
ALPHA = 32         # pixel que conta (alfa de 0..255)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "floor_sprites.lua")


def read_pack(path, want):
    d = open(path, "rb").read()
    p = 4
    out = {}

    def i32():
        nonlocal p
        v = struct.unpack_from("<i", d, p)[0]
        p += 4
        return v

    def string():
        nonlocal p
        n = i32()
        v = d[p:p + n].decode("latin1")
        p += n
        return v

    assert d[:4] == b"PZPK", path
    i32()  # versão
    for _ in range(i32()):
        string()
        n = i32()
        i32()
        entries = []
        for _ in range(n):
            name = string()
            entries.append([name] + [i32() for _ in range(8)])
        size = i32()
        png = d[p:p + size]
        p += size
        img = None
        for name, x, y, w, h, ox, oy, fw, fh in entries:
            if name in out or not want(name):
                continue
            if img is None:
                img = Image.open(io.BytesIO(png)).convert("RGBA")
            out[name] = (ox, oy, w, h, img.crop((x, y, x + w, y + h)).getchannel("A").tobytes())
    return out


def upright_names():
    txt = open(os.path.join(GAME, "media", "tiledefinitions_erosion.tiles.txt")).read()
    names = set()
    for m in re.finditer(r"// (\S+)\s*\n\s*tile\s*\{([^}]*)\}", txt):
        if "MoveWithWind" in m.group(2) or "vegitation" in m.group(2):
            names.add(m.group(1))
    return names


def measure(ox, oy, w, h, alpha):
    """inside: fração do conteúdo no diamante do chão; cov: alfa / área do diamante (4096 px);
    rise: quantos px o conteúdo sobe acima do topo do diamante (0 = deitado no chão)."""
    total = inside = 0
    top = 192
    for j in range(h):
        for i in range(w):
            if alpha[j * w + i] < ALPHA:
                continue
            total += 1
            gx, gy = ox + i + 0.5, oy + j + 0.5
            if abs(gx - 64) / 64 + abs(gy - 224) / 32 <= 1.02:
                inside += 1
            top = min(top, gy)
    if total == 0:
        return 0.0, 0.0, 0
    return inside / total, total / 4096, int(192 - top)


def main():
    sprites = {}
    for pack in PACKS:
        found = read_pack(os.path.join(GAME, "media", "texturepacks", pack),
                          lambda n: n.startswith(tuple(PREFIXES)))
        for k, v in found.items():
            sprites.setdefault(k, v)
    upright = upright_names()
    lines = ["-- Gerado por scripts/audit_floor_sprites.py (só medida do pack Tiles2x, nada copiado).",
             "-- inside: fração do conteúdo no diamante do chão (anexado ao piso, o quadro do pack é o do tile);",
             "-- cov: alfa / área do diamante (4096 px); rise: px acima do topo do diamante (0 = deitado);",
             "-- wind: MoveWithWind/vegitation em tiledefinitions_erosion (planta em pé quando é objeto).",
             "return {"]

    def key(n):
        m = re.match(r"(.*_)(\d+)$", n)
        return (m.group(1), int(m.group(2)))

    for name in sorted(sprites, key=key):
        inside, cov, rise = measure(*sprites[name])
        if cov == 0:
            continue  # entrada vazia no pack
        lines.append('    ["%s"] = { inside = %.2f, cov = %.2f, rise = %d, wind = %s },'
                     % (name, inside, cov, rise, "true" if name in upright else "false"))
    lines.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("%d sprites medidos -> %s" % (len(lines) - 6, OUT))


if __name__ == "__main__":
    main()
