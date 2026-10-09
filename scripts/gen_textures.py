#!/usr/bin/env python3
"""Gera as texturas do visual dos monstros (sprint 0012), procedurais e originais.

Cada textura veste um modelo VANILLA citado por nome (nada do jogo é copiado; da
textura vanilla só se usa o tamanho e, na pele, onde fica o rosto). Os desenhos não
dependem do mapa UV do modelo: padrões que valem em qualquer ponto (rachadura, veia,
chiado, fio), então a peça inteira vira o material. Contraste cheio e formas grandes
(sprint 0014): a 0012 tinha ruído fino que virava "lã" no jogo. Direção de arte em
docs/gdd/art-direction.md; prévia em scripts/preview_textures.py.

Saída (mod/42/media/textures/):
  Body/NOM_Estalador.png         256  The Pale: cera legível com midtones, rachadura suave (0060)
  Body/NOM_Corredor.png          256  The Misaligned: pele clara, veias/sombra suaves assimétricas (0060)
  Body/NOM_Carpideira.png        256  Forgotten Patient: pele clínica fria legível (0060)
  Body/NOM_SemRosto.png          256  Wrong Person: pele cotidiana pálida sob a casca (0060)
  NOM/NOM_EstaladorVenda.png     128  atadura em faixas branco-sujas, dois arames farpados ferrugem, sangue seco (óculos de esqui)
  NOM/NOM_CorredorBoca.png       128  vermelho escuro, rasgo preto com dentes brancos (máscara cirúrgica)
  NOM/NOM_SemRostoEstatica.png   128  Wrong Person: vazios suaves + chiado residual (0060; sem P&B binário)
  NOM/NOM_CarpideiraCabelo.png   128  cabelo preto de piche com três mechas brancas (véu)
  NOM/NOM_CarpideiraManto.png    256  Distorted Silhouette: hospital desbotado orgânico, sem blocos/faixas (0054)
  NOM/NOM_EstaladorRoupa.png     256  roupa cotidiana suja (camada corpo, 0060)
  NOM/NOM_CorredorRoupa.png      256  roupa errada / assimétrica (camada corpo, 0060)
  NOM/NOM_SemRostoRoupa.png      256  roupa banal (jeans/camiseta suja, 0060)
  NOM/NOM_EcoCinza.png           256  quase branco, salpicos pequenos e escorridos finos de cinza (camada sem modelo)
  NOM/NOM_EcoVeu.png             128  o mesmo, mais escuro nas bordas (véu)
  NOM/NOM_Brasa.png              256  carvão quase preto em placas, rachaduras largas em brasa laranja (casca Hazmat, sprint 0022)
  Body/NOM_Ticao.png             256  carvão em placas pequenas, rachaduras finas de brasa apagando (Tição, sprint 0038)

Efeitos de tela (sprint 0013), branco com alfa (a cor sai do desenho):
  NOM/ScreenFx/NOM_Grain1..4.png 256  grão de filme em blocos de 2 px, um quadro cada
  NOM/ScreenFx/NOM_Vignette.png  512  vinheta: alfa 0 no centro, sobe pras bordas
  NOM/ScreenFx/NOM_Lines.png     512×256  linhas horizontais de chiado, falhadas
  NOM/ScreenFx/NOM_White.png     8    branco opaco (o pulso do grito, tingido de vermelho)

Estática da névoa (sprint 0034), tons de cinza com alfa, tingida pela cor da névoa:
  NOM/ScreenFx/NOM_NevoaEstatica.png 256  chiado fino de 1 px com riscos curtos, fecha em mosaico

Lascas do Outro Mundo (sprint 0035), fundo transparente, tingidas pela cor da névoa no desenho:
  NOM/NOM_Lascas.png             256×128 sprite sheet: 8 quadros de giro × 4 formatos de lasca
                                         (tinta velha suja, craquelê, fio de borda clara falhado,
                                         ferrugem marrom escamando; contorno serrilhado; verso ferrugem)
  NOM/NOM_Cinza.png              16   floco de cinza torto e macio, tons de cinza

Sonar do Estalador (sprint 0037), branco com alfa, tingido e achatado no desenho:
  NOM/ScreenFx/NOM_SonarAnel.png 256  anel fino em r = 0,9 com rastro macio pra dentro e falhas suaves

Semente fixa: rodar de novo dá os mesmos bytes. Uso: python3 scripts/gen_textures.py
"""
import os

import numpy as np
from PIL import Image

