#!/usr/bin/env python3
"""Gera os modelos 3D próprios do mod (sprints 0041–0043), procedurais e originais.

Peças estáticas presas ao osso da cabeça (m_Static, m_AttachBone Bip01_Head), um modelo por
sexo (NOM_M_/NOM_F_<peça>.x):
  EstaladorVenda    faixa de atadura com volume nos olhos, dois arames farpados por cima (com
                    farpas), nó atrás com as duas pontas caindo (0041)
  CorredorBoca      boca escancarada larga demais: buraco escuro, lábios rasgados, dentes em
                    volta, rasgos até perto da orelha (0042)
  SemRostoEstatica  casca lisa em volta da cabeça inteira, sem feição nenhuma (0042; a textura de
                    chiado é a de scripts/gen_textures.py)
  CarpideiraCabelo  cortina de mechas pretas caindo da cabeça, densa na frente do rosto, três
                    mechas brancas (0042)
  TicaoCrosta       crosta de carvão em placas na cabeça inteira, dois olhos de brasa, lascas
                    no alto e atrás, três fitas de fumaça subindo (0043, a versão por script do
                    teste de IA)

Saída (mod/42/media/):
  models_X/Static/Clothes/NOM_M_<peça>.x, NOM_F_<peça>.x   .x texto (DirectX), sem templates
  textures/NOM/NOM_EstaladorVenda3D.png    128  pano (espelhado), ferrugem do arame no meio
  textures/NOM/NOM_CorredorBoca3D.png      128  dente, lábio, buraco no meio (espelhado)
  textures/NOM/NOM_CarpideiraCabelo3D.png  128  piche com fios, mecha branca no meio (espelhado)
  textures/NOM/NOM_TicaoCrosta3D.png       128  carvão rachado em brasa, fumaça, brasa no meio (espelhado)

Medido nos .x vanilla, só números (pz-api-notes §32):
- quadro do osso da cabeça em metros: X sobe pela cabeça, Y de orelha a orelha, Z pra
  frente (a lente dos óculos de esqui fica em z +0,077 com y = 0);
- winding: cross(b−a, c−a) aponta pro lado da normal gravada;
- a cabeça na altura dos olhos: os óculos de esqui de cada sexo (HEADS);
- a cabeça inteira e o rosto: touca de banho, máscaras de hóquei e cirúrgica, brinco de nariz,
  capacete fechado (FACES).

O jogo pode ler v de cima ou de baixo: as texturas daqui são espelhadas em volta de v = 0,5 e
cada parte usa uma faixa que o espelho leva nela mesma, então as duas leituras dão o mesmo desenho.

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

# Cabeça inteira e rosto (sprint 0042), números dos .x vanilla:
#   top, back, side   alto do crânio, nuca e lado (touca de banho)
#   nose              frente do rosto na altura do nariz (máscara de hóquei)
#   chin              embaixo do queixo, x e z (máscara cirúrgica)
#   mouth             centro da boca (entre a narina do brinco de nariz e o queixo), meia altura
#   face_ry, face_rz  o rosto na altura da boca: meia largura e frente (máscaras de hóquei e bandana)
FACES = {
    "M": {"top": 0.181, "back": -0.092, "side": 0.071, "nose": 0.084, "chin": (-0.017, 0.062),
          "mouth": 0.024, "mouth_half": 0.015, "face_ry": 0.050, "face_rz": 0.076},
    "F": {"top": 0.176, "back": -0.082, "side": 0.066, "nose": 0.086, "chin": (-0.007, 0.064),
          "mouth": 0.019, "mouth_half": 0.013, "face_ry": 0.048, "face_rz": 0.078},
}

# Boca do Corredor
MOUTH_PHI = 0.8        # meia abertura em ângulo em volta do rosto (~7 cm de canto a canto)
LIP_R = 0.0030         # raio do lábio rasgado (mais o serrilhado)
TEETH = 8              # dentes em cima e embaixo
TEAR_PHI = 0.42        # quanto o rasgo segue do canto pra orelha
TEETH_V, LIPS_V, HOLE_V = 0.07, 0.26, 0.5
TEETH_U = 0.53         # no meio de um dente da textura (o vão escuro fica a cada 1/8)

# Casca do Sem-rosto: superelipsoide em volta da cabeça inteira, com folga
SHELL_GAP = 0.008      # além do crânio
SHELL_CHIN = 0.022     # abaixo do queixo
SHELL_POW = 3.0        # expoente na vertical: mais "caixa" que elipse, cobre o queixo
SHELL_LAT, SHELL_LON = 18, 28

# Cabelo da Carpideira: a superfície por onde as mechas passam (elipsoide um pouco fora do
# crânio, mais longe na frente pra não encostar no nariz) e as mechas
HAIR = {
    "M": {"c": (0.085, 0.0, -0.004), "r": (0.100, 0.074, 0.098)},
    "F": {"c": (0.082, 0.0, 0.0), "r": (0.096, 0.070, 0.096)},
}
STRANDS = 36
STREAKS = (-0.28, 0.06, 0.34)   # ângulos das três mechas brancas (0 = meio da testa)
HAIR_V, STREAK_V = (0.05, 0.30), (0.42, 0.58)


# Crosta do Tição: a casca do Sem-rosto um pouco mais grossa, em placas de alturas diferentes
CRUST_GAP = 0.010
CRUST_PLATES = 22      # direções-semente das placas (esfera de Fibonacci)
CRUST_LUMP = 0.005     # quanto a placa mais alta sobe
CRUST_V, SMOKE_V, EMBER_V = (0.02, 0.34), (0.37, 0.43), 0.5
SHARD_V = 0.035        # faixa de carvão liso (sem rachadura) no alto da textura
SHARDS = 14
WISPS = ((0.22, -2.1), (0.30, 0.5), (0.18, 2.5))   # (ângulo do alto, ângulo em volta) de cada fumaça


def hash01(*k):
    """0..1 fixo por chave (sem sorteio: o mesmo arquivo a cada rodada)."""
    x = math.sin(sum(v * c for v, c in zip(k, (12.9898, 78.233, 37.719)))) * 43758.5453
    return x - math.floor(x)


def unit(v):
    return v / np.linalg.norm(v)


class Mesh:
    """Vértices, normais, UV e faces; parts[i] diz de que parte é a face i e strand[i] de que
    mecha (−1 fora do cabelo)."""

    def __init__(self, texture=""):
        self.texture = texture
        self.verts, self.normals, self.uvs, self.faces, self.parts, self.strand = [], [], [], [], [], []

    def add_shell(self, verts, uvs, faces, part, flat=False, strand=-1):
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
        self.strand += [strand] * len(f)


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
        for i, flip in ((0, False), (cols - 1, True)):
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


def build_venda(sex):
    h = HEADS[sex]
    m = Mesh("NOM_EstaladorVenda3D")
    band(m, h)
    knot(m, h)
    tails(m, h)
    for phase in (0.0, math.pi):
        wire(m, h, phase)
    return m


def face_point(f, phi, x, lift=0.0):
    """Ponto no rosto na altura da boca (cilindro elíptico em volta do eixo X) e a normal pra fora."""
    ry, rz = f["face_ry"], f["face_rz"]
    out = unit(np.array([0.0, math.sin(phi) / ry, math.cos(phi) / rz]))
    return np.array([x, ry * math.sin(phi), rz * math.cos(phi)]) + out * lift, out


def mouth_half(f, phi):
    """Meia altura da boca aberta: cheia no meio, 45% nos cantos. Canto em ponta dobraria o tubo do
    lábio por cima dele mesmo (raio da curva menor que o do tubo)."""
    return f["mouth_half"] * (0.45 + 0.55 * max(0.0, 1 - (phi / MOUTH_PHI) ** 2) ** 0.7)


def mouth_loop(f, tau):
    """Contorno da boca: τ = 0 no canto esquerdo, π/2 no meio de cima, π no direito, 3π/2 embaixo."""
    phi = -MOUTH_PHI * math.cos(tau)
    return phi, f["mouth"] + mouth_half(f, phi) * math.sin(tau)


def boca(sex):
    f = FACES[sex]
    m = Mesh("NOM_CorredorBoca3D")
    # o buraco: lente escura que entra no rosto e fica um pouco à frente dele
    n = 17
    pts, frames, prof = [], [], []
    for i in range(n):
        phi = -MOUTH_PHI * 0.97 + 2 * MOUTH_PHI * 0.97 * i / (n - 1)
        p, out = face_point(f, phi, f["mouth"], -0.001)
        pts.append(p)
        frames.append((out, np.array([1.0, 0.0, 0.0])))
        h = mouth_half(f, phi)
        prof.append([(0.004 * math.cos(2 * math.pi * j / 8), h * math.sin(2 * math.pi * j / 8)) for j in range(8)])
    v, uv, fc = sweep(pts, frames, prof, lambda u, j, pa, pb, k: (u, HOLE_V), closed=False)
    m.add_shell(v, uv, fc, "cavity")
    # lábio rasgado: tubo serrilhado em volta do contorno
    n = 48
    pts, outs = [], []
    for i in range(n):
        tau = 2 * math.pi * i / n
        phi, x = mouth_loop(f, tau)
        p, out = face_point(f, phi, x, 0.002)
        pts.append(p)
        outs.append(out)
    frames, prof = [], []
    for i in range(n):
        tan = unit(pts[(i + 1) % n] - pts[i - 1])
        a = unit(outs[i] - (outs[i] @ tan) * tan)
        frames.append((a, np.cross(tan, a)))
        tau = 2 * math.pi * i / n
        s = abs(math.sin(tau))                     # afina e alisa nos cantos (curva mais fechada)
        r = LIP_R * (0.4 + 0.6 * s) * (1 + 0.45 * s * (0.5 + 0.5 * math.sin(13 * tau + 1.7) * math.sin(7 * tau)))
        prof.append([(r * math.cos(2 * math.pi * j / 6), r * math.sin(2 * math.pi * j / 6)) for j in range(6)])
    v, uv, fc = sweep(pts, frames, prof, lambda u, j, pa, pb, k: (u, LIPS_V), closed=True)
    m.add_shell(v, uv, fc, "lips")
    # dentes: em cima apontam pra baixo, embaixo pra cima, um pouco pra frente; tamanhos tortos
    for row, (t0, t1, down) in enumerate(((0.18, 0.82, -1.0), (1.18, 1.82, 1.0))):
        for k in range(TEETH):
            tau = math.pi * (t0 + (t1 - t0) * (k + 0.5) / TEETH)
            phi, x = mouth_loop(f, tau)
            p, out = face_point(f, phi, x, 0.002)
            side = np.array([0.0, math.cos(phi), -math.sin(phi)])
            d = unit(np.array([down, 0.0, 0.0]) + 0.3 * out + 0.25 * (hash01(row, k, 1) - 0.5) * side)
            length = 0.0055 + 0.0035 * hash01(row, k, 2)
            tooth(m, p, d, length, 0.0019)
    # rasgos: dos cantos até perto da orelha, subindo um pouco
    for sgn in (-1, 1):
        n = 7
        pts, frames, prof = [], [], []
        for i in range(n):
            t = i / (n - 1)
            phi = sgn * (MOUTH_PHI + TEAR_PHI * t)
            p, out = face_point(f, phi, f["mouth"] + 0.008 * t ** 1.3, 0.0012)
            pts.append(p)
            frames.append((out, np.array([1.0, 0.0, 0.0])))
            w = 0.0022 * (1 - 0.7 * t)
            prof.append([(0.0012, w), (-0.0012, w), (-0.0012, -w), (0.0012, -w)])
        v, uv, fc = sweep(pts, frames, prof, lambda u, j, pa, pb, k: (u, HOLE_V), closed=False)
        m.add_shell(v, uv, fc, "tear")
    return m


def tooth(mesh, p, d, length, base):
    e1 = unit(np.cross(d, [0.0, 0.0, 1.0]) if abs(d[2]) < 0.9 else np.cross(d, [0.0, 1.0, 0.0]))
    e2 = np.cross(d, e1)
    ring = [p + base * (math.cos(t) * e1 + math.sin(t) * e2) for t in (0, 2.0944, 4.1888)]
    uvs = [(TEETH_U, TEETH_V)] * 4
    mesh.add_shell(ring + [p + d * length], uvs, [[0, 1, 2], [0, 3, 1], [1, 3, 2], [2, 3, 0]], "teeth", flat=True)


def head_shell(sex, gap):
    """Superelipsoide em volta da cabeça inteira (mais caixa na vertical pra cobrir o queixo),
    frente e nuca com raios próprios. Devolve o ponto em (ângulo do alto, ângulo em volta)."""
    f = FACES[sex]
    bottom = f["chin"][0] - SHELL_CHIN
    top = f["top"] + gap
    cx, rx = (top + bottom) / 2, (top - bottom) / 2
    ry = f["side"] + gap
    rz_front, rz_back = f["nose"] + gap + 0.005, -f["back"] + gap
    e = 2 / SHELL_POW

    def point(th, ps):
        c, s = math.cos(th), math.sin(th)
        rad = abs(s) ** e
        rz = rz_front if math.cos(ps) > 0 else rz_back
        return np.array([cx + rx * math.copysign(abs(c) ** e, c), ry * rad * math.sin(ps), rz * rad * math.cos(ps)])
    return point, top, bottom, cx


def shell_grid(sex, gap, v_band=(0.0, 1.0)):
    """Grade da casca: polo em cima, SHELL_LAT−1 anéis com a costura repetida, polo embaixo."""
    point, top, bottom, cx = head_shell(sex, gap)
    v0, dv = v_band[0], v_band[1] - v_band[0]
    verts, uvs, faces = [np.array([top, 0.0, 0.0])], [(0.5, v0)], []
    for i in range(1, SHELL_LAT):
        th = math.pi * i / SHELL_LAT
        for j in range(SHELL_LON + 1):
            verts.append(point(th, 2 * math.pi * j / SHELL_LON))
            uvs.append((j / SHELL_LON, v0 + dv * i / SHELL_LAT))
    verts.append(np.array([bottom, 0.0, 0.0]))
    uvs.append((0.5, v0 + dv))
    last, w = len(verts) - 1, SHELL_LON + 1
    row = lambda i: 1 + (i - 1) * w
    for j in range(SHELL_LON):
        faces.append([0, row(1) + j, row(1) + j + 1])
        faces.append([last, row(SHELL_LAT - 1) + j + 1, row(SHELL_LAT - 1) + j])
    for i in range(1, SHELL_LAT - 1):
        for j in range(SHELL_LON):
            p0, p1, q0, q1 = row(i) + j, row(i) + j + 1, row(i + 1) + j, row(i + 1) + j + 1
            faces += [[p0, q0, q1], [p0, q1, p1]]
    return verts, uvs, faces, cx


def semrosto(sex):
    """Casca lisa em volta da cabeça inteira. Sem nariz, olho nem boca."""
    m = Mesh("NOM_SemRostoEstatica")
    verts, uvs, faces, _ = shell_grid(sex, SHELL_GAP)
    m.add_shell(verts, uvs, faces, "shell")
    return m


def fibonacci(n):
    g = math.pi * (3 - math.sqrt(5))
    return [np.array([1 - 2 * (k + 0.5) / n, math.sqrt(1 - (1 - 2 * (k + 0.5) / n) ** 2) * math.cos(g * k),
                      math.sqrt(1 - (1 - 2 * (k + 0.5) / n) ** 2) * math.sin(g * k)]) for k in range(n)]


def blob(mesh, c, r, part, strand, uv, lat=5, lon=8):
    """Elipsoide fechado pequeno (olho de brasa)."""
    verts, faces = [c + [r[0], 0, 0]], []
    for i in range(1, lat):
        th = math.pi * i / lat
        for j in range(lon):
            ps = 2 * math.pi * j / lon
            verts.append(c + [r[0] * math.cos(th), r[1] * math.sin(th) * math.sin(ps), r[2] * math.sin(th) * math.cos(ps)])
    verts.append(c - [r[0], 0, 0])
    last = len(verts) - 1
    row = lambda i: 1 + (i - 1) * lon
    for j in range(lon):
        k = (j + 1) % lon
        faces.append([0, row(1) + j, row(1) + k])
        faces.append([last, row(lat - 1) + k, row(lat - 1) + j])
    for i in range(1, lat - 1):
        for j in range(lon):
            k = (j + 1) % lon
            faces += [[row(i) + j, row(i + 1) + j, row(i + 1) + k], [row(i) + j, row(i + 1) + k, row(i) + k]]
    mesh.add_shell(verts, [uv] * len(verts), faces, part, strand=strand)


def crosta(sex):
    """Crosta de carvão do Tição: a casca em placas (cada vértice sobe a altura da placa mais
    perto), dois olhos de brasa saindo da frente, lascas no alto e atrás, fumaça subindo."""
    m = Mesh("NOM_TicaoCrosta3D")
    verts, uvs, faces, cx = shell_grid(sex, CRUST_GAP, CRUST_V)
    seeds = fibonacci(CRUST_PLATES)
    centre = np.array([cx, 0.0, 0.0])
    for k, p in enumerate(verts):
        d = unit(p - centre)
        plate = max(range(CRUST_PLATES), key=lambda q: d @ seeds[q])
        verts[k] = p + d * CRUST_LUMP * hash01(plate, 11)
    m.add_shell(verts, uvs, faces, "crust")
    point, top, _, _ = head_shell(sex, CRUST_GAP)
    eye_x = HEADS[sex]["front"]                       # altura dos olhos (centro da venda na frente)
    for k, side in enumerate((-1, 1)):
        y = 0.030 * side
        ps = math.asin(y / (FACES[sex]["side"] + CRUST_GAP))
        z = point(math.pi / 2, ps)[2] * 0.97
        blob(m, np.array([eye_x, y, z]), (0.009, 0.014, 0.006), "ember", k, (0.5, EMBER_V))
    for k in range(SHARDS):
        if k < 4:
            th, ps = 0.12 + 0.2 * hash01(k, 21), 2 * math.pi * hash01(k, 22)
        else:
            th, ps = 0.3 + 0.9 * hash01(k, 21), math.pi * (0.6 + 0.8 * hash01(k, 22))
        base = point(th, ps)
        d = unit(unit(base - centre) + [0.35, 0, 0])
        e1 = unit(np.cross(d, [0.0, 0.0, 1.0]) if abs(d[2]) < 0.9 else np.cross(d, [0.0, 1.0, 0.0]))
        e2 = np.cross(d, e1)
        b, length = 0.005 + 0.002 * hash01(k, 23), 0.018 + 0.012 * hash01(k, 24)
        ring = [base + b * (math.cos(t) * e1 + math.sin(t) * e2) for t in (0, 2.0944, 4.1888)]
        m.add_shell(ring + [base + d * length], [(0.5, SHARD_V)] * 4,
                    [[0, 1, 2], [0, 3, 1], [1, 3, 2], [2, 3, 0]], "shard", flat=True, strand=k)
    for k, (th0, ps0) in enumerate(WISPS):
        start = point(th0, ps0)
        rise = 0.09 + 0.03 * hash01(k, 31)
        phase = 6.28 * hash01(k, 32)
        pts = []
        for i in range(11):
            t = i / 10
            pts.append(np.array([start[0] - 0.004 + rise * t,
                                 start[1] * (1 - 0.4 * t) + 0.016 * t * math.cos(phase + 5 * t),
                                 start[2] * (1 - 0.4 * t) + 0.016 * t * math.sin(phase + 5 * t)]))
        n = len(pts)
        side = unit(np.array([0.0, math.cos(ps0 + phase), -math.sin(ps0 + phase)]))
        frames, prof = [], []
        for i in range(n):
            tan = unit(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
            bb = unit(side - (side @ tan) * tan)
            frames.append((np.cross(tan, bb), bb))
            w = 0.003 + 0.007 * i / (n - 1)
            prof.append([(0.0008, w), (-0.0008, w), (-0.0008, -w), (0.0008, -w)])
        uv_of = lambda u, j, pa, pb, i: (u, SMOKE_V[0] + (SMOKE_V[1] - SMOKE_V[0]) * (0.5 + 0.5 * math.copysign(1, pb)))
        v, uv, fc = sweep(pts, frames, prof, uv_of, closed=False)
        m.add_shell(v, uv, fc, "smoke", flat=True, strand=k)   # fita fina torcida: normal suave vira
    return m


def cabelo(sex):
    """Mechas: cada uma sai perto do alto da cabeça, desce pela superfície do HAIR até a altura
    dos olhos e cai reta, abrindo um pouco pra fora. Mais densas na frente (tapam o rosto)."""
    h = HAIR[sex]
    c, r = np.array(h["c"]), np.array(h["r"])
    m = Mesh("NOM_CarpideiraCabelo3D")
    angles = []
    for k in range(STRANDS):
        s = -1 + 2 * (k + 0.5) / STRANDS
        angles.append(math.pi * math.copysign(abs(s) ** 1.6, s))
    white = {min(range(STRANDS), key=lambda k: abs(angles[k] - a)) for a in STREAKS}
    for k, psi in enumerate(angles):
        front = abs(psi) < math.pi / 3
        layer = 1 + (0.002 + 0.004 * hash01(k, 3)) / 0.09   # 2 a 6 mm acima do HAIR, em camadas
        th0 = 0.12 + 0.12 * hash01(k, 4)
        crown = []
        for i in range(5):
            th = th0 + (math.pi / 2 - th0) * i / 4
            crown.append(c + layer * r * np.array([math.cos(th), math.sin(th) * math.sin(psi),
                                                   math.sin(th) * math.cos(psi)]))
        eq = crown[-1]
        if front:
            end, flare = -0.085 - 0.03 * hash01(k, 5), 0.05
        elif abs(psi) < 2 * math.pi / 3:
            end, flare = -0.07 - 0.02 * hash01(k, 5), 0.25
        else:
            end, flare = -0.05 - 0.02 * hash01(k, 5), 0.25
        drop = []
        phase = 6.28 * hash01(k, 6)
        for i in range(1, 7):
            t = i / 6
            x = eq[0] + (end - eq[0]) * t
            y = eq[1] * (1 + flare * t) + 0.004 * t * math.sin(2.5 * t * math.pi + phase)
            z = c[2] + (eq[2] - c[2]) * (1 + flare * t)
            drop.append(np.array([x, y, z]))
        pts = crown + drop
        n = len(pts)
        wid = 0.011 + 0.005 * hash01(k, 7)
        th = 0.0008
        side = np.array([0.0, math.cos(psi), -math.sin(psi)])
        frames, prof = [], []
        for i in range(n):
            tan = unit(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
            b = unit(side - (side @ tan) * tan)
            frames.append((np.cross(tan, b), b))
            w = wid / 2 * (1 - 0.6 * i / (n - 1))
            prof.append([(th, w), (-th, w), (-th, -w), (th, -w)])
        band = STREAK_V if k in white else HAIR_V
        uv_of = lambda u, j, pa, pb, i, band=band: (u, band[0] + (band[1] - band[0]) * (0.5 + 0.5 * math.copysign(1, pb)))
        v, uv, fc = sweep(pts, frames, prof, uv_of, closed=False)
        m.add_shell(v, uv, fc, "streak" if k in white else "hair", strand=k)
    return m


BUILDERS = {
    "EstaladorVenda": build_venda,
    "CorredorBoca": boca,
    "SemRostoEstatica": semrosto,
    "CarpideiraCabelo": cabelo,
    "TicaoCrosta": crosta,
}


def build(piece, sex):
    return BUILDERS[piece](sex)


def fmt(x):
    return "%.6f" % (x + 0.0 if abs(x) >= 5e-7 else 0.0)


def to_x(mesh, name):
    """O .x texto que o Assimp lê (o mesmo leiaute do vanilla, CRLF, sem templates)."""
    tex = mesh.texture
    out = ["xof 0303txt 0032", "",
           "Material %s {" % tex,
           " 1.000000;1.000000;1.000000;1.000000;;",
           " 10.000000;",
           " 0.000000;0.000000;0.000000;;",
           " 0.000000;0.000000;0.000000;;",
           "",
           " TextureFilename {",
           '  "%s.png";' % tex,
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
    out += ["   0," for _ in range(nf - 1)] + ["   0;", "   { %s }" % tex, "  }", ""]
    out += ["  MeshTextureCoords {", "   %d;" % nv]
    listing(["%s;%s" % (fmt(u), fmt(v)) for u, v in mesh.uvs], "   ")
    out += ["  }", " }", "}", ""]
    return "\r\n".join(out)


def venda_texture(size=128):
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


def mirrored(top_rows, size=128):
    """Monta a textura com as linhas de cima e o espelho delas embaixo (o v pode vir virado)."""
    rgb = np.zeros((size, size, 3), np.float32)
    rgb[:size // 2] = top_rows[:size // 2]
    rgb[size // 2:] = rgb[:size // 2][::-1]
    return np.clip(rgb, 0, 255).astype(np.uint8)


def boca_texture(size=128):
    """Lote 2 / bíblia §5: rasgo escuro largo SEM dentes de longe; lábio pálido
    (não vermelho vivo); buraco quase preto. Transições suaves (evita faixa reta)."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    v = y / size
    u = x / size
    # pele → lábio → buraco com rampas (sem bandas duras)
    skin_c = np.asarray((72, 58, 52), np.float32)
    lip_c = np.asarray((186, 168, 150), np.float32)
    hole_c = np.asarray((18, 14, 13), np.float32)
    # ondula o limiar pra não ler listra horizontal
    wobble = 0.03 * np.sin(x * 0.35 + 1.2)
    t_lip = np.clip((v - (0.18 + wobble)) / 0.10, 0, 1)
    t_hole = np.clip((v - (0.34 + wobble * 0.6)) / 0.12, 0, 1)
    rgb = skin_c[None, None, :] * (1 - t_lip)[..., None]
    rgb = rgb + lip_c[None, None, :] * (t_lip * (1 - t_hole))[..., None]
    rgb = rgb + hole_c[None, None, :] * t_hole[..., None]
    # micro-variação (quebra faixa)
    grain = 0.92 + 0.08 * np.sin(x * 0.31) * np.sin(y * 0.27)
    rgb = rgb * grain[..., None]
    # rasgos finos irregulares até as orelhas
    tear = (np.abs(v - (0.36 + wobble)) < 0.015) & (u > 0.06) & (u < 0.94)
    rgb[tear] = (28, 22, 20)
    return mirrored(rgb.astype(np.float32), size)


