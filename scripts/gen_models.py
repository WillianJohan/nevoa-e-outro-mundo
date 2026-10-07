#!/usr/bin/env python3
"""Gera os modelos 3D próprios do mod (sprint 0041), procedurais e originais.

Venda do Estalador: faixa de atadura com volume em volta dos olhos, dois arames farpados
enrolados por cima (com farpas) e o nó atrás com as duas pontas caindo. Peça estática
presa ao osso da cabeça (m_Static, m_AttachBone Bip01_Head), um modelo por sexo.

Saída (mod/42/media/):
  models_X/Static/Clothes/NOM_M_EstaladorVenda.x   .x texto (DirectX), sem templates
  models_X/Static/Clothes/NOM_F_EstaladorVenda.x
  textures/NOM/NOM_EstaladorVenda3D.png            128  pano em cima e embaixo (espelhado),
                                                        faixa de ferrugem no meio pro arame

Medido nos .x vanilla, só números (pz-api-notes §32):
- quadro do osso da cabeça em metros: X sobe pela cabeça, Y de orelha a orelha, Z pra
  frente (a lente dos óculos de esqui fica em z +0,077 com y = 0);
- winding: cross(b−a, c−a) aponta pro lado da normal gravada;
- a cabeça na altura dos olhos: os óculos de esqui de cada sexo (HEADS).

O jogo pode ler v de cima ou de baixo: a textura é espelhada em volta de v = 0,5 e o
arame usa só a faixa do meio (WIRE_V), então as duas leituras dão o mesmo desenho.

Cada parte é uma casca fechada (cada aresta em duas faces) e virada pra fora (volume com
sinal positivo): o culling de face de trás nunca mostra buraco. Sem sorteio: rodar de novo
dá os mesmos bytes. Uso: python3 scripts/gen_models.py (testes: tests/test_models.py).
"""
import math
import os

import numpy as np
from PIL import Image

MEDIA = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media")
MODELS = os.path.join(MEDIA, "models_X", "Static", "Clothes")
TEXTURE = "NOM_EstaladorVenda3D"

# Cabeça na altura dos olhos, pelos óculos de esqui vanilla (M_/F_Glasses_SkiGoggles.x):
# meia largura em y, z de trás e da frente, altura (x) do centro da faixa na frente e atrás
# (a tira dos óculos sobe atrás até x ≈ 0,10 no masculino).
HEADS = {
    "M": {"y": 0.060, "z": (-0.073, 0.077), "front": 0.079, "back": 0.100},
    "F": {"y": 0.057, "z": (-0.062, 0.081), "front": 0.071, "back": 0.091},
}
GAP = 0.001            # folga entre os óculos e o lado de dentro da faixa
THICK = 0.0045         # espessura da faixa (atadura em várias voltas)
HALF_FRONT = 0.017     # meia altura da faixa na frente (cobre os olhos)
HALF_BACK = 0.011      # e atrás, onde aperta
RING = 56              # segmentos em volta da cabeça
PROFILE = 10           # pontos no perfil arredondado da faixa

WIRE_R = 0.0015        # raio do arame (estilizado: fino de verdade some na tela)
WIRE_WAVES = 7         # voltas de cada arame em volta da faixa
WIRE_STEPS = 12        # amostras por volta
WIRE_SIDES = 5
BARB_LEN = 0.0055
BARB_BASE = 0.0009
BARBS_PER_WAVE = 2

# Faixas da textura (v de 0 a 1, de cima pra baixo). O pano de cima é espelhado embaixo.
CLOTH_V = (0.02, 0.38)
WIRE_V = (0.40, 0.60)
TAIL_U = (0.08, 0.22)  # pedaço do pano usado nas pontas do nó (longe das manchas dos olhos)


def unit(v):
    return v / np.linalg.norm(v)


