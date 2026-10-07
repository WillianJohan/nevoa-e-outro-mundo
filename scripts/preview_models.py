#!/usr/bin/env python3
"""Prévia dos modelos de scripts/gen_models.py (sprint 0041): quatro vistas por sexo.

Rasterizador simples com z-buffer: UV e normal interpolados por pixel, textura sem filtro,
luz difusa, face de trás cortada como no jogo. Cabeça cinza de referência: um elipsoide no
tamanho medido dos óculos de esqui vanilla (HEADS do gerador), não a malha do jogo.

Uso: python3 scripts/preview_models.py [saída.png]
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import gen_models as g  # noqa: E402

SIZE = 320
SCALE = 1900           # pixels por metro
LIGHT = np.array([0.6, 0.3, 0.75])
# vistas: (nome, rotação em volta de X pela cabeça, inclinação) — câmera olha pra −Z da vista
VIEWS = (("frente", 0.0, 0.0), ("lado", math.pi / 2, 0.0), ("trás", math.pi, 0.0), ("iso", math.pi / 4, 0.55))


def head(h, n=24):
    """Elipsoide de referência: cabeça na altura dos olhos (y, z dos óculos, um pouco pra dentro)."""
    z0 = (h["z"][0] + h["z"][1]) / 2
    ry, rz, rx, cx = h["y"] - 0.004, (h["z"][1] - h["z"][0]) / 2 - 0.004, 0.115, 0.085
    m = g.Mesh()
    verts, uvs, faces = [], [], []
    for i in range(n + 1):
        for j in range(2 * n + 1):
            ph, th = math.pi * i / n, 2 * math.pi * j / (2 * n)
            verts.append([cx + rx * math.cos(ph), ry * math.sin(ph) * math.sin(th), z0 + rz * math.sin(ph) * math.cos(th)])
            uvs.append((0.0, 0.0))
    w = 2 * n + 1
    for i in range(n):
        for j in range(2 * n):
            p0, p1, q0, q1 = i * w + j, i * w + j + 1, (i + 1) * w + j, (i + 1) * w + j + 1
            faces += [[p0, q0, q1], [p0, q1, p1]]
    m.add_shell(verts, uvs, faces, "head")
    return m


def render(meshes, tex, yaw, tilt):
    color = np.zeros((SIZE, SIZE, 3), np.float32)
    color[:] = (40, 44, 52)
    depth = np.full((SIZE, SIZE), -np.inf)
    cy, sy, ct, st = math.cos(yaw), math.sin(yaw), math.cos(tilt), math.sin(tilt)
    light = LIGHT / np.linalg.norm(LIGHT)

    def rot(p):
        # cabeça: X pra cima, Y de lado, Z pra frente → câmera: (lado, cima, profundidade)
        y, z = p[..., 1] * cy - p[..., 2] * sy, p[..., 1] * sy + p[..., 2] * cy
        x = p[..., 0]
        return np.stack([y, x * ct - z * st, x * st + z * ct], axis=-1)
    th, tw = tex.shape[:2]
    for mesh, flat in meshes:
        v = rot(np.array(mesh.verts) - [0.085, 0, 0])
        n, uv = rot(np.array(mesh.normals)), np.array(mesh.uvs)
        sx, sy2 = SIZE / 2 + v[:, 0] * SCALE, SIZE * 0.55 - v[:, 1] * SCALE
        for f in mesh.faces:
            a, b, c = f
            area = (sx[b] - sx[a]) * (sy2[c] - sy2[a]) - (sx[c] - sx[a]) * (sy2[b] - sy2[a])
            if area >= 0:
                continue                           # face de trás (y da tela pra baixo): o jogo corta
            x0, x1 = int(max(0, min(sx[f]))), int(min(SIZE - 1, max(sx[f]) + 1))
            y0, y1 = int(max(0, min(sy2[f]))), int(min(SIZE - 1, max(sy2[f]) + 1))
            if x0 > x1 or y0 > y1:
                continue
            py, px = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
            w0 = ((sx[b] - px) * (sy2[c] - py) - (sx[c] - px) * (sy2[b] - py)) / area
            w1 = ((sx[c] - px) * (sy2[a] - py) - (sx[a] - px) * (sy2[c] - py)) / area
            w2 = 1 - w0 - w1
            inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not inside.any():
                continue
            z = w0 * v[a, 2] + w1 * v[b, 2] + w2 * v[c, 2]
            win = depth[y0:y1 + 1, x0:x1 + 1]
            ok = inside & (z > win)
            if not ok.any():
                continue
            win[ok] = z[ok]
            nn = w0[..., None] * n[a] + w1[..., None] * n[b] + w2[..., None] * n[c]
            lit = 0.35 + 0.65 * np.clip(nn @ light / (np.linalg.norm(nn, axis=-1) + 1e-12), 0, 1)
            if flat is not None:
                col = np.broadcast_to(np.asarray(flat, np.float32), z.shape + (3,))
            else:
                uu = w0 * uv[a, 0] + w1 * uv[b, 0] + w2 * uv[c, 0]
                vv = w0 * uv[a, 1] + w1 * uv[b, 1] + w2 * uv[c, 1]
                col = tex[np.clip((vv * th).astype(int), 0, th - 1), np.clip((uu * tw).astype(int), 0, tw - 1)]
            color[y0:y1 + 1, x0:x1 + 1][ok] = (col * lit[..., None])[ok]
    return Image.fromarray(np.clip(color, 0, 255).astype(np.uint8))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/nom_models_preview.png"
    tex = g.texture().astype(np.float32)
    sheet = Image.new("RGB", (SIZE * len(VIEWS), SIZE * 2))
    for row, sex in enumerate(g.HEADS):
        meshes = [(head(g.HEADS[sex]), (150, 146, 140)), (g.build(sex), None)]
        for col, (_, yaw, tilt) in enumerate(VIEWS):
            sheet.paste(render(meshes, tex, yaw, tilt), (col * SIZE, row * SIZE))
    sheet.save(out)
    print("ok", out)


if __name__ == "__main__":
    main()
