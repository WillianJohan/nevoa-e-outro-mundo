#!/usr/bin/env python3
"""Gera os sons do mod de forma procedural (sem amostra de terceiros).

Saída: mod/42/media/sound/*.ogg (mono, 44.1 kHz), via ffmpeg (libvorbis).
Semente fixa: rodar de novo dá o mesmo áudio. Uso: python3 scripts/gen_sounds.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
SEED = 4004
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media", "sound")


def resonator(x, freq, q):
    """Filtro passa-banda de 2 polos (ressonância de garganta/boca)."""
    w = 2 * np.pi * freq / RATE
    r = np.exp(-w / (2 * q))
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = x[i] - a1 * y[i - 1] - a2 * y[i - 2] if i > 1 else x[i]
    return y * (1 - r)


def click(rng):
    """Estalador: três estalos secos de língua, o último mais forte, ~0,5 s."""
    out = np.zeros(int(0.55 * RATE))
    for start, gain in ((0.0, 0.6), (0.11, 0.7), (0.24, 1.0)):
        n = int(0.025 * RATE)
        t = np.arange(n) / RATE
        burst = rng.standard_normal(n) * np.exp(-t * 260)
        body = resonator(burst, 2300 + rng.uniform(-200, 200), 9) + 0.4 * resonator(burst, 900, 5)
        i = int(start * RATE)
        out[i:i + n] += gain * body
    return out


def scream(rng):
    """Corredor: grito rasgado que sobe, segura e quebra, ~1,6 s."""
    dur = 1.6
    t = np.arange(int(dur * RATE)) / RATE
    f0 = np.interp(t, [0, 0.25, 1.0, 1.6], [420, 880, 760, 520])
    f0 = f0 * (1 + 0.03 * np.sin(2 * np.pi * 7 * t)) * (1 + 0.01 * rng.standard_normal(len(t)).cumsum() / 300)
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    voice = sum(np.sin(k * phase) / k for k in range(1, 18))  # serra (rouca)
    voice = voice + 0.6 * rng.standard_normal(len(t))  # ar na garganta
    formants = resonator(voice, 1000, 6) + 0.8 * resonator(voice, 2600, 8) + 0.5 * resonator(voice, 3600, 10)
    env = np.interp(t, [0, 0.06, 1.2, 1.6], [0, 1, 0.8, 0])
    return np.tanh(1.5 * formants / np.max(np.abs(formants)) * env)  # saturação: garganta estourando


def write(name, signal):
    signal = signal / np.max(np.abs(signal)) * 0.9
    pcm = (signal * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "5",
                        "-map_metadata", "-1", "-fflags", "+bitexact", dst], check=True)
    os.unlink(tmp.name)
    print(dst)


def main():
    rng = np.random.default_rng(SEED)
    write("NOM_EstaladorClick", click(rng))
    write("NOM_CorredorScream", scream(rng))


if __name__ == "__main__":
    main()
