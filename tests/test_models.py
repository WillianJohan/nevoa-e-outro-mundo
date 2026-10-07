#!/usr/bin/env python3
"""Modelos 3D próprios (sprint 0041): a venda do Estalador, gerada por scripts/gen_models.py.

  formato    .x texto (xof 0303txt 0032), contagens e índices batem; lido por um parser
             daqui, não pelo do gerador
  winding    o do vanilla (medido em M_HeadBandage e M_Glasses_SkiGoggles): cross(b−a, c−a)
             aponta pro lado da normal em toda face
  fechada    soldando por posição, toda aresta tem duas faces (o culling não mostra buraco)
  encaixe    nada entra na cabeça (elipse medida nos óculos de esqui vanilla, por sexo), tudo
             fica perto dos óculos e a frente da faixa está em +Z
  UV         arame na faixa de ferrugem e atadura no pano, lendo v de cima ou de baixo
  mesmo      regerar não muda um byte (modelos e textura)

Uso: python3 tests/test_models.py (o run-tests.sh chama). Exit 0 = passou.
"""
import importlib.util
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MEDIA = os.path.join(ROOT, "mod", "42", "media")
MODELS = os.path.join(MEDIA, "models_X", "Static", "Clothes")
TEXTURE = os.path.join(MEDIA, "textures", "NOM", "NOM_EstaladorVenda3D.png")
SEXES = ("M", "F")

# Óculos de esqui vanilla (M_/F_Glasses_SkiGoggles.x, só números): a venda de hoje.
# A cabeça na altura dos olhos cabe na elipse (y, z) um pouco menor que eles.
GOGGLES = {
    "M": {"x": (0.055, 0.108), "y": 0.060, "z": (-0.073, 0.077)},
    "F": {"x": (0.048, 0.098), "y": 0.057, "z": (-0.062, 0.081)},
}
HEAD_INSET = 0.004   # a pele fica uns mm pra dentro da superfície dos óculos
BOX_SLACK = 0.03     # a peça pode passar dos óculos (pontas do nó caem atrás)


def generator():
    spec = importlib.util.spec_from_file_location("gen_models", os.path.join(ROOT, "scripts", "gen_models.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def model_path(sex):
    return os.path.join(MODELS, "NOM_%s_EstaladorVenda.x" % sex)


def parse_x(text):
    """Lê o .x texto: vértices, faces, normais (por vértice) e UV. Só o que o gerador usa."""
    assert text.startswith("xof 0303txt 0032"), "cabeçalho"
    num = r"-?\d+(?:\.\d+)?(?:e[-+]?\d+)?"

    def block(name):
        m = re.search(r"\b%s\b[^{]*\{" % name, text)
        assert m, "sem bloco " + name
        return [float(t) for t in re.findall(num, text[m.end():])]

    t = block("Mesh")
    nv = int(t[0])
    verts = np.array(t[1:1 + 3 * nv]).reshape(nv, 3)
    i = 1 + 3 * nv
    nf = int(t[i])
    i += 1
    faces = []
    for _ in range(nf):
        assert int(t[i]) == 3, "face não é triângulo"
        faces.append([int(v) for v in t[i + 1:i + 4]])
        i += 4
    faces = np.array(faces)
    t = block("MeshNormals")
    nn = int(t[0])
    normals = np.array(t[1:1 + 3 * nn]).reshape(nn, 3)
    j = 1 + 3 * nn
    assert int(t[j]) == nf, "faces de normal ≠ faces"
    fnorm = np.array([[int(v) for v in t[j + 2 + 4 * k:j + 5 + 4 * k]] for k in range(nf)])
    t = block("MeshTextureCoords")
    nt = int(t[0])
    uv = np.array(t[1:1 + 2 * nt]).reshape(nt, 2)
    t = block("MeshMaterialList")
    assert int(t[0]) == 1 and int(t[1]) == nf, "lista de material"
    assert "TextureFilename" in text, "material sem textura"
    return verts, faces, normals, fnorm, uv


def load(sex):
    with open(model_path(sex), encoding="ascii") as f:
        return parse_x(f.read())


def test_format():
    for sex in SEXES:
        verts, faces, normals, fnorm, uv = load(sex)
        n = len(verts)
        # a peça tem ~20 px de tela: até ~2500 vértices (o HeadBandage vanilla tem 52)
        assert 200 < n < 2500, "%s: %d vértices" % (sex, n)
        assert faces.min() >= 0 and faces.max() < n, sex + ": índice de face fora"
        assert len(normals) == n and np.array_equal(fnorm, faces), sex + ": normal por vértice"
        assert len(uv) == n, sex + ": UV por vértice"
        assert np.allclose(np.linalg.norm(normals, axis=1), 1, atol=1e-3), sex + ": normal não unitária"
        assert uv.min() >= 0 and uv.max() <= 1, sex + ": UV fora de 0..1"


def winding_ok(verts, faces, normals):
    a, b, c = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    cross = np.cross(b - a, c - a)
    return np.einsum("ij,ij->i", cross, normals[faces].sum(axis=1)) > 0


def test_winding_like_vanilla():
    for sex in SEXES:
        verts, faces, normals, _, _ = load(sex)
        ok = winding_ok(verts, faces, normals)
        assert ok.all(), "%s: %d faces ao contrário" % (sex, (~ok).sum())
    # o critério pega a face virada
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], float)
    n = np.array([[0, 0, 1]] * 3, float)
    assert winding_ok(v, np.array([[0, 1, 2]]), n).all() and not winding_ok(v, np.array([[0, 2, 1]]), n).any()


