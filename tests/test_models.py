#!/usr/bin/env python3
"""Modelos 3D próprios (sprints 0041–0042), gerados por scripts/gen_models.py.

Em toda peça, nos dois sexos:
  formato    .x texto (xof 0303txt 0032), contagens e índices batem; lido por um parser
             daqui, não pelo do gerador
  winding    o do vanilla (medido em M_HeadBandage e M_Glasses_SkiGoggles): cross(b−a, c−a)
             aponta pro lado da normal em toda face
  fechada    soldando por posição, toda aresta tem duas faces (o culling não mostra buraco)
  pra fora   cada casca com volume com sinal positivo
  cor        cada parte cai na cor certa da textura; as texturas nossas são espelhadas em v
             (o jogo pode ler v de cima ou de baixo)
  mesmo      regerar não muda um byte (modelos e texturas)

Encaixe por peça, contra números medidos nos .x vanilla (pz-api-notes §32):
  venda      nada entra na cabeça na altura dos olhos, tudo perto dos óculos de esqui, frente em +Z
  boca       perto da boca, na frente do rosto, bem mais larga que alta
  sem-rosto  a cabeça inteira (pontos medidos) dentro da casca, casca perto do capacete fechado
  cabelo     nada no crânio, mechas na frente do nariz, o rosto tapado, três mechas brancas

Uso: python3 tests/test_models.py (o run-tests.sh chama). Exit 0 = passou.
"""
import importlib.util
import math
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MEDIA = os.path.join(ROOT, "mod", "42", "media")
MODELS = os.path.join(MEDIA, "models_X", "Static", "Clothes")
TEXTURES = os.path.join(MEDIA, "textures", "NOM")
SEXES = ("M", "F")

# peça → textura
PIECES = {
    "EstaladorVenda": "NOM_EstaladorVenda3D",
    "CorredorBoca": "NOM_CorredorBoca3D",
    "SemRostoEstatica": "NOM_SemRostoEstatica",
    "CarpideiraCabelo": "NOM_CarpideiraCabelo3D",
    "CarpideiraCapuz": "NOM_CarpideiraCapuz3D",
    "CarpideiraLaco": "NOM_CarpideiraLaco3D",
    "TicaoCrosta": "NOM_TicaoCrosta3D",
}
MIRRORED = ("NOM_EstaladorVenda3D", "NOM_CorredorBoca3D", "NOM_CarpideiraCabelo3D",
            "NOM_CarpideiraCapuz3D", "NOM_CarpideiraLaco3D", "NOM_TicaoCrosta3D")
MAX_VERTS = 2500     # a peça tem ~20 px de tela (o HeadBandage vanilla tem 52 vértices)

# Óculos de esqui vanilla (M_/F_Glasses_SkiGoggles.x, só números): a cabeça na altura dos
# olhos cabe na elipse (y, z) um pouco menor que eles.
GOGGLES = {
    "M": {"x": (0.055, 0.108), "y": 0.060, "z": (-0.073, 0.077)},
    "F": {"x": (0.048, 0.098), "y": 0.057, "z": (-0.062, 0.081)},
}
HEAD_INSET = 0.004   # a pele fica uns mm pra dentro da superfície dos óculos
BOX_SLACK = 0.03     # a venda pode passar dos óculos (pontas do nó caem atrás)

# Pontos da cabeça (touca de banho, máscara de hóquei, máscara cirúrgica, óculos de esqui,
# bandana: só números). Ficam dentro da casca do Sem-rosto e fora do cabelo da Carpideira.
HEAD_POINTS = {
    "M": [(0.181, 0, -0.01), (0.10, 0, -0.092), (0.11, 0.071, -0.01), (0.11, -0.071, -0.01),
          (0.08, 0.060, 0.0), (0.08, -0.060, 0.0), (0.12, 0, 0.072), (0.05, 0, 0.084),
          (-0.017, 0, 0.062), (0.0, 0.050, 0.03), (0.0, -0.050, 0.03)],
    "F": [(0.176, 0, -0.01), (0.10, 0, -0.082), (0.11, 0.066, -0.01), (0.11, -0.066, -0.01),
          (0.075, 0.057, 0.0), (0.075, -0.057, 0.0), (0.11, 0, 0.074), (0.05, 0, 0.086),
          (-0.007, 0, 0.064), (0.005, 0.048, 0.03), (0.005, -0.048, 0.03)],
}
SHELL_MARGIN = 0.004
HELMET = {   # capacete fechado vanilla (a casca do Sem-rosto fica por perto)
    "M": {"x": (-0.017, 0.179), "y": 0.071, "z": (-0.091, 0.093)},
    "F": {"x": (-0.014, 0.171), "y": 0.067, "z": (-0.085, 0.088)},
}
MOUTH = {    # entre o queixo (máscara cirúrgica) e a narina (brinco de nariz), na frente
    "M": {"x": (-0.017, 0.054), "front": 0.072},
    "F": {"x": (-0.007, 0.041), "front": 0.074},
}
NOSE_Z = {"M": 0.084, "F": 0.086}


