#!/usr/bin/env python3
"""Gera as texturas do visual dos monstros (sprint 0012), procedurais e originais.

Cada textura veste um modelo VANILLA citado por nome (nada do jogo é copiado; da
textura vanilla só se usa o tamanho). Os desenhos não dependem do mapa UV do
modelo: padrões que valem em qualquer ponto (rachadura, veia, chiado, fio), então
a peça inteira vira o material. Direção de arte em docs/gdd/art-direction.md.

Saída (mod/42/media/textures/):
  Body/NOM_Estalador.png         256  pele de porcelana rachada, costuras escuras
  Body/NOM_Corredor.png          256  pele cinza-cinza esticada, veias escuras
  Body/NOM_Carpideira.png        256  pele pálida com escorridos de fuligem (lágrimas)
  NOM/NOM_EstaladorVenda.png     128  atadura manchada com arame enferrujado (óculos de esqui)
  NOM/NOM_CorredorBoca.png       128  boca rasgada: carne escura e rasgos (máscara cirúrgica)
  NOM/NOM_SemRostoEstatica.png   128  chiado de TV cinza (balaclava inteira)
  NOM/NOM_CarpideiraCabelo.png   128  cabelo preto embolado caindo (véu)
  NOM/NOM_EcoCinza.png           256  cinza e fumaça no corpo todo (camada sem modelo)
  NOM/NOM_EcoVeu.png             128  fumaça clara (véu)

Efeitos de tela (sprint 0013), branco com alfa (a cor sai do desenho):
  NOM/ScreenFx/NOM_Grain1..4.png 256  grão de filme em blocos de 2 px, um quadro cada
  NOM/ScreenFx/NOM_Vignette.png  512  vinheta: alfa 0 no centro, sobe pras bordas
  NOM/ScreenFx/NOM_Lines.png     512×256  linhas horizontais de chiado, falhadas
  NOM/ScreenFx/NOM_White.png     8    branco opaco (o pulso do grito, tingido de vermelho)

Semente fixa: rodar de novo dá os mesmos bytes. Uso: python3 scripts/gen_textures.py
"""
import os

import numpy as np
from PIL import Image

SEED = 1203
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media", "textures")


def noise(rng, size, cells):
    """Ruído de valor 0..1: grade pequena ampliada com bicúbica."""
    grid = rng.random((cells, cells)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255


def fbm(rng, size, cells=(4, 9, 23), weights=(0.55, 0.3, 0.15)):
    return sum(w * noise(rng, size, c) for w, c in zip(weights, cells))


def cracks(rng, size, points):
    """Bordas de Voronoi: ~0 na rachadura, sobe longe dela."""
    pts = rng.random((points, 2)) * size
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sort(np.stack([np.hypot(x - px, y - py) for px, py in pts]), axis=0)
    return d[1] - d[0]


def color(base, shade):
    """base RGB 0..255 vezes shade (H×W) → H×W×3."""
    return np.asarray(base, np.float32)[None, None, :] * shade[..., None]


def save(rgb, path, alpha=None):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is None:
        img = Image.fromarray(rgb, "RGB")
    else:
        a = np.clip(alpha * 255, 0, 255).astype(np.uint8)
        img = Image.fromarray(np.dstack([rgb, a]), "RGBA")
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full, optimize=True)
    print("ok", path)


def estalador_skin(rng, size=256):
    # porcelana: branco-osso quase sem variação; rachaduras finas e escuras que
    # parecem costuras (vibra quando estala)
    shade = 0.92 + 0.08 * fbm(rng, size)
    rgb = color((222, 214, 198), shade)
    c = cracks(rng, size, 70)
    line = np.clip(1 - c / 2.2, 0, 1)                     # fio da rachadura
    halo = np.clip(1 - c / 7.0, 0, 1) * 0.35              # borda suja em volta
    dark = np.asarray((38, 30, 28), np.float32)
    k = np.maximum(line, halo)[..., None]
    return rgb * (1 - k) + dark * k


