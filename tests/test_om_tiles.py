#!/usr/bin/env python3
"""Texturas próprias do Outro Mundo estilo Silent Hill (sprint 0035, Tarefa 4a).

Decalques anexados na erosão (spike-sprite-proprio.md, caminho 1b), gerados por
scripts/gen_tiles.py em media/textures/NOM/OutroMundo/NOM_OM_<tipo>_<lado>_<nn>.png:

  quadro    RGBA 128×256, o quadro inteiro do tile (o PNG de arquivo não tem recorte)
  máscara   nada opaco fora do lado: losango do chão (F), face oeste (W) ou norte (N), na
            geometria medida no spike (§3); a borda é antisserrilhada, nunca passa da cobertura
  cobertura os tipos parciais não são vazios nem o tile cheio; a Descasca cobre bem mais
  variação  as variações de um tipo/lado são diferentes entre si
  paleta    suja e dessaturada: saturação média abaixo de um teto, quase nada de laranja vivo
  halo      o pixel transparente da borda tem a cor dos vizinhos (o filtro linear do jogo
            não puxa preto nem branco pra borda)
  detalhe   não é cor chapada: a luminância varia dentro do desenho

A lista em shared/NOM_OwnSpriteList.lua é conferida contra os arquivos em
tests/test_own_sprite_list.lua (luajit); aqui só que o gerador escreve a mesma lista e os
mesmos pixels (determinístico).

Uso: python3 tests/test_om_tiles.py (o run-tests.sh chama). Exit 0 = passou.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DIR = os.path.join(ROOT, "mod", "42", "media", "textures", "NOM", "OutroMundo")
LIST_LUA = os.path.join(ROOT, "mod", "42", "media", "lua", "shared", "NOM_OwnSpriteList.lua")
NAME = re.compile(r"^NOM_OM_([A-Za-z]+)_([FWN])_(\d\d)\.png$")
W, H = 128, 256

# Geometria do spike (§3), escrita aqui de novo (não importa o gerador): vértices de cada lado.
POLY = {
    "F": ((64, 192), (128, 224), (64, 256), (0, 224)),
    "W": ((0, 32), (64, 0), (64, 194), (0, 226)),
    "N": ((64, 0), (128, 32), (128, 228), (64, 196)),
}
KINDS = {"F": {"Grade", "Ferrugem", "Chapa", "Tinta"}, "W": {"Tinta", "Ferrugem", "Descasca"},
         "N": {"Tinta", "Ferrugem", "Descasca"}}
# fração do lado coberta (alfa médio na máscara): parcial = nem vazio nem tile cheio. Os
# escorridos de ferrugem na parede são fios e manchas de fonte: cobrem pouco (3–15%).
COVER = {"Ferrugem": (0.03, 0.6), "Tinta": (0.06, 0.6), "Grade": (0.3, 0.93), "Chapa": (0.25, 0.93),
         "Descasca": (0.6, 0.98)}
SAT_MAX = 0.42          # saturação média (HSV) do que é opaco
VIVID_MAX = 0.01        # fração de laranja vivo (saturação > 0,65 e brilho > 0,4)
HALO_MAX = 0.12         # |luminância| do pixel transparente contra os vizinhos com tinta
DIFF_MIN = 0.02         # diferença média de alfa entre duas variações
DETAIL_MIN = 0.035      # desvio da luminância no opaco


def files():
    out = []
    for f in sorted(os.listdir(DIR)):
        m = NAME.match(f)
        assert m, "nome fora do padrão NOM_OM_<tipo>_<lado>_<nn>.png: " + f
        out.append((m.group(1), m.group(2), int(m.group(3)), f))
    return out


def load(f):
    img = Image.open(os.path.join(DIR, f))
    return img, np.asarray(img.convert("RGBA"), np.float64) / 255


def inside(side, x, y):
    out = np.ones(x.shape, bool)
    p = POLY[side]
    for i in range(4):
        (x0, y0), (x1, y1) = p[i], p[(i + 1) % 4]
        out &= (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0) >= 0
    return out


def coverage(side, ss=8):
    """Fração de cada pixel do quadro dentro do polígono do lado (ss×ss sub-amostras)."""
    ys, xs = np.mgrid[0:H * ss, 0:W * ss]
    return inside(side, (xs + 0.5) / ss, (ys + 0.5) / ss).reshape(H, ss, W, ss).mean(axis=(1, 3))


def touched(side, n=16):
    """Pixel que encosta no polígono: algum ponto de uma grade (n + 1)×(n + 1) do quadradinho
    dele, bordas incluídas, está dentro."""
    ys, xs = np.mgrid[0:H * n + 1, 0:W * n + 1]
    g = inside(side, xs / n, ys / n)
    t = g[:-1, :-1].reshape(H, n, W, n).any(axis=(1, 3))
    t |= g[n::n, :-1].reshape(H, W, n).any(axis=2)
    t |= g[:-1, n::n].reshape(H, n, W).any(axis=1)
    return t | g[n::n, n::n]


COV = {s: coverage(s) for s in POLY}
TOUCH = {s: touched(s) for s in POLY}
EDGE_TOL = 0.08         # a cobertura medida aqui (8×8) e a do gerador diferem até ~1/8 na borda


def lum(a):
    return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def cover_of(side, al):
    return float((al * (COV[side] > 0)).sum() / COV[side].sum())


def groups():
    out = {}
    for kind, side, n, f in files():
        out.setdefault((kind, side), []).append(f)
    return out


def test_names_and_kinds():
    g = groups()
    assert g, "nenhuma textura em " + DIR
    for side, kinds in KINDS.items():
        found = {k for k, s in g if s == side}
        assert found == kinds, "lado %s: tipos %s, esperava %s" % (side, sorted(found), sorted(kinds))
    for (kind, side), fs in g.items():
        assert 4 <= len(fs) <= 6, "%s_%s: %d variações (4 a 6)" % (kind, side, len(fs))
        nums = sorted(int(NAME.match(f).group(3)) for f in fs)
        assert nums == list(range(1, len(fs) + 1)), "%s_%s numeradas %s" % (kind, side, nums)


def test_frame_rgba_128x256():
    for _, _, _, f in files():
        img, _ = load(f)
        assert img.size == (W, H) and img.mode == "RGBA", "%s: %s %s" % (f, img.size, img.mode)


def test_nothing_outside_side_mask():
    for _, side, _, f in files():
        _, a = load(f)
        al = a[..., 3]
        out = al[~TOUCH[side]]
        assert out.max() == 0, "%s: alfa %.3f fora do lado %s (%d px)" % (f, out.max(), side, (out > 0).sum())
        over = al - COV[side]
        assert over.max() <= EDGE_TOL, "%s: alfa passa da cobertura do lado na borda (%.3f)" % (f, over.max())


def test_coverage_partial_and_heavy():
    per = {}
    for kind, side, _, f in files():
        _, a = load(f)
        c = cover_of(side, a[..., 3])
        lo, hi = COVER[kind]
        assert lo < c < hi, "%s cobre %.3f do lado (esperado %.2f a %.2f)" % (f, c, lo, hi)
        per.setdefault((kind, side), []).append(c)
    for side in ("W", "N"):
        assert min(per[("Descasca", side)]) > max(per[("Tinta", side)]) + 0.25, \
            "Descasca_%s não cobre bem mais que Tinta_%s: %s × %s" % (side, side, per[("Descasca", side)],
                                                                     per[("Tinta", side)])


def test_variations_differ():
    for (kind, side), fs in groups().items():
        arr = [load(f)[1] for f in fs]
        for i in range(len(arr)):
            for j in range(i + 1, len(arr)):
                da = float(np.abs(arr[i][..., 3] - arr[j][..., 3]).mean())
                dl = float(np.abs(lum(arr[i]) * arr[i][..., 3] - lum(arr[j]) * arr[j][..., 3]).mean())
                cov = COV[side].mean()
                assert da / cov > DIFF_MIN and dl / cov > DIFF_MIN / 2, \
                    "%s e %s quase iguais (alfa %.4f, lum %.4f)" % (fs[i], fs[j], da / cov, dl / cov)


def saturation(a):
    mx, mn = a[..., :3].max(axis=2), a[..., :3].min(axis=2)
    return (mx - mn) / np.maximum(mx, 1e-6), mx


def test_palette_desaturated():
    for _, _, _, f in files():
        _, a = load(f)
        op = a[..., 3] > 0.5
        sat, mx = saturation(a)
        mean = float(sat[op].mean())
        vivid = float(((sat > 0.65) & (mx > 0.4) & op).sum() / max(op.sum(), 1))
        assert mean < SAT_MAX, "%s: saturação média %.3f (teto %.2f)" % (f, mean, SAT_MAX)
        assert vivid < VIVID_MAX, "%s: %.1f%% de laranja vivo" % (f, 100 * vivid)


def neighbours_mean(v, w):
    """Média de v ponderada por w nos 8 vizinhos de cada pixel."""
    pv, pw = np.pad(v * w, 1), np.pad(w, 1)
    s = sum(pv[1 + dy:pv.shape[0] - 1 + dy, 1 + dx:pv.shape[1] - 1 + dx]
            for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    n = sum(pw[1 + dy:pw.shape[0] - 1 + dy, 1 + dx:pw.shape[1] - 1 + dx]
            for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    return s / np.maximum(n, 1e-9), n


def halo(a):
    """Maior |luminância| do pixel transparente (alfa 0) contra a média dos vizinhos com tinta,
    pesada pelo alfa: é a cor que o filtro linear puxa pra borda do desenho."""
    al = a[..., 3]
    m, n = neighbours_mean(lum(a), al)
    edge = (al == 0) & (n > 0.25)
    return float(np.abs(lum(a) - m)[edge].max()) if edge.any() else 0.0


def test_no_halo():
    for _, _, _, f in files():
        h = halo(load(f)[1])
        assert h < HALO_MAX, "%s: halo na borda (%.3f)" % (f, h)


def test_halo_criterion_catches_black_edge():
    # o PNG ingênuo: desenho claro e o resto preto transparente. Tem de reprovar.
    a = np.zeros((32, 32, 4))
    a[8:24, 8:24] = (0.7, 0.68, 0.6, 1.0)
    assert halo(a) > HALO_MAX, "o critério não pega a borda preta"


def test_not_flat():
    for _, _, _, f in files():
        _, a = load(f)
        op = a[..., 3] > 0.5
        sd = float(lum(a)[op].std())
        assert sd > DETAIL_MIN, "%s: cor chapada (desvio %.3f)" % (f, sd)


def generator():
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import gen_tiles
    return gen_tiles


def test_list_written_by_generator():
    g = generator()
    with open(LIST_LUA, encoding="utf-8") as fh:
        assert fh.read() == g.lua_list(), "NOM_OwnSpriteList.lua difere do que o gen_tiles.py escreve"


def test_generator_deterministic():
    # regera duas texturas na memória (uma de chão, uma de parede) e compara com o arquivo
    g = generator()
    for kind, side, n in (("Grade", "F", 2), ("Tinta", "W", 3)):
        rgb, al = g.render(kind, side, n)
        mine = g.to_rgba(rgb, al)
        disk = np.asarray(Image.open(os.path.join(DIR, g.file_name(kind, side, n))).convert("RGBA"))
        assert np.array_equal(mine, disk), "%s mudou ao regerar" % g.file_name(kind, side, n)


def main():
    tests = [test_names_and_kinds, test_frame_rgba_128x256, test_nothing_outside_side_mask,
             test_coverage_partial_and_heavy, test_variations_differ, test_palette_desaturated,
             test_no_halo, test_halo_criterion_catches_black_edge, test_not_flat,
             test_list_written_by_generator, test_generator_deterministic]
    fail = 0
    for t in tests:
        try:
            t()
        except (AssertionError, FileNotFoundError, ImportError) as e:
            fail += 1
            print("FAIL tests/test_om_tiles.py :: %s\n  %s" % (t.__name__, e))
    print("outro mundo total=%d passou=%d falhou=%d" % (len(tests), len(tests) - fail, fail))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
