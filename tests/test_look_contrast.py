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
    "Body/NOM_Corredor.png": (0.25, 0.15, 0.10),
    "NOM/NOM_CorredorBoca.png": (0.20, 0.30, 0.10),
    "Body/NOM_Carpideira.png": (0.25, 0.15, 0.10),
    "NOM/NOM_CarpideiraCabelo.png": (0.20, 0.10, 0.08),
    # casca de brasa (sprint 0022): vista ~1 s queimando, não precisa ler de longe parada;
    # carvão e brasa sem cinza médio, rachaduras finas entre placas grandes (far baixo).
    "NOM/NOM_Brasa.png": (0.20, 0.15, 0.05),
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
HORIZONTAL = {"NOM/NOM_EstaladorVenda.png"}


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


def test_every_look_texture_has_limits():
    found = set()
    for sub in ("Body", "NOM"):
        for f in os.listdir(os.path.join(TEX, sub)):
            if f.startswith("NOM_") and f.endswith(".png"):
                found.add(sub + "/" + f)
    missing = found - set(LIMITS) - set(PALE)
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


def main():
    tests = [test_every_look_texture_has_limits, test_contrast_catches_wool, test_contrast_catches_cow_and_lattice, test_textures_contrast]
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