class Mesh:
    """Vértices, normais, UV e faces; parts[i] diz de que parte é a face i."""

    def __init__(self):
        self.verts, self.normals, self.uvs, self.faces, self.parts = [], [], [], [], []

    def add_shell(self, verts, uvs, faces, part, flat=False):
        """Junta uma casca fechada. Vira as faces se o volume com sinal der negativo e
        calcula a normal: suave (média por posição, a costura do UV não aparece) ou chapada."""
        v = np.asarray(verts, float)
        f = np.asarray(faces, int)
        a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
        if np.einsum("ij,ij->i", a, np.cross(b, c)).sum() < 0:
            f = f[:, ::-1]
            a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
        cross = np.cross(b - a, c - a)
        if flat:
            nv, nu, nf = [], [], []
            for k, tri in enumerate(f):
                for q in tri:
                    nv.append(v[q])
                    nu.append(uvs[q])
                nf.append([3 * k, 3 * k + 1, 3 * k + 2])
            n = np.repeat(np.array([unit(x) for x in cross]), 3, axis=0)
            v, uvs, f = np.array(nv), nu, np.array(nf)
        else:
            keys = [tuple(p) for p in np.round(v, 7).tolist()]
            acc = {}
            for tri, cr in zip(f, cross):
                for q in tri:
                    acc[keys[q]] = acc.get(keys[q], 0) + cr
            n = np.array([unit(acc[k]) for k in keys])
        base = len(self.verts)
        self.verts += v.tolist()
        self.normals += n.tolist()
        self.uvs += [list(map(float, x)) for x in uvs]
        self.faces += (f + base).tolist()
        self.parts += [part] * len(f)


def sweep(points, frames, profile, uv_of, closed):
    """Varre um perfil 2D fechado ao longo de uma linha. points[i] é o centro, frames[i] =
    (A, B) o plano do perfil, profile[i] a lista de (a, b) daquela amostra. Caminho fechado
    repete a primeira coluna no fim (costura do UV); aberto ganha tampa nas duas pontas."""
    n, m = len(points), len(profile[0])
    cols = n + 1 if closed else n
    verts, uvs, faces = [], [], []
    for i in range(cols):
        k = i % n
        A, B = frames[k]
        for j, (pa, pb) in enumerate(profile[k]):
            verts.append(points[k] + pa * A + pb * B)
            uvs.append(uv_of(i / (cols - 1), j, pa, pb, k))
    for i in range(cols - 1):
        for j in range(m):
            p0, p1 = i * m + j, i * m + (j + 1) % m
            q0, q1 = p0 + m, p1 + m
            faces += [[p0, q0, q1], [p0, q1, p1]]
    if not closed:
        for i, flip in ((0, True), (cols - 1, False)):
            centre = len(verts)
            verts.append(np.mean([verts[i * m + j] for j in range(m)], axis=0))
            uvs.append(uvs[i * m])
            for j in range(m):
                tri = [centre, i * m + j, i * m + (j + 1) % m]
                faces.append(tri[::-1] if flip else tri)
    return verts, uvs, faces


def band_frame(h, th):
    """Ponto na elipse de dentro da faixa, a normal pra fora (horizontal) e a tangente."""
    z0 = (h["z"][0] + h["z"][1]) / 2
    ry = h["y"] + GAP
    rz = (h["z"][1] - h["z"][0]) / 2 + GAP
    s = (1 - math.cos(th)) / 2                      # 0 na frente, 1 atrás
    x = h["front"] + (h["back"] - h["front"]) * s
    p = np.array([x, ry * math.sin(th), z0 + rz * math.cos(th)])
    out = unit(np.array([0.0, math.sin(th) / ry, math.cos(th) / rz]))
    dx = (h["back"] - h["front"]) * math.sin(th) / 2
    tan = unit(np.array([dx, ry * math.cos(th), -rz * math.sin(th)]))
    up = unit(np.cross(tan, out))
    if up[0] < 0:
        up = -up
    out = unit(np.cross(up, tan))
    if out @ np.array([0.0, math.sin(th), math.cos(th)]) < 0:
        out = -out
    half = HALF_FRONT + (HALF_BACK - HALF_FRONT) * s
    return p, out, up, half