def generator():
    spec = importlib.util.spec_from_file_location("gen_models", os.path.join(ROOT, "scripts", "gen_models.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def model_path(piece, sex):
    return os.path.join(MODELS, "NOM_%s_%s.x" % (sex, piece))


def texture_path(piece):
    return os.path.join(TEXTURES, PIECES[piece] + ".png")


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


CACHE = {}


def load(piece, sex):
    key = (piece, sex)
    if key not in CACHE:
        with open(model_path(piece, sex), encoding="ascii") as f:
            CACHE[key] = parse_x(f.read())
    return CACHE[key]


def every():
    for piece in PIECES:
        for sex in SEXES:
            yield piece, sex, "%s/%s" % (piece, sex)


def test_format():
    for piece, sex, name in every():
        verts, faces, normals, fnorm, uv = load(piece, sex)
        n = len(verts)
        assert 200 < n < MAX_VERTS, "%s: %d vértices" % (name, n)
        assert faces.min() >= 0 and faces.max() < n, name + ": índice de face fora"
        assert len(normals) == n and np.array_equal(fnorm, faces), name + ": normal por vértice"
        assert len(uv) == n, name + ": UV por vértice"
        assert np.allclose(np.linalg.norm(normals, axis=1), 1, atol=1e-3), name + ": normal não unitária"
        assert uv.min() >= 0 and uv.max() <= 1, name + ": UV fora de 0..1"


def winding_ok(verts, faces, normals):
    a, b, c = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    cross = np.cross(b - a, c - a)
    return np.einsum("ij,ij->i", cross, normals[faces].sum(axis=1)) > 0


def test_winding_like_vanilla():
    for piece, sex, name in every():
        verts, faces, normals, _, _ = load(piece, sex)
        ok = winding_ok(verts, faces, normals)
        assert ok.all(), "%s: %d faces ao contrário" % (name, (~ok).sum())
    # o critério pega a face virada
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], float)
    n = np.array([[0, 0, 1]] * 3, float)
    assert winding_ok(v, np.array([[0, 1, 2]]), n).all() and not winding_ok(v, np.array([[0, 2, 1]]), n).any()


def weld(verts):
    rounded = np.round(verts, 6).tolist()
    key = {tuple(p): k for k, p in enumerate(rounded)}
    return np.array([key[tuple(p)] for p in rounded])


def open_edges(verts, faces):
    count = {}
    for f in weld(verts)[faces]:
        for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
            e = (min(e), max(e))
            count[e] = count.get(e, 0) + 1
    return sum(1 for c in count.values() if c != 2)


def test_closed():
    for piece, sex, name in every():
        verts, faces, _, _, _ = load(piece, sex)
        bad = open_edges(verts, faces)
        assert bad == 0, "%s: %d arestas sem par" % (name, bad)
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], float)
    assert open_edges(v, np.array([[0, 1, 2]])) == 3, "o critério não pega a face solta"


def flipped_edges(verts, faces):
    """Arestas orientadas sem o par contrário (soldando por posição): face virada no meio da casca."""
    seen = {}
    for f in weld(verts)[faces]:
        for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
            seen[e] = seen.get(e, 0) + 1
    return sum(1 for (a, b), c in seen.items() if c != 1 or seen.get((b, a), 0) != 1)