def corredor_skin(rng, size=256):
    # cinza de cinza, esticada (manchas alongadas na vertical), veias quase pretas
    stretch = np.asarray(Image.fromarray((fbm(rng, size) * 255).astype(np.uint8)).resize((size // 4, size)).resize((size, size), Image.BICUBIC), np.float32) / 255
    rgb = color((128, 126, 120), 0.8 + 0.3 * stretch)
    v = fbm(rng, size, (6, 14, 31), (0.5, 0.35, 0.15))
    vein = np.clip(1 - np.abs(v - 0.5) / 0.035, 0, 1)      # isolinha fina: veia
    v2 = fbm(rng, size, (5, 12, 27), (0.5, 0.35, 0.15))
    vein = np.maximum(vein, np.clip(1 - np.abs(v2 - 0.5) / 0.025, 0, 1) * 0.8)
    dark = np.asarray((34, 18, 40), np.float32)            # roxo-preto
    k = vein[..., None]
    return rgb * (1 - k) + dark * k


def carpideira_skin(rng, size=256):
    # pálida, um pouco azulada; escorridos de fuligem de cima pra baixo
    rgb = color((196, 198, 204), 0.9 + 0.1 * fbm(rng, size))
    cols = rng.random(size).astype(np.float32)
    streak = (cols > 0.82).astype(np.float32) * (0.4 + 0.6 * rng.random(size).astype(np.float32))
    y = np.linspace(0, 1, size, dtype=np.float32)[:, None]
    fade = np.clip(1.2 - y - 0.4 * noise(rng, size, 8), 0, 1)  # escorre e acaba
    k = np.clip(streak[None, :] * fade, 0, 1)
    soot = np.asarray((22, 20, 20), np.float32)
    rgb = rgb * (1 - k[..., None] * 0.85) + soot * (k[..., None] * 0.85)
    blot = np.clip((fbm(rng, size) - 0.62) * 4, 0, 1) * 0.5    # manchas onde esfregou
    return rgb * (1 - blot[..., None]) + soot * blot[..., None]


def estalador_venda(rng, size=128):
    # atadura amarelada e manchada, trama na horizontal, arame enferrujado em X
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    weave = 0.85 + 0.15 * (np.sin(y * 1.6) * 0.5 + 0.5)
    stain = np.clip((fbm(rng, size) - 0.45) * 2.5, 0, 1)
    rgb = color((206, 192, 160), weave)
    rgb = rgb * (1 - stain[..., None] * 0.6) + np.asarray((96, 70, 40), np.float32) * (stain[..., None] * 0.6)
    wire = np.zeros((size, size), np.float32)
    for s in (14, 23):
        for off in range(0, size * 2, s * 2):
            wire = np.maximum(wire, np.clip(1.4 - np.abs((x + y - off) % (s * 2) - s / 2), 0, 1))
            wire = np.maximum(wire, np.clip(1.4 - np.abs((x - y + size * 2 - off) % (s * 2) - s / 2), 0, 1))
    rust = color((132, 62, 24), 0.7 + 0.5 * noise(rng, size, 16))
    return rgb * (1 - wire[..., None]) + rust * wire[..., None]


def corredor_boca(rng, size=128):
    # carne crua e escura, rasgos claros na vertical, pontas de dente
    rgb = color((92, 14, 16), 0.5 + 0.6 * fbm(rng, size))
    tear = np.clip((noise(rng, size, 24) - 0.7) * 5, 0, 1)
    tear = np.asarray(Image.fromarray((tear * 255).astype(np.uint8)).resize((size, size // 6)).resize((size, size), Image.BICUBIC), np.float32) / 255
    rgb = rgb * (1 - tear[..., None]) + np.asarray((168, 60, 58), np.float32) * tear[..., None]
    teeth = (rng.random((size, size)) > 0.993).astype(np.float32)
    teeth = np.maximum(teeth, np.roll(teeth, 1, 0))
    rgb = rgb * (1 - teeth[..., None]) + np.asarray((214, 204, 170), np.float32) * teeth[..., None]
    hole = np.clip((fbm(rng, size) - 0.55) * 3, 0, 1)        # o fundo da boca, preto
    return rgb * (1 - hole[..., None] * 0.8)


def semrosto_estatica(rng, size=128):
    # chiado de TV: grão por pixel em cinza, faixas horizontais mais claras e escuras
    grain = rng.random((size, size)).astype(np.float32)
    band = 0.85 + 0.3 * rng.random(size).astype(np.float32)[:, None]
    roll = (np.arange(size)[:, None] % 9 == 0) * 0.25
    v = np.clip((0.25 + 0.6 * grain) * band + roll, 0, 1)
    return color((205, 205, 205), v)


def carpideira_cabelo(rng, size=128):
    # fios pretos-castanhos caindo, ondulando, embolados em nós
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    wob = 3.0 * np.sin(y / 9.0 + noise(rng, size, 6) * 6.0)
    strands = np.sin((x + wob) * 2.3) * 0.5 + 0.5
    clump = noise(rng, size, 10)
    v = 0.25 + 0.5 * strands * (0.6 + 0.4 * clump)
    rgb = color((52, 40, 34), v)
    knot = np.clip((fbm(rng, size) - 0.6) * 4, 0, 1)
    return rgb * (1 - knot[..., None] * 0.6)


def eco_cinza(rng, size=256):
    # cinza claro e fumaça: manchas que sobem, quase branco nas bordas
    y = np.linspace(0, 1, size, dtype=np.float32)[:, None]
    smoke = fbm(rng, size, (3, 7, 19), (0.5, 0.3, 0.2))
    rise = np.asarray(Image.fromarray((smoke * 255).astype(np.uint8)).resize((size // 3, size)).resize((size, size), Image.BICUBIC), np.float32) / 255
    v = 0.72 + 0.28 * rise - 0.08 * y
    rgb = color((214, 216, 222), v)
    ash = (rng.random((size, size)) > 0.985).astype(np.float32) * 0.5
    return rgb * (1 - ash[..., None]) + np.asarray((70, 70, 72), np.float32) * ash[..., None]


def eco_veu(rng, size=128):
    smoke = fbm(rng, size, (3, 8, 21), (0.5, 0.3, 0.2))
    return color((226, 228, 234), 0.75 + 0.25 * smoke)


def screen_grain(rng, size=256):
    # ruído em blocos de 2 px, esparso: a maioria quase transparente, poucos grãos fortes
    cells = rng.random((size // 2, size // 2)).astype(np.float32) ** 3
    a = np.kron(cells, np.ones((2, 2), np.float32))
    return np.full((size, size, 3), 255, np.float32), a


def screen_vignette(size=512):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.hypot(x - (size - 1) / 2, y - (size - 1) / 2) / (size / 2)  # 0 no centro, ~1.41 no canto
    a = np.clip((d - 0.45) / 0.85, 0, 1) ** 1.6
    return np.full((size, size, 3), 255, np.float32), a


def screen_lines(rng, w=512, h=256):
    # cada linha da textura: chiado ou nada; as que chiam têm falhas ao longo do x
    row = (rng.random(h) > 0.82).astype(np.float32) * (0.35 + 0.65 * rng.random(h).astype(np.float32))
    gaps = np.clip(noise(rng, w, 32)[:h, :] * 1.6 - 0.3, 0, 1)
    a = row[:, None] * gaps
    return np.full((h, w, 3), 255, np.float32), a


def main():
    rng = np.random.default_rng(SEED)
    save(estalador_skin(rng), "Body/NOM_Estalador.png")
    save(corredor_skin(rng), "Body/NOM_Corredor.png")
    save(carpideira_skin(rng), "Body/NOM_Carpideira.png")
    save(estalador_venda(rng), "NOM/NOM_EstaladorVenda.png")
    save(corredor_boca(rng), "NOM/NOM_CorredorBoca.png")
    save(semrosto_estatica(rng), "NOM/NOM_SemRostoEstatica.png")
    save(carpideira_cabelo(rng), "NOM/NOM_CarpideiraCabelo.png")
    # camada no corpo todo, como o Gown_Hospital vanilla (RGBA): opaca, cobre a pele
    save(eco_cinza(rng), "NOM/NOM_EcoCinza.png", alpha=np.ones((256, 256), np.float32))
    save(eco_veu(rng), "NOM/NOM_EcoVeu.png")
    # efeitos de tela: gerador próprio, pra não mudar as texturas acima
    srng = np.random.default_rng(SEED + 13)
    for i in range(1, 5):
        rgb, a = screen_grain(srng)
        save(rgb, "NOM/ScreenFx/NOM_Grain%d.png" % i, alpha=a)
    rgb, a = screen_vignette()
    save(rgb, "NOM/ScreenFx/NOM_Vignette.png", alpha=a)
    rgb, a = screen_lines(srng)
    save(rgb, "NOM/ScreenFx/NOM_Lines.png", alpha=a)
    save(np.full((8, 8, 3), 255, np.float32), "NOM/ScreenFx/NOM_White.png", alpha=np.ones((8, 8), np.float32))


if __name__ == "__main__":
    main()
