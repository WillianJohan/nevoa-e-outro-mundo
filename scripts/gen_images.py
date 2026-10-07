#!/usr/bin/env python3
"""Gera as imagens do mod a partir da arte de lançamento do Johan (ADR-019).

A arte é do Johan, por decisão dele (AGENTS.md, 2026-10-06); este script só
redimensiona, separa as cores e tinge. As fontes ficam reduzidas em docs/art/:

  docs/art/NOM_Post.png             768x768   pôster (parede descascando, "NOISE OF MIST")
  docs/art/NOM_Preview_Cinza.png    768x768   preview cinza do Workshop
  docs/art/NOM_Preview_Vermelha.png 768x768   preview vermelha (pôster de staging)
  docs/art/NOM_Icon.png             768x768   "NOM" enferrujado
  docs/art/NOM_Banner.png          1280x720   banner do README e da descrição do Workshop

Saída (oficial: o repo e o build-workshop.sh só usam estas):
  mod/42/poster.png          512x512  painel de info do mod (mod.info poster=)
  mod/42/icon.png             64x64   lista de mods (mod.info icon=)
  docs/workshop/preview.png  512x512  item no Workshop (o jogo exige PNG quadrado de
                                      256 ou 512, até 1 024 000 bytes)
  mod2/42/poster.png, mod3/42/poster.png  512x512  o pôster com as cores separadas
  mod2/42/icon.png, mod3/42/icon.png       64x64   o ícone com as cores separadas

Saída de staging (só a cópia do scripts/dev-sync.sh usa; nunca em mod*/42/):
  docs/art/staging/poster.png 512x512  a preview vermelha
  docs/art/staging/icon.png    64x64   o ícone oficial avermelhado

Uso:
  python3 scripts/gen_images.py                    # gera as saídas a partir de docs/art/
  python3 scripts/gen_images.py --importar DIR     # reduz os originais de DIR pra docs/art/ antes
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
ART = os.path.join(ROOT, "docs", "art")
# original do Johan -> fonte reduzida em docs/art/, largura máxima
SOURCES = {
    "NOM_Post.png": ("NOM_Post.png", 768),
    "NOM_Preview_2.png": ("NOM_Preview_Cinza.png", 768),
    "NOM_Preview_ 1.png": ("NOM_Preview_Vermelha.png", 768),
    "NOM_Icon.png": ("NOM_Icon.png", 768),
    "NOM_Banner.png": ("NOM_Banner.png", 1280),
}


def save(img, *path):
    out = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out, optimize=True)
    print(f"{os.path.relpath(out, ROOT)}: {img.width}x{img.height}, {os.path.getsize(out)} bytes")


def resized(img, width):
    height = round(img.height * width / img.width)
    return img.resize((width, height), Image.LANCZOS)


def importar(src_dir):
    for original, (name, width) in SOURCES.items():
        img = Image.open(os.path.join(src_dir, original)).convert("RGB")
        save(resized(img, min(width, img.width)), "docs", "art", name)


def art(name, size):
    return resized(Image.open(os.path.join(ART, name)).convert("RGB"), size)


def split_colors(img, shift):
    """Aberração cromática: vermelho pra um lado, azul pro outro (o que o shader do mod2 faz)."""
    r, g, b = img.split()
    w, h = img.size
    r = r.transform((w, h), Image.AFFINE, (1, 0, -shift, 0, 1, 0), Image.BILINEAR)
    b = b.transform((w, h), Image.AFFINE, (1, 0, shift, 0, 1, 0), Image.BILINEAR)
    return Image.merge("RGB", (r, g, b))


def reddened(img):
    """Tinge pela luminância numa rampa vermelha: preto continua preto, o claro vira vermelho vivo."""
    rgb = np.asarray(img, np.float32) / 255
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    red = np.stack([np.clip(lum * 1.35, 0, 1), lum * 0.28, lum * 0.24], axis=-1)
    return Image.fromarray((red * 255 + 0.5).astype(np.uint8), "RGB")


def main():
    args = sys.argv[1:]
    if args[:1] == ["--importar"] and len(args) == 2:
        importar(args[1])
    elif args:
        sys.exit(__doc__)

    poster, icon = art("NOM_Post.png", 512), art("NOM_Icon.png", 64)
    save(poster, "mod", "42", "poster.png")
    save(icon, "mod", "42", "icon.png")
    save(art("NOM_Preview_Cinza.png", 512), "docs", "workshop", "preview.png")
    for mod in ("mod2", "mod3"):
        save(split_colors(poster, 2), mod, "42", "poster.png")
        save(split_colors(icon, 1), mod, "42", "icon.png")
    save(art("NOM_Preview_Vermelha.png", 512), "docs", "art", "staging", "poster.png")
    save(reddened(icon), "docs", "art", "staging", "icon.png")


if __name__ == "__main__":
    main()