def test_consistent_orientation():
    # o volume da casca só vê o total; face virada no meio (ponta, lasca) passa nele e não aqui
    for piece, sex, name in every():
        verts, faces, _, _, _ = load(piece, sex)
        bad = flipped_edges(verts, faces)
        assert bad == 0, "%s: %d arestas com face virada" % (name, bad)
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]], float)
    good = np.array([[0, 2, 1], [0, 1, 3], [1, 2, 3], [2, 0, 3]])
    bad = good.copy()
    bad[3] = bad[3][::-1]
    assert flipped_edges(v, good) == 0 and flipped_edges(v, bad) > 0, "o critério não pega a face virada"


def shells(verts, faces):
    """Componentes conexas (soldando por posição): lista de arrays de faces."""
    w = weld(verts)
    parent = list(range(len(verts)))

    def root(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for f in w[faces]:
        for q in f[1:]:
            parent[root(q)] = root(f[0])
    groups = {}
    for k, f in enumerate(w[faces]):
        groups.setdefault(root(f[0]), []).append(k)
    return [faces[g] for g in groups.values()]


def signed_volume(verts, faces):
    a, b, c = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    return np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6


def test_outward():
    # cada casca virada pra fora: com o winding do vanilla, volume com sinal positivo
    for piece, sex, name in every():
        verts, faces, _, _, _ = load(piece, sex)
        bad = [k for k, f in enumerate(shells(verts, faces)) if signed_volume(verts, f) <= 0]
        assert not bad, "%s: %d cascas viradas pra dentro" % (name, len(bad))
    v = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]], float)
    tetra = np.array([[0, 2, 1], [0, 1, 3], [1, 2, 3], [2, 0, 3]])
    assert signed_volume(v, tetra) > 0 and signed_volume(v, tetra[:, ::-1]) < 0, "critério do volume"


def test_venda_fits_head():
    for sex in SEXES:
        verts, _, _, _, _ = load("EstaladorVenda", sex)
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


def part_verts(piece, sex, parts):
    """Vértices (do build, não do arquivo) das faces das partes pedidas."""
    m = generator().build(piece, sex)
    idx = sorted({q for f, p in zip(m.faces, m.parts) if p in parts for q in f})
    return np.array(m.verts)[idx], np.array(m.uvs)[idx]


def test_boca_fits_mouth():
    g = generator()
    for sex in SEXES:
        verts, _, _, _, _ = load("CorredorBoca", sex)
        b = MOUTH[sex]
        x, y, z = verts[:, 0], verts[:, 1], verts[:, 2]
        assert x.min() > b["x"][0] and x.max() < b["x"][1], "%s: x %.3f..%.3f fora da boca" % (sex, x.min(), x.max())
        # colada na face: sem focinho (z max bem perto do nariz)
        assert np.abs(y).max() < 0.045 and z.min() > 0.0 and z.max() < 0.095, "%s: longe do rosto" % sex
        front = verts[np.argmax(z)]
        assert abs(front[1]) < 0.03 and front[2] > b["front"] - 0.01, "%s: frente fora de +Z %s" % (sex, front)
        hole, _ = part_verts("CorredorBoca", sex, ("cavity",))
        wide = np.ptp(hole[:, 1])
        tall = np.ptp(hole[:, 0])
        assert wide >= tall, "%s: buraco %.3f de largura por %.3f de altura" % (sex, wide, tall)
        # −40% vs abertura antiga (~0.08): largura do buraco ≤ 0.05
        assert 0.030 <= wide < 0.055, "%s: boca fora da faixa (%.3f)" % (sex, wide)
        m = g.build("CorredorBoca", sex)
        assert any(p == "tear" for p in m.parts), "%s: sem rasgo" % sex
        # um rasgo só (não bilateral): verts de tear no mesmo lado Y
        tear_v, _ = part_verts("CorredorBoca", sex, ("tear",))
        assert (tear_v[:, 1] > -0.005).mean() > 0.85 or (tear_v[:, 1] < 0.005).mean() > 0.85, \
            "%s: rasgo bilateral" % sex


def inside_mesh(verts, faces, p):
    """Paridade de um raio em +Y (Möller–Trumbore) contra todas as faces."""
    a, b, c = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    d = np.array([0.0137, 1.0, 0.0071])        # torto de leve: não passa rente a aresta
    e1, e2 = b - a, c - a
    h = np.cross(d, e2)
    det = np.einsum("ij,ij->i", e1, h)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    s = np.asarray(p) - a
    u = inv * np.einsum("ij,ij->i", s, h)
    q = np.cross(s, e1)
    v = inv * (q @ d)
    t = inv * np.einsum("ij,ij->i", e2, q)
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    return int(hit.sum()) % 2 == 1


