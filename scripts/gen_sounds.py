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


def loopable(signal, fade):
    """Funde o fim no começo (crossfade de `fade` s): o loop não estala na emenda."""
    n = int(fade * RATE)
    body, tail = signal[:-n].copy(), signal[-n:]
    ramp = np.linspace(0, 1, n)
    body[:n] = body[:n] * ramp + tail * (1 - ramp)
    return body


def drone(rng):
    """Névoa: drone grave que respira, ~8 s em loop sem emenda audível."""
    dur = 8.0
    t = np.arange(int((dur + 1.0) * RATE)) / RATE
    # frequências com número inteiro de ciclos em 8 s: o tom fecha o loop sozinho
    tone = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
               for f, a in ((41.25, 1.0), (55.0, 0.7), (82.5, 0.35), (110.125, 0.15)))
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * t / dur)
    rumble = resonator(rng.standard_normal(len(t)), 70, 2) * 6
    return loopable((tone * swell + rumble) * 0.5, 1.0)


def metal(rng):
    """Névoa: pancada metálica distante (parciais inarmônicos + eco longo), ~4 s."""
    dur = 4.0
    t = np.arange(int(dur * RATE)) / RATE
    hit = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d)
              for f, d in ((187, 1.4), (431, 2.2), (697, 2.9), (1123, 4.0), (1577, 5.5)))
    hit = hit * np.minimum(1, t / 0.004)
    out = hit.copy()
    for delay, gain in ((0.23, 0.45), (0.51, 0.3), (0.87, 0.18), (1.3, 0.1)):  # galpão vazio
        k = int(delay * RATE)
        out[k:] += gain * hit[:-k]
    dist = resonator(out, 500, 0.7)  # longe: perde o brilho
    return dist * np.exp(-t * 0.4)


def radio_static(rng):
    """Rádio chiando: ruído de banda de rádio com estalos e zumbido, ~4 s em loop."""
    dur = 4.0
    t = np.arange(int((dur + 0.3) * RATE)) / RATE
    hiss = resonator(rng.standard_normal(len(t)), 2400, 0.8) + 0.3 * rng.standard_normal(len(t))
    flutter = 0.7 + 0.3 * np.sin(2 * np.pi * 3.0 * t) * np.sin(2 * np.pi * 0.5 * t)
    crackle = (rng.random(len(t)) > 0.9993) * rng.standard_normal(len(t)) * 8
    hum = 0.15 * np.sin(2 * np.pi * 60 * t)
    return loopable(hiss * flutter + crackle + hum, 0.3)


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
    # sprint 0005: geradores próprios, pra não mudar os sons acima
    write("NOM_FogDrone", drone(np.random.default_rng(SEED + 1)))
    write("NOM_FogMetal", metal(np.random.default_rng(SEED + 2)))
    write("NOM_RadioStatic", radio_static(np.random.default_rng(SEED + 3)))


if __name__ == "__main__":
    main()
