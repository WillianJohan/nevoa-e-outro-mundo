#!/usr/bin/env python3
"""Contraste das texturas do visual dos monstros (sprint 0014).

No jogo o zumbi tem ~1–2 m de tela na câmera isométrica e a névoa corta 30–50% do
brilho: ruído fino e cinza médio viram "lã" (a balaclava do Sem-rosto na 0012).
Por textura, na luminância Rec. 601 (0..1) dos pixels opacos:

  std  desvio da luminância                     → tem preto E branco
  mid  fração de pixels em 0,3 < L < 0,7        → pouco cinza médio
  far  desvio depois da média em blocos de 1/8  → as formas são grandes:
       da largura (o que sobra visto de longe)    ruído por pixel cai pra ~0

Uso: python3 tests/test_look_contrast.py (o run-tests.sh chama). Exit 0 = passou.
"""
import os
import sys

import numpy as np
from PIL import Image

TEX = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media", "textures")

# nome → (std mínimo, mid máximo, far mínimo). O Sem-rosto é o mais apertado (é o
# caso da lã); a boca folga no mid (o vermelho saturado é o desenho). A venda era
# laranja vivo (mid 0,45); virou atadura com arame ferrugem-escuro, sem cinza médio.
LIMITS = {
    "NOM/NOM_SemRostoEstatica.png": (0.40, 0.08, 0.20),
    "Body/NOM_Estalador.png": (0.25, 0.15, 0.10),
    "NOM/NOM_EstaladorVenda.png": (0.25, 0.15, 0.10),
    # venda 3D (sprint 0041): o mesmo pano e a ferrugem do arame numa faixa no meio
    "NOM/NOM_EstaladorVenda3D.png": (0.25, 0.15, 0.10),
    "Body/NOM_Corredor.png": (0.25, 0.15, 0.10),
    "NOM/NOM_CorredorBoca.png": (0.20, 0.30, 0.10),
    "Body/NOM_Carpideira.png": (0.25, 0.15, 0.10),
    "NOM/NOM_CarpideiraCabelo.png": (0.20, 0.10, 0.08),
    # manto penitente (sprint 0052): tecido escuro com rasgos — contraste alto, pouco cinza médio
    "NOM/NOM_CarpideiraManto.png": (0.20, 0.25, 0.08),
    # peças 3D da 0042: mesmos limites das texturas que elas substituem
    "NOM/NOM_CorredorBoca3D.png": (0.20, 0.30, 0.10),
    "NOM/NOM_CarpideiraCabelo3D.png": (0.20, 0.10, 0.08),
    # casca de brasa (sprint 0022): vista ~1 s queimando, não precisa ler de longe parada;
    # carvão e brasa sem cinza médio, rachaduras finas entre placas grandes (far baixo).
    "NOM/NOM_Brasa.png": (0.20, 0.15, 0.05),
    # Tição (sprint 0038): mesma família da casca, placas menores; lê de longe pela brasa.
    "Body/NOM_Ticao.png": (0.20, 0.15, 0.05),
    # crosta 3D do Tição (sprint 0043): carvão e brasa da pele, mais a fumaça clara
    "NOM/NOM_TicaoCrosta3D.png": (0.20, 0.15, 0.05),
}

# O Eco fica fora da regra das formas grandes: ele lê por ser muito mais claro que
# qualquer outro zumbi, não pelo desenho. Mancha grande preta e branca no corpo todo
# vira couro de vaca (prévia da 0014). Então: nome → (média mínima, mid máximo,
# fração escura máxima, L < 0,3): fantasma claro com poucos salpicos.
PALE = {
    "NOM/NOM_EcoCinza.png": (0.82, 0.12, 0.08),
    "NOM/NOM_EcoVeu.png": (0.78, 0.15, 0.12),   # escurece pras bordas do véu
}

# Atadura: faixas horizontais. A luminância tem que variar muito mais de linha pra
# linha do que de coluna pra coluna (uma grade em diagonal varia igual nos dois).
HORIZONTAL = {"NOM/NOM_EstaladorVenda.png", "NOM/NOM_EstaladorVenda3D.png"}


def luminance(img):
    a = np.asarray(img.convert("RGBA"), np.float32) / 255
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    return lum, a[..., 3] > 0.5


