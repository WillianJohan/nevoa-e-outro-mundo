#!/usr/bin/env python3
"""Experimental — não usado in-game (revertido 2026-10-11).

Protótipo sprint 0061: gritos procedurais monstro/ambiente. Saída seria
mod/42/media/sound/*.ogg (mono 44,1 kHz), mesma pipeline do gen_sounds.write.
Semente SEED=61061 — regerar localmente: python3 scripts/gen_screams.py

O mod usa ElevenLabs (0048) + gen_sounds.py nos slots oficiais; este script não entra no build.
"""
from __future__ import annotations

import os
import sys

import numpy as np

# Importa helpers do gerador principal (mesmo diretório).
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import gen_sounds as gs  # noqa: E402

RATE = gs.RATE
OUT = gs.OUT
SEED = 61061  # sprint 0061 — documentado; não misturar com SEED 4004 do gen_sounds.py

write = gs.write
scream = gs.scream
wail = gs.wail
ambient_scream = gs.ambient_scream
glottal_source = gs.glottal_source
voice_tract = gs.voice_tract
room_echo = gs.room_echo
peak = gs.peak
lowpass = gs.lowpass
highpass = gs.highpass
bandpass = gs.bandpass
peaking = gs.peaking
reverb_wet = gs.reverb_wet
resonator = gs.resonator
smooth_noise = gs.smooth_noise
smoothstep = gs.smoothstep
tsec = gs.tsec
nsamp = gs.nsamp


def _rng(k: int):
    return np.random.default_rng(SEED + k)


# --- 5 gritos de monstro (Corredor + Carpideira / Screamer) -------------------

def monster_scream1(rng):
    """Grave feral curto: homem distorcido, pico baixo-médio, ~1,8 s."""
    return scream(_rng(1))


def monster_scream2(rng):
    """Agudo seco: surto rápido ~1,1 s, registro alto quebrado."""
    dur = 1.12
    t = tsec(nsamp(dur))
    f0 = np.exp(np.interp(t, [0, 0.05, 0.22, dur], np.log([220, 680, 720, 380])))
    f0 = f0 * (1 + 0.04 * np.sin(2 * np.pi * 7.2 * t))
    src = glottal_source(f0, oq=0.42, tilt=1.5, rough=0.65, rng=rng, grit=0.38)
    voiced = voice_tract(src, rng, 720, 1450, 2700, bw_mul=1.0, aspir=0.35, drift=0.7)
    env = np.interp(t, [0, 0.03, 0.15, dur - 0.08, dur], [0, 0.95, 1.0, 0.2, 0])
    dry = np.tanh(1.4 * peak(voiced) * env)
    return room_echo(dry, ((0.06, 0.18), (0.14, 0.09)), 102, lp=2800)


def monster_scream3(rng):
    """Lamento longo feminino distorcido (~3,6 s) — Screamer / Carpideira."""
    return wail(_rng(3))


def monster_scream4(rng):
    """Rosnado-grito híbrido: grave que explode no meio (~2,0 s)."""
    dur = 2.05
    t = tsec(nsamp(dur))
    growl_f = np.interp(t, [0, 0.4, 0.55, dur], [95, 110, 280, 200])
    ph = np.cumsum(growl_f) / RATE
    growl = sum(np.sin(k * 2 * np.pi * ph) / k for k in range(1, 8))
    growl = lowpass(growl * np.interp(t, [0, 0.35, 0.5, dur], [0.3, 0.5, 1.0, 0.4]), 900, 2)
    burst_t = 0.52
    mask = smoothstep((t - burst_t) / 0.04) * (1 - smoothstep((t - burst_t - 0.85) / 0.25))
    f0 = 180 + 420 * mask
    src = glottal_source(f0, oq=0.5, rough=0.5 + 0.3 * mask, rng=rng, grit=0.32 * mask + 0.1)
    voiced = voice_tract(src, rng, 600, 1200, 2400, bw_mul=1.2, aspir=0.25, drift=0.9)
    mixed = peak(growl) * 0.55 + peak(voiced) * np.interp(t, [0, 0.45, 0.55, dur], [0.2, 0.3, 1.0, 0.15])
    env = np.interp(t, [0, 0.08, 0.5, dur - 0.12, dur], [0, 0.4, 1.0, 0.25, 0])
    dry = np.tanh(1.3 * peak(mixed) * env)
    return room_echo(dry, ((0.1, 0.22), (0.24, 0.11), (0.45, 0.06)), 104, lp=2400)