def test_semrosto_covers_head():
    for sex in SEXES:
        verts, faces, _, _, _ = load("SemRostoEstatica", sex)
        for p in HEAD_POINTS[sex]:
            p = np.array(p, float)
            for d in ([1, 0, 0], [0, 1, 0], [0, 0, 1]):          # o ponto e a folga em volta
                for sgn in (1, -1):
                    q = p + sgn * SHELL_MARGIN * np.array(d, float)
                    assert inside_mesh(verts, faces, q), "%s: ponto da cabeça %s fora da casca" % (sex, tuple(q))
        h = HELMET[sex]
        x, y, z = verts[:, 0], verts[:, 1], verts[:, 2]
        s = 0.025
        assert x.min() > h["x"][0] - s and x.max() < h["x"][1] + s, "%s: x %.3f..%.3f" % (sex, x.min(), x.max())
        assert np.abs(y).max() < h["y"] + s and z.min() > h["z"][0] - s and z.max() < h["z"][1] + s, \
            "%s: casca grande demais" % sex
    # o critério pega ponto de fora
    cube = np.array([[x, y, z] for x in (0, 1) for y in (0, 1) for z in (0, 1)], float)
    faces = np.array([[0, 1, 3], [0, 3, 2], [4, 6, 7], [4, 7, 5], [0, 4, 5], [0, 5, 1],
                      [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]])
    assert inside_mesh(cube, faces, (0.5, 0.5, 0.5)) and not inside_mesh(cube, faces, (1.5, 0.5, 0.5))


SKULL = {   # crânio: o elipsoide que a touca de banho e a máscara de hóquei cercam, um pouco pra dentro
    "M": {"c": (0.085, 0.0, -0.004), "r": (0.092, 0.066, 0.084)},
    "F": {"c": (0.082, 0.0, 0.0), "r": (0.088, 0.062, 0.080)},
}


def part_groups(m, part):
    """strand → índices dos vértices daquela parte (cada brasa, lasca ou fumaça tem o seu)."""
    out = {}
    for f, p, k in zip(m.faces, m.parts, m.strand):
        if p == part:
            out.setdefault(k, set()).update(f)
    return {k: sorted(v) for k, v in out.items()}


def test_ticao_crust_covers_head():
    g = generator()
    for sex in SEXES:
        verts, faces, _, _, _ = load("TicaoCrosta", sex)
        for p in HEAD_POINTS[sex]:
            assert inside_mesh(verts, faces, np.array(p, float)), "%s: ponto da cabeça %s fora" % (sex, p)
        m = g.build("TicaoCrosta", sex)
        v = np.array(m.verts)
        crust = v[sorted({q for f, p in zip(m.faces, m.parts) if p == "crust" for q in f})]
        h = HELMET[sex]
        # ≤ cabeça vanilla + 5% no raio lateral/frente; folga no queixo (placas baixas)
        assert crust[:, 0].max() < h["x"][1] * 1.05 + 0.012, "%s: crosta alta demais %.3f" % (sex, crust[:, 0].max())
        assert crust[:, 0].min() > h["x"][0] - 0.035, "%s: crosta baixa demais %.3f" % (sex, crust[:, 0].min())
        assert np.abs(crust[:, 1]).max() < h["y"] * 1.05 + 0.015, "%s: crosta larga demais (+5%%)" % sex
        assert crust[:, 2].min() > h["z"][0] - 0.025 and crust[:, 2].max() < h["z"][1] * 1.05 + 0.015, \
            "%s: crosta funda demais" % sex
        # contorno irregular: raio das placas tem dispersão (não cúpula lisa)
        centre = crust.mean(axis=0)
        radii = np.linalg.norm(crust - centre, axis=1)
        assert radii.std() > 0.004, "%s: crosta lisa demais (std=%.4f)" % (sex, radii.std())