def metrics(img):
    lum, opaque = luminance(img)
    vals = lum[opaque]
    std = float(vals.std())
    mid = float(((vals > 0.3) & (vals < 0.7)).mean())
    k = lum.shape[1] // 8
    h, w = (lum.shape[0] // k) * k, (lum.shape[1] // k) * k
    blocks = lum[:h, :w].reshape(h // k, k, w // k, k).mean(axis=(1, 3))
    return std, mid, float(blocks.std())


def check_pale(name, img):
    lum, opaque = luminance(img)
    vals = lum[opaque]
    mean, mid, dark = float(vals.mean()), float(((vals > 0.3) & (vals < 0.7)).mean()), float((vals < 0.3).mean())
    mmin, midmax, dmax = PALE[name]
    errs = []
    if mean < mmin:
        errs.append("média %.3f < %.2f (não é claro o bastante)" % (mean, mmin))
    if mid > midmax:
        errs.append("mid %.3f > %.2f" % (mid, midmax))
    if dark > dmax:
        errs.append("escuro %.3f > %.2f (mancha demais: couro de vaca)" % (dark, dmax))
    return errs, (mean, mid, dark)


def horizontal_ratio(img):
    lum, _ = luminance(img)
    return float(lum.mean(axis=1).std() / max(lum.mean(axis=0).std(), 1e-6))


def check(name, img):
    if name in PALE:
        return check_pale(name, img)
    std, mid, far = metrics(img)
    smin, mmax, fmin = LIMITS[name]
    errs = []
    if std < smin:
        errs.append("std %.3f < %.2f" % (std, smin))
    if mid > mmax:
        errs.append("mid %.3f > %.2f" % (mid, mmax))
    if far < fmin:
        errs.append("far %.3f < %.2f (formas pequenas: vira lã de longe)" % (far, fmin))
    if name in HORIZONTAL and horizontal_ratio(img) < 2:
        errs.append("linhas/colunas %.2f < 2 (não são faixas horizontais)" % horizontal_ratio(img))
    return errs, (std, mid, far)


# Lascas do Outro Mundo (sprint 0035): partícula, não monstro. Sprite sheet de FRAMES quadros de
# giro (colunas) × SHAPES formatos (linhas), célula de CELL px, recortada no jogo por
# drawSubTexture (shared/NOM_FlakeRules.lua). A cinza é um floco branco tingido no desenho.
FLAKE_SHEET, FLAKE_ASH = "NOM/NOM_Lascas.png", "NOM/NOM_Cinza.png"
FLAKE_CELL, FLAKE_FRAMES, FLAKE_SHAPES = 32, 8, 4
PARTICLES = {FLAKE_SHEET, FLAKE_ASH}


def test_every_look_texture_has_limits():
    found = set()
    for sub in ("Body", "NOM"):
        for f in os.listdir(os.path.join(TEX, sub)):
            if f.startswith("NOM_") and f.endswith(".png"):
                found.add(sub + "/" + f)
    missing = found - set(LIMITS) - set(PALE) - PARTICLES
    assert not missing, "textura de visual sem limite de contraste: %s" % sorted(missing)


def test_contrast_catches_wool():
    # o chiado da 0012: grão por pixel em volta do cinza médio. Tem que reprovar.
    rng = np.random.default_rng(0)
    wool = (0.25 + 0.6 * rng.random((128, 128))) * 205
    errs, _ = check("NOM/NOM_SemRostoEstatica.png", Image.fromarray(wool.astype(np.uint8), "L"))
    assert errs, "ruído fino passou como contraste"
    # e preto/branco por pixel (std alto) também: de longe vira cinza
    salt = (rng.random((128, 128)) > 0.5) * 255
    errs, _ = check("NOM/NOM_SemRostoEstatica.png", Image.fromarray(salt.astype(np.uint8), "L"))
    assert any("far" in e for e in errs), "sal e pimenta por pixel passou de longe"


def test_contrast_catches_cow_and_lattice():
    rng = np.random.default_rng(1)
    cow = (np.kron(rng.random((8, 8)) > 0.6, np.ones((32, 32))) * -220 + 240).astype(np.uint8)
    errs, _ = check("NOM/NOM_EcoCinza.png", Image.fromarray(cow, "L"))
    assert errs, "couro de vaca passou como Eco"
    y, x = np.mgrid[0:128, 0:128]
    lattice = np.where(np.minimum(np.abs((x + y) % 64 - 32), np.abs((x - y + 128) % 64 - 32)) < 8, 20, 235)
    errs, _ = check("NOM/NOM_EstaladorVenda.png", Image.fromarray(lattice.astype(np.uint8), "L"))
    assert any("faixas" in e for e in errs), "grade em diagonal passou como atadura"


def test_textures_contrast():
    bad = []
    for name in sorted(LIMITS) + sorted(PALE):
        errs, m = check(name, Image.open(os.path.join(TEX, name)))
        fmt = "média=%.3f mid=%.3f escuro=%.3f" if name in PALE else "std=%.3f mid=%.3f far=%.3f"
        print("  %-30s " % name + fmt % m)
        if errs:
            bad.append(name + ": " + "; ".join(errs))
    assert not bad, "\n  ".join(bad)


# Estática da névoa na tela (sprint 0034): o contrário dos monstros. É um chiado fino que
# cobre a tela em mosaico, tingido pela cor da névoa no desenho: só tons de cinza, sem forma
# grande que se veja de longe (far baixo) e sem emenda entre um ladrilho e outro.
SCREEN_STATIC = "NOM/ScreenFx/NOM_NevoaEstatica.png"


def seam_ratio(a, axis):
    """Diferença média na emenda (última → primeira linha/coluna) sobre a de dentro."""
    d = np.abs(np.diff(a, axis=axis)).mean()
    first, last = np.take(a, 0, axis=axis), np.take(a, -1, axis=axis)
    return float(np.abs(first - last).mean() / max(d, 1e-6))


def test_screen_static_gray_fine_tiles():
    a = np.asarray(Image.open(os.path.join(TEX, SCREEN_STATIC)).convert("RGBA"), np.float32) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    assert np.all(rgb[..., 0] == rgb[..., 1]) and np.all(rgb[..., 1] == rgb[..., 2]), "estática com cor"
    assert float(rgb[..., 0].std()) > 0.1, "estática sem tons (cinza chapado)"
    assert 0.15 < float(alpha.mean()) < 0.6, "alfa médio %.3f" % alpha.mean()
    _, _, far = metrics(Image.fromarray((rgb[..., 0] * alpha * 255).astype(np.uint8), "L"))
    assert far < 0.05, "far %.3f: tem forma grande, não é chiado fino" % far
    for axis in (0, 1):
        r = seam_ratio(alpha * rgb[..., 0], axis)
        assert 0.6 < r < 1.4, "emenda no mosaico (eixo %d): %.2f" % (axis, r)


def rgba(name):
    return np.asarray(Image.open(os.path.join(TEX, name)).convert("RGBA"), np.float32) / 255


def flake_cells(a):
    c = FLAKE_CELL
    return [[a[r * c:(r + 1) * c, f * c:(f + 1) * c] for f in range(FLAKE_FRAMES)] for r in range(a.shape[0] // c)]


def test_flake_sheet_cells():
    # cada célula: lasca no meio, borda de 1 px transparente (o filtro linear do recorte não
    # puxa o quadro vizinho); o giro muda de um quadro pro outro, passa pelo verso e de perfil
    # (quadros 2 e 6) vira um risco fino, mas ainda visível
    a = rgba(FLAKE_SHEET)
    assert a.shape[:2] == (FLAKE_CELL * FLAKE_SHAPES, FLAKE_CELL * FLAKE_FRAMES), "sheet %s" % (a.shape[:2],)
    for r, row in enumerate(flake_cells(a)):
        prev, cover = None, []
        for f, cell in enumerate(row):
            al = cell[..., 3]
            assert max(al[0].max(), al[-1].max(), al[:, 0].max(), al[:, -1].max()) == 0, \
                "célula %d,%d encosta na borda" % (r, f)
            cover.append(float((al > 0.5).mean()))
            low = 0.012 if f in PROFILES else 0.03
            assert low < cover[-1] < 0.6, "célula %d,%d cobre %.3f" % (r, f, cover[-1])
            if prev is not None:
                assert np.abs(al - prev).mean() > 0.01, "quadro %d,%d igual ao anterior" % (r, f)
            prev = al
        assert cover[2] < 0.45 * cover[0] and cover[6] < 0.45 * cover[4], "formato %d de perfil não afina" % r


def hull_area(pts):
    """Área do fecho convexo (cadeia monótona) dos pontos inteiros pts (N × 2)."""
    pts = sorted(set(map(tuple, pts)))

    def half(seq):
        out = []
        for p in seq:
            while len(out) >= 2 and (out[-1][0] - out[-2][0]) * (p[1] - out[-2][1]) - \
                    (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0]) <= 0:
                out.pop()
            out.append(p)
        return out[:-1]
    h = np.asarray(half(pts) + half(pts[::-1]), np.float64)
    x, y = h[:, 0], h[:, 1]
    return 0.5 * abs(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))


def solidity(al):
    """Área da lasca sobre a do fecho convexo dos cantos dos pixels: ~0,95 num polígono liso,
    cai com dente arrancado, fratura reentrante e serrilhado."""
    ys, xs = np.nonzero(al > 0.5)
    corners = np.concatenate([np.stack([xs + dx, ys + dy], 1) for dx in (0, 1) for dy in (0, 1)])
    return float(len(xs) / hull_area(corners))


def neighbours4(m):
    p = np.pad(m, 1)
    return p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def flake_lum(cell):
    return 0.299 * cell[..., 0] + 0.587 * cell[..., 1] + 0.114 * cell[..., 2]


# Lasca orgânica (pedido do Johan depois da v1 parecer adesivo): limites medidos na v2 com folga;
# a clip-art da v1 (test_flake_criteria_catch_clipart) reprova em cada um.
SOLIDITY_MAX = 0.86      # média por formato, quadros de frente e de verso (a v1 dava 0,88–0,91)
FINE_MIN = 0.4           # fração de vizinhos no miolo com |Δ luminância| > FINE_STEP: tem grão
FINE_STEP = 0.008        # (a v1 chapada dava ≤ 0,15; a borda entre duas cores chapadas não conta)
RIM_LIGHT = 0.55         # luminância da tinta clara lascada
FACES, PROFILES = (0, 1, 3, 4, 5, 7), (2, 6)
FOG_LIGHT, FOG_DARK = 0.62, 0.12   # névoa cinza de dia e de noite


def flake_issues(a):
    """Tudo que faz a lasca parecer adesivo ou sumir na névoa; [] = passou."""
    issues = []
    rows = flake_cells(a)
    light_share = []
    for r, row in enumerate(rows):
        tag = "formato %d: " % r
        if np.mean([solidity(row[f][..., 3]) for f in FACES]) > SOLIDITY_MAX:
            issues.append(tag + "contorno liso (polígono de adesivo)")
        fine = []
        for f in (0, 4):
            lum, al = flake_lum(row[f]), row[f][..., 3]
            core = neighbours4(neighbours4(al >= 0.999)) & (lum < RIM_LIGHT)
            pair = core[:, :-1] & core[:, 1:]
            fine.append(float((np.abs(np.diff(lum, axis=1))[pair] > FINE_STEP).mean()) if pair.any() else 0.0)
        if min(fine) < FINE_MIN:
            issues.append(tag + "textura chapada (%.2f)" % min(fine))
        # a tinta clara: um fio que falha, nunca o contorno inteiro nem uma faixa grossa
        front = row[0]
        lum, op = flake_lum(front), front[..., 3] > 0.5
        light = (lum > RIM_LIGHT) & op
        edge = op & ~neighbours4(op)
        light_share.append(float(np.mean([((flake_lum(row[f]) > RIM_LIGHT) & (row[f][..., 3] > 0.5)).sum()
                                          / max((row[f][..., 3] > 0.5).sum(), 1) for f in (0, 1, 7)])))
        if edge.any() and (light & edge).sum() / edge.sum() > 0.6:
            issues.append(tag + "borda clara contínua")
        if light.sum() > 0 and (neighbours4(light) & light).sum() / light.sum() > 0.2:
            issues.append(tag + "borda clara grossa")
        # lê sobre névoa clara e escura (frente e verso, sem o perfil)
        for bg, need, name in ((FOG_LIGHT, 0.2, "clara"), (FOG_DARK, 0.08, "escura")):
            d = np.mean([np.abs(flake_lum(row[f]) - bg)[row[f][..., 3] > 0.5].mean() for f in FACES])
            if d < need:
                issues.append(tag + "some na névoa %s (%.3f)" % (name, d))
        # de perfil a face não pega luz: mais escura que de frente e de costas
        def mean_lum(cell):
            w = cell[..., 3]
            return float((flake_lum(cell) * w).sum() / max(w.sum(), 1e-6))
        if not (mean_lum(row[2]) < mean_lum(row[0]) and mean_lum(row[6]) < mean_lum(row[4])):
            issues.append(tag + "de perfil não escurece")
    if not any(s > 0.02 for s in light_share):
        issues.append("nenhum formato com lasca de tinta clara")
    if not any(s < 0.005 for s in light_share):
        issues.append("todos os formatos com borda clara")
    # ferrugem marrom, dessaturada: laranja vivo é adesivo
    rgb, op = a[..., :3], a[..., 3] > 0.5
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    rust = op & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] > rgb[..., 2]) & (sat > 0.3)
    if rust.sum() / op.sum() < 0.1:
        issues.append("sem ferrugem")
    elif sat[rust].mean() > 0.58 or ((sat > 0.72) & (mx > 0.45) & rust).sum() / rust.sum() > 0.03:
        issues.append("ferrugem laranja saturada (saturação média %.2f)" % sat[rust].mean())
    # halo: pixel quase transparente claro vira contorno branco no filtro linear
    if ((a[..., 3] < 0.5) & (flake_lum(a) > 0.8)).any():
        issues.append("halo branco na borda")
    return issues