def monster_scream5(rng):
    """Oco / hollow: voz média filtrada, micro-soluços (~2,4 s)."""
    dur = 2.35
    t = tsec(nsamp(dur))
    f0 = np.interp(t, [0, 0.2, 0.9, 1.6, dur], [260, 310, 340, 290, 220])
    f0 = f0 * (1 + 0.02 * smooth_noise(rng, len(t), 11))
    src = glottal_source(f0, oq=0.54, tilt=1.25, rough=0.4, rng=rng, grit=0.22)
    voiced = voice_tract(src, rng, 650, 1180, 2200, bw_mul=1.35, aspir=0.28, drift=1.1)
    voiced = peaking(voiced, 450, 2.2, -3.0)  # oco: menos peito
    env = np.interp(t, [0, 0.12, 0.35, dur - 0.2, dur], [0, 0.6, 1.0, 0.35, 0])
    for tc in (0.55, 1.05, 1.55):
        env = env * (1 - 0.32 * np.exp(-((t - tc) / 0.05) ** 2))
    dry = peak(voiced) * env
    dry = bandpass(dry, 800, 0.55) + 0.4 * dry
    dry = lowpass(dry, 3200, 2)
    return room_echo(dry, ((0.11, 0.19), (0.27, 0.1)), 105, lp=2000)


MONSTER = (
    ("NOM_MonsterScream1", monster_scream1, 1),
    ("NOM_MonsterScream2", monster_scream2, 2),
    ("NOM_MonsterScream3", monster_scream3, 3),
    ("NOM_MonsterScream4", monster_scream4, 4),
    ("NOM_MonsterScream5", monster_scream5, 5),
)


# --- 3 gritos ambiente (coral distante, tensão horde — sintético) ------------

def _voice_layer(rng, dur, f_mul, delay_s, gain, lp_hz):
    """Uma voz sintética distante para empilhar."""
    t = tsec(nsamp(dur))
    f_lo = rng.uniform(170, 240) * f_mul
    f_hi = rng.uniform(420, 580) * f_mul
    f0 = np.exp(np.interp(t, [0, 0.25, 0.7, dur], np.log([f_lo, f_hi, f_hi * 0.85, f_lo * 0.9])))
    rough = 0.25 + 0.2 * smoothstep(t / dur)
    src = glottal_source(f0, oq=0.55, rough=rough, rng=rng, grit=0.28)
    voiced = voice_tract(src, rng, 700 * f_mul, 1300, 2500, bw_mul=1.5, aspir=0.32, drift=1.2)
    env = np.interp(t, [0, 0.08, 0.4, dur - 0.3, dur], [0, 0.7, 1.0, 0.45, 0])
    sig = peak(voiced) * env
    sig = lowpass(sig, lp_hz, 3)
    k = nsamp(delay_s)
    out = np.zeros(nsamp(dur + delay_s + 0.5))
    out[k:k + len(sig)] += gain * sig
    return out[: nsamp(dur + 0.3)]


def ambient_horde_coral(rng):
    """Várias vozes defasadas, muito filtradas — sensação de horda longe (~3,8 s)."""
    dur = 3.8
    layers = [
        _voice_layer(rng, dur, 1.0, 0.0, 0.55, 1100),
        _voice_layer(rng, dur, 1.15, 0.35, 0.45, 950),
        _voice_layer(rng, dur, 0.92, 0.72, 0.4, 850),
        _voice_layer(rng, dur, 1.28, 1.05, 0.35, 780),
    ]
    n = max(len(x) for x in layers)
    mix = np.zeros(n)
    for lay in layers:
        mix[: len(lay)] += lay
    mix = highpass(mix, 90, 1)
    wet = room_echo(mix, ((0.38, 0.35), (0.82, 0.2), (1.35, 0.12)), 201, lp=900)
    return wet + 0.3 * reverb_wet(wet, 3.0, 0.2, 650, 202)