def test_ticao_eyes_smoke_shards():
    """Duas brasas nos olhos, na frente; fumaça subindo do alto; lascas de carvão no alto e atrás,
    longe do rosto (o rosto é carvão liso com os dois olhos acesos)."""
    g = generator()
    for sex in SEXES:
        m = g.build("TicaoCrosta", sex)
        v = np.array(m.verts)
        gg, nose = GOGGLES[sex], NOSE_Z[sex]
        eyes = [v[i].mean(axis=0) for i in part_groups(m, "ember").values()]
        assert len(eyes) == 2, "%s: %d olhos" % (sex, len(eyes))
        assert sorted(np.sign([e[1] for e in eyes])) == [-1, 1], "%s: olhos do mesmo lado" % sex
        for e in eyes:
            assert gg["x"][0] <= e[0] <= gg["x"][1], "%s: olho fora da altura dos olhos %.3f" % (sex, e[0])
            assert 0.018 <= abs(e[1]) <= 0.045 and e[2] > nose - 0.01, "%s: olho fora do lugar %s" % (sex, e)
        smoke = part_groups(m, "smoke")
        assert len(smoke) >= 3, "%s: %d fumaças" % (sex, len(smoke))
        for idx in smoke.values():
            w = v[idx]
            assert w[:, 0].max() >= HELMET[sex]["x"][1] + 0.06, "%s: fumaça não sobe" % sex
            assert w[:, 0].min() >= HELMET[sex]["x"][1] - 0.04, "%s: fumaça sai baixo" % sex
            assert np.abs(w[:, 1]).max() <= 0.10 and np.abs(w[:, 2]).max() <= 0.10, "%s: fumaça longe" % sex
        shards = part_groups(m, "shard")
        assert len(shards) >= 8, "%s: %d lascas" % (sex, len(shards))
        for idx in shards.values():
            b = v[idx].mean(axis=0)
            assert b[2] < 0.03 or b[0] > 0.14, "%s: lasca no rosto %s" % (sex, b)


def test_cabelo_close_to_head():
    """Cabelo é cabelo, não peruca de palhaço: rente ao crânio em cima (perto do capacete
    fechado) e, embaixo, abrindo no máximo uns centímetros pra fora."""
    for sex in SEXES:
        verts = load("CarpideiraCabelo", sex)[0]
        h = HELMET[sex]
        assert verts[:, 0].max() <= h["x"][1] + 0.02, "%s: cabelo sobe %.3f" % (sex, verts[:, 0].max())
        top = verts[verts[:, 0] > 0.10]
        assert np.abs(top[:, 1]).max() <= h["y"] + 0.015, "%s: lado do alto %.3f" % (sex, np.abs(top[:, 1]).max())
        assert top[:, 2].min() >= h["z"][0] - 0.02 and top[:, 2].max() <= h["z"][1] + 0.02, "%s: alto fundo demais" % sex
        assert np.abs(verts[:, 1]).max() <= h["y"] + 0.05, "%s: lados abrem %.3f" % (sex, np.abs(verts[:, 1]).max())
        assert verts[:, 2].min() >= h["z"][0] - 0.05, "%s: nuca abre %.3f" % (sex, verts[:, 2].min())
        assert verts[:, 2].max() <= h["z"][1] + 0.04, "%s: frente abre %.3f" % (sex, verts[:, 2].max())


def test_capuz_within_head_plus_5pct():
    """0064 Embrulhada: capuz ≤ SKULL+5% (não capacete-ovo); topo caído; boca na frente.
    Pontos internos do crânio ficam dentro; o pano (cloth) respeita o elipsoide;
    boca/barbante podem sair um pouco na frente (relevo)."""
    g = generator()
    for sex in SEXES:
        verts, faces, _, _, _ = load("CarpideiraCapuz", sex)
        sk = SKULL[sex]
        c, r = np.array(sk["c"]), np.array(sk["r"])
        for th in (0.3, 0.8, 1.2, 1.6):
            for ps in (0.0, 1.0, 2.0, 3.5):
                p = c + 0.9 * r * np.array([math.cos(th), math.sin(th) * math.sin(ps),
                                           math.sin(th) * math.cos(ps)])
                assert inside_mesh(verts, faces, p), "%s: crânio %s fora" % (sex, p)
        h = HELMET[sex]
        m = g.build("CarpideiraCapuz", sex)
        cloth = np.array(m.verts)[sorted({q for f, p in zip(m.faces, m.parts) if p == "cloth" for q in f})]
        x, y, z = cloth[:, 0], cloth[:, 1], cloth[:, 2]
        assert np.abs(y).max() <= sk["r"][1] * 1.05 + 0.001, "%s: capuz largo demais vs SKULL %.3f" % (
            sex, np.abs(y).max())
        assert z.max() <= sk["c"][2] + sk["r"][2] * 1.05 + 0.002, "%s: capuz fundo demais %.3f" % (
            sex, z.max())
        assert x.max() <= sk["c"][0] + sk["r"][0] * 1.05 + 0.002, "%s: capuz alto demais %.3f" % (
            sex, x.max())
        assert x.min() > h["x"][0] - 0.055, "%s: capuz baixo demais %.3f" % (sex, x.min())
        top = cloth[cloth[:, 0] > 0.14]
        assert len(top) > 20 and top[:, 2].mean() < 0.01, "%s: topo não caiu pra trás" % sex
        assert "cloth" in m.parts and "rope" in m.parts and "mouth" in m.parts, \
            "%s: falta pano/boca/barbante" % sex
        mouth = [np.array(m.verts)[list(f)].mean(axis=0)
                 for f, p in zip(m.faces, m.parts) if p == "mouth"]
        assert len(mouth) >= 8, "%s: sem relevo de boca" % sex
        mz = np.array(mouth)[:, 2].mean()
        assert mz > NOSE_Z[sex] - 0.02, "%s: boca atrás do nariz %.3f" % (sex, mz)