def ring_angle(i, n):
    return -math.pi + 2 * math.pi * i / n          # frente em 0, costura atrás


def cloth_v(t):
    """t de −1 (embaixo) a 1 (em cima) → v no pano de cima."""
    return CLOTH_V[0] + (CLOTH_V[1] - CLOTH_V[0]) * (1 - t) / 2


def band(mesh, h):
    pts, frames, prof = [], [], []
    for i in range(RING):
        th = ring_angle(i, RING)
        p, out, up, half = band_frame(h, th)
        bulge = 1 + 0.15 * math.sin(5 * th) ** 2          # voltas mal enroladas
        t = THICK * bulge
        pts.append(p + out * t / 2)
        frames.append((out, up))
        ring = []
        for j in range(PROFILE):
            phi = 2 * math.pi * j / PROFILE
            c, s = math.cos(phi), math.sin(phi)
            ring.append((t / 2 * math.copysign(abs(c) ** 0.5, c), half * math.copysign(abs(s) ** 0.4, s)))
        prof.append(ring)
    halves = [band_frame(h, ring_angle(i, RING))[3] for i in range(RING)]
    v, uv, f = sweep(pts, frames, prof, lambda u, j, pa, pb, k: (u, cloth_v(pb / halves[k])), closed=True)
    mesh.add_shell(v, uv, f, "band")