def clipart_sheet(shapes=FLAKE_SHAPES):
    """A v1 rejeitada: polígono liso, contorno claro grosso e contínuo, miolo chapado e
    ferrugem laranja viva."""
    from PIL import ImageDraw
    ss, c = 4, FLAKE_CELL
    img = Image.new("RGBA", (c * FLAKE_FRAMES * ss, c * shapes * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for r in range(shapes):
        ang = np.linspace(0, 2 * np.pi, 7)[:-1] + r
        for f in range(FLAKE_FRAMES):
            phi = 2 * np.pi * f / FLAKE_FRAMES
            sq = max(abs(np.cos(phi)), 0.18)
            ox, oy = (f + 0.5) * c * ss, (r + 0.5) * c * ss
            pts = [(ox + np.cos(t) * 12 * ss, oy + np.sin(t) * 12 * ss * sq) for t in ang]
            body, rim = ((52, 49, 46), (228, 220, 202)) if np.cos(phi) >= 0 else ((150, 70, 30), (82, 38, 18))
            d.polygon(pts, fill=rim + (255,))
            d.polygon([(ox + (x - ox) * 0.72, oy + (y - oy) * 0.72) for x, y in pts], fill=body + (255,))
    small = img.convert("RGBa").resize((c * FLAKE_FRAMES, c * shapes), Image.BOX).convert("RGBA")
    return np.asarray(small, np.float32) / 255


def test_flake_criteria_catch_clipart():
    found = " | ".join(flake_issues(clipart_sheet()))
    for want in ("contorno liso", "textura chapada", "borda clara contínua", "borda clara grossa",
                 "todos os formatos com borda clara", "ferrugem laranja", "halo branco"):
        assert want in found, "a lasca de adesivo passou em '%s': %s" % (want, found)


def test_flake_sheet_organic():
    a = rgba(FLAKE_SHEET)
    issues = flake_issues(a)
    rows = flake_cells(a)
    print("  %-30s solidez=%s" % (FLAKE_SHEET, " ".join("%.3f" % np.mean([solidity(row[f][..., 3]) for f in FACES])
                                                     for row in rows)))
    assert not issues, "\n  ".join(issues)


def test_flake_ash():
    # floco claro em tons de cinza (a cor sai do desenho), macio, torto (não é um ponto
    # redondo: girar 90° muda o desenho) e com os cantos vazios
    a = rgba(FLAKE_ASH)
    rgb, al = a[..., :3], a[..., 3]
    assert np.all(rgb[..., 0] == rgb[..., 1]) and np.all(rgb[..., 1] == rgb[..., 2]), "cinza com cor"
    assert float(rgb[..., 0][al > 0.5].mean()) > 0.75, "cinza escura"
    assert max(al[0, 0], al[0, -1], al[-1, 0], al[-1, -1]) == 0, "cantos cheios"
    assert 0 < float(((al > 0) & (al < 1)).mean()), "borda dura"

    def round_dot(m):
        return float(np.abs(m - np.rot90(m)).mean()) < 0.03
    y, x = np.mgrid[0:16, 0:16]
    assert round_dot(np.clip(6 - np.hypot(x - 7.5, y - 7.5), 0, 1)), "o critério não pega o ponto redondo"
    assert not round_dot(al), "cinza redonda (%.3f)" % np.abs(al - np.rot90(al)).mean()


def main():
    tests = [test_every_look_texture_has_limits, test_contrast_catches_wool, test_contrast_catches_cow_and_lattice,
             test_textures_contrast, test_screen_static_gray_fine_tiles, test_flake_sheet_cells,
             test_flake_criteria_catch_clipart, test_flake_sheet_organic, test_flake_ash]
    fail = 0
    for t in tests:
        try:
            t()
        except AssertionError as e:
            fail += 1
            print("FAIL tests/test_look_contrast.py :: %s\n  %s" % (t.__name__, e))
    print("contraste total=%d passou=%d falhou=%d" % (len(tests), len(tests) - fail, fail))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
