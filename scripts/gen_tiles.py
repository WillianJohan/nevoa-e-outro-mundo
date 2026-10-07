#!/usr/bin/env python3
"""Gera as texturas próprias do Outro Mundo estilo Silent Hill (sprint 0035, Tarefa 4a).

Decalques pra anexar na erosão (docs/sprints/sprint-0035-silent-hill/spike-sprite-proprio.md,
caminho 1b): PNG RGBA 128×256, o quadro inteiro do tile do Tiles2x (desenhado em escala 1 com
tileScale 2), transparente fora do desenho. Cada desenho é feito num plano (o chão visto de cima,
a parede vista de frente), em px de tela com K amostras por px, e mapeado pro losango ou pra face
isométrica com SS×SS sub-amostras por pixel: o alfa sai antisserrilhado. Do jogo, só a geometria
medida no spike (§3); nenhum pixel.

Lados:
  F  chão: losango (64,192)–(128,224)–(64,256)–(0,224); u segue a aresta norte, v a oeste
  W  parede oeste: x 0..64, topo 32 − x/2, base 226 − x/2
  N  parede norte: x 64..128, topo (x − 64)/2, base 196 + (x − 64)/2
  Na parede a vertical continua vertical e a horizontal segue a inclinação ±x/2.

Tipos (mod/42/media/textures/NOM/OutroMundo/NOM_OM_<tipo>_<lado>_<nn>.png):
  Grade_F       grade de piso industrial (quadrados, losangos ou barras) num quadro de cantoneira
                com parafusos, ferrugem e sujeira; o vão é escuro com alfa parcial (o chão do jogo
                aparece por baixo, apagado) e a grade faz sombra nele e em volta
  Ferrugem_F    mancha de ferrugem: auréola, marca de maré seca, miolo escamado e farelo em volta
  Chapa_F       chapa rebitada (lisa gasta ou xadrez antiderrapante), riscos, ferrugem na borda e
                nos rebites, canto amassado
  Tinta_F       película de tinta velha lascada no chão (o chão aparece nos buracos)
  Tinta_W/N     tinta descolando em placas: o reboco ou a chapa enferrujada aparece por baixo, a
                borda levanta (lado de baixo claro, sombra no buraco), sujeira e craquelê em volta.
                A tinta que fica é a parede do jogo (transparente): serve em qualquer cor de parede
  Ferrugem_W/N  escorridos de ferrugem saindo de parafusos, de uma emenda ou do alto; bolhas de ferrugem
                furando a tinta, em cachos
  Descasca_W/N  a parede quase toda descascada (só ilhas da tinta do jogo ficam)

Outro Mundo queimado da névoa preta (sprint 0039), no fim de KINDS (a semente das antigas não muda):
  Cinza_F       monte de cinza assentada, grão claro, pedacinho de carvão e farelo em volta
  Brasa_F       pedaços de carvão rachado com brasa fraca em algumas trincas (apagando)
  Fuligem_W/N   fuligem subindo do rodapé em plumas que afinam, escura embaixo

Paleta suja e dessaturada (ferrugem marrom, não laranja); o RGB dos pixels vazios herda o dos
vizinhos (o filtro linear do jogo não puxa preto pra borda). Também escreve
mod/42/media/lua/shared/NOM_OwnSpriteList.lua (nome, lado e tipo de cada PNG).

Semente fixa e um gerador por textura: rodar de novo dá os mesmos bytes e não toca em nenhuma
outra textura do mod. Uso: python3 scripts/gen_tiles.py [--preview]
(--preview só monta /tmp/om_tiles_preview.png a partir dos PNG gerados.)
"""
import os
import sys

import numpy as np
from PIL import Image

SEED = 3504
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GAME_DIR = "media/textures/NOM/OutroMundo/"
OUT = os.path.join(ROOT, "mod", "42", GAME_DIR)
LIST_LUA = os.path.join(ROOT, "mod", "42", "media", "lua", "shared", "NOM_OwnSpriteList.lua")
PREVIEW = "/tmp/om_tiles_preview.png"

W, H = 128, 256         # quadro do tile no Tiles2x
SS = 4                  # sub-amostras por pixel em cada eixo, na projeção
K = 4                   # amostras do plano por px de tela
VARIANTS = 5
# largura × altura do plano em px de tela (a aresta do losango e a largura da face medem ~71,6 px)
PLANE = {"F": (72, 72), "W": (72, 194), "N": (72, 196)}
KINDS = (("Grade", "F"), ("Ferrugem", "F"), ("Chapa", "F"), ("Tinta", "F"),
         ("Tinta", "W"), ("Ferrugem", "W"), ("Descasca", "W"),
         ("Tinta", "N"), ("Ferrugem", "N"), ("Descasca", "N"),
         ("Cinza", "F"), ("Brasa", "F"), ("Fuligem", "W"), ("Fuligem", "N"))

# luz do alto à esquerda da tela, no plano (x, y): na parede x segue a face e y desce; no chão
# o alto à esquerda da tela cai em (−3, −1) no (u, v)
LIGHT = {"F": (-0.949, -0.316), "W": (-0.6, -0.8), "N": (-0.6, -0.8)}

GRIME = (34, 30, 27)
VOID = (15, 13, 12)
PRIMER = (176, 170, 156)        # o avesso da tinta, claro, quando a borda enrola
EDGE_DARK = (50, 45, 40)
STEEL_D, STEEL, STEEL_L = (46, 46, 45), (86, 85, 82), (134, 132, 126)
RUST_D, RUST, RUST_L = (60, 45, 38), (104, 77, 61), (138, 107, 84)
OXIDE = (124, 106, 80)          # óxido seco, ocre apagado
STREAK = (118, 96, 76)          # o fim do escorrido, lavado
PLASTER = ((150, 144, 132), (139, 135, 127), (158, 149, 134), (146, 140, 134), (152, 146, 128))
PAINTS = ((164, 156, 136), (110, 118, 104), (146, 136, 104), (104, 108, 112), (132, 126, 112))
ASH_D, ASH, ASH_L = (62, 60, 57), (114, 111, 106), (160, 157, 150)
CHAR_D, CHAR = (24, 22, 21), (54, 50, 47)
EMBER_D, EMBER = (92, 42, 27), (160, 70, 34)     # brasa apagando: laranja sujo, nunca vivo
SOOT_D, SOOT = (16, 15, 14), (92, 84, 75)


# ---------------------------------------------------------------- utilidades do plano

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def col(c):
    return np.asarray(c, np.float32)


def ramp(t, c0, c1):
    t = np.clip(t, 0, 1)[..., None]
    return col(c0) * (1 - t) + col(c1) * t


def ramp3(t, c0, c1, c2):
    return np.where((t < 0.5)[..., None], ramp(t * 2, c0, c1), ramp(t * 2 - 1, c1, c2))


def mix(rgb, c, k):
    """Pinta c (cor ou campo RGB) por cima de rgb com cobertura k."""
    k = np.clip(k, 0, 1)[..., None]
    return rgb * (1 - k) + (col(c) if not isinstance(c, np.ndarray) else c) * k


def over(rgb, a, c, k):
    """Camada c com alfa k por cima de (rgb, a), alfa não pré-multiplicado."""
    k = np.clip(k, 0, 1)
    c = col(c) if not isinstance(c, np.ndarray) else c
    na = k + a * (1 - k)
    out = (c * k[..., None] + rgb * (a * (1 - k))[..., None]) / np.maximum(na, 1e-6)[..., None]
    return out, na


def norm(a):
    lo, hi = np.percentile(a, (1, 99))
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0, 1).astype(np.float32)


