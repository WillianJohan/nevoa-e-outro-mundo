#!/usr/bin/env python3
"""Gera as imagens do mod de forma procedural (desenho original, nada copiado).

Saída:
  mod/42/poster.png          512x512  painel de info do mod (mod.info poster=)
  mod/42/icon.png             64x64   lista de mods, desenhado a 28 px (mod.info icon=): o "N" na névoa
  docs/workshop/preview.png  256x256  imagem do item no Workshop (o jogo exige
                                      PNG quadrado de 256 ou 512, < 1 024 000 bytes)

Névoa em camadas de ruído suavizado, um poste com luz fraca e uma figura sem
rosto ao longe. Texto na fonte embutida do Pillow (Aileron); ela não tem "É",
então o acento é desenhado à mão. Semente fixa: rodar de novo dá a mesma imagem.
Uso: python3 scripts/gen_images.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SEED = 4007
ROOT = os.path.join(os.path.dirname(__file__), "..")
TEXT = (214, 218, 214)


def noise(rng, size, cells):
    """Ruído de valor: grade aleatória pequena ampliada com bicúbica, 0..1."""
    grid = rng.random((cells, cells)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255


def fog_scene(size, rng, figure=True):
    """Cena em float 0..1 (RGB): céu escuro, névoa, poste, figura, vinheta, grão."""
    y = np.linspace(0, 1, size, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, size, dtype=np.float32)[None, :]
    base = np.zeros((size, size, 3), np.float32)
    base[...] = (0.05 + 0.05 * y)[..., None] * np.array([0.85, 0.95, 1.0], np.float32)

    # névoa: três oitavas, mais densa numa faixa na altura do horizonte
    fog = 0.55 * noise(rng, size, 4) + 0.3 * noise(rng, size, 9) + 0.15 * noise(rng, size, 23)
    band = np.exp(-((y - 0.62) ** 2) / 0.06)
    base += (fog * (0.12 + 0.4 * band))[..., None] * np.array([0.78, 0.82, 0.8], np.float32)

    # luz do poste: halo amarelado, apagado pela névoa
    lx, ly = 0.24, 0.30
    halo = np.exp(-(((x - lx - 0.04) ** 2) + ((y - ly) ** 2) * 1.4) / 0.012)
    base += (halo * 0.35)[..., None] * np.array([1.0, 0.85, 0.55], np.float32)

    # silhuetas desenhadas em máscara e desfocadas (a névoa engole os contornos)
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    s = size / 512
    d.rectangle([lx * size - 3 * s, ly * size, lx * size + 3 * s, size], fill=230)  # poste
    d.rectangle([lx * size - 3 * s, ly * size - 2 * s, lx * size + 26 * s, ly * size + 4 * s], fill=230)
    if figure:
        fx, fy = 0.66 * size, 0.60 * size
        d.ellipse([fx - 9 * s, fy - 62 * s, fx + 9 * s, fy - 40 * s], fill=200)  # cabeça sem rosto
        d.polygon([(fx - 15 * s, fy - 38 * s), (fx + 15 * s, fy - 38 * s), (fx + 11 * s, fy + 40 * s),
                   (fx - 11 * s, fy + 40 * s)], fill=200)  # corpo
        d.line([(fx - 15 * s, fy - 34 * s), (fx - 19 * s, fy + 12 * s)], fill=200, width=max(1, int(6 * s)))
        d.line([(fx + 15 * s, fy - 34 * s), (fx + 19 * s, fy + 12 * s)], fill=200, width=max(1, int(6 * s)))
    mask = mask.filter(ImageFilter.GaussianBlur(2.2 * s))
    shadow = np.asarray(mask, np.float32)[..., None] / 255
    base = base * (1 - 0.8 * shadow)

    # névoa da frente por cima de tudo, vinheta e grão
    front = noise(rng, size, 6) * np.exp(-((y - 0.85) ** 2) / 0.05)
    base += (front * 0.18)[..., None]
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
    base *= np.clip(1.15 - 1.1 * r, 0, 1)[..., None]
    base += rng.normal(0, 0.012, (size, size, 1)).astype(np.float32)
    return np.clip(base, 0, 1)


def to_image(arr):
    return Image.fromarray((arr * 255).astype(np.uint8), "RGB")


def draw_title(img, text, cy, height):
    """Texto centrado em maiúsculas; "É" vira "E" com acento desenhado."""
    font = ImageFont.load_default(height)
    d = ImageDraw.Draw(img)
    plain = text.replace("É", "E")
    width = font.getlength(plain)
    x = (img.width - width) / 2
    top = font.getbbox(plain)[1]
    y = cy - height / 2 - top / 2
    for ch, orig in zip(plain, text):
        d.text((x, y), ch, font=font, fill=TEXT)
        if orig == "É":
            w = font.getlength("E")
            gx, gy = x + w * 0.55, y + top - height * 0.08
            d.polygon([(gx - w * 0.12, gy), (gx + w * 0.22, gy - height * 0.2),
                       (gx + w * 0.42, gy - height * 0.2), (gx + w * 0.02, gy)], fill=TEXT)
        x += font.getlength(ch)


def poster(rng, size, subtitle=True):
    img = to_image(fog_scene(size, rng))
    draw_title(img, "NÉVOA E", size * 0.14, int(size * 0.095))
    draw_title(img, "OUTRO MUNDO", size * 0.25, int(size * 0.095))
    if subtitle:
        font = ImageFont.load_default(int(size * 0.035))
        d = ImageDraw.Draw(img)
        line = "Project Zomboid - Build 42"
        d.text(((size - font.getlength(line)) / 2, size * 0.92), line, font=font, fill=(150, 156, 152))
    return img


def icon(rng):
    """O "N" no meio da névoa, desenhado grande e reduzido (lido a 28-64 px)."""
    size = 256
    scene = fog_scene(size, rng, figure=False)
    font = ImageFont.load_default(int(size * 0.8))
    mask = Image.new("L", (size, size), 0)
    left, top, right, bottom = font.getbbox("N")
    ImageDraw.Draw(mask).text(((size - (right - left)) / 2 - left, (size - (bottom - top)) / 2 - top),
                              "N", font=font, fill=255)
    letter = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.5)), np.float32)[..., None] / 255
    glow = np.asarray(mask.filter(ImageFilter.GaussianBlur(14)), np.float32)[..., None] / 255
    # a névoa come o pé da letra: some de cima pra baixo
    y = np.linspace(0, 1, size, dtype=np.float32)[:, None, None]
    fade = np.clip(1.25 - 0.9 * y, 0.35, 1) * (0.75 + 0.25 * noise(rng, size, 7)[..., None])
    text = np.array(TEXT, np.float32) / 255
    out = scene + glow * 0.18 * fade
    out = out * (1 - letter * fade) + text * letter * fade
    return to_image(np.clip(out, 0, 1)).resize((64, 64), Image.LANCZOS)


def save(img, *path):
    out = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out, optimize=True)
    print(f"{os.path.relpath(out, ROOT)}: {img.width}x{img.height}, {os.path.getsize(out)} bytes")


def main():
    save(poster(np.random.default_rng(SEED), 512), "mod", "42", "poster.png")
    save(icon(np.random.default_rng(SEED + 1)), "mod", "42", "icon.png")
    save(poster(np.random.default_rng(SEED + 2), 256, subtitle=False), "docs", "workshop", "preview.png")


if __name__ == "__main__":
    main()