def cabelo_texture(size=128):
    """Piche com fios um pouco menos pretos correndo no comprimento (u) e, no meio, a faixa da
    mecha branca suja com fios cinza-claros. Sem cinza médio: as duas leem de longe."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    v = y / size
    fib = 0.5 + 0.5 * np.sin(y * 2.1 + 1.3 * np.sin(x * 0.05 + y * 0.7))
    rgb = np.asarray((14, 12, 12), np.float32)[None, None, :] + fib[..., None] * 14
    white = v >= STREAK_V[0] - 0.015
    rgb[white] = (np.asarray((226, 222, 214), np.float32)[None, :] - (fib[white] * 46)[..., None])
    return mirrored(rgb, size)


def crosta_texture(size=128):
    """Carvão em placas com rachaduras de brasa (Voronoi que fecha em u, a crosta dá a volta na
    cabeça), uma faixa de carvão liso no alto (lascas e polo), a fumaça clara e a brasa no meio."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    v = y / size
    rgb = np.zeros((size, size, 3), np.float32)
    v0, dv = CRUST_V[0] * size, (CRUST_V[1] - CRUST_V[0]) * size
    cells = [((c + 0.2 + 0.6 * hash01(c, r, 41)) * size / 7, v0 + (r + 0.2 + 0.6 * hash01(c, r, 42)) * dv / 3)
             for c in range(7) for r in range(3)]      # grade com tremida: duas sementes nunca encostam
    d1 = np.full((size, size), 1e9, np.float32)
    d2 = np.full((size, size), 1e9, np.float32)
    for cxp, cyp in cells:
        dx = np.abs(x - cxp)
        dx = np.minimum(dx, size - dx)
        d = np.sqrt(dx ** 2 + ((y - cyp) * 2.2) ** 2)
        d2 = np.where(d < d1, d1, np.minimum(d2, d))
        d1 = np.minimum(d1, d)
    edge = d2 - d1
    shade = 0.8 + 0.2 * np.sin(x * 0.37 + 2 * np.sin(y * 0.23))
    rgb[:] = np.asarray((24, 18, 15), np.float32) * shade[..., None]
    crust = (v >= CRUST_V[0] + 0.03) & (v < CRUST_V[1] + 0.015)
    glow = crust & (edge < 1.6)
    core = crust & (edge < 0.7)
    rgb[glow] = (110, 26, 8)
    rgb[core] = (236, 96, 22)
    smoke = (v >= CRUST_V[1] + 0.015) & (v < 0.46)
    puff = 0.5 + 0.5 * np.sin(x * 0.21 + 3 * np.sin(y * 0.4))
    rgb[smoke] = (np.asarray((176, 174, 170), np.float32)[None, :] + (puff[smoke] * 40)[..., None])
    ember = v >= 0.46
    rgb[ember] = (np.asarray((255, 186, 84), np.float32)[None, :] - (puff[ember] * 14)[..., None])
    return mirrored(rgb, size)


TEXTURES = {
    "NOM_EstaladorVenda3D": venda_texture,
    "NOM_CorredorBoca3D": boca_texture,
    "NOM_CarpideiraCabelo3D": cabelo_texture,
    "NOM_TicaoCrosta3D": crosta_texture,
}


def textures():
    return {name: fn() for name, fn in TEXTURES.items()}


def main():
    os.makedirs(MODELS, exist_ok=True)
    for piece in BUILDERS:
        for sex in HEADS:
            name = "NOM_%s_%s" % (sex, piece)
            with open(os.path.join(MODELS, name + ".x"), "w", encoding="ascii", newline="") as f:
                f.write(to_x(build(piece, sex), name))
            print("ok models_X/Static/Clothes/%s.x" % name)
    for name, img in textures().items():
        Image.fromarray(img, "RGB").save(os.path.join(MEDIA, "textures", "NOM", name + ".png"), optimize=True)
        print("ok textures/NOM/%s.png" % name)


if __name__ == "__main__":
    main()