def sample(img, fy, fx):
    """Bilinear em img (h × w [× c]) nos índices contínuos (fy, fx), preso na borda."""
    h, w = img.shape[:2]
    fx = np.clip(fx, 0, w - 1.001)
    fy = np.clip(fy, 0, h - 1.001)
    x0, y0 = fx.astype(np.int32), fy.astype(np.int32)
    tx, ty = (fx - x0).astype(np.float32), (fy - y0).astype(np.float32)
    if img.ndim == 3:
        tx, ty = tx[..., None], ty[..., None]
    top = img[y0, x0] * (1 - tx) + img[y0, x0 + 1] * tx
    bot = img[y0 + 1, x0] * (1 - tx) + img[y0 + 1, x0 + 1] * tx
    return top * (1 - ty) + bot * ty


def box(a, r, axis):
    a = np.moveaxis(a, axis, 0)
    pad = [(r + 1, r)] + [(0, 0)] * (a.ndim - 1)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=0, dtype=np.float64)
    return np.moveaxis(((c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)).astype(np.float32), 0, axis)


def blur(a, px):
    """Gaussiana aproximada (três caixas por eixo) com sigma de px px de tela."""
    sig = px * K
    r = int(round((np.sqrt(4 * sig * sig + 1) - 1) / 2))
    if r < 1:
        return a.astype(np.float32)
    for axis in (0, 1):
        for _ in range(3):
            a = box(a, r, axis)
    return a


