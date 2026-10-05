#!/usr/bin/env python3
"""Gera as texturas do visual dos monstros (sprint 0012), procedurais e originais.

Cada textura veste um modelo VANILLA citado por nome (nada do jogo é copiado; da
textura vanilla só se usa o tamanho e, na pele, onde fica o rosto). Os desenhos não
dependem do mapa UV do modelo: padrões que valem em qualquer ponto (rachadura, veia,
chiado, fio), então a peça inteira vira o material. Contraste cheio e formas grandes
(sprint 0014): a 0012 tinha ruído fino que virava "lã" no jogo. Direção de arte em
docs/gdd/art-direction.md; prévia em scripts/preview_textures.py.

Saída (mod/42/media/textures/):
  Body/NOM_Estalador.png         256  porcelana quase branca, rachaduras grossas pretas
  Body/NOM_Corredor.png          256  cinza-cinza clara, veias grossas roxo-pretas
  Body/NOM_Carpideira.png        256  muito pálida, escorridos de fuligem, fuligem nos olhos
  NOM/NOM_EstaladorVenda.png     128  atadura branco-suja, arame ferrugem em X com contorno preto (óculos de esqui)
  NOM/NOM_CorredorBoca.png       128  vermelho escuro, rasgo preto com dentes brancos (máscara cirúrgica)
  NOM/NOM_SemRostoEstatica.png   128  chiado de TV em blocos preto/branco e faixas rasgadas (balaclava inteira)
  NOM/NOM_CarpideiraCabelo.png   128  cabelo preto de piche com três mechas brancas (véu)
  NOM/NOM_EcoCinza.png           256  quase branco com salpico escuro, no corpo todo (camada sem modelo)
  NOM/NOM_EcoVeu.png             128  quase branco com salpico escuro (véu)

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


# Contraste (sprint 0014): no jogo o zumbi tem ~1–2 m de tela na câmera isométrica e a
# névoa corta 30–50% do brilho. Ruído fino e cinza médio viram "lã". Então: quase preto e
# quase branco, formas de 1/8 da largura pra cima, poucas cores, brilho puxado pra cima.
# tests/test_look_contrast.py mede cada textura.
INK = (14, 12, 12)          # o preto de todo desenho


def mix(rgb, ink, k):
    """Pinta ink por cima de rgb com cobertura k (H×W, 0..1)."""
    return rgb * (1 - k[..., None]) + np.asarray(ink, np.float32) * k[..., None]


def blocks(rng, rows, cols, size):
    """Grade rows×cols de 0..1 ampliada sem suavizar pra size×size (blocos de borda dura)."""
    return np.kron(rng.random((rows, cols)).astype(np.float32), np.ones((size // rows, size // cols), np.float32))


def estalador_skin(rng, size=256):
    # porcelana quase branca, rachaduras GROSSAS pretas em placas grandes; o Estalador
    # lê como um boneco trincado
    rgb = color((246, 242, 234), 0.97 + 0.03 * fbm(rng, size))
    c = cracks(rng, size, 22)                             # poucas placas, ~50 px cada
    k = np.clip((5.0 - c) / 1.5, 0, 1)                    # rachadura de ~8 px, borda dura
    fine = cracks(rng, size, 60)
    k = np.maximum(k, np.clip((2.2 - fine) / 1.0, 0, 1) * (noise(rng, size, 5) > 0.55))
    return mix(rgb, INK, k)


def corredor_skin(rng, size=256):
    # cinza de cinza claro (brilho alto contra a névoa), veias grossas quase pretas
    rgb = color((200, 197, 190), 0.96 + 0.04 * fbm(rng, size))
    k = np.zeros((size, size), np.float32)
    for cells, width in ((4, 0.06), (7, 0.045), (11, 0.03)):
        v = fbm(rng, size, (cells, cells * 2), (0.8, 0.2))
        k = np.maximum(k, np.clip((width - np.abs(v - 0.5)) / 0.012, 0, 1))
    return mix(rgb, (24, 10, 26), k)                     # roxo-preto


def carpideira_skin(rng, size=256):
    # muito pálida; escorridos grossos de fuligem de cima pra baixo e o rosto sujo onde
    # ela enxugou as lágrimas
    rgb = color((242, 242, 246), 0.97 + 0.03 * fbm(rng, size))
    cols = blocks(rng, 1, 32, size)[0]                    # colunas de 8 px
    streak = (cols > 0.8).astype(np.float32)
    y = np.linspace(0, 1, size, dtype=np.float32)[:, None]
    stop = 0.2 + 0.5 * blocks(rng, 1, 32, size)            # cada escorrido acaba numa altura
    k = streak[None, :] * (y < stop)
    k = np.maximum(k, (fbm(rng, size, (3, 6), (0.7, 0.3)) > 0.74).astype(np.float32))
    # fuligem debaixo dos olhos: o rosto da pele de zumbi vanilla fica no alto e no meio
    # (M e F iguais, visto pelo layout: rosto em x 44–56%, olhos em x ~47% e ~53%,
    # y ~12%). Uma mancha por olho que escorre até ~24%.
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    for ex in (0.47, 0.53):
        eye = (np.abs(xx - ex) < 0.022) & (yy > 0.11) & (yy < 0.17 + 0.07 * (np.abs(xx - ex) < 0.008))
        k = np.maximum(k, eye.astype(np.float32))
    return mix(rgb, INK, k)


def estalador_venda(rng, size=128):
    # atadura branco-suja em faixas, arame ferrugem grosso em X com contorno preto
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    rgb = color((238, 230, 210), np.ones((size, size), np.float32))
    rgb = mix(rgb, (150, 132, 104), ((y % 32) < 3).astype(np.float32))  # dobra da atadura
    d1 = np.abs((x + y) % 64 - 32)                       # um X grande a cada 64 px
    d2 = np.abs((x - y + size) % 64 - 32)
    d = np.minimum(d1, d2)
    rgb = mix(rgb, INK, (d < 10).astype(np.float32))     # contorno
    return mix(rgb, (214, 92, 24), (d < 6).astype(np.float32))  # ferrugem viva


def corredor_boca(rng, size=128):
    # vermelho escuro saturado; um rasgo preto largo de lado a lado, com dentes brancos
    # grandes em cima e embaixo, e escorridos pretos que descem do rasgo
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    rgb = color((168, 8, 14), 0.9 + 0.1 * fbm(rng, size))
    mid = size / 2 + 6 * np.sin(x / 20.0)                # o rasgo ondula
    gap = np.abs(y - mid) < 12
    zig = np.abs((x % 32) - 16)                           # dentes de 32 px
    teeth = (np.abs(y - mid) >= 12) & (np.abs(y - mid) < 12 + 16 - zig)
    drip = (blocks(rng, 1, 32, size)[0] > 0.75)[None, :] & (y > mid) & (y < mid + 24 + 40 * blocks(rng, 1, 32, size))
    rgb = mix(rgb, INK, (gap | (drip & ~teeth)).astype(np.float32))
    return mix(rgb, (240, 232, 210), teeth.astype(np.float32))


def semrosto_estatica(rng, size=128):
    # TV fora do ar visto de longe: blocos grandes preto/branco, faixas de varredura e a
    # imagem rasgada na horizontal. Quase nada de cinza. Vale em qualquer ponto (a
    # balaclava vanilla é um tricô uniforme: o layout não mostra onde fica o rosto).
    b = (blocks(rng, 16, 8, size) > 0.45).astype(np.float32)   # 16×8 px, mais branco
    rows = size // 8
    shift = (rng.integers(-3, 4, rows) * 8)               # cada faixa de 8 px escorrega
    for r in range(rows):
        b[r * 8:(r + 1) * 8] = np.roll(b[r * 8:(r + 1) * 8], int(shift[r]), axis=1)
    band = rng.random(rows)
    for r in range(rows):
        if band[r] > 0.82:
            b[r * 8:r * 8 + 4] = 1.0                      # faixa de varredura branca
        elif band[r] < 0.12:
            b[r * 8:r * 8 + 3] = 0.0                      # faixa preta
    v = 0.05 + 0.92 * b
    return color((255, 255, 255), v)


def carpideira_cabelo(rng, size=128):
    # preto de piche caindo, poucas mechas brancas largas que ondulam
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    rgb = color(INK, np.ones((size, size), np.float32))
    k = np.zeros((size, size), np.float32)
    for cx, w in zip((np.asarray((0.15, 0.5, 0.82)) + 0.08 * rng.random(3)) * size, (2.0, 3.0, 4.0)):
        wob = 8.0 * np.sin(y / (10.0 + cx / 8) + cx)
        k = np.maximum(k, (np.abs(x - cx - wob) < w).astype(np.float32))
    return mix(rgb, (226, 226, 226), k)


def eco_ash(rng, size, base):
    # quase branco, salpico escuro em manchas: gente feita de fumaça e cinza
    rgb = color(base, 0.95 + 0.05 * fbm(rng, size))
    speck = (fbm(rng, size, (size // 16, size // 8), (0.7, 0.3)) > 0.66).astype(np.float32)
    return mix(rgb, (40, 40, 44), speck)


def eco_cinza(rng, size=256):
    return eco_ash(rng, size, (238, 238, 242))


def eco_veu(rng, size=128):
    return eco_ash(rng, size, (244, 244, 248))


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