def open_edges(verts, faces):
    key = {tuple(p): k for k, p in enumerate(np.round(verts, 6).tolist())}
    weld = np.array([key[tuple(p)] for p in np.round(verts, 6).tolist()])
    count = {}
    for f in weld[faces]:
        for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
            e = (min(e), max(e))
            count[e] = count.get(e, 0) + 1
    return sum(1 for c in count.values() if c != 2)


def test_closed():
    for sex in SEXES:
        verts, faces, _, _, _ = load(sex)
        bad = open_edges(verts, faces)
        assert bad == 0, "%s: %d arestas sem par" % (sex, bad)
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], float)
    assert open_edges(v, np.array([[0, 1, 2]])) == 3, "o critério não pega a face solta"


def shells(verts, faces):
    """Componentes conexas (soldando por posição): lista de arrays de faces."""
    key = {tuple(p): k for k, p in enumerate(np.round(verts, 6).tolist())}
    weld = np.array([key[tuple(p)] for p in np.round(verts, 6).tolist()])
    parent = list(range(len(verts)))

    def root(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for f in weld[faces]:
        for q in f[1:]:
            parent[root(q)] = root(f[0])
    groups = {}
    for k, f in enumerate(weld[faces]):
        groups.setdefault(root(f[0]), []).append(k)
    return [faces[g] for g in groups.values()]


def signed_volume(verts, faces):
    a, b, c = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    return np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6


def test_outward():
    # cada casca virada pra fora: com o winding do vanilla, volume com sinal positivo
    for sex in SEXES:
        verts, faces, _, _, _ = load(sex)
        parts = shells(verts, faces)
        assert len(parts) > 3, "%s: %d cascas" % (sex, len(parts))
        bad = [k for k, f in enumerate(parts) if signed_volume(verts, f) <= 0]
        assert not bad, "%s: %d cascas viradas pra dentro" % (sex, len(bad))
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]], float)
    tetra = np.array([[0, 2, 1], [0, 1, 3], [1, 2, 3], [2, 0, 3]])
    assert signed_volume(v, tetra) > 0 and signed_volume(v, tetra[:, ::-1]) < 0, "critério do volume"


def test_fits_head():
    for sex in SEXES:
        verts, _, _, _, _ = load(sex)
        g = GOGGLES[sex]
        x, y, z = verts[:, 0], verts[:, 1], verts[:, 2]
        z0 = (g["z"][0] + g["z"][1]) / 2
        rz = (g["z"][1] - g["z"][0]) / 2 - HEAD_INSET
        ry = g["y"] - HEAD_INSET
        band = (x > g["x"][0]) & (x < g["x"][1])
        inside = (y[band] / ry) ** 2 + ((z[band] - z0) / rz) ** 2 < 1
        assert not inside.any(), "%s: %d vértices dentro da cabeça" % (sex, inside.sum())
        s = BOX_SLACK
        assert x.min() > g["x"][0] - 2 * s and x.max() < g["x"][1] + s, "%s: x %.3f..%.3f" % (sex, x.min(), x.max())
        assert np.abs(y).max() < g["y"] + s, "%s: y %.3f" % (sex, np.abs(y).max())
        assert z.min() > g["z"][0] - s and z.max() < g["z"][1] + s, "%s: z %.3f..%.3f" % (sex, z.min(), z.max())
        front = verts[np.argmax(z)]
        assert abs(front[1]) < 0.02 and front[2] > g["z"][1], "%s: frente fora de +Z %s" % (sex, front)


def luminance(rgb):
    return (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255


def sample(img, uv):
    h, w = img.shape[:2]
    px = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
    py = np.clip((uv[:, 1] * h).astype(int), 0, h - 1)
    return img[py, px].astype(np.float32)


def test_uv_survives_v_flip():
    g = generator()
    img = np.asarray(Image.open(TEXTURE).convert("RGB"))
    assert img.shape == (128, 128, 3), "textura %s" % (img.shape,)
    for sex in SEXES:
        m = g.build(sex)
        uv = np.array(m.uvs)
        wire = np.zeros(len(uv), bool)
        for f, part in zip(m.faces, m.parts):
            if part in ("wire", "barb"):
                wire[list(f)] = True
        assert wire.any() and (~wire).any(), sex + ": sem arame ou sem atadura"
        for flip in (False, True):
            u = uv.copy()
            if flip:
                u[:, 1] = 1 - u[:, 1]
            rgb = sample(img, u)
            rust = rgb[wire]
            assert (luminance(rust) < 0.4).all() and (rust[:, 0] > rust[:, 1]).all(), \
                "%s: arame fora da ferrugem (flip=%s)" % (sex, flip)
            cloth = u[~wire, 1]
            assert ((cloth < g.WIRE_V[0]) | (cloth > g.WIRE_V[1])).all(), "%s: atadura na ferrugem" % sex


def test_generator_deterministic():
    g = generator()
    for sex in SEXES:
        with open(model_path(sex), encoding="ascii", newline="") as f:
            disk = f.read()
        assert g.to_x(g.build(sex), "NOM_%s_EstaladorVenda" % sex) == disk, sex + ": .x mudou ao regerar"
    disk = np.asarray(Image.open(TEXTURE).convert("RGB"))
    assert np.array_equal(g.texture(), disk), "textura mudou ao regerar"


def main():
    tests = [test_format, test_winding_like_vanilla, test_closed, test_outward, test_fits_head,
             test_uv_survives_v_flip, test_generator_deterministic]
    fail = 0
    for t in tests:
        try:
            t()
        except (AssertionError, FileNotFoundError, AttributeError, ImportError) as e:
            fail += 1
            print("FAIL tests/test_models.py :: %s\n  %s" % (t.__name__, e))
    print("modelos total=%d passou=%d falhou=%d" % (len(tests), len(tests) - fail, fail))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
