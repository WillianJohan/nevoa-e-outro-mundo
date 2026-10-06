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
  NOM/NOM_EstaladorVenda.png     128  atadura em faixas branco-sujas, dois arames farpados ferrugem, sangue seco (óculos de esqui)
  NOM/NOM_CorredorBoca.png       128  vermelho escuro, rasgo preto com dentes brancos (máscara cirúrgica)
  NOM/NOM_SemRostoEstatica.png   128  chiado de TV em blocos preto/branco e faixas rasgadas (balaclava inteira)
  NOM/NOM_CarpideiraCabelo.png   128  cabelo preto de piche com três mechas brancas (véu)
  NOM/NOM_EcoCinza.png           256  quase branco, salpicos pequenos e escorridos finos de cinza (camada sem modelo)
  NOM/NOM_EcoVeu.png             128  o mesmo, mais escuro nas bordas (véu)
  NOM/NOM_Brasa.png              256  carvão quase preto em placas, rachaduras largas em brasa laranja (casca Hazmat, sprint 0022)

Efeitos de tela (sprint 0013), branco com alfa (a cor sai do desenho):
  NOM/ScreenFx/NOM_Grain1..4.png 256  grão de filme em blocos de 2 px, um quadro cada
  NOM/ScreenFx/NOM_Vignette.png  512  vinheta: alfa 0 no centro, sobe pras bordas
  NOM/ScreenFx/NOM_Lines.png     512×256  linhas horizontais de chiado, falhadas
  NOM/ScreenFx/NOM_White.png     8    branco opaco (o pulso do grito, tingido de vermelho)

Estática da névoa (sprint 0034), tons de cinza com alfa, tingida pela cor da névoa:
  NOM/ScreenFx/NOM_NevoaEstatica.png 256  chiado fino de 1 px com riscos curtos, fecha em mosaico

Lascas do Outro Mundo (sprint 0035), fundo transparente, tingidas pela cor da névoa no desenho:
  NOM/NOM_Lascas.png             256×96  sprite sheet: 8 quadros de giro × 3 formatos de lasca
                                         (tinta escura, borda clara ou ferrugem; verso ferrugem)
  NOM/NOM_Cinza.png              16   ponto de cinza claro e macio, tons de cinza

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
    k = np.maximum(k, (fbm(rng, size, (3, 6), (0.7, 0.3)) > 0.8).astype(np.float32))   # onde esfregou
    # fuligem debaixo dos olhos: o rosto da pele de zumbi vanilla fica no alto e no meio
    # (M e F iguais, visto pelo layout: rosto em x 44–56%, olhos em x ~47% e ~53%,
    # y ~12%). Uma mancha por olho que escorre até ~24%.
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    for ex in (0.47, 0.53):
        eye = (np.abs(xx - ex) < 0.022) & (yy > 0.11) & (yy < 0.17 + 0.07 * (np.abs(xx - ex) < 0.008))
        k = np.maximum(k, eye.astype(np.float32))
    return mix(rgb, INK, k)


def estalador_venda(rng, size=128):
    # atadura: faixas horizontais branco-sujas com frestas escuras entre elas, dois
    # arames ferrugem-escuros enrolados de lado a lado (linha ondulada com farpas) e uma
    # mancha de sangue seco. Nada de grade em diagonal (lia como toalha de piquenique).
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    rgb = color((236, 228, 206), 0.94 + 0.06 * fbm(rng, size))
    rgb = mix(rgb, (58, 44, 34), ((y % 24) < 5).astype(np.float32))      # fresta entre faixas
    stain = (fbm(rng, size, (3, 6), (0.7, 0.3)) > 0.76).astype(np.float32)   # uma mancha só
    rgb = mix(rgb, (104, 22, 18), stain * 0.9)                           # sangue seco
    wire = np.zeros((size, size), np.float32)
    for row, phase in ((38, 0.0), (90, 2.0)):
        wy = row + 7 * np.sin(x / 9.0 + phase)                           # o arame enrolando
        wire = np.maximum(wire, (np.abs(y - wy) < 3.5).astype(np.float32))
        barb = ((x + 4 * phase) % 14 < 2.5) & (np.abs(y - wy) < 8)       # farpas
        wire = np.maximum(wire, barb.astype(np.float32))
    return mix(rgb, (92, 40, 16), wire)                                  # ferrugem escura


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


