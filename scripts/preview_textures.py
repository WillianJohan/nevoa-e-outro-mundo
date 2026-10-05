#!/usr/bin/env python3
"""Folha de contato das texturas do visual dos monstros, no tamanho do jogo (sprint 0014).

Cada textura reduzida a 64 px (mais ou menos o que a peça ocupa na tela no zoom normal),
ao lado de uma cópia com metade do brilho e tom vermelho: o que sobra dela debaixo da
névoa (ADR-008/010 cortam 30–50% do brilho; a vermelha puxa pro vermelho). Se o desenho
some na cópia escura, ele não lê no jogo.

Uso: python3 scripts/preview_textures.py
Saída: docs/sprints/sprint-0014-contraste-visual/preview.png
"""
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
TEX = os.path.join(ROOT, "mod", "42", "media", "textures")
OUT = os.path.join(ROOT, "docs", "sprints", "sprint-0014-contraste-visual", "preview.png")

TEXTURES = [
    "NOM/NOM_SemRostoEstatica.png",
    "Body/NOM_Estalador.png",
    "NOM/NOM_EstaladorVenda.png",
    "Body/NOM_Corredor.png",
    "NOM/NOM_CorredorBoca.png",
    "Body/NOM_Carpideira.png",
    "NOM/NOM_CarpideiraCabelo.png",
    "NOM/NOM_EcoCinza.png",
    "NOM/NOM_EcoVeu.png",
]
FOG = np.asarray((0.62, 0.32, 0.32), np.float32)  # metade do brilho, puxado pro vermelho
CELL, PAD, LABEL = 64, 8, 12


def main():
    w = PAD + 2 * (CELL + PAD)
    sheet = Image.new("RGB", (w * 3, PAD + 3 * (CELL + LABEL + PAD)), (24, 20, 20))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(TEXTURES):
        x0, y0 = (i % 3) * w, PAD + (i // 3) * (CELL + LABEL + PAD)
        small = Image.open(os.path.join(TEX, name)).convert("RGB").resize((CELL, CELL), Image.BOX)
        fog = Image.fromarray((np.asarray(small, np.float32) * FOG).astype(np.uint8))
        sheet.paste(small, (x0 + PAD, y0 + LABEL))
        sheet.paste(fog, (x0 + 2 * PAD + CELL, y0 + LABEL))
        draw.text((x0 + PAD, y0), os.path.basename(name)[4:-4], fill=(220, 220, 220))
    sheet.save(OUT, optimize=True)
    print("ok", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