def test_laco_on_crown():
    """0064 K1: laço branco no alto da cabeça, largo o bastante pra ler de longe, sem ovo."""
    for sex in SEXES:
        verts, _, _, _, _ = load("CarpideiraLaco", sex)
        h = HELMET[sex]
        assert verts[:, 0].min() > 0.12, "%s: laço baixo demais" % sex
        assert verts[:, 0].max() < h["x"][1] + 0.04, "%s: laço alto demais" % sex
        assert np.abs(verts[:, 1]).max() < 0.060, "%s: laço largo demais" % sex
        assert np.abs(verts[:, 1]).max() > 0.035, "%s: laço estreito demais (precisa ~cabeça)" % sex


def test_cabelo_hides_face():
    g = generator()
    for sex in SEXES:
        verts, faces, _, _, _ = load("CarpideiraCabelo", sex)
        k = SKULL[sex]
        rel = (verts - k["c"]) / k["r"]
        inside = (rel ** 2).sum(axis=1) < 1
        assert not inside.any(), "%s: %d vértices no crânio" % (sex, inside.sum())
        face = (np.abs(verts[:, 1]) < 0.03) & (verts[:, 0] > 0.0) & (verts[:, 0] < 0.10) & (verts[:, 2] > 0)
        assert (verts[face, 2] > NOSE_Z[sex]).all(), "%s: mecha atravessa o rosto" % sex
        m = g.build("CarpideiraCabelo", sex)
        v = np.array(m.verts)
        cross = set()
        for k_, (f, s) in enumerate(zip(m.faces, m.strand)):
            p = v[f].mean(axis=0)
            if abs(p[1]) < 0.03 and 0.03 < p[0] < 0.07 and p[2] > NOSE_Z[sex]:
                cross.add(s)
        assert len(cross) >= 3, "%s: só %d mechas na frente do rosto" % (sex, len(cross))
        white = {s for s, p in zip(m.strand, m.parts) if p == "streak"}
        assert len(white) == 3, "%s: %d mechas brancas" % (sex, len(white))