def shift(a, dx, dy):
    """Desloca a de (dx, dy) px de tela, sem dar a volta; o que entra é 0."""
    dx, dy = int(round(dx * K)), int(round(dy * K))
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = \
        a[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return out


def grad(a):
    gy, gx = np.gradient(a)
    return gx * K, gy * K


def lit(a, light, gain):
    """−∇a · luz, preso em −1..1: positivo na encosta virada pra luz."""
    gx, gy = grad(a)
    return np.clip(-(gx * light[0] + gy * light[1]) * gain, -1, 1)


def drip_down(src, keep):
    """Escorre src pra baixo: cada linha fica com o máximo entre ela e a de cima vezes keep."""
    out = src.astype(np.float32).copy()
    for y in range(1, out.shape[0]):
        np.maximum(out[y], out[y - 1] * keep, out=out[y])
    return out


class Plane:
    """O plano do desenho: grade de amostras com coordenadas X, Y em px de tela."""

    def __init__(self, rng, side):
        self.rng, self.side = rng, side
        self.pw, self.ph = PLANE[side]
        self.w, self.h = self.pw * K, self.ph * K
        yy, xx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.X, self.Y = (xx + 0.5) / K, (yy + 0.5) / K
        self.light = LIGHT[side]

    def noise(self, px, py=None):
        """Ruído de valor 0..1 com formas de ~px × py px de tela."""
        py = px if py is None else py
        cx = max(2, int(round(self.pw / px)) + 2)
        cy = max(2, int(round(self.ph / py)) + 2)
        g = self.rng.random((cy, cx)).astype(np.float32)
        img = Image.fromarray(g).resize((self.w, self.h), Image.BICUBIC)
        return np.clip(np.asarray(img, np.float32), 0, 1)

    def fbm(self, px, octaves=4, gain=0.5):
        out, amp, tot = 0, 1.0, 0
        for o in range(octaves):
            out = out + amp * self.noise(px / 2 ** o)
            tot += amp
            amp *= gain
        return norm(out / tot)

    def at(self, field, x, y):
        """field (amostras do plano) lido nos pontos (x, y) em px."""
        return sample(field, y * K - 0.5, x * K - 0.5)

    def warp(self, px, amp):
        return (self.X + amp * (self.noise(px) - 0.5), self.Y + amp * (self.noise(px) - 0.5))

    def voronoi(self, cell, X=None, Y=None):
        """Voronoi numa grade com jitter (células de ~cell px): F1, F2, valor sorteado da célula
        mais perto e o centro dela."""
        X = self.X if X is None else X
        Y = self.Y if Y is None else Y
        nx, ny = int(self.pw / cell) + 5, int(self.ph / cell) + 5
        gx = (np.arange(nx)[None, :] - 2 + 0.1 + 0.8 * self.rng.random((ny, nx))) * cell
        gy = (np.arange(ny)[:, None] - 2 + 0.1 + 0.8 * self.rng.random((ny, nx))) * cell
        val = self.rng.random(ny * nx).astype(np.float32)
        ci = np.floor(X / cell).astype(np.int32) + 2
        cj = np.floor(Y / cell).astype(np.int32) + 2
        f1 = np.full(X.shape, np.inf, np.float32)
        f2 = f1.copy()
        best = np.zeros(X.shape, np.int32)
        for dj in (-1, 0, 1):
            for di in (-1, 0, 1):
                jj, ii = np.clip(cj + dj, 0, ny - 1), np.clip(ci + di, 0, nx - 1)
                d = np.hypot(X - gx[jj, ii], Y - gy[jj, ii])
                closer = d < f1
                f2 = np.where(closer, f1, np.minimum(f2, d))
                best = np.where(closer, jj * nx + ii, best)
                f1 = np.where(closer, d, f1)
        return f1, f2, val[best], gx.ravel()[best], gy.ravel()[best]

    def blobs(self, n, r0, r1, x, y, margin, aspect=(1.0, 1.0)):
        """Até n manchas (gaussianas de raio r0..r1) com centro longe da borda, lidas em (x, y)."""
        out = np.zeros(x.shape, np.float32)
        for _ in range(n):
            cx = self.rng.uniform(margin, self.pw - margin)
            cy = self.rng.uniform(margin, self.ph - margin)
            r = self.rng.uniform(r0, r1)
            asp = self.rng.uniform(*aspect)
            d2 = ((x - cx) / r) ** 2 + ((y - cy) / (r * asp)) ** 2
            out = np.maximum(out, np.exp(-1.6 * d2))
        return out

    def edge_px(self, x=None, y=None, sides="xy"):
        """Distância em px até a borda do plano (só as verticais com sides='x')."""
        x = self.X if x is None else x
        y = self.Y if y is None else y
        d = np.minimum(x, self.pw - x)
        if "y" in sides:
            d = np.minimum(d, np.minimum(y, self.ph - y))
        return d

    def segment(self, x0, y0, x1, y1):
        dx, dy = x1 - x0, y1 - y0
        t = np.clip(((self.X - x0) * dx + (self.Y - y0) * dy) / (dx * dx + dy * dy), 0, 1)
        return np.hypot(self.X - x0 - t * dx, self.Y - y0 - t * dy)


# ---------------------------------------------------------------- materiais

def rust_mat(p, dark=0.0):
    """Ferrugem: tom em placas, óxido seco, escamas com borda escura, pites e grão."""
    t = p.fbm(7)
    rgb = ramp3(t, RUST_D, RUST, RUST_L)
    rgb = mix(rgb, OXIDE, 0.4 * smooth(0.6, 0.9, p.noise(10)))
    f1, f2, v, _, _ = p.voronoi(3.0)
    rgb = rgb * (0.86 + 0.26 * v)[..., None]
    rgb = mix(rgb, col(RUST_D) * 0.7, 0.6 * (1 - smooth(0.0, 0.5, f2 - f1)))
    rgb = mix(rgb, (36, 27, 23), 0.75 * smooth(0.8, 0.9, p.noise(0.7)))
    return rgb * ((0.9 + 0.2 * p.noise(0.5)) * (1 - dark))[..., None]


def steel_mat(p, scratches=40, brushed=True):
    """Aço velho: pouco manchado, escovado numa direção, grão fino e riscos claros e escuros."""
    rgb = col(STEEL) * (0.9 + 0.16 * p.fbm(6, 3))[..., None]
    if brushed:
        horiz = p.rng.random() < 0.5
        b = p.noise(7, 0.45) if horiz else p.noise(0.45, 7)
        rgb = rgb * (0.9 + 0.2 * b)[..., None]
    rgb = mix(rgb, (60, 56, 50), 0.4 * smooth(0.6, 0.85, p.noise(9)))           # pátina
    for _ in range(scratches):
        x0, y0 = p.rng.uniform(0, p.pw), p.rng.uniform(0, p.ph)
        ang, ln = p.rng.uniform(0, np.pi), p.rng.uniform(3, 18)
        d = p.segment(x0, y0, x0 + ln * np.cos(ang), y0 + ln * np.sin(ang))
        k = np.clip(1 - d / 0.4, 0, 1) * p.rng.uniform(0.3, 0.7)
        rgb = mix(rgb, (156, 154, 148) if p.rng.random() < 0.65 else (38, 36, 34), k)
    return rgb * (0.92 + 0.16 * p.noise(0.5))[..., None]


def plaster_mat(p, base):
    """Reboco: grão médio e fino, umidade com marca de maré, pites e trinca fina."""
    rgb = col(base) * (0.9 + 0.12 * p.fbm(10, 4))[..., None]
    rgb = rgb * (0.9 + 0.2 * p.noise(1.4))[..., None] * (0.92 + 0.16 * p.noise(0.45))[..., None]
    d = p.fbm(18, 4)
    rgb = mix(rgb, (98, 88, 76), 0.42 * smooth(0.6, 0.72, d))
    rgb = mix(rgb, (78, 70, 62), 0.35 * (smooth(0.6, 0.62, d) - smooth(0.64, 0.7, d)))
    rgb = mix(rgb, (66, 60, 54), 0.7 * smooth(0.85, 0.93, p.noise(0.8)))
    f1, f2, _, _, _ = p.voronoi(16, *p.warp(6, 4))
    crack = (1 - smooth(0.05, 0.35, f2 - f1)) * (p.noise(10) > 0.55)
    return mix(rgb, (60, 54, 48), 0.7 * crack)


def dome(p, pts, r):
    """Cabeças de rebite/parafuso: altura 0..1 (domo) nos pontos pts, raio r px."""
    h = np.zeros(p.X.shape, np.float32)
    for x, y in pts:
        d2 = ((p.X - x) ** 2 + (p.Y - y) ** 2) / (r * r)
        h = np.maximum(h, np.sqrt(np.clip(1 - d2, 0, 1)))
    return h


def shade_domes(p, rgb, a, h, base, rust_k):
    """Põe os domos h por cima: sombra embaixo à direita, luz em cima à esquerda, ferrugem em volta."""
    m = (h > 0).astype(np.float32)
    lx, ly = p.light
    bloom = np.clip(blur(m, 1.4) * 2.2, 0, 1) * (1 - m) * (0.55 + 0.45 * p.noise(0.9))
    rgb, a = over(rgb, a, ramp(p.noise(1.2), RUST, RUST_D), 0.7 * bloom * rust_k)
    rgb, a = over(rgb, a, GRIME, 0.7 * blur(shift(m, -lx * 0.7, -ly * 0.7), 0.35) * (1 - m))
    s = lit(blur(h, 0.12), p.light, 0.7)
    c = col(base) * (0.72 + 0.55 * s)[..., None]
    c = mix(c, rust_mat(p), 0.45 * rust_k * p.noise(1.0))
    c = mix(c, (170, 166, 158), 0.5 * smooth(0.55, 0.9, s) * smooth(0.5, 0.8, h))       # brilho
    return over(rgb, a, c, m)


def curve(p, px, amp):
    """Desvio lateral (h,) que muda a cada ~px px de altura: o fio de um escorrido."""
    n = int(p.ph / px) + 3
    knots = p.rng.random(n) - 0.5
    y = p.Y[:, 0]
    return (amp * np.interp(y / px, np.arange(n), knots)).astype(np.float32)


# ---------------------------------------------------------------- parede

OLD_PAINT = ((128, 136, 120), (150, 141, 120), (116, 120, 124), (120, 106, 94), (140, 138, 128))


def wall_peel(p, heavy, sub):
    """Tinta descolando em placas (Tinta) ou quase toda descascada (Descasca). A tinta que fica é a
    parede do jogo; no buraco aparece uma demão velha de outra cor e, no fundo, o reboco ou a chapa."""
    rng = p.rng
    Xw, Yw = p.warp(10, 3.0)
    _, _, vbig, _, _ = p.voronoi(9.0, Xw, Yw)
    f1, f2, vs, cx, cy = p.voronoi(2.4, Xw, Yw)
    low = p.fbm(22, 3)
    score = 0.62 * p.at(low, cx, cy) + 0.24 * vbig + 0.14 * vs
    edge = np.minimum(cx, p.pw - cx)
    if heavy:
        score = score - 0.35 * (1 - smooth(0, 6, edge)) - 0.25 * (1 - smooth(0, 5, np.minimum(cy, p.ph - cy)))
        target = rng.uniform(0.68, 0.8)
    else:
        env = p.blobs(int(rng.integers(1, 4)), 10, 20, cx, cy, 14, aspect=(1.0, 1.7))
        score = 0.4 * score + 0.8 * env - 0.6 * (1 - smooth(2, 9, edge))
        target = rng.uniform(0.12, 0.2)
    miss = (score > np.quantile(score, 1 - target)).astype(np.float32)
    layered = sub != "metal"
    deep = (score > np.quantile(score, 1 - target * rng.uniform(0.45, 0.7))).astype(np.float32) if layered else miss
    old = miss - deep
    paint = 1 - miss

    if sub == "reboco":
        base = plaster_mat(p, PLASTER[int(rng.integers(len(PLASTER)))])
        metal = np.zeros(p.X.shape, np.float32)
    elif sub == "metal":
        base = mix(rust_mat(p), steel_mat(p, 12, False), 0.35 * smooth(0.6, 0.8, p.noise(8)))
        seams = [rng.uniform(30, 70), rng.uniform(110, 160)]
        for sy in seams:
            base = mix(base, (30, 24, 20), 0.85 * np.clip(1 - np.abs(p.Y - sy) / 0.55, 0, 1))
            base = mix(base, RUST_L, 0.4 * np.clip(1 - np.abs(p.Y - sy - 1.0) / 0.5, 0, 1))
        pts = [(x, sy + d) for sy in seams for d in (-2.6, 2.6) for x in np.arange(4.5, p.pw, 7.5)]
        base, _ = shade_domes(p, base, np.ones(p.X.shape, np.float32), dome(p, pts, 1.2), (96, 84, 72), 1.0)
        metal = np.ones(p.X.shape, np.float32)
    else:
        base = plaster_mat(p, PLASTER[int(rng.integers(len(PLASTER)))])
        metal = smooth(0.55, 0.75, p.fbm(12, 3))
        base = mix(base, rust_mat(p), metal)

    lx, ly = p.light
    # o fundo: sombra das camadas levantadas (luz do alto à esquerda) e mais escuro perto da borda
    raised = 1 - deep
    cast = blur(shift(raised, -lx * 1.3, -ly * 1.3), 0.6) * deep
    ao = blur(raised, 1.6) * deep
    rgb = base * (1 - 0.55 * cast - 0.3 * ao)[..., None]
    a = deep.copy()
    # a demão velha, outra cor, gasta, com a própria borda quebrada
    oc = col(OLD_PAINT[int(rng.integers(len(OLD_PAINT)))]) * (0.86 + 0.2 * p.fbm(8, 3))[..., None]
    oc = oc * (0.92 + 0.16 * p.noise(0.5))[..., None]
    oc = mix(oc, GRIME, 0.35 * smooth(0.5, 0.85, p.noise(3)))
    oc = mix(oc, EDGE_DARK, 0.55 * old * smooth(0.02, 0.3, blur(deep, 0.45)))
    oc = oc * (1 + 0.3 * np.clip(lit(blur(old, 0.5), p.light, 1.0), 0, 1))[..., None]
    oc = oc * (1 - 0.5 * blur(shift(paint, -lx * 1.1, -ly * 1.1), 0.5))[..., None]
    rgb, a = over(rgb, a, oc, old)

    # sujeira em volta do estrago (salpicada, não um borrão) e água escorrendo dos buracos
    near = blur(miss, 2.5)
    if heavy:
        dirt = paint * (0.3 + 0.7 * smooth(0.3, 0.8, p.noise(1.2))) * (0.4 + 0.6 * np.clip(near * 2, 0, 1))
    else:
        dirt = paint * np.clip(near * 2.4, 0, 1) * smooth(0.25, 0.8, p.noise(1.1)) * (0.6 + 0.4 * p.noise(4))
    rgb, a = over(rgb, a, GRIME, 0.34 * dirt)
    keep = np.exp(-1.0 / (K * (4 + 16 * p.noise(3, 400)[0])))
    run = drip_down(miss * (p.noise(1.3, 400) > 0.78), keep) * paint
    run = blur(run, 0.3) * (0.6 + 0.4 * p.noise(0.8, 6))
    rgb, a = over(rgb, a, ramp(metal, (74, 64, 54), RUST), (0.38 + 0.25 * metal) * run)
    # craquelê perto do estrago
    crk = paint * (1 - smooth(0.08, 0.38, f2 - f1)) * np.clip(blur(miss, 5.0) * 3, 0, 1) * (p.noise(4) > 0.45)
    rgb, a = over(rgb, a, (44, 40, 36), 0.45 * crk)
    # a borda da tinta do jogo: fio escuro, luz no lado virado pra luz e lascas enroladas (avesso claro)
    rim = paint * smooth(0.02, 0.25, blur(miss, 0.45))
    rgb, a = over(rgb, a, EDGE_DARK, 0.65 * rim)
    hl = np.clip(lit(blur(paint, 0.55), p.light, 1.3), 0, 1) * paint
    rgb, a = over(rgb, a, (210, 204, 192), 0.5 * hl)
    curl = paint * smooth(0.05, 0.16, blur(miss, 1.0)) * ((vs * 17.3) % 1 < 0.5)
    rgb, a = over(rgb, a, GRIME, 0.6 * blur(shift(curl, -lx * 0.9, -ly * 0.9), 0.45) * (1 - curl))
    c = col(PRIMER) * (0.74 + 0.36 * lit(blur(curl, 0.35), p.light, 0.9) + 0.1 * p.noise(1.0))[..., None]
    rgb, a = over(rgb, a, c, curl)
    return rgb, a


def drip(p, x0, y0, length, w0, wob, taper=-0.65):
    """Um escorrido: nasce em (x0, y0) com largura w0 px, afina (taper < 0) ou abre em leque
    (taper > 0), ondula e apaga até length px."""
    out = np.zeros(p.X.shape, np.float32)
    r0, r1 = max(int(y0 * K), 0), min(int((y0 + length) * K) + 1, p.h)
    if r1 <= r0:
        return out
    X, Y = p.X[r0:r1], p.Y[r0:r1]
    t = np.clip((Y - y0) / length, 0, 1)
    xc = x0 + curve(p, p.rng.uniform(5, 10), wob)[r0:r1, None] * smooth(0, 0.15, t)
    w = w0 * (1 + taper * t)
    d = (X - xc) / np.maximum(w, 0.3)
    breakup = 0.7 + 0.3 * np.interp(Y[:, 0] / 4.0, np.arange(int(p.ph / 4) + 2), p.rng.random(int(p.ph / 4) + 2))[:, None]
    out[r0:r1] = np.exp(-2.2 * d * d) * (1 - t) ** 1.2 * breakup * smooth(0, 0.02, t + 0.005)
    return out


def wall_rust(p, seam, top):
    """Escorridos de ferrugem saindo de parafusos, de uma emenda e do alto; bolhas de ferrugem."""
    rng = p.rng
    lines = np.zeros(p.X.shape, np.float32)        # os fios, juntados como tinta que soma
    wash = np.zeros(p.X.shape, np.float32)         # a cortina lavada embaixo de cada fonte
    bloom = np.zeros(p.X.shape, np.float32)
    bolts, sources = [], []
    for _ in range(int(rng.integers(3, 5))):
        bx, by = rng.uniform(10, p.pw - 10), rng.uniform(12, p.ph * 0.55)
        bolts.append((bx, by))
        sources.append((bx, by, rng.uniform(2.2, 4.0), rng.uniform(50, 130)))
    if seam:
        seam_y = rng.uniform(40, p.ph - 80)
        xs = np.arange(rng.uniform(4, 8), p.pw - 3, 9.5)
        bolts += [(x, seam_y) for x in xs]
        for x in rng.choice(xs, min(len(xs), int(rng.integers(3, 6))), replace=False):
            sources.append((x, seam_y, rng.uniform(1.4, 2.4), rng.uniform(30, 90)))
    if top:
        for _ in range(int(rng.integers(2, 5))):
            sources.append((rng.uniform(6, p.pw - 6), -2.0, rng.uniform(2.0, 3.5), rng.uniform(80, 175)))
    Xw, Yw = p.warp(3, 2.5)
    for sx, sy, r, ln in sources:
        d = np.hypot(Xw - sx, (Yw - sy) * 1.1) / r
        bloom = np.maximum(bloom, smooth(1.4, 0.15, d))
        for k in range(int(rng.integers(3, 7))):
            main = k == 0
            x0 = sx + (0 if main else rng.normal(0, r * 0.5))
            w0 = rng.uniform(2.0, 3.2) if main else rng.uniform(0.6, 1.5)
            L = ln * (1 if main else rng.uniform(0.25, 0.85))
            s = drip(p, x0, sy + r * 0.4, L, w0, rng.uniform(0.6, 1.6)) * rng.uniform(0.45, 1.0)
            lines = 1 - (1 - lines) * (1 - s)
        cw = drip(p, sx, sy, ln * 0.75, rng.uniform(4, 7), 1.0, taper=0.9)
        wash = np.maximum(wash, cw * rng.uniform(0.65, 0.85))
    wash = wash * (0.5 + 0.5 * p.noise(0.7, 10))
    side = smooth(0, 5, p.edge_px(sides="x"))
    lines, wash = lines * side, wash * side
    # o escorrido: escuro perto da fonte, lavado embaixo; a cortina por baixo dos fios
    grain = (0.9 + 0.2 * p.noise(0.6))[..., None]
    rgb = np.zeros(p.X.shape + (3,), np.float32) + col(STREAK)
    rgb, a = over(rgb, np.zeros(p.X.shape, np.float32), ramp(0.3 + 0.7 * p.noise(2, 12), STREAK, RUST) * grain, wash)
    rgb, a = over(rgb, a, ramp(np.clip(lines * 1.4, 0, 1), STREAK, RUST_D) * grain, np.clip(lines * 1.1, 0, 0.92))

    # bolhas de ferrugem furando a tinta, em cachos: miolo escuro, beirada clara, umas escorrem
    blist = []
    for _ in range(int(rng.integers(1, 3))):
        gx, gy = rng.uniform(10, p.pw - 10), rng.uniform(20, p.ph - 40)
        for _ in range(int(rng.integers(4, 10))):
            blist.append((np.clip(gx + rng.normal(0, 4.0), 3, p.pw - 3), gy + rng.normal(0, 6.0), rng.uniform(0.6, 1.5)))
    hb = np.zeros(p.X.shape, np.float32)
    for bx, by, br in blist:
        hb = np.maximum(hb, np.sqrt(np.clip(1 - ((p.X - bx) ** 2 + (p.Y - by) ** 2) / (br * br), 0, 1)))
        if rng.random() < 0.35:
            s = drip(p, bx, by + br * 0.5, rng.uniform(6, 22), br * 0.8, 0.5) * 0.8
            lines = 1 - (1 - lines) * (1 - s)
            rgb, a = over(rgb, a, ramp(np.clip(s * 1.4, 0, 1), STREAK, RUST_D) * grain, np.clip(s, 0, 0.9))
    bm = (hb > 0).astype(np.float32)
    rgb, a = over(rgb, a, ramp(p.noise(1.5), OXIDE, RUST), 0.6 * np.clip(blur(bm, 1.2) * 2.5, 0, 1) * (1 - bm))
    bc = ramp(hb, RUST, RUST_L) * (0.8 + 0.45 * lit(blur(hb, 0.15), p.light, 0.6))[..., None]
    rgb, a = over(rgb, a, mix(bc, (40, 30, 25), smooth(0.92, 1.0, hb)), bm)
    # a fonte: crosta de ferrugem em volta e o parafuso (o da emenda é rebite)
    crust = bloom * (0.55 + 0.45 * p.noise(0.9))
    rgb, a = over(rgb, a, mix(rust_mat(p), RUST_D, 0.3 * smooth(0.5, 1, bloom)), 0.92 * smooth(0.15, 0.7, crust))
    if seam:
        seam_line = np.clip(1 - np.abs(p.Y - seam_y) / 0.55, 0, 1) * side
        rgb, a = over(rgb, a, (34, 28, 24), 0.75 * seam_line)
    return shade_domes(p, rgb, a, dome(p, bolts, 1.25), (78, 70, 62), 1.0)


# ---------------------------------------------------------------- chão

def floor_grade(p, style, torn):
    rng = p.rng
    X, Y = p.X, p.Y
    m, fw = rng.uniform(1.6, 2.6), rng.uniform(2.0, 2.6)
    lo, hi = m, p.pw - m
    e = np.minimum(np.minimum(X - lo, hi - X), np.minimum(Y - lo, hi - Y))
    panel = (e > 0).astype(np.float32)
    if torn:
        sx, sy = rng.choice((-1, 1), 2)
        jag = 4.0 * (p.noise(1.6) - 0.5) + 2.5 * (p.noise(5) - 0.5)
        cut = sx * (X - 36) + sy * (Y - 36) - rng.uniform(40, 48) + jag
        panel *= (cut < 0)
        tear = np.clip(1 - np.abs(cut) / 4.0, 0, 1)
    else:
        tear = np.zeros(X.shape, np.float32)
    frame = panel * (e < fw)
    inner = panel * (e >= fw)

    def bars(c, pitch, w, off):
        d = np.abs((c - off + pitch / 2) % pitch - pitch / 2)
        return np.clip(1 - d / (w / 2), 0, 1)
    off = lo + fw
    if style == "quadrado":
        pitch = (hi - lo - 2 * fw) / int(rng.integers(7, 9))
        h = np.maximum(bars(X, pitch, 1.6, off), bars(Y, pitch, 1.6, off))
        cell = np.floor((X - off) / pitch) * 31 + np.floor((Y - off) / pitch)
    elif style == "losango":
        pitch = rng.uniform(7.5, 8.8)
        a_, b_ = (X + Y) / np.sqrt(2), (X - Y) / np.sqrt(2)
        h = np.maximum(bars(a_, pitch, 1.5, 0.3), bars(b_, pitch, 1.5, 0.3))
        cell = np.floor((a_ - 0.3) / pitch) * 31 + np.floor((b_ - 0.3) / pitch)
    else:
        p1, p2 = rng.uniform(4.2, 4.8), rng.uniform(15, 19)
        h = np.maximum(bars(X, p1, 1.25, off), 0.85 * bars(Y, p2, 1.4, off))
        cell = np.floor((X - off) / p1) * 31 + np.floor((Y - off) / p2)
    broken = smooth(0.82, 0.88, p.noise(5)) + tear
    bar = (h > 0) * inner * (broken < 0.5)
    hb = h * bar

    rust_k = np.clip(smooth(0.45, 0.8, p.fbm(8)) + 0.7 * blur(tear + (broken > 0.3), 2.0), 0, 1)
    metal = mix(steel_mat(p, 20), rust_mat(p), rust_k * 0.85)
    ao = blur(bar, 1.2)
    s = lit(blur(hb, 0.2), p.light, 0.5)
    bar_rgb = metal * (1.0 + 0.45 * s - 0.2 * ao + 0.22 * smooth(0.7, 1, h))[..., None]

    # o vão: escuro com alfa parcial (o chão aparece apagado), sombra da grade e entulho
    lx, ly = p.light
    hole = inner * (1 - bar)
    hv = np.sin(cell * 12.9898) * 43758.5453 % 1
    shadow = blur(shift(bar + frame, -lx * 1.8, -ly * 1.8), 0.5)
    ha = (0.58 + 0.14 * p.noise(4) + 0.25 * shadow) * hole
    rgb = np.zeros(X.shape + (3,), np.float32) + col(VOID)
    rgb, a = over(rgb, np.zeros(X.shape, np.float32), VOID, ha)
    junk = hole * (hv < 0.12) * smooth(0.3, 0.6, p.noise(1.5))
    rgb, a = over(rgb, a, mix(ramp(p.noise(2), GRIME, RUST_D), RUST, 0.3 * p.noise(0.8)), 0.9 * junk)
    rgb, a = over(rgb, a, bar_rgb, bar)

    # cantoneira com parafusos
    hf = smooth(0, 0.7, e) * smooth(fw, fw - 0.7, e)
    fs = lit(blur(hf * frame, 0.2), p.light, 0.5)
    fr = mix(steel_mat(p, 10), rust_mat(p), np.clip(0.3 + 0.7 * rust_k, 0, 1) * 0.8)
    rgb, a = over(rgb, a, fr * (0.85 + 0.38 * fs)[..., None], frame)
    c = fw / 2 + lo
    pts = [(x, y) for x in (c, 36, p.pw - c) for y in (c, 36, p.pw - c) if (x, y) != (36, 36)]
    pts = [q for q in pts if panel[int(q[1] * K), int(q[0] * K)] > 0]
    rgb, a = shade_domes(p, rgb, a, dome(p, pts, 0.95), STEEL, 0.8)
    # sombra da grade no chão em volta
    out = blur(shift(panel, -lx * 1.6, -ly * 1.6), 0.8) * (1 - panel)
    return over(rgb, a, VOID, 0.45 * out)


def floor_chapa(p, tread, plates):
    rng = p.rng
    lx, ly = p.light
    rgb = np.zeros(p.X.shape + (3,), np.float32)
    a = np.zeros(p.X.shape, np.float32)
    for i in range(plates):
        if plates == 1:
            cx, cy = 36 + rng.normal(0, 2.0), 36 + rng.normal(0, 2.0)
            w, h = rng.uniform(46, 58), rng.uniform(46, 58)
        else:
            cx, cy = rng.uniform(22, 50), rng.uniform(22, 50)
            w, h = rng.uniform(26, 36), rng.uniform(26, 36)
        th = rng.uniform(-0.08, 0.08)
        u = (p.X - cx) * np.cos(th) + (p.Y - cy) * np.sin(th)
        v = -(p.X - cx) * np.sin(th) + (p.Y - cy) * np.cos(th)
        e = np.minimum(w / 2 - np.abs(u), h / 2 - np.abs(v))
        mask = e > 0
        if rng.random() < 0.6:
            su, sv = rng.choice((-1, 1), 2)
            cut = su * u + sv * v - (w + h) / 2 + rng.uniform(7, 13) + 1.6 * (p.noise(1.5) - 0.5)
            mask &= cut < 0
            e = np.minimum(e, -cut / 1.4)
        m = mask.astype(np.float32)
        # sombra da chapa no chão (ou na chapa de baixo)
        rgb, a = over(rgb, a, VOID, 0.55 * blur(shift(m, -lx * 1.5, -ly * 1.5), 0.6) * (1 - m))
        metal = steel_mat(p, 45) * 1.15
        wear = smooth(0.2, 1.0, 1 - np.hypot(u / (w * 0.5), v / (h * 0.5))) * p.noise(8)
        metal = mix(metal, (130, 128, 122), 0.3 * wear)
        if tread:
            q = 7.0
            i_, j_ = np.floor(u / q), np.floor(v / q)
            du, dv = u - (i_ + 0.5) * q, v - (j_ + 0.5) * q
            alt = ((i_ + j_) % 2) * 2 - 1
            s1, s2 = (du + alt * dv) / np.sqrt(2), (du - alt * dv) / np.sqrt(2)
            hl = np.sqrt(np.clip(1 - (s1 / 3.2) ** 2 - (s2 / 1.0) ** 2, 0, 1))
            metal = metal * (0.88 + 0.55 * lit(blur(hl, 0.15), p.light, 0.7) * (hl > 0) + 0.12 * hl)[..., None]
        rust_k = np.clip(smooth(4 + 3 * p.noise(3), 0, e) * (0.5 + 0.5 * p.noise(1.5))
                         + 0.6 * smooth(0.62, 0.8, p.fbm(9)), 0, 1)
        metal = mix(metal, rust_mat(p), 0.88 * rust_k)
        oil = p.fbm(12, 4)
        metal = mix(metal, (32, 30, 28), 0.45 * smooth(0.7, 0.74, oil) * (0.6 + 0.4 * p.noise(2)))   # óleo seco
        # chanfro: fio claro no lado da luz, escuro no outro
        bev = lit(blur(m, 0.35), p.light, 1.6) * (e < 1.2)
        metal = metal * (1 + 0.6 * bev)[..., None]
        rgb, a = over(rgb, a, metal, m)
        # rebites ao longo da borda
        pts = []
        step = rng.uniform(6.5, 8.0)
        for d in np.arange(-w / 2 + 2.6, w / 2 - 2.5, step):
            pts += [(d, -h / 2 + 2.6), (d, h / 2 - 2.6)]
        for d in np.arange(-h / 2 + 2.6 + step, h / 2 - 2.5 - step / 2, step):
            pts += [(-w / 2 + 2.6, d), (w / 2 - 2.6, d)]
        pts = [(cx + pu * np.cos(th) - pv * np.sin(th), cy + pu * np.sin(th) + pv * np.cos(th)) for pu, pv in pts]
        pts = [q for q in pts if 0 < q[0] < p.pw and 0 < q[1] < p.ph and mask[int(q[1] * K), int(q[0] * K)]]
        rgb, a = shade_domes(p, rgb, a, dome(p, pts, 1.3), (138, 136, 130), 0.45)
    return rgb, a


def floor_rust(p):
    rng = p.rng
    env = p.blobs(int(rng.integers(1, 4)), 12, 22, *p.warp(8, 6), 16)
    field = 0.62 * env + 0.38 * p.fbm(9) - 0.6 * (1 - smooth(2, 9, p.edge_px()))
    th = np.quantile(field, 1 - rng.uniform(0.32, 0.45))
    tc = np.quantile(field, 1 - rng.uniform(0.15, 0.24))
    f1, f2, v, cx, cy = p.voronoi(2.2)
    halo = smooth(th, th + 0.05, field)
    ring = (smooth(th, th + 0.012, field) - smooth(th + 0.025, th + 0.06, field)) * (p.noise(2) > 0.35)
    core = (p.at(field, cx, cy) > tc - 0.03 * v).astype(np.float32)
    rgb = np.zeros(p.X.shape + (3,), np.float32)
    rgb, a = over(rgb, np.zeros(p.X.shape, np.float32), ramp(p.noise(3), OXIDE, RUST),
                  0.34 * halo * (0.6 + 0.4 * p.noise(1.4)))
    rgb, a = over(rgb, a, RUST_D, 0.45 * ring)
    lx, ly = p.light
    rgb, a = over(rgb, a, VOID, 0.4 * blur(shift(core, -lx * 0.7, -ly * 0.7), 0.4) * (1 - core))
    # o miolo em escamas: placas com trinca escura e a beirada levantada pegando luz
    g1, g2, gv, _, _ = p.voronoi(4.5, *p.warp(4, 1.5))
    plates = (1 - smooth(0.0, 0.4, g2 - g1)) * core
    sc = rust_mat(p) * (0.85 + 0.12 * gv + 0.3 * lit(blur(core, 0.4), p.light, 0.6))[..., None]
    sc = sc * (1 + 0.25 * np.clip(lit(blur(1 - plates, 0.25), p.light, 0.6), 0, 1))[..., None]
    sc = mix(sc, (34, 26, 22), 0.75 * plates)
    rgb, a = over(rgb, a, sc, 0.97 * core)
    # farelo em volta
    _, _, fv, fx, fy = p.voronoi(1.8)
    zone = p.at(halo, fx, fy) * (1 - p.at(core, fx, fy))
    chip = ((fv < 0.07 * zone) & (blur(core, 2.0) < 0.5)).astype(np.float32)
    rgb, a = over(rgb, a, VOID, 0.4 * blur(shift(chip, -lx * 0.5, -ly * 0.5), 0.3) * (1 - chip))
    c = ramp(p.noise(1), RUST_D, RUST) * (1 + 0.3 * lit(blur(chip, 0.25), p.light, 0.6))[..., None]
    return over(rgb, a, c, chip)


def floor_paint(p, paint_rgb):
    rng = p.rng
    Xw, Yw = p.warp(9, 3.0)
    _, _, vb, _, _ = p.voronoi(8.0, Xw, Yw)
    f1, f2, vs, cx, cy = p.voronoi(2.2, Xw, Yw)
    env = p.blobs(int(rng.integers(1, 3)), 13, 22, cx, cy, 18)
    edge = p.edge_px(cx, cy)
    score = 0.62 * env + 0.24 * vb + 0.14 * vs - 0.7 * (1 - smooth(2, 9, edge))
    film = score > np.quantile(score, 1 - rng.uniform(0.26, 0.42))
    film &= ~(((vb * 31.7) % 1 < 0.16) & (vs < 0.75))
    film = film.astype(np.float32)
    lx, ly = p.light
    rgb = np.zeros(p.X.shape + (3,), np.float32)
    a = np.zeros(p.X.shape, np.float32)
    rgb, a = over(rgb, a, GRIME, 0.28 * np.clip(blur(film, 1.2) * 2, 0, 1) * (1 - film) * (0.5 + 0.5 * p.noise(1)))
    rgb, a = over(rgb, a, VOID, 0.42 * blur(shift(film, -lx * 1.0, -ly * 1.0), 0.45) * (1 - film))
    c = col(paint_rgb) * (0.88 + 0.2 * p.fbm(10))[..., None] * (0.93 + 0.14 * p.noise(0.5))[..., None]
    c = mix(c, GRIME, 0.45 * smooth(0.55, 0.9, p.fbm(12, 3)))
    scuff = smooth(0.6, 0.85, p.at(p.noise(1.0, 12), (p.X + p.Y) / 2 + 18, (p.X - p.Y) / 2 + 36))
    c = mix(c, (176, 172, 162), 0.2 * scuff)
    g1, g2, _, _, _ = p.voronoi(5.5, *p.warp(4, 1.5))
    c = mix(c, (44, 40, 36), 0.6 * (1 - smooth(0.05, 0.3, g2 - g1)) * (p.noise(6) > 0.4))   # craquelê
    rim = film * smooth(0.02, 0.25, blur(1 - film, 0.45))
    c = mix(c, EDGE_DARK, 0.55 * rim)
    c = c * (1 + 0.4 * np.clip(lit(blur(film, 0.45), p.light, 1.1), 0, 1))[..., None]
    rgb, a = over(rgb, a, c, film)
    curl = film * smooth(0.06, 0.18, blur(1 - film, 0.9)) * ((vs * 13.1) % 1 < 0.22)
    pc = col(PRIMER) * (0.78 + 0.32 * lit(blur(curl, 0.35), p.light, 0.8))[..., None]
    return over(rgb, a, pc, curl)


# ---------------------------------------------------------------- queimado (sprint 0039)

def floor_ash(p):
    rng = p.rng
    env = p.blobs(int(rng.integers(1, 4)), 12, 24, *p.warp(8, 6), 14)
    field = 0.6 * env + 0.4 * p.fbm(8) - 0.7 * (1 - smooth(2, 10, p.edge_px()))
    th = np.quantile(field, 1 - rng.uniform(0.3, 0.45))
    a = smooth(th, th + 0.12, field)                 # borda macia: a cinza assenta
    h = blur(a, 1.2) * (0.8 + 0.2 * p.fbm(4))
    rgb = ramp3(p.fbm(5), ASH_D, ASH, ASH_L) * (0.9 + 0.25 * lit(h, p.light, 1.2))[..., None]
    rgb = mix(rgb, ASH_L, 0.3 * smooth(0.65, 0.9, p.noise(0.6)))       # grão claro
    _, _, v, cx, cy = p.voronoi(1.6)
    bits = ((v < 0.06) & (p.at(a, cx, cy) > 0.3)).astype(np.float32)
    rgb = mix(rgb, CHAR_D, 0.85 * bits)
    a = np.clip(a * (0.75 + 0.25 * p.noise(1.0)), 0, 1)                # cinza fina: o chão passa
    zone = smooth(th - 0.15, th, field) * (1 - a)
    _, _, fv, _, _ = p.voronoi(1.2)
    crumbs = ((fv < 0.08) & (zone > 0.2)).astype(np.float32) * zone
    rgb = np.where((crumbs > a)[..., None], col(ASH) * (0.85 + 0.3 * p.noise(0.5))[..., None], rgb)
    return rgb, np.maximum(a, 0.8 * crumbs)


def floor_ember(p, glow):
    rng = p.rng
    env = p.blobs(int(rng.integers(1, 3)), 9, 16, *p.warp(6, 4), 18)
    field = 0.65 * env + 0.35 * p.fbm(6) - 0.7 * (1 - smooth(2, 10, p.edge_px()))
    th = np.quantile(field, 1 - rng.uniform(0.12, 0.22))
    f1, f2, v, cx, cy = p.voronoi(3.2, *p.warp(4, 1.5))
    lump = (p.at(field, cx, cy) > th).astype(np.float32)           # pedaço de carvão inteiro
    gap = 1 - smooth(0.0, 0.5, f2 - f1)
    piece = lump * (1 - gap)
    rgb = np.zeros(p.X.shape + (3,), np.float32)
    a = np.zeros(p.X.shape, np.float32)
    ash = smooth(th - 0.2, th, field)
    rgb, a = over(rgb, a, ramp(p.noise(2), ASH_D, ASH), 0.55 * ash * (0.6 + 0.4 * p.noise(1.2)))
    lx, ly = p.light
    rgb, a = over(rgb, a, VOID, 0.5 * blur(shift(piece, -lx * 0.6, -ly * 0.6), 0.4) * (1 - piece))
    c = ramp(v, CHAR_D, CHAR) * (0.85 + 0.35 * lit(blur(piece, 0.3), p.light, 0.8))[..., None]
    c = mix(c, ASH, 0.35 * smooth(0.6, 0.9, p.noise(0.7)))         # casca de cinza
    rgb, a = over(rgb, a, c, piece)
    # brasa: a trinca larga entre pedaços, só em algumas e fraca (apagando); a trinca fina fica preta
    crack = lump * (1 - smooth(0.1, 1.1, f2 - f1))
    nz = p.noise(2.5)
    q = np.quantile(nz[crack > 0.3], 0.5) if (crack > 0.3).any() else 0.5   # metade das trincas
    hot = crack * smooth(q - 0.1, q + 0.1, nz)
    return over(rgb, a, ramp(crack * p.noise(1.0) * glow, EMBER_D, EMBER), 0.95 * hot)


def wall_soot(p, tall):
    rng = p.rng
    u = p.Y / p.ph                                   # 0 no alto, 1 no rodapé
    plumes = np.zeros(p.X.shape, np.float32)
    for _ in range(int(rng.integers(3, 6))):
        x0, w0 = rng.uniform(4, p.pw - 4), rng.uniform(12, 26)
        top = rng.uniform(0.1, 0.45) if tall else rng.uniform(0.35, 0.65)
        sway = curve(p, 30, 12)[:, None]
        rise = smooth(top, 1.0, u)                   # 0 acima do topo da pluma, 1 no rodapé
        w = w0 * (0.3 + 0.7 * rise)
        d = np.abs(p.X - x0 - sway * (1 - rise))
        plumes = np.maximum(plumes, smooth(0, 1, 1 - d / np.maximum(w, 1e-3)) * np.sqrt(rise))
    streak = p.noise(1.6, 14)                        # a fumaça sobe em fios
    field = np.maximum(plumes, 0.9 * smooth(0.7, 1.0, u)) * (0.55 + 0.45 * p.fbm(9)) * (0.75 + 0.35 * streak)
    a = np.clip(field * 1.5, 0, 0.95) * smooth(0, 3, p.edge_px(sides="x"))
    rgb = ramp(0.45 * p.fbm(7) + 0.45 * u + 0.4 * (streak - 0.5), SOOT, SOOT_D)
    rgb = rgb * (0.7 + 0.6 * p.noise(2.5))[..., None]                     # manchas da fuligem
    rgb = mix(rgb, (84, 76, 66), 0.4 * smooth(0.05, 0.4, a) * (1 - smooth(0.4, 0.8, a)))   # borda da fumaça
    return rgb, a


# ---------------------------------------------------------------- variações

WALL_SUB = {"Tinta": ("reboco", "metal", "reboco", "misto", "reboco"),
            "Descasca": ("metal", "reboco", "misto", "metal", "reboco")}
GRADE = (("quadrado", False), ("losango", False), ("barra", True), ("losango", True), ("quadrado", True))
CHAPA = ((False, 1), (True, 1), (False, 2), (True, 2), (False, 1))
RUST_WALL = ((False, False), (True, False), (False, True), (True, True), (False, False))
GLOW = (1.0, 0.8, 0.9, 0.65, 0.85)
SOOT_TALL = (True, False, True, False, False)


def file_name(kind, side, n):
    return "NOM_OM_%s_%s_%02d.png" % (kind, side, n)


def plane_coords(side, x, y):
    """Ponto de tela → (s, t), 0..1 dentro do lado."""
    if side == "F":
        dx, dy = (x - 64) / 64, (y - 192) / 32
        return (dx + dy) / 2, (dy - dx) / 2
    if side == "W":
        return x / 64, (y - (32 - x / 2)) / 194
    return (x - 64) / 64, (y - (x - 64) / 2) / 196


def project(side, rgb, a):
    """Do plano pro quadro 128×256: SS×SS sub-amostras por pixel, bilinear no plano."""
    pw, ph = PLANE[side]
    ys, xs = np.mgrid[0:H * SS, 0:W * SS].astype(np.float32)
    s, t = plane_coords(side, (xs + 0.5) / SS, (ys + 0.5) / SS)
    inside = ((s >= 0) & (s <= 1) & (t >= 0) & (t <= 1)).astype(np.float32)
    fx, fy = s * pw * K - 0.5, t * ph * K - 0.5
    al = sample(a.astype(np.float32), fy, fx) * inside
    pm = sample((rgb * a[..., None]).astype(np.float32), fy, fx) * inside[..., None]
    al = al.reshape(H, SS, W, SS).mean(axis=(1, 3))
    pm = pm.reshape(H, SS, W, SS, 3).mean(axis=(1, 3))
    return np.where(al[..., None] > 0, pm / np.maximum(al, 1e-9)[..., None], 0), al


def bleed(rgb, a, passes=4):
    """O RGB dos pixels vazios vira a média dos vizinhos com tinta, pesada pelo alfa, em anéis; o
    resto fica com a média do desenho (nem o mipmap puxa preto pra borda)."""
    rgb, wt, known = rgb.copy(), a.astype(np.float32).copy(), a > 0
    for _ in range(passes):
        pm, pw_ = np.pad(rgb * wt[..., None], ((1, 1), (1, 1), (0, 0))), np.pad(wt, 1)
        s = sum(pm[1 + dy:pm.shape[0] - 1 + dy, 1 + dx:pm.shape[1] - 1 + dx]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        n = sum(pw_[1 + dy:pw_.shape[0] - 1 + dy, 1 + dx:pw_.shape[1] - 1 + dx]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        fill = ~known & (n > 0)
        rgb[fill] = s[fill] / n[fill][..., None]
        wt = np.where(fill, 1e-3, wt)
        known |= fill
    rgb[~known] = (rgb * a[..., None]).sum(axis=(0, 1)) / max(a.sum(), 1e-6)
    return rgb


def render(kind, side, n):
    """(rgb 0..255, alfa 0..1) da variação n (1..VARIANTS), já no quadro 128×256."""
    rng = np.random.default_rng((SEED, KINDS.index((kind, side)), n))
    p = Plane(rng, side)
    i = n - 1
    if side == "F":
        if kind == "Grade":
            rgb, a = floor_grade(p, *GRADE[i])
        elif kind == "Chapa":
            rgb, a = floor_chapa(p, *CHAPA[i])
        elif kind == "Ferrugem":
            rgb, a = floor_rust(p)
        elif kind == "Cinza":
            rgb, a = floor_ash(p)
        elif kind == "Brasa":
            rgb, a = floor_ember(p, GLOW[i])
        else:
            rgb, a = floor_paint(p, PAINTS[i % len(PAINTS)])
    elif kind == "Ferrugem":
        rgb, a = wall_rust(p, *RUST_WALL[i])
    elif kind == "Fuligem":
        rgb, a = wall_soot(p, SOOT_TALL[(i + (side == "N") * 2) % len(SOOT_TALL)])
    else:
        subs = WALL_SUB[kind]
        rgb, a = wall_peel(p, kind == "Descasca", subs[(i + (side == "N") * 2) % len(subs)])
    rgb, a = project(side, np.clip(rgb, 0, 255), np.clip(a, 0, 1))
    a = np.round(a * 255) / 255
    return bleed(rgb, a), a


def to_rgba(rgb, a):
    return np.dstack([np.clip(np.round(rgb), 0, 255), np.round(a * 255)]).astype(np.uint8)


def names():
    return [(kind, side, n) for kind, side in KINDS for n in range(1, VARIANTS + 1)]


def lua_list():
    out = ["-- Gerado por scripts/gen_tiles.py: não edite à mão (rode o script de novo).",
           "-- Texturas próprias do Outro Mundo estilo Silent Hill (sprint 0035). O nome do sprite é o",
           "-- caminho do PNG, o mesmo do getTexture (spike-sprite-proprio.md §1b). Lado F = chão",
           "-- (FloorOverlay); W e N = parede oeste e norte (WallOverlay + attachedW ou attachedN).",
           "NOM_OwnSpriteList = {",
           '    DIR = "%s",' % GAME_DIR,
           "    SPRITES = {"]
    for kind, side, n in names():
        out.append('        { name = "%s%s", side = "%s", kind = "%s" },' % (GAME_DIR, file_name(kind, side, n), side, kind))
    out += ["    },", "}", "", "return NOM_OwnSpriteList", ""]
    return "\n".join(out)


# ---------------------------------------------------------------- prévia

def neutral(side, tone=1.0):
    """Chão (concreto com junta) ou parede (tinta lisa com rodapé) neutros da prévia, RGBA 0..255."""
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    s, t = plane_coords(side, xs + 0.5, ys + 0.5)
    m = (s >= 0) & (s <= 1) & (t >= 0) & (t <= 1)
    if side == "F":
        edge = np.minimum(np.minimum(s, 1 - s), np.minimum(t, 1 - t))
        v = tone * (0.96 + 0.04 * np.sin(xs * 0.7) * np.cos(ys * 1.3)) * np.where(edge < 0.012, 0.8, 1.0)
        rgb = np.stack([v * 128, v * 124, v * 116], -1)
    else:
        v = np.where(t > 0.93, 0.6, 1.0) * (0.92 if side == "W" else 1.0)
        rgb = np.stack([v * 168, v * 170, v * 158], -1)
    return np.dstack([rgb, m * 255.0])


def paste(canvas, tile, x, y):
    """Compõe tile RGBA (0..255) no canvas RGB, com o canto do quadro em (x, y)."""
    t = tile.astype(np.float32)
    a = t[..., 3:4] / 255
    reg = canvas[y:y + H, x:x + W]
    reg[:] = reg * (1 - a) + t[..., :3] * a


def tex(kind, side, n):
    return np.asarray(Image.open(os.path.join(OUT, file_name(kind, side, n))).convert("RGBA"))


def preview():
    """Um quarto 5×5 (chão com alguns decalques, paredes W e N) sobre chão e parede neutros, em
    escala de jogo e ampliado 2×; embaixo, todas as texturas, cada uma sobre o neutro do lado, 2×."""
    n_t, top = 5, 40
    room = np.zeros((n_t * 64 + H + top, 2 * n_t * 64 + W, 3), np.float32) + 28
    floor = {(1, 1): ("Grade", 1), (2, 1): ("Grade", 2), (1, 2): ("Ferrugem", 1), (3, 3): ("Chapa", 2),
             (2, 3): ("Tinta", 1), (3, 1): ("Ferrugem", 3), (0, 3): ("Tinta", 3), (4, 2): ("Grade", 3),
             (3, 4): ("Chapa", 1), (1, 4): ("Ferrugem", 4), (4, 4): ("Grade", 5)}
    wall_w = (("Descasca", 1), ("Tinta", 1), ("Ferrugem", 2), ("Tinta", 3), ("Descasca", 4))
    wall_n = (("Tinta", 2), ("Ferrugem", 1), ("Descasca", 2), ("Tinta", 4), ("Ferrugem", 4))

    def at(i, j):
        return (n_t - 1 + i - j) * 64, top + (i + j) * 32
    for i in range(n_t):
        paste(room, neutral("N"), *at(i, 0))
        paste(room, tex(wall_n[i][0], "N", wall_n[i][1]), *at(i, 0))
        paste(room, neutral("W"), *at(0, i))
        paste(room, tex(wall_w[i][0], "W", wall_w[i][1]), *at(0, i))
    for j in range(n_t):
        for i in range(n_t):
            paste(room, neutral("F", 0.92 + 0.03 * ((i * 7 + j * 3) % 3)), *at(i, j))
            if (i, j) in floor:
                paste(room, tex(floor[(i, j)][0], "F", floor[(i, j)][1]), *at(i, j))
    room_img = Image.fromarray(np.clip(room, 0, 255).astype(np.uint8))
    big = room_img.resize((room_img.width * 2, room_img.height * 2), Image.BILINEAR)

    rows = []
    for kind, side in KINDS:
        y0, y1 = (176, 256) if side == "F" else (0, 232)
        row = []
        for n in range(1, VARIANTS + 1):
            cell = np.zeros((H, W, 3), np.float32) + 28
            paste(cell, neutral(side, 0.95), 0, 0)
            paste(cell, tex(kind, side, n), 0, 0)
            row.append(cell[y0:y1])
        rows.append(np.concatenate(row, 1))
    sheet = Image.fromarray(np.clip(np.concatenate(rows, 0), 0, 255).astype(np.uint8))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.BILINEAR)

    out = Image.new("RGB", (max(room_img.width + big.width, sheet.width) + 30, big.height + sheet.height + 30),
                    (20, 20, 20))
    out.paste(room_img, (10, 10))
    out.paste(big, (room_img.width + 20, 10))
    out.paste(sheet, (10, big.height + 20))
    out.save(PREVIEW)
    print("prévia", PREVIEW)


def main():
    if "--preview" in sys.argv:
        preview()
        return
    os.makedirs(OUT, exist_ok=True)
    keep = {file_name(*k) for k in names()}
    for f in os.listdir(OUT):
        if f.endswith(".png") and f not in keep:
            os.remove(os.path.join(OUT, f))
    for kind, side, n in names():
        rgb, a = render(kind, side, n)
        Image.fromarray(to_rgba(rgb, a), "RGBA").save(os.path.join(OUT, file_name(kind, side, n)), optimize=True)
        print("ok", GAME_DIR + file_name(kind, side, n))
    with open(LIST_LUA, "w", encoding="utf-8") as fh:
        fh.write(lua_list())
    print("ok", os.path.relpath(LIST_LUA, ROOT))
    preview()


if __name__ == "__main__":
    main()