SEED = 1203  # texturas legadas byte-iguais; só pele/manto/estática mudam (0054)
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media", "textures")
BLOOD = (90, 4, 8)       # sangue bem saturado (contraste 0014: pouco cinza médio)
GRIME = (18, 14, 12)     # sujeira quase preta


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
    # Não regrava se os pixels já batem: o optimize do Pillow muda os bytes do PNG
    # sem mudar a imagem e quebrava look_assets_deterministic / screenfx_assets_deterministic.
    if os.path.isfile(full):
        old = Image.open(full).convert(img.mode)
        if old.size == img.size and np.array_equal(np.asarray(old), np.asarray(img)):
            print("ok", path, "(igual)")
            return
    img.save(full, optimize=True)
    print("ok", path)


# Contraste (sprint 0014): no jogo o zumbi tem ~1–2 m de tela na câmera isométrica e a
# névoa corta 30–50% do brilho. Ruído fino e cinza médio viram "lã". Então: quase preto e
# quase branco, formas de 1/8 da largura pra cima, poucas cores, brilho puxado pra cima.
# tests/test_look_contrast.py mede cada textura.
INK = (14, 12, 12)          # o preto de todo desenho
WAX = (248, 244, 236)       # pele de cera (The Pale)
CLINIC = (236, 238, 232)    # hospital frio (Forgotten Patient)


def mix(rgb, ink, k):
    """Pinta ink por cima de rgb com cobertura k (H×W, 0..1)."""
    return rgb * (1 - k[..., None]) + np.asarray(ink, np.float32) * k[..., None]