def luminance(rgb):
    return (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255


def sample(img, uv):
    h, w = img.shape[:2]
    px = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
    py = np.clip((uv[:, 1] * h).astype(int), 0, h - 1)
    return img[py, px].astype(np.float32)


def test_textures_mirrored():
    for name in MIRRORED:
        img = np.asarray(Image.open(os.path.join(TEXTURES, name + ".png")).convert("RGB"))
        assert img.shape == (128, 128, 3), "%s: %s" % (name, img.shape)
        assert np.array_equal(img, img[::-1]), name + ": não é espelhada em v"


# parte → (o que a cor tem de ser, descrição)
def rust(c): return (luminance(c) < 0.4) & (c[:, 0] > c[:, 1])
def bright(c): return luminance(c) > 0.6
def dark(c): return luminance(c) < 0.22  # lote 2: buraco carvão (~L 0,05–0,21), não tinta preta pura
def red(c): return (c[:, 0] > 2 * c[:, 1]) & (c[:, 0] > 60) & (luminance(c) < 0.4)
def pale(c): return (luminance(c) > 0.45) & (luminance(c) < 0.90) & ((c.max(axis=1) - c.min(axis=1)) < 90)
def lip_skin(c):  # pele−10%: médio-escuro, sem aro claro
    return (luminance(c) > 0.12) & (luminance(c) < 0.40) & ((c.max(axis=1) - c.min(axis=1)) < 70)
def cloth(c): return np.ones(len(c), bool)
def ember(c): return (c[:, 0] > 170) & (c[:, 0] > 1.3 * c[:, 1]) & (c[:, 1] > c[:, 2])
def smoke(c): return (luminance(c) > 0.55) & (c.max(axis=1) - c.min(axis=1) < 40)


def not_rust(c):
    # pano, fresta ou sangue: a ferrugem tem verde ~0,45 do vermelho, o sangue ~0,2 e o pano ~1
    gr = c[:, 1] / np.maximum(c[:, 0], 1)
    return ~((gr > 0.36) & (gr < 0.56))


COLOURS = {
    "EstaladorVenda": {"wire": rust, "barb": rust, "band": not_rust},
    # ajuste playtest: lábio = pele−10% (não aro claro); buraco/tear escuros
    "CorredorBoca": {"teeth": dark, "cavity": dark, "tear": dark, "lips": lip_skin},
    "SemRostoEstatica": {"shell": cloth},
    "CarpideiraCabelo": {"hair": dark, "streak": bright},
    # cloth: lençol + manchas/plástico (não é pale uniforme)
    "CarpideiraCapuz": {"cloth": cloth, "mouth": dark, "rope": cloth},
    "CarpideiraLaco": {"bow": pale},
    "TicaoCrosta": {"crust": cloth, "shard": dark, "ember": ember, "smoke": smoke},
}


def test_parts_land_on_colours():
    g = generator()
    for piece, sex, name in every():
        img = np.asarray(Image.open(texture_path(piece)).convert("RGB"))
        m = g.build(piece, sex)
        uv = np.array(m.uvs)
        seen = set()
        for part, check in COLOURS[piece].items():
            idx = sorted({q for f, p in zip(m.faces, m.parts) if p == part for q in f})
            assert idx, "%s: sem a parte %s" % (name, part)
            seen.add(part)
            ok = check(sample(img, uv[idx]))
            assert ok.all(), "%s: %d vértices de %s fora da cor" % (name, (~ok).sum(), part)
        assert set(m.parts) == seen, "%s: parte sem regra de cor %s" % (name, set(m.parts) - seen)
    # o critério pega a cor errada
    assert not dark(np.array([[236.0, 228, 206]])).any() and not bright(np.array([[20.0, 6, 6]])).any()
    assert not ember(np.array([[120.0, 120, 120]])).any() and not smoke(np.array([[240.0, 120, 30]])).any()


def test_generator_deterministic():
    g = generator()
    for piece, sex, name in every():
        with open(model_path(piece, sex), encoding="ascii", newline="") as f:
            disk = f.read()
        assert g.to_x(g.build(piece, sex), "NOM_%s_%s" % (sex, piece)) == disk, name + ": .x mudou ao regerar"
    for tex, img in g.textures().items():
        disk = np.asarray(Image.open(os.path.join(TEXTURES, tex + ".png")).convert("RGB"))
        assert np.array_equal(img, disk), tex + ": textura mudou ao regerar"


def main():
    tests = [test_format, test_winding_like_vanilla, test_closed, test_consistent_orientation, test_outward, test_venda_fits_head,
             test_boca_fits_mouth, test_semrosto_covers_head, test_cabelo_close_to_head, test_cabelo_hides_face,
             test_capuz_within_head_plus_5pct, test_laco_on_crown,
             test_ticao_crust_covers_head, test_ticao_eyes_smoke_shards, test_textures_mirrored,
             test_parts_land_on_colours, test_generator_deterministic]
    fail = 0
    for t in tests:
        try:
            t()
        except (AssertionError, FileNotFoundError, AttributeError, ImportError, KeyError, TypeError) as e:
            fail += 1
            print("FAIL tests/test_models.py :: %s\n  %s: %s" % (t.__name__, type(e).__name__, e))
    print("modelos total=%d passou=%d falhou=%d" % (len(tests), len(tests) - fail, fail))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