def wire(mesh, h, phase):
    n = WIRE_WAVES * WIRE_STEPS
    pts, outs = [], []
    for i in range(n):
        th = ring_angle(i, n)
        p, out, up, half = band_frame(h, th)
        b = 1.08 * half * math.sin(WIRE_WAVES * th + phase)
        lift = THICK * 1.15 * max(0.0, 1 - (b / half) ** 2) ** 0.25
        pts.append(p + out * (lift + WIRE_R + 0.0003) + up * b)
        outs.append(out)
    frames = []
    for i in range(n):
        tan = unit(pts[(i + 1) % n] - pts[i - 1])
        a = unit(outs[i] - (outs[i] @ tan) * tan)
        frames.append((a, np.cross(tan, a)))
    ring = [(WIRE_R * math.cos(2 * math.pi * j / WIRE_SIDES), WIRE_R * math.sin(2 * math.pi * j / WIRE_SIDES))
            for j in range(WIRE_SIDES)]
    wire_v = (WIRE_V[0] + WIRE_V[1]) / 2
    v, uv, f = sweep(pts, frames, [ring] * n, lambda u, j, pa, pb, k: (u, wire_v), closed=True)
    mesh.add_shell(v, uv, f, "wire")
    step = WIRE_STEPS // BARBS_PER_WAVE
    for k, i in enumerate(range(step // 2, n, step)):
        a, b = frames[i]
        barb(mesh, pts[i], unit(a + b) if k % 2 == 0 else unit(a - b))


def barb(mesh, p, d):
    """Farpa: tetraedro com a ponta pra fora (d sempre tem componente pra fora da cabeça)."""
    e1 = unit(np.cross(d, [1.0, 0.0, 0.0]) if abs(d[0]) < 0.9 else np.cross(d, [0.0, 1.0, 0.0]))
    e2 = np.cross(d, e1)
    base = [p + BARB_BASE * (math.cos(t) * e1 + math.sin(t) * e2) for t in (0, 2.0944, 4.1888)]
    verts = base + [p + d * BARB_LEN]
    wire_v = (WIRE_V[0] + WIRE_V[1]) / 2
    uvs = [(0.5, wire_v)] * 4
    mesh.add_shell(verts, uvs, [[0, 1, 2], [0, 3, 1], [1, 3, 2], [2, 3, 0]], "barb", flat=True)


def knot(mesh, h):
    """O nó atrás: um bolo achatado por cima da faixa."""
    p, out, up, half = band_frame(h, math.pi)
    c = p + out * (THICK + 0.004)
    rad = np.array([0.0075, 0.0085, 0.0045])     # (up, lado, fora)
    side = unit(np.cross(up, out))
    lat, lon = 6, 10
    verts, uvs, faces = [c + up * rad[0]], [(TAIL_U[0], CLOTH_V[0])], []
    for a in range(1, lat):
        ph = math.pi * a / lat
        for b in range(lon + 1):
            th = 2 * math.pi * b / lon
            q = (math.cos(ph) * rad[0] * up + math.sin(ph) * (math.cos(th) * rad[1] * side
                                                             + math.sin(th) * rad[2] * out))
            verts.append(c + q)
            uvs.append((TAIL_U[0] + (TAIL_U[1] - TAIL_U[0]) * b / lon, cloth_v(math.cos(ph))))
    verts.append(c - up * rad[0])
    uvs.append((TAIL_U[1], CLOTH_V[1]))
    last = len(verts) - 1
    row = lambda a: 1 + (a - 1) * (lon + 1)
    for b in range(lon):
        faces.append([0, row(1) + b, row(1) + b + 1])
        faces.append([last, row(lat - 1) + b + 1, row(lat - 1) + b])
    for a in range(1, lat - 1):
        for b in range(lon):
            p0, p1 = row(a) + b, row(a) + b + 1
            q0, q1 = row(a + 1) + b, row(a + 1) + b + 1
            faces += [[p0, q0, q1], [p0, q1, p1]]
    mesh.add_shell(verts, uvs, faces, "band")


def tails(mesh, h):
    """As duas pontas do nó caindo atrás, uma pra cada lado, com uma ondinha."""
    p, out, up, half = band_frame(h, math.pi)
    side = unit(np.cross(up, out))
    start = p + out * (THICK + 0.005)
    for sgn, length in ((1, 0.046), (-1, 0.038)):
        n = 7
        pts = []
        for i in range(n):
            t = i / (n - 1)
            pts.append(start - up * (length * t) + side * sgn * (0.003 + 0.010 * t)
                       + out * (0.004 * t + 0.0015 * math.sin(math.pi * 1.5 * t)))
        frames = []
        for i in range(n):
            tan = unit(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
            a = unit(side - (side @ tan) * tan)
            frames.append((a, np.cross(tan, a)))
        w, th = 0.0055, 0.0009
        rect = [(w, th), (-w, th), (-w, -th), (w, -th)]
        prof = [[(x * (1 - 0.35 * i / (n - 1)), y) for x, y in rect] for i in range(n)]
        uv_of = lambda u, j, pa, pb, k: (TAIL_U[0] + (TAIL_U[1] - TAIL_U[0]) * (0.5 + pa / (2 * w)),
                                         CLOTH_V[0] + (CLOTH_V[1] - CLOTH_V[0]) * u)
        v, uv, f = sweep(pts, frames, prof, uv_of, closed=False)
        mesh.add_shell(v, uv, f, "band")


def build(sex):
    h = HEADS[sex]
    m = Mesh()
    band(m, h)
    knot(m, h)
    tails(m, h)
    for phase in (0.0, math.pi):
        wire(m, h, phase)
    return m


def fmt(x):
    return "%.6f" % (x + 0.0 if abs(x) >= 5e-7 else 0.0)


def to_x(mesh, name):
    """O .x texto que o Assimp lê (o mesmo leiaute do vanilla, CRLF, sem templates)."""
    out = ["xof 0303txt 0032", "",
           "Material %s {" % TEXTURE,
           " 1.000000;1.000000;1.000000;1.000000;;",
           " 10.000000;",
           " 0.000000;0.000000;0.000000;;",
           " 0.000000;0.000000;0.000000;;",
           "",
           " TextureFilename {",
           '  "%s.png";' % TEXTURE,
           " }",
           "}",
           "",
           "Frame %s {" % name,
           "",
           " FrameTransformMatrix {",
           "  1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,"
           "0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000;;",
           " }",
           "",
           " Mesh %s {" % name]

    def listing(rows, indent):
        for k, r in enumerate(rows):
            out.append(indent + r + (";;" if k == len(rows) - 1 else ";,"))

    nv, nf = len(mesh.verts), len(mesh.faces)
    out.append("  %d;" % nv)
    listing([";".join(fmt(c) for c in v) for v in mesh.verts], "  ")
    out.append("  %d;" % nf)
    faces = ["3;%d,%d,%d" % tuple(f) for f in mesh.faces]
    listing(faces, "  ")
    out += ["", "  MeshNormals {", "   %d;" % nv]
    listing([";".join(fmt(c) for c in n) for n in mesh.normals], "   ")
    out.append("   %d;" % nf)
    listing(faces, "   ")
    out += ["  }", "", "  MeshMaterialList {", "   1;", "   %d;" % nf]
    out += ["   0," for _ in range(nf - 1)] + ["   0;", "   { %s }" % TEXTURE, "  }", ""]
    out += ["  MeshTextureCoords {", "   %d;" % nv]
    listing(["%s;%s" % (fmt(u), fmt(v)) for u, v in mesh.uvs], "   ")
    out += ["  }", " }", "}", ""]
    return "\r\n".join(out)


def texture(size=128):
    """Pano em cima (faixas, manchas de sangue nos olhos), o mesmo espelhado embaixo e a
    ferrugem do arame no meio. Sem sorteio: as manchas saem de senos fixos."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    top = int(WIRE_V[0] * size) + 1                # linhas de pano em cima
    u, v = x / size, y / size
    shade = 0.95 + 0.05 * np.sin(u * 37.0 + v * 11.0) * np.sin(v * 53.0 + u * 7.0)
    rgb = np.asarray((236, 228, 206), np.float32)[None, None, :] * shade[..., None]

    def paint(ink, k):
        nonlocal rgb
        rgb = rgb * (1 - k[..., None]) + np.asarray(ink, np.float32)[None, None, :] * k[..., None]

    paint((58, 44, 34), ((y % 17) < 3).astype(np.float32))          # fresta entre as voltas
    vc = (CLOTH_V[0] + CLOTH_V[1]) / 2
    for ex in (0.5 - 0.089, 0.5 + 0.089):                            # um olho de cada lado da frente
        wob = 1 + 0.25 * np.sin(np.arctan2(v - vc, u - ex) * 5 + ex * 40)
        d = np.hypot((u - ex) / 0.075, (v - vc) / 0.13) / wob
        paint((104, 22, 18), (d < 1).astype(np.float32))              # sangue seco
        paint((52, 12, 10), (d < 0.45).astype(np.float32))            # mais escuro no meio
    rgb[size - top:] = rgb[:top][::-1]                               # espelho: o v pode vir virado
    rust = (92, 40, 16)
    band = (y >= top) & (y < size - top)
    rgb[band] = np.asarray(rust, np.float32) * (0.9 + 0.1 * np.sin(x[band] * 0.7))[..., None]
    mid = (np.abs(y - (size - 1) / 2) < 1)
    rgb[mid] = (138, 66, 30)                                         # brilho do arame
    return np.clip(rgb, 0, 255).astype(np.uint8)


def main():
    os.makedirs(MODELS, exist_ok=True)
    for sex in HEADS:
        name = "NOM_%s_EstaladorVenda" % sex
        with open(os.path.join(MODELS, name + ".x"), "w", encoding="ascii", newline="") as f:
            f.write(to_x(build(sex), name))
        print("ok models_X/Static/Clothes/%s.x" % name)
    path = os.path.join(MEDIA, "textures", "NOM", TEXTURE + ".png")
    Image.fromarray(texture(), "RGB").save(path, optimize=True)
    print("ok textures/NOM/%s.png" % TEXTURE)


if __name__ == "__main__":
    main()