def blocks(rng, rows, cols, size):
    """Grade rows×cols de 0..1 ampliada sem suavizar pra size×size (blocos de borda dura)."""
    return np.kron(rng.random((rows, cols)).astype(np.float32), np.ones((size // rows, size // cols), np.float32))


def face_hollows(size, left=(0.46, 0.125), right=(0.545, 0.12), rx=0.028, ry=0.038):
    """Órbitas na UV da pele de zumbi (olhos ~47%/53%, y~12%). Assimetria de propósito."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    k = np.zeros((size, size), np.float32)
    for (ex, ey), srx, sry in ((left, rx, ry), (right, rx * 0.85, ry * 1.15)):
        eye = ((xx - ex) / srx) ** 2 + ((yy - ey) / sry) ** 2
        k = np.maximum(k, np.clip(1.15 - eye, 0, 1))
    return k


def soft_flesh(rng, size, base):
    """Pele legível com midtones (0060): shade amplo (não só branco), sem P&B binário."""
    # 0.55..0.95 → luminância cai no intervalo mid (0,3–0,7) em boa parte da UV
    shade = 0.55 + 0.40 * fbm(rng, size, (2, 5, 11), (0.55, 0.30, 0.15))
    return color(base, shade)


def estalador_skin(rng, size=256):
    # The Pale (0060): cera legível — rachadura e órbitas em marrom-suave, não grade P&B.
    rgb = soft_flesh(rng, size, WAX)
    c = cracks(rng, size, 12)
    k = np.clip((4.2 - c) / 3.2, 0, 1) * 0.45
    fine = cracks(rng, size, 28)
    k = np.maximum(k, np.clip((1.6 - fine) / 1.4, 0, 1) * 0.22 * (noise(rng, size, 4) > 0.50))
    mott = np.clip((fbm(rng, size, (3, 5), (0.7, 0.3)) - 0.50) / 0.35, 0, 1) * 0.35
    k = np.maximum(k, mott)
    k = np.maximum(k, face_hollows(size, left=(0.455, 0.12), right=(0.55, 0.135)) * 0.55)
    return mix(rgb, (110, 85, 75), k)


def corredor_skin(rng, size=256):
    # The Misaligned (0060): pele clara + veias/sombra assimétricas em rampa (não binário).
    rgb = soft_flesh(rng, size, (232, 220, 208))
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    side = np.clip((0.50 - xx) / 0.18, 0, 1) * (0.40 + 0.50 * fbm(rng, size, (2, 4), (0.75, 0.25)))
    k = side * 0.65
    for cells, width in ((3, 0.06), (5, 0.04), (8, 0.028)):
        v = fbm(rng, size, (cells, cells * 2), (0.8, 0.2))
        vein = np.clip(1.0 - np.abs(v - 0.5) / width, 0, 1) * np.clip((xx - 0.28) / 0.2, 0, 1)
        k = np.maximum(k, vein * 0.50)
    hollow = face_hollows(size, left=(0.44, 0.13), right=(0.56, 0.11), rx=0.032, ry=0.042)
    k = np.maximum(k, hollow * 0.55)
    return mix(rgb, (90, 60, 65), k)


def carpideira_skin(rng, size=256):
    # Forgotten Patient (0060): pele clínica fria legível; órbitas e manchas em midtones.
    rgb = soft_flesh(rng, size, CLINIC)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    k = face_hollows(size, left=(0.47, 0.122), right=(0.535, 0.128), rx=0.032, ry=0.048) * 0.60
    for ex, w, stop in ((0.47, 0.018, 0.34), (0.535, 0.016, 0.40), (0.50, 0.012, 0.26)):
        drip = (np.abs(xx - ex) < w) & (yy > 0.11) & (yy < stop)
        k = np.maximum(k, drip.astype(np.float32) * 0.45)
    blot = np.clip((fbm(rng, size, (2, 4), (0.7, 0.3)) - 0.48) / 0.35, 0, 1) * 0.40
    k = np.maximum(k, blot)
    plaque = np.clip(1.0 - (((xx - 0.72) / 0.20) ** 2 + ((yy - 0.55) / 0.24) ** 2), 0, 1)
    k = np.maximum(k, plaque * 0.45)
    return mix(rgb, (85, 95, 88), k)


def semrosto_skin(rng, size=256):
    # Wrong Person (0060): pele cotidiana pálida sob a casca — parece gente, não UV.
    rgb = soft_flesh(rng, size, (220, 198, 180))
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    flush = np.clip((fbm(rng, size, (2, 4), (0.7, 0.3)) - 0.40) / 0.4, 0, 1) * 0.35
    rgb = mix(rgb, (175, 120, 110), flush)
    # frente clara + sombra no torso: puxa fora do mid-cinza puro (anti-lã 0014)
    highlight = np.clip(1.0 - np.hypot(xx - 0.5, yy - 0.22) / 0.28, 0, 1) * 0.85
    rgb = mix(rgb, (250, 240, 228), highlight)
    shadow = np.clip((yy - 0.40) / 0.45, 0, 1) * (0.55 + 0.40 * fbm(rng, size, (3, 5), (0.6, 0.4)))
    return mix(rgb, (55, 42, 38), shadow)


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


def cloth_body(rng, size, base, stain, accent=None, accent_side=None):
    """Tecido de roupa cotidiana (0060): fibra + manchas grandes; sem grade/faixa wrap."""
    weave = 0.70 + 0.30 * fbm(rng, size, (3, 7, 14), (0.5, 0.3, 0.2))
    rgb = color(base, weave)
    dirt = np.clip((fbm(rng, size, (2, 3, 5), (0.55, 0.3, 0.15)) - 0.42) / 0.40, 0, 1)
    rgb = mix(rgb, stain, dirt * 0.70)
    if accent is not None and accent_side is not None:
        yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
        side = np.clip((accent_side - xx) / 0.35, 0, 1) if accent_side < 0.5 else np.clip((xx - accent_side) / 0.35, 0, 1)
        rgb = mix(rgb, accent, side * (0.55 + 0.30 * fbm(rng, size, (3, 5), (0.7, 0.3))))
    c = cracks(rng, size, 8)
    wear = np.clip((5.0 - c) / 3.0, 0, 1) * 0.40
    return mix(rgb, (36, 30, 26), wear)


def estalador_roupa(rng, size=256):
    # camisa bege suja / calça marrom — pessoa comum errada
    return cloth_body(rng, size, (168, 152, 128), (72, 58, 42))


def corredor_roupa(rng, size=256):
    # metade tom errado (roupa “trocada”) — Misaligned no tecido; contraste alto de longe
    rgb = cloth_body(rng, size, (110, 118, 132), (36, 30, 28), accent=(160, 70, 60), accent_side=0.40)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    patch = np.clip(1.0 - (((xx - 0.28) / 0.25) ** 2 + ((yy - 0.52) / 0.32) ** 2), 0, 1)
    rgb = mix(rgb, (18, 16, 14), patch * 0.90)
    light = np.clip(1.0 - (((xx - 0.72) / 0.20) ** 2 + ((yy - 0.35) / 0.22) ** 2), 0, 1)
    return mix(rgb, (200, 190, 175), light * 0.55)


def semrosto_roupa(rng, size=256):
    # jeans + camiseta desbotada — Wrong Person vestido de gente
    return cloth_body(rng, size, (78, 92, 118), (50, 44, 40), accent=(180, 176, 168), accent_side=0.55)


def semrosto_estatica(rng, size=128):
    # Wrong Person (0060): casca com vazios suaves e chiado residual — não P&B binário.
    # Mantém contraste alto o bastante pra ler de longe (0014), mas com midtones.
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    b = 0.72 + 0.18 * fbm(rng, size, (3, 6, 12), (0.5, 0.3, 0.2))
    blot = np.clip((0.52 - fbm(rng, size, (3, 5, 9), (0.55, 0.3, 0.15))) / 0.35, 0, 1)
    b = b * (1 - blot * 0.85)
    eye = ((xx - 0.36) / 0.14) ** 2 + ((yy - 0.40) / 0.12) ** 2
    b = b * (1 - np.clip(1.05 - eye, 0, 1) * 0.90)
    band = np.clip(1.0 - np.abs(yy - 0.70) / 0.09, 0, 1) * np.clip(
        (fbm(rng, size, (2, 3), (0.8, 0.2)) - 0.25) / 0.5, 0, 1)
    b = b * (1 - band * 0.75)
    # faixas de varredura claras (chiado residual), suaves
    rows = size // 16
    for r in range(rows):
        if rng.random() > 0.85:
            b[r * 16:r * 16 + 4] = np.maximum(b[r * 16:r * 16 + 4], 0.92)
    return color((255, 255, 255), b)


def carpideira_cabelo(rng, size=128):
    # preto de piche caindo, poucas mechas brancas largas que ondulam
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    rgb = color(INK, np.ones((size, size), np.float32))
    k = np.zeros((size, size), np.float32)
    for cx, w in zip((np.asarray((0.15, 0.5, 0.82)) + 0.08 * rng.random(3)) * size, (2.0, 3.0, 4.0)):
        wob = 8.0 * np.sin(y / (10.0 + cx / 8) + cx)
        k = np.maximum(k, (np.abs(x - cx - wob) < w).astype(np.float32))
    return mix(rgb, (226, 226, 226), k)


def carpideira_manto(rng, size=256):
    # Distorted Silhouette (0060): avental hospitalar com midtones de tecido — capuz escuro
    # orgânico. SEM blocos 8×8 / faixas (wrap). Menos binário que a 0054.
    tile = fbm(rng, size, (3, 5, 9), (0.55, 0.3, 0.15))
    light = np.clip((tile - 0.35) / 0.40, 0, 1)
    rgb = mix(color((42, 38, 36), np.ones((size, size), np.float32)), (220, 214, 200), light)
    clinic = np.clip((fbm(rng, size, (2, 4), (0.7, 0.3)) - 0.58) / 0.30, 0, 1)
    rgb = mix(rgb, (70, 86, 78), clinic * 0.40)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    hood = np.clip(1.0 - np.hypot(xx - 0.5, yy - 0.14) / 0.42, 0, 1)
    rgb = mix(rgb, (22, 18, 16), hood * 0.78)
    c = cracks(rng, size, 16)
    tear = np.clip((3.8 - c) / 2.2, 0, 1) * 0.45 * (noise(rng, size, 3) > 0.35)
    rgb = mix(rgb, (28, 24, 22), tear)
    stain = np.clip((fbm(rng, size, (4, 8), (0.65, 0.35)) - 0.62) / 0.28, 0, 1)
    return mix(rgb, (48, 40, 34), stain * 0.45)


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


def ticao_skin(rng, size=256):
    # Tição (sprint 0038): o corpo queimado da névoa preta. Carvão em placas menores que as da
    # casca (lê como pele, não como roupa) e rachaduras finas de brasa que apagam em vermelho
    # escuro em parte delas: no escuro, o que se vê de longe é a brasa.
    rgb = color((30, 24, 21), 0.8 + 0.4 * fbm(rng, size))
    g = 8
    pts = (np.stack(np.mgrid[0:g, 0:g], -1).reshape(-1, 2) + 0.2 + 0.6 * rng.random((g * g, 2))) * size / g
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sort(np.stack([np.hypot(x - px, y - py) for py, px in pts]), axis=0)
    c = d[1] - d[0]
    crack = np.clip((5.0 - c) / 2.0, 0, 1)
    hot = noise(rng, size, 4) > 0.45                                     # brasa viva ou apagada
    rgb = mix(rgb, (120, 22, 10), crack * ~hot)                          # brasa apagando
    rgb = mix(rgb, (255, 120, 24), crack * hot)                          # brasa viva
    return mix(rgb, (255, 210, 110), np.clip((2.0 - c) / 1.0, 0, 1) * hot)


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


def sonar_ring(size=256):
    # anel do sonar (0037→0053): bem mais suave — playtest: anéis brancos quebravam imersão.
    # Frente larga e fraca; alfa baixo. Com SCREEN_DRAW=false quase não é usado.
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2
    r = np.hypot(x - cx, y - cy) / (size / 2)
    th = np.arctan2(y - cy, x - cx)
    front = np.exp(-((r - 0.9) / 0.045) ** 2)
    wake = np.where(r < 0.9, np.exp(-((0.9 - r) / 0.18) ** 2) * 0.22, 0)
    gaps = 0.55 + 0.45 * np.sin(5 * th) * np.sin(2 * th + 0.8)
    a = np.clip((front + wake) * gaps * 0.35, 0, 1)
    a[r > 0.98] = 0
    return np.full((size, size, 3), 220, np.float32), a


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


FLAKE_CELL, FLAKE_FRAMES, FLAKE_SHAPES = 32, 8, 4   # = shared/NOM_FlakeRules.lua
FLAKE_SS = 4                  # sub-amostras por pixel em cada eixo (o alfa sai antisserrilhado)
FLAKE_GRID, FLAKE_SPAN = 192, 1.2   # textura no plano da lasca: GRID px cobrindo ±SPAN (raio 1)
FLAKE_THIN = 0.2              # de lado a lasca vira um risco de ~20% da largura
PAINT, GRIME = (64, 62, 56), (30, 28, 25)       # tinta velha escura e a sujeira por cima
PAINT_EDGE = (192, 188, 172)                   # a camada de tinta clara que aparece onde lascou
# ferrugem marrom, dessaturada (saturação ~0,5): laranja vivo vira adesivo
RUST, RUST_DARK, RUST_LIGHT = (110, 74, 56), (60, 42, 33), (140, 100, 74)
# formatos (linhas do sheet): achatamento, dentes arrancados, serrilhado, fração de borda clara,
# ferrugem comendo a tinta, frente de tinta ou de ferrugem
FLAKE_KINDS = (
    (0.85, 4, 0.14, 0.55, 0.30, "tinta"),      # tinta descascando, borda clara falhada
    (0.72, 4, 0.16, 0.0, 0.65, "tinta"),       # tinta suja, sem borda, ferrugem nas beiradas
    (0.92, 4, 0.16, 0.0, 0.0, "ferrugem"),     # escama de ferrugem dos dois lados
    (0.46, 3, 0.12, 0.6, 0.40, "tinta"),       # lasca comprida, borda clara de um lado só
)


def periodic(rng, th, cells):
    """Ruído 1D periódico em th (0..2π), linear entre pontos sorteados: dá ponta, não onda."""
    return np.interp(th, np.linspace(0, 2 * np.pi, cells, endpoint=False), rng.random(cells), period=2 * np.pi)


def polygon_radius(rng, th, n):
    """Raio por ângulo de um polígono torto de n pontas em volta da origem (fraturas retas)."""
    a = np.sort((np.arange(n) + 0.15 + 0.7 * rng.random(n)) / n * 2 * np.pi)
    rad = 0.42 + 0.58 * rng.random(n)
    rad[rng.integers(n)] = 0.3 + 0.12 * rng.random()          # sempre uma fratura reentrante
    p = np.stack([np.cos(a) * rad, np.sin(a) * rad], 1)
    i = (np.searchsorted(a, th) - 1) % n
    s, e = p[i], p[(i + 1) % n] - p[i]
    return (s[:, 0] * e[:, 1] - s[:, 1] * e[:, 0]) / (np.cos(th) * e[:, 1] - np.sin(th) * e[:, 0])


def flake_radius(rng, th, notches, jag):
    """Raio do contorno por ângulo, no máximo 1: polígono torto (a tinta quebra em linha reta),
    serrilhado (ruído linear) e dentes em V arrancados na borda, um deles fino e fundo (trinca)."""
    r = polygon_radius(rng, th, int(rng.integers(5, 9)))
    r = r * (1 + jag * (periodic(rng, th, 26) - 0.5) + 0.5 * jag * (periodic(rng, th, 64) - 0.5))
    for i in range(notches + 1):
        c = rng.random() * 2 * np.pi
        w, d = (0.05, 0.5) if i == notches else (0.12 + 0.25 * rng.random(), 0.1 + 0.25 * rng.random())
        dist = np.abs((th - c + np.pi) % (2 * np.pi) - np.pi)
        r -= d * np.clip(1 - dist / w, 0, 1)
    return np.maximum(r, 0.15) / r.max()


def flake_shape(rng, aspect, notches, jag):
    """Devolve inside(u, v) → (dentro, distância até a borda), no plano da lasca."""
    th_tab = np.linspace(0, 2 * np.pi, 1024, endpoint=False)
    r_tab = flake_radius(rng, th_tab, notches, jag)

    def inside(u, v):
        v = v / aspect
        rho = np.hypot(u, v)
        r = np.interp(np.arctan2(v, u) % (2 * np.pi), th_tab, r_tab, period=2 * np.pi)
        return rho < r, r - rho
    return inside, th_tab, r_tab


def rust_face(rng, g, dark):
    """Ferrugem escamando: tom variando em placas, grão fino, poros escuros e as camadas."""
    t = fbm(rng, g, (5, 13, 31), (0.5, 0.3, 0.2))
    k = np.clip(1.6 * (t - 0.5) + 0.5 + 0.35 * (noise(rng, g, 48) - 0.5), 0, 1)
    rgb = color(RUST_DARK, 1 - k) + color(RUST_LIGHT, k)
    rgb = mix(rgb, RUST, 0.35 * noise(rng, g, 9))
    rgb = mix(rgb, (40, 28, 22), 0.8 * np.clip((noise(rng, g, 30) - 0.74) / 0.08, 0, 1))      # poros
    rgb = mix(rgb, (48, 33, 26), 0.5 * (np.abs((t * 9) % 1 - 0.5) < 0.05))                    # escamas
    return rgb * (0.78 if dark else 1.0)


def paint_face(rng, g, edge, th_tab, rim, rust):
    """Tinta velha: manchada, grão fino, craquelê leve, ferrugem entrando pela beirada e, nos
    formatos com rim, um fio de tinta clara de ~1 px que falha ao longo do contorno."""
    rgb = color(PAINT, 0.8 + 0.3 * noise(rng, g, 10) + 0.25 * (noise(rng, g, 34) - 0.5))
    rgb = mix(rgb, GRIME, 0.75 * np.clip((fbm(rng, g, (3, 7), (0.7, 0.3)) - 0.52) / 0.16, 0, 1))
    crack = np.clip((4.0 - cracks(rng, g, 24)) / 2.0, 0, 1) * (noise(rng, g, 6) > 0.42)
    rgb = mix(rgb, GRIME, 0.6 * crack) * (0.85 + 0.3 * noise(rng, g, 48))[..., None]   # grão por cima de tudo
    if rust > 0:
        reach = rust * 0.6 * np.clip(2.2 * noise(rng, g, 7) - 0.8, 0, 1)   # entra só por alguns lados
        k = np.maximum(np.clip((reach - edge) / 0.05, 0, 1),
                       np.clip((noise(rng, g, 8) - (1 - 0.3 * rust)) / 0.06, 0, 1))
        rgb = mix(rgb, rust_face(rng, g, False), k)
    if rim > 0:
        on = np.clip((periodic(rng, th_tab, 15) - (1 - rim)) / 0.06, 0, 1)
        width = 0.06 + 0.07 * periodic(rng, th_tab, 9)
        return rgb, on, width
    return rgb, None, None


def bilinear(tex, u, v):
    """Amostra tex (GRID × GRID [× 3]) que cobre ±SPAN nos pontos (u, v) do plano da lasca."""
    n = tex.shape[0] - 1
    x = np.clip((u + FLAKE_SPAN) / (2 * FLAKE_SPAN) * n, 0, n - 1e-4)
    y = np.clip((v + FLAKE_SPAN) / (2 * FLAKE_SPAN) * n, 0, n - 1e-4)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    if tex.ndim == 3:
        fx, fy = fx[..., None], fy[..., None]
    top = tex[y0, x0] * (1 - fx) + tex[y0, x0 + 1] * fx
    bot = tex[y0 + 1, x0] * (1 - fx) + tex[y0 + 1, x0 + 1] * fx
    return top * (1 - fy) + bot * fy


def bleed(rgb, a, passes=2):
    """O RGB dos pixels vazios vira a média dos vizinhos com tinta: o filtro linear do jogo
    não puxa preto nem branco pra borda (sem halo)."""
    for _ in range(passes):
        pm, w = rgb * a[..., None], a.copy()
        pad_pm, pad_w = np.pad(pm, ((1, 1), (1, 1), (0, 0))), np.pad(w, 1)
        s_pm = sum(pad_pm[1 + dy:pad_pm.shape[0] - 1 + dy, 1 + dx:pad_pm.shape[1] - 1 + dx]
                   for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        s_w = sum(pad_w[1 + dy:pad_w.shape[0] - 1 + dy, 1 + dx:pad_w.shape[1] - 1 + dx]
                  for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        fill = (a == 0) & (s_w > 0)
        rgb[fill] = s_pm[fill] / s_w[fill][..., None]
        a = np.where(fill, 1e-6, a)
    return rgb


def flake_cell(look, frame, axis):
    """Um quadro do giro: a lasca tomba em volta de axis (uma volta em FRAMES quadros) e roda
    meia volta no plano. Cada sub-amostra da célula volta pro plano da lasca: forma exata,
    textura da frente ou do verso (espelhado) e luz pela inclinação (de perfil, mais escura)."""
    inside, front, back, rim_on, rim_w, th_tab = look
    phi = 2 * np.pi * frame / FLAKE_FRAMES
    spin = np.pi * frame / FLAKE_FRAMES
    c = np.cos(phi)
    squash = np.copysign(max(abs(c), FLAKE_THIN), c)
    n = FLAKE_CELL * FLAKE_SS
    sy, sx = (np.mgrid[0:n, 0:n].astype(np.float64) + 0.5) / FLAKE_SS - FLAKE_CELL / 2
    sx, sy = sx / (FLAKE_CELL / 2 - 3), sy / (FLAKE_CELL / 2 - 3)
    qx = np.cos(spin) * sx + np.sin(spin) * sy
    qy = (-np.sin(spin) * sx + np.cos(spin) * sy) / squash
    u = np.cos(axis) * qx - np.sin(axis) * qy
    v = np.sin(axis) * qx + np.cos(axis) * qy
    hit, edge = inside(u, v)
    rgb = bilinear(front if c >= 0 else back, u, v)
    if c >= 0 and rim_on is not None:
        th = np.arctan2(v, u) % (2 * np.pi)
        on = np.interp(th, th_tab, rim_on, period=2 * np.pi)
        w = np.interp(th, th_tab, rim_w, period=2 * np.pi)
        k = on * np.clip((w - edge) / 0.025, 0, 1)
        rgb = mix(rgb, PAINT_EDGE, 0.9 * k)
    light = (0.6 + 0.4 * abs(c)) * (1 + 0.15 * np.sin(phi) * np.clip(qy * abs(squash), -1, 1))
    rgb = rgb * light[..., None]
    m = hit.astype(np.float64)
    pm = (rgb * m[..., None]).reshape(FLAKE_CELL, FLAKE_SS, FLAKE_CELL, FLAKE_SS, 3).sum(axis=(1, 3))
    a = m.reshape(FLAKE_CELL, FLAKE_SS, FLAKE_CELL, FLAKE_SS).mean(axis=(1, 3))
    out = np.where(a[..., None] > 0, pm / np.maximum(a, 1e-9)[..., None] / FLAKE_SS ** 2, 0)
    out = bleed(out, a)
    a[[0, -1], :] = 0
    a[:, [0, -1]] = 0
    return out, a


def flake_sheet(rng):
    # lascas de tinta velha e ferrugem (sprint 0035, Silent Hill): FLAKE_SHAPES formatos ×
    # FLAKE_FRAMES quadros de giro, rasterizados no plano da lasca (FLAKE_KINDS). O verso das
    # de tinta é ferrugem; a cor da névoa multiplica no desenho (NOM_FlakeRules.palette).
    g = FLAKE_GRID
    gy, gx = np.mgrid[0:g, 0:g].astype(np.float64) / (g - 1) * 2 * FLAKE_SPAN - FLAKE_SPAN
    rows_rgb, rows_a = [], []
    for aspect, notches, jag, rim, rust, kind in FLAKE_KINDS:
        inside, th_tab, _ = flake_shape(rng, aspect, notches, jag)
        _, edge = inside(gx, gy)
        if kind == "tinta":
            front, rim_on, rim_w = paint_face(rng, g, edge, th_tab, rim, rust)
            back = mix(rust_face(rng, g, False), GRIME, np.full((g, g), 0.15))
        else:
            front, rim_on, rim_w = rust_face(rng, g, False), None, None
            back = rust_face(rng, g, True)
        # a comprida tomba pelo eixo maior: de lado ainda é um risco que se vê
        axis = rng.random() * 0.4 if aspect < 0.6 else rng.random() * np.pi
        look = (inside, front, back, rim_on, rim_w, th_tab)
        cells = [flake_cell(look, f, axis) for f in range(FLAKE_FRAMES)]
        rows_rgb.append(np.concatenate([c[0] for c in cells], 1))
        rows_a.append(np.concatenate([c[1] for c in cells], 1))
    return np.concatenate(rows_rgb, 0), np.concatenate(rows_a, 0)


def ash_flake(rng, size=16, ss=8):
    # cinza (sprint 0035): floco torto e macio, um pouco manchado, tons de cinza (a cor sai do
    # desenho). Não é redondo: harmônicos e serrilhado no raio, como a lasca, com borda suave.
    th_tab = np.linspace(0, 2 * np.pi, 512, endpoint=False)
    r = np.ones_like(th_tab)
    for k in range(2, 5):
        r += rng.normal(0, 0.2 / k) * np.cos(k * th_tab + rng.random() * 2 * np.pi)
    r += 0.25 * (periodic(rng, th_tab, 11) - 0.5)
    r = r / r.max() * (size / 2 - 2.2)
    n = size * ss
    y, x = (np.mgrid[0:n, 0:n].astype(np.float64) + 0.5) / ss - size / 2 - (rng.random(2) - 0.5)[:, None, None] * 0.6
    rho = np.hypot(x, y)
    edge = np.interp(np.arctan2(y, x) % (2 * np.pi), th_tab, r, period=2 * np.pi) - rho
    a = np.clip(edge / 1.8 + 0.25, 0, 1).reshape(size, ss, size, ss).mean(axis=(1, 3))
    a *= 0.72 + 0.28 * noise(rng, size, 5)
    shade = 0.84 + 0.12 * noise(rng, size, 6)
    return color((236, 236, 236), shade), a


def main():
    # um gerador por textura: mexer no desenho de uma não sorteia as outras de novo
    def rng(i):
        return np.random.default_rng((SEED, i))
    save(estalador_skin(rng(1)), "Body/NOM_Estalador.png")
    save(corredor_skin(rng(2)), "Body/NOM_Corredor.png")
    save(carpideira_skin(rng(3)), "Body/NOM_Carpideira.png")
    save(semrosto_skin(rng(22)), "Body/NOM_SemRosto.png")
    save(estalador_venda(rng(4)), "NOM/NOM_EstaladorVenda.png")
    save(corredor_boca(rng(5)), "NOM/NOM_CorredorBoca.png")
    save(semrosto_estatica(rng(6)), "NOM/NOM_SemRostoEstatica.png")
    save(carpideira_cabelo(rng(7)), "NOM/NOM_CarpideiraCabelo.png")
    # manto hospitalar desbotado (0054→0060 tecido legível; era wrap na 0052)
    save(carpideira_manto(rng(21)), "NOM/NOM_CarpideiraManto.png", alpha=np.ones((256, 256), np.float32))
    # roupas cotidianas no corpo (0060): cobrem a pele nuada pelo strip ADR-012
    opaque = np.ones((256, 256), np.float32)
    save(estalador_roupa(rng(23)), "NOM/NOM_EstaladorRoupa.png", alpha=opaque)
    save(corredor_roupa(rng(24)), "NOM/NOM_CorredorRoupa.png", alpha=opaque)
    save(semrosto_roupa(rng(25)), "NOM/NOM_SemRostoRoupa.png", alpha=opaque)
    # camada no corpo todo, como o Gown_Hospital vanilla (RGBA): opaca, cobre a pele
    save(eco_cinza(rng(8)), "NOM/NOM_EcoCinza.png", alpha=np.ones((256, 256), np.float32))
    save(eco_veu(rng(9)), "NOM/NOM_EcoVeu.png")
    # casca de brasa: corpo inteiro (malha Hazmat), opaca como a cinza
    save(ember_shell(rng(10)), "NOM/NOM_Brasa.png", alpha=np.ones((256, 256), np.float32))
    save(ticao_skin(rng(20)), "Body/NOM_Ticao.png")
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
    rgb, a = ash_flake(np.random.default_rng((SEED, 16)))
    save(rgb, "NOM/NOM_Cinza.png", alpha=a)
    # anel do sonar (sprint 0037): sem sorteio
    rgb, a = sonar_ring()
    save(rgb, "NOM/ScreenFx/NOM_SonarAnel.png", alpha=a)


if __name__ == "__main__":
    main()
