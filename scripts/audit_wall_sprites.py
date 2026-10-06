#!/usr/bin/env python3
"""Auditoria dos sprites de parede do Outro Mundo (sprint 0034): mede, só lendo o pack e os
arquivos de texto do jogo instalado, de que lado cada sprite cai e se o desenho continua no
tile vizinho, e escreve tests/wall_sprites.lua. Nenhum pixel é copiado: sai só número.

Três caminhos pro lado (pz-api-notes §16.3):
- recorte: no quadro de 128x256 do Tiles2x, a parede W ocupa a metade esquerda (x 0..65) e a
  N a direita (x 60..125); left = fração do conteúdo com x < 64;
- profundidade: media/tileDepthTextureAssignments.txt (preset_depthmaps_01_4 = W, _5 = N);
- definição do tile: attachedW/attachedN em media/newtiledefinitions.tiles.txt (o CellLoader
  anexa WallOverlay pelo lado: CellLoader.DoTileObjectCreation 1673-1970).

Pichação e mensagem são desenhos de várias paredes seguidas cortados em peças de um tile: lo/hi
dizem se o conteúdo encosta na borda esquerda/direita da face (continua no vizinho da tela).

Uso: scripts/audit_wall_sprites.py [pasta do jogo]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audit_floor_sprites import ALPHA, GAME, read_pack  # noqa: E402

PREFIXES = ["overlay_blood_wall_01_", "overlay_grime_wall_01_", "d_wallcracks_1_", "f_wallvines_1_",
            "overlay_graffiti_wall_01_", "overlay_messages_wall_01_"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "wall_sprites.lua")
DEPTH = {"4": "W", "5": "N"}


def depths():
    out = {}
    for line in open(os.path.join(GAME, "media", "tileDepthTextureAssignments.txt")):
        m = re.match(r"\s*(\S+) = preset_depthmaps_01_(\d+),", line)
        if m:
            out[m.group(1)] = DEPTH.get(m.group(2), "C")
    return out


def attached():
    txt = open(os.path.join(GAME, "media", "newtiledefinitions.tiles.txt")).read()
    out = {}
    for m in re.finditer(r"// (\S+)\s*\n\s*tile\s*\{([^}]*)\}", txt):
        body = m.group(2)
        side = "W" if re.search(r"\battachedW\b", body) else "N" if re.search(r"\battachedN\b", body) else None
        if side:
            out[m.group(1)] = side
    return out


def measure(ox, oy, w, h, alpha):
    xs = [ox + k % w for k in range(w * h) if alpha[k] >= ALPHA]
    if not xs:
        return None
    left = sum(1 for x in xs if x < 64) / len(xs)
    if left >= 0.5:
        lo, hi = min(xs) <= 3, max(xs) >= 63
    else:
        lo, hi = min(xs) <= 61, max(xs) >= 122
    return left, lo, hi


def main():
    sprites = read_pack(os.path.join(GAME, "media", "texturepacks", "Tiles2x.pack"),
                        lambda n: n.startswith(tuple(PREFIXES)))
    dep, att = depths(), attached()
    lines = ["-- Gerado por scripts/audit_wall_sprites.py (só medida do pack Tiles2x, nada copiado).",
             "-- left: fração do conteúdo na metade esquerda do quadro (parede W; a N fica à direita);",
             "-- lo/hi: o conteúdo encosta na borda esquerda/direita da face (o desenho continua no vizinho);",
             "-- depth: lado por tileDepthTextureAssignments (W, N, C = canto/outro; nil = textura própria);",
             "-- attached: attachedW/attachedN em newtiledefinitions.tiles.txt (nil = sem).",
             "return {"]

    def key(n):
        m = re.match(r"(.*_)(\d+)$", n)
        return (m.group(1), int(m.group(2)))

    def lua(v):
        return "nil" if v is None else '"%s"' % v

    for name in sorted(sprites, key=key):
        r = measure(*sprites[name])
        if r is None:
            continue  # entrada vazia no pack
        left, lo, hi = r
        lines.append('    ["%s"] = { left = %.2f, lo = %s, hi = %s, depth = %s, attached = %s },'
                     % (name, left, "true" if lo else "false", "true" if hi else "false",
                        lua(dep.get(name)), lua(att.get(name))))
    lines.append("}")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("%d sprites medidos -> %s" % (len(lines) - 7, OUT))


if __name__ == "__main__":
    main()