# O Eco fica fora da regra das formas grandes: lê por ser muito mais claro que qualquer
# outro zumbi. Mancha grande preta no corpo todo virou couro de vaca (prévia da 0014).
def eco_ash(rng, size, base, edge):
    # quase branco; salpicos pequenos de cinza escura, esparsos, e poucos escorridos
    # finos na vertical (fumaça subindo, cinza escorrendo); edge escurece as bordas
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    border = np.clip(1 - np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y)) / 0.2, 0, 1)
    rgb = color(base, (0.96 + 0.04 * fbm(rng, size)) * (1 - edge * border))
    speck = np.kron((rng.random((size // 2, size // 2)) > 0.975).astype(np.float32), np.ones((2, 2), np.float32))
    cols = np.repeat(rng.random(size // 2) > 0.96, 2)                    # escorridos de 2 px
    top, length = np.repeat(rng.random(size // 2), 2), np.repeat(0.2 + 0.4 * rng.random(size // 2), 2)
    drip = cols[None, :] & (y > top[None, :]) & (y < (top + length)[None, :])
    k = np.maximum(speck, drip.astype(np.float32))
    return mix(rgb, (52, 50, 54), k)


def eco_cinza(rng, size=256):
    return eco_ash(rng, size, (240, 240, 244), 0.0)


def eco_veu(rng, size=128):
    return eco_ash(rng, size, (246, 246, 250), 0.22)                     # borda do véu mais escura


def ember_shell(rng, size=256):
    # casca de brasa da mutação (sprint 0022): carvão quase preto em placas grandes,
    # rachaduras largas em laranja de brasa com o miolo amarelado. Vista só por ~1 s, queimando
    # (o shader soma a borda laranja): tem de ler como "o corpo inteiro em brasa", não como roupa.
    rgb = color((34, 26, 22), 0.85 + 0.3 * fbm(rng, size))             # carvão
    # placas por grade com jitter (pontos sorteados soltos encostam e abrem leques de brasa)
    g = 5
    pts = (np.stack(np.mgrid[0:g, 0:g], -1).reshape(-1, 2) + 0.2 + 0.6 * rng.random((g * g, 2))) * size / g
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sort(np.stack([np.hypot(x - px, y - py) for py, px in pts]), axis=0)
    c = d[1] - d[0]
    glow = np.clip((7.0 - c) / 3.0, 0, 1)                                # rachadura de ~10 px
    rgb = mix(rgb, (255, 112, 20), glow)                                 # brasa
    return mix(rgb, (255, 214, 120), np.clip((3.0 - c) / 1.5, 0, 1))    # miolo quente


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


def screen_static(rng, size=256):
    # estática da névoa (sprint 0034): chiado fino de TV fora do ar, em tons de cinza (a cor
    # da névoa sai do desenho). Grão de 1 px e riscos horizontais curtos; os riscos dão a volta
    # na borda, então fecha em mosaico. O contrário do Sem-rosto: nada que se leia de longe.
    v = rng.random((size, size)).astype(np.float32)
    streak = np.zeros((size, size), np.float32)
    for _ in range(size * 3):
        r, x0, n = rng.integers(0, size), rng.integers(0, size), rng.integers(4, 24)
        streak[r, (x0 + np.arange(n)) % size] = 0.6 + 0.4 * rng.random()
    v = np.maximum(v, streak)
    a = np.clip(v ** 1.6, 0, 1)
    return color((255, 255, 255), 0.35 + 0.65 * v), a


FLAKE_CELL, FLAKE_FRAMES, FLAKE_SHAPES = 32, 8, 3   # = shared/NOM_FlakeRules.lua
PAINT, PAINT_EDGE = (52, 49, 46), (228, 220, 202)    # tinta velha escura, borda descascada clara
RUST, RUST_DARK = (150, 70, 30), (82, 38, 18)        # o verso da lasca, ferrugem


def flake_outline(rng):
    """Polígono irregular de 6 a 8 pontas em volta da origem, raio ~1 (lasca de tinta)."""
    n = int(rng.integers(6, 9))
    ang = np.sort(rng.random(n) * 2 * np.pi)
    rad = 0.55 + 0.45 * rng.random(n)
    return np.stack([np.cos(ang) * rad, np.sin(ang) * rad], 1)


def flake_cell(pts, frame, axis, edge, ss=4):
    """Um quadro do giro: a lasca tomba em volta de axis (largura × cos) e roda no plano.
    Frente: tinta escura com a borda edge; verso (cos < 0): ferrugem com a borda mais escura."""
    from PIL import ImageDraw
    phi = 2 * np.pi * frame / FLAKE_FRAMES                    # tombo: uma volta inteira
    spin = np.pi * frame / FLAKE_FRAMES                       # e meia volta no plano
    c, s = np.cos(axis), np.sin(axis)
    local = pts @ np.array([[c, -s], [s, c]])                 # eixo do tombo no x
    local[:, 1] *= max(abs(np.cos(phi)), 0.18)                # de lado vira um risco fino
    rot = np.array([[np.cos(spin), np.sin(spin)], [-np.sin(spin), np.cos(spin)]])
    p = (local @ rot) * (FLAKE_CELL / 2 - 3) + FLAKE_CELL / 2
    big = FLAKE_CELL * ss
    front = np.cos(phi) >= 0
    body, rim = (PAINT, edge) if front else (RUST, RUST_DARK)
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    poly = [tuple(v) for v in p * ss]
    d.polygon(poly, fill=rim + (255,))
    # o corpo é o polígono encolhido pro centro: sobra a borda de ~2 px
    mid = p.mean(axis=0)
    inner = [tuple(v) for v in (mid + (p - mid) * 0.72) * ss]
    d.polygon(inner, fill=body + (255,))
    # média dos sub-pixels com alfa pré-multiplicado: a borda não escurece pelo fundo vazio
    small = img.convert("RGBa").resize((FLAKE_CELL, FLAKE_CELL), Image.BOX).convert("RGBA")
    a = np.asarray(small, np.float32)
    a[[0, -1], :, 3] = 0
    a[:, [0, -1], 3] = 0
    return a


def flake_sheet(rng):
    # lascas de tinta (sprint 0035, Silent Hill): FLAKE_SHAPES formatos × FLAKE_FRAMES quadros de
    # giro. Borda clara de tinta descascada nos dois primeiros, ferrugem no terceiro; o verso de
    # todas é ferrugem. A cor da névoa multiplica no desenho (NOM_FlakeRules.palette).
    rows = []
    for shape in range(FLAKE_SHAPES):
        pts = flake_outline(rng)
        axis = rng.random() * np.pi
        edge = PAINT_EDGE if shape < 2 else (176, 92, 44)
        rows.append(np.concatenate([flake_cell(pts, f, axis, edge) for f in range(FLAKE_FRAMES)], 1))
    a = np.concatenate(rows, 0)
    return a[..., :3], a[..., 3] / 255


def ash_dot(size=16):
    # cinza (sprint 0035): ponto claro e macio, tons de cinza (a cor sai do desenho)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.hypot(x - (size - 1) / 2, y - (size - 1) / 2) / (size / 2 - 1)
    a = np.clip(1.25 - d * 1.25, 0, 1) ** 1.2
    a[d >= 1] = 0
    return color((236, 236, 236), np.ones((size, size), np.float32)), a


def main():
    # um gerador por textura: mexer no desenho de uma não sorteia as outras de novo
    def rng(i):
        return np.random.default_rng((SEED, i))
    save(estalador_skin(rng(1)), "Body/NOM_Estalador.png")
    save(corredor_skin(rng(2)), "Body/NOM_Corredor.png")
    save(carpideira_skin(rng(3)), "Body/NOM_Carpideira.png")
    save(estalador_venda(rng(4)), "NOM/NOM_EstaladorVenda.png")
    save(corredor_boca(rng(5)), "NOM/NOM_CorredorBoca.png")
    save(semrosto_estatica(rng(6)), "NOM/NOM_SemRostoEstatica.png")
    save(carpideira_cabelo(rng(7)), "NOM/NOM_CarpideiraCabelo.png")
    # camada no corpo todo, como o Gown_Hospital vanilla (RGBA): opaca, cobre a pele
    save(eco_cinza(rng(8)), "NOM/NOM_EcoCinza.png", alpha=np.ones((256, 256), np.float32))
    save(eco_veu(rng(9)), "NOM/NOM_EcoVeu.png")
    # casca de brasa: corpo inteiro (malha Hazmat), opaca como a cinza
    save(ember_shell(rng(10)), "NOM/NOM_Brasa.png", alpha=np.ones((256, 256), np.float32))
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
    # estática da névoa: gerador próprio, pra não mudar as de cima
    rgb, a = screen_static(np.random.default_rng((SEED, 14)))
    save(rgb, "NOM/ScreenFx/NOM_NevoaEstatica.png", alpha=a)
    # lascas e cinza do Outro Mundo (sprint 0035): gerador próprio
    rgb, a = flake_sheet(np.random.default_rng((SEED, 15)))
    save(rgb, "NOM/NOM_Lascas.png", alpha=a)
    rgb, a = ash_dot()
    save(rgb, "NOM/NOM_Cinza.png", alpha=a)


if __name__ == "__main__":
    main()
