#!/usr/bin/env python3
"""Auditoria dos sprites de chão do Outro Mundo (sprint 0021): mede, só lendo o pack do
jogo instalado, onde o conteúdo de cada sprite cai e escreve tests/floor_sprites.lua.
Nenhum pixel é copiado: sai só número (cobertura, fração dentro do diamante, pixels na
zona de um personagem). Os testes conferem o pool de NOM_DressingRules contra a tabela.

Geometria (pack Tiles2x, quadro 128x256): o diamante do chão tem centro em (64, 224),
meia-largura 64, meia-altura 32. O IsoMarker desenha o recorte da textura com a base no
centro do tile e centrado na horizontal (IsoSprite.renderTextureWithDepth: x - w/2, y - h).

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
PREFIXES = ["overlay_blood_floor_01_", "overlay_grime_floor_01_", "d_streetcracks_1_", "d_plants_1_"]
ALPHA = 32         # pixel que conta (alfa de 0..255)
HALF = 24          # meia-largura de um personagem em px do quadro 2x
FEET = 6           # o pé desce isso abaixo do centro do tile
# centros dos tiles de trás (N, W e NW) relativos ao centro do tile do decalque
BEHIND = [(-64, -32), (64, -32), (0, -64)]
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
    total = inside = zone = spill = 0
    for j in range(h):
        for i in range(w):
            if alpha[j * w + i] < ALPHA:
                continue
            total += 1
            gx, gy = ox + i + 0.5, oy + j + 0.5
            if abs(gx - 64) / 64 + abs(gy - 224) / 32 <= 1.02:
                inside += 1
            dx, dy = i + 0.5 - w / 2, j + 0.5 - h  # onde o marcador põe, relativo ao centro
            if abs(dx) / 64 + abs(dy) / 32 > 1:
                spill += 1
            if any(abs(dx - cx) <= HALF and dy <= cy + FEET for cx, cy in BEHIND):
                zone += 1
    total = max(1, total)
    return inside / total, zone, total / 4096, spill / total


def main():
    sprites = {}
    for pack in PACKS:
        found = read_pack(os.path.join(GAME, "media", "texturepacks", pack),
                          lambda n: n.startswith(tuple(PREFIXES)))
        for k, v in found.items():
            sprites.setdefault(k, v)
    upright = upright_names()
    lines = ["-- Gerado por scripts/audit_floor_sprites.py (só medida do pack Tiles2x, nada copiado).",
             "-- flat: conteúdo no diamante do chão e sem MoveWithWind/vegitation (tiledefinitions_erosion);",
             "-- zone: pixels que o IsoMarker põe onde um personagem de tile vizinho de trás está;",
             "-- cov: alfa / área do diamante (4096 px); spill: fração fora do diamante do tile como o marcador desenha.",
             "return {"]
    counts = {}

    def key(n):
        m = re.match(r"(.*_)(\d+)$", n)
        return (m.group(1), int(m.group(2)))

    for name in sorted(sprites, key=key):
        ox, oy, w, h, alpha = sprites[name]
        inside, zone, cov, spill = measure(ox, oy, w, h, alpha)
        flat = inside >= 0.95 and name not in upright
        prefix = key(name)[0]
        c = counts.setdefault(prefix, [0, 0, 0])
        c[0] += 1
        c[1] += flat
        c[2] += flat and zone == 0
        lines.append('    ["%s"] = { flat = %s, zone = %d, cov = %.2f, spill = %.2f },'
                     % (name, "true" if flat else "false", zone, cov, spill))
    lines.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    for prefix, (n, flat, safe) in counts.items():
        print("%-26s %3d no pack, %3d chatos, %3d chatos e seguros" % (prefix, n, flat, safe))


if __name__ == "__main__":
    main()