def ambient_tension_swell(rng):
    """Tensão: um grito principal + respostas mais fracas (eco em coral) ~3,2 s."""
    base = ambient_scream(_rng(211), style=3)
    dur = 3.2
    n = nsamp(dur)
    out = np.zeros(n)
    out[: min(len(base), n)] += base[: min(len(base), n)] * 0.85
    for delay, g in ((0.55, 0.35), (1.1, 0.22)):
        echo = ambient_scream(_rng(212 + int(delay * 10)), style=0)
        k = nsamp(delay)
        end = min(n, k + len(echo))
        out[k:end] += g * lowpass(echo[: end - k], 700, 2)
    return lowpass(out, 1200, 2) + 0.22 * reverb_wet(out, 2.8, 0.15, 720, 213)


def ambient_distant_mixed(rng):
    """Sofrimento + choro distante em camadas (estilo wall of sound longe) ~3,5 s."""
    a = ambient_scream(_rng(221), style=1)
    b = ambient_scream(_rng(222), style=2)
    n = max(len(a), len(b))
    out = np.zeros(n)
    out[: len(a)] += 0.6 * a
    k = nsamp(0.45)
    out[k:k + len(b)] += 0.55 * b[: max(0, n - k)]
    return room_echo(out, ((0.42, 0.38), (0.95, 0.18)), 223, lp=1000)


AMBIENT = (
    ("NOM_AmbientScream5", ambient_horde_coral, 200),
    ("NOM_AmbientScream6", ambient_tension_swell, 210),
    ("NOM_AmbientScream7", ambient_distant_mixed, 220),
)


# --- teste Silent Hill PT: metal / arranhão industrial sutil -------------------

def monster_noise_test_pt(rng):
    """Clip de teste: arranhão metálico, reverberação seca, unease (~4,5 s). Não gameplay."""
    dur = 4.5
    t = tsec(nsamp(dur))
    # arranhão modulado (não sample)
    f_scrape = 180 + 40 * smooth_noise(rng, len(t), 2.5)
    ph = np.cumsum(f_scrape) / RATE
    scrape = np.sin(2 * np.pi * ph * 3.7) * np.sin(2 * np.pi * ph * 0.23)
    scrape += 0.4 * rng.standard_normal(len(t)) * np.abs(np.sin(2 * np.pi * 2.1 * t))
    scrape = bandpass(scrape, 1200, 1.4) + 0.35 * bandpass(scrape, 2800, 2.0)
    env_scrape = np.interp(t, [0, 0.5, 1.2, 2.8, 3.6, dur], [0, 0.15, 0.55, 0.45, 0.2, 0])
    scrape = scrape * env_scrape
    # pancada metálica distante
    hit = sum(
        np.sin(2 * np.pi * f * t) * np.exp(-t * d)
        for f, d in ((220, 2.0), (510, 3.2), (890, 4.5))
    )
    hit = hit * np.exp(-((t - 0.85) / 0.08) ** 2) * 0.35
    hit = lowpass(hit, 1800, 2)
    # zumbido elétrico baixo
    hum = 0.12 * np.sin(2 * np.pi * 58 * t) * smoothstep(t / 1.5) * (1 - smoothstep((t - 3.8) / 0.4))
    rumble = resonator(rng.standard_normal(len(t)), 55, 1.5) * 0.08 * env_scrape
    mix = peak(scrape) + hit + hum + rumble
    mix = lowpass(mix, 4500, 2)
    wet = room_echo(mix, ((0.18, 0.25), (0.41, 0.14), (0.72, 0.08)), 301, lp=1600)
    return wet * np.interp(t, [0, 0.2, dur - 0.5, dur], [0, 1, 1, 0])


TEST = (("NOM_MonsterNoiseTest", monster_noise_test_pt, 300),)


ALL = MONSTER + AMBIENT + TEST


def main():
    only = set(sys.argv[1:])

    def want(name):
        return not only or name in only

    os.makedirs(OUT, exist_ok=True)
    for name, fn, _k in ALL:
        if want(name):
            write(name, fn(_rng(_k)))


if __name__ == "__main__":
    main()
