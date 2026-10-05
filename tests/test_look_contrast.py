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
# caso da lã); onde a cor saturada é o desenho (ferrugem, vermelho), mid folga.
LIMITS = {
    "NOM/NOM_SemRostoEstatica.png": (0.40, 0.08, 0.20),
    "Body/NOM_Estalador.png": (0.25, 0.15, 0.10),
    "NOM/NOM_EstaladorVenda.png": (0.25, 0.45, 0.10),
    "Body/NOM_Corredor.png": (0.25, 0.15, 0.10),
    "NOM/NOM_CorredorBoca.png": (0.20, 0.30, 0.10),
    "Body/NOM_Carpideira.png": (0.25, 0.15, 0.10),
    "NOM/NOM_CarpideiraCabelo.png": (0.20, 0.10, 0.08),
    "NOM/NOM_EcoCinza.png": (0.20, 0.15, 0.08),
    "NOM/NOM_EcoVeu.png": (0.20, 0.15, 0.08),
}


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


def check(name, img):
    std, mid, far = metrics(img)
    smin, mmax, fmin = LIMITS[name]
    errs = []
    if std < smin:
        errs.append("std %.3f < %.2f" % (std, smin))
    if mid > mmax:
        errs.append("mid %.3f > %.2f" % (mid, mmax))
    if far < fmin:
        errs.append("far %.3f < %.2f (formas pequenas: vira lã de longe)" % (far, fmin))
    return errs, (std, mid, far)


def test_every_look_texture_has_limits():
    found = set()
    for sub in ("Body", "NOM"):
        for f in os.listdir(os.path.join(TEX, sub)):
            if f.startswith("NOM_") and f.endswith(".png"):
                found.add(sub + "/" + f)
    missing = found - set(LIMITS)
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


def test_textures_contrast():
    bad = []
    for name in sorted(LIMITS):
        errs, m = check(name, Image.open(os.path.join(TEX, name)))
        print("  %-30s std=%.3f mid=%.3f far=%.3f" % ((name,) + m))
        if errs:
            bad.append(name + ": " + "; ".join(errs))
    assert not bad, "\n  ".join(bad)


def main():
    tests = [test_every_look_texture_has_limits, test_contrast_catches_wool, test_textures_contrast]
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
