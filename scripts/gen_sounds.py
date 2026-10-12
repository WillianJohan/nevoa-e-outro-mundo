#!/usr/bin/env python3
"""Gera os sons do mod de forma procedural (sem amostra de terceiros).

Saída: mod/42/media/sound/*.ogg (mono, 44.1 kHz), via ffmpeg (libvorbis).
Semente fixa: rodar de novo dá o mesmo áudio. Uso: python3 scripts/gen_sounds.py, ou com
nomes pra gerar só alguns (python3 scripts/gen_sounds.py NOM_DevTv NOM_DevBurst).

Exceção (sprint 0048): gritos Corredor / Carpideira / Ambient vêm dos MP3 ElevenLabs
gerados pelo Johan — converter com `scripts/import_elevenlabs_screams.py` (refs fora do
repo). Este script não sobrescreve esses slots; as funções `scream`/`wail`/`ambient_scream`
ficam como referência / fallback histórico.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

import nom_synth as ns
import sirenes
from nom_synth import (alto_falante, bandpass, bipe, canal_am, chiado_radio, crepitar, desvanecimento,
                       estalo, estatica, h_bandpass, harm, highpass, lowpass, lowpass_ctrl, motivo, norm,
                       nsamp, peak, peaking, phase_of, put, quase_voz, ramp_out, respiracao, reverb_wet,
                       rms, sirene_invertida, smooth_noise, smoothstep, tsec, tv_filter, window,
                       zumbido_rede)
from sirenes import (v1 as sv1, v2 as sv2, v3 as sv3, v4 as sv4, v5 as sv5, v6 as sv6, v7 as sv7, v8 as sv8,
                     v9 as sv9)

RATE = 44100
SEED = 4004
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media", "sound")
assert RATE == ns.RATE == sirenes.RATE_GEN and SEED == sirenes.SEED_GEN


def resonator(x, freq, q):
    """Filtro passa-banda de 2 polos (ressonância de garganta/boca)."""
    w = 2 * np.pi * freq / RATE
    r = np.exp(-w / (2 * q))
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = x[i] - a1 * y[i - 1] - a2 * y[i - 2] if i > 1 else x[i]
    return y * (1 - r)


# Espelho de NOM_SonarRules (sprint 0056). Teste: sonar_beats_match_gen_sounds.
# Onsets por variação; o OGG NOM_EstaladorClick é um tac curto — o jogo agenda um por batida.
CLICK_BURSTS = {
    "A": [0, 90, 165, 250, 320, 410, 490, 600, 720, 880, 1100, 1400],
    "B": [0, 500, 1000, 1800],
    "C": [0, 1000, 2000, 2065, 4065, 7065],
}
CLICK_BEATS_MS = CLICK_BURSTS["A"]  # legado 0048


def click_tac(rng):
    """Um tac seco de língua/mandíbula (~18 ms). Sem grave contínuo (não latido)."""
    n = int(rng.uniform(0.014, 0.022) * RATE)
    t = np.arange(n) / RATE
    burst = rng.standard_normal(n) * np.exp(-t * rng.uniform(220, 320))
    f_hi = 2100 + rng.uniform(-180, 220)
    body = resonator(burst, f_hi, 10) + 0.35 * resonator(burst, 850 + rng.uniform(-80, 80), 5)
    return highpass(body, 400, 1)


def click_burst(rng, beats_ms):
    """Série de tacs nos onsets (referência / preview); o jogo usa click_tac agendado."""
    dur = beats_ms[-1] / 1000.0 + 0.08
    out = np.zeros(int(dur * RATE) + 1)
    n_beats = len(beats_ms)
    for bi, start_ms in enumerate(beats_ms):
        body = click_tac(rng)
        gain = 0.55 + 0.35 * (bi / max(1, n_beats - 1))
        if bi == n_beats - 1:
            gain = 1.0
        i = int(start_ms / 1000.0 * RATE)
        end = min(len(out), i + len(body))
        out[i:end] += gain * body[: end - i]
    return out


def click(rng):
    """Estalador (0056): tac curto único. Ritmos A/B/C vêm da agenda Lua (BURST_GAPS)."""
    return click_tac(rng)


def glottal_source(f0, oq=0.55, tilt=1.35, rough=0.0, rng=None, grit=0.18):
    """Fonte glotal estilo Rosenberg/LF: fluxo que sobe e fecha seco + radiação (derivada).

    Harmônicos com tilt alto soam garganta, não serra FM. `rough` (0..1, escalar ou array)
    soma subharmônico e shimmer; `grit` mistura ruído na fonte (aperiodicidade entre
    harmônicos — o que falta pro ouvido ler "pessoa", não oscilador limpo)."""
    n = len(f0)
    if rng is None:
        rng = np.random.default_rng(0)
    f0 = np.maximum(f0, 40.0)
    rough = np.asarray(rough, dtype=float)
    if rough.ndim == 0:
        rough = np.full(n, float(rough))
    # jitter de período humano (mais forte que LFO de synth) + micro-deriva
    f = f0 * (1
              + 0.014 * smooth_noise(rng, n, 28)
              + 0.008 * rough * smooth_noise(rng, n, 70)
              + 0.004 * smooth_noise(rng, n, 9))
    ph = np.cumsum(f) / RATE  # ciclos
    frac = ph % 1.0
    open_m = frac < oq
    x = np.zeros(n)
    u = frac / oq
    # fluxo glotal: sobe em ~t²(1-t), fecha abrupto (borda = brilho natural)
    x[open_m] = (u[open_m] ** 2) * (1.0 - u[open_m])
    # radiação labial ≈ 1ª diferença; lowpass tira o click digital do fecho
    flow = lowpass(np.diff(x, prepend=x[0]), 6000, 2)
    # harmônicos suaves por cima (corpo da vogal) com tilt forte — sem chirp
    body = harm(phase_of(f), f, range(1, 22), tilt)
    src = 0.55 * peak(flow) + 0.45 * peak(body)
    # subharmônico + shimmer onde rough > 0
    sub = harm(phase_of(f * 0.5), f * 0.5, (1, 3, 5), 1.1)
    shimmer = 1.0 - rough * 0.35 * (0.5 + 0.5 * np.sin(phase_of(f * 0.5))) ** 2
    src = (1.0 - 0.45 * rough) * src + 0.45 * rough * peak(sub)
    src = src * shimmer
    # grit: ruído moldado pelo envelope da voz (preenche entre harmônicos)
    grit = np.asarray(grit, dtype=float)
    if grit.ndim == 0:
        grit = np.full(n, float(grit))
    if np.any(grit > 0):
        env = np.abs(lowpass(np.abs(src), 80, 2))
        env = env / (np.max(env) + 1e-12)
        noise = bandpass(rng.standard_normal(n), 1200, 0.7) + 0.5 * bandpass(
            rng.standard_normal(n), 2800, 1.0)
        src = (1.0 - 0.55 * grit) * src + grit * peak(noise) * env
    return src


def voice_tract(src, rng, f1, f2, f3, bw_mul=1.0, aspir=0.22, drift=1.0):
    """Trato vocal paralelo (Klatt-lite): 3 formantes que derivam + aspiração/turbulência."""
    n = len(src)
    dur = n / RATE
    d1 = smooth_noise(rng, int(dur * 40) + 2, 0.7)
    d2 = smooth_noise(rng, int(dur * 40) + 2, 0.55)
    d3 = smooth_noise(rng, int(dur * 40) + 2, 0.4)
    # bases podem ser escalares ou arrays (envelope de vogal no tempo)
    if np.isscalar(f1):
        f1 = np.full(n, float(f1))
        f2 = np.full(n, float(f2))
        f3 = np.full(n, float(f3))

    def formants(fr, tc):
        i = int(np.clip(tc * 40, 0, len(d1) - 1))
        j = int(np.clip(tc * RATE, 0, n - 1))
        # bandas mais largas = menos "picos de synth", mais garganta
        q1, q2, q3 = 2.4 / bw_mul, 3.0 / bw_mul, 3.8 / bw_mul
        a = f1[j] + 55 * drift * d1[i]
        b = f2[j] + 120 * drift * d2[i]
        c = f3[j] + 90 * drift * d3[i]
        # F1/F2 dominam (corpo da vogal); F3 e brilho só coloram — evita "chip" agudo
        return (1.35 * h_bandpass(fr, a, q1)
                + 0.95 * h_bandpass(fr, b, q2)
                + 0.28 * h_bandpass(fr, c, q3)
                + 0.06 * h_bandpass(fr, 3400, 5.5))

    # aspiração: ruído de glote aberta (grito = muito ar) — escalar ou array
    aspir = np.asarray(aspir, dtype=float)
    if aspir.ndim == 0:
        aspir = np.full(n, float(aspir))
    noise = highpass(rng.standard_normal(n), 500, 1)
    asp = bandpass(noise, 1800, 0.9) + 0.45 * bandpass(noise, 3200, 1.2)
    mix = peak(src) + aspir * peak(asp)
    y = tv_filter(np.concatenate([mix, np.zeros(4096)]), formants)[:n]
    return y


def room_echo(dry, taps, seed, lp=2400):
    """Ecos curtos de rua/galpão + cauda molhada leve."""
    wet = dry.copy()
    for delay, gain in taps:
        k = int(delay * RATE)
        if 0 < k < len(wet):
            wet[k:] += gain * lowpass(dry, lp, 1)[: len(wet) - k]
    wet = wet + 0.12 * reverb_wet(dry, 1.4, 0.05, min(lp, 1600), seed)
    return wet


def scream(rng):
    """Corredor (0048→redo): grito curto humano-morto — pulso glotal + formantes, raspagem.

    Anticipação de ar, pico de pânico, quebra de registro; eco curto. Sem serra 'blehhh'.
    """
    dur = rng.uniform(1.55, 1.95)
    t = tsec(nsamp(dur))
    # contorno F0: antecipação baixa → pico → queda (pessoa, não sirene)
    f_lo = rng.uniform(140, 190)
    f_peak = rng.uniform(380, 520)
    f_end = rng.uniform(160, 240)
    knots_t = [0, 0.12, 0.28, 0.55, 1.0, dur]
    knots_f = [f_lo, f_lo * 1.15, f_peak, f_peak * rng.uniform(0.88, 0.98),
               f_peak * 0.7, f_end]
    f0 = np.exp(lowpass(np.interp(t, knots_t, np.log(knots_f)), 8.0, 2))
    # vibrato irregular fraco + uma quebra de registro no meio
    vib = 0.018 * np.sin(2 * np.pi * (5.0 + 1.2 * smooth_noise(rng, len(t), 0.8)) * t)
    f0 = f0 * (1 + vib)
    brk = 0.55 + rng.uniform(-0.08, 0.12)
    g = smoothstep((t - brk) / 0.015) * (1 - smoothstep((t - brk - 0.09) / 0.04))
    f0 = f0 * (1 + (0.78 - 1) * g)
    rough = 0.55 + 0.25 * smoothstep((t - 0.2) / 0.4)
    src = glottal_source(f0, oq=0.48, tilt=1.4, rough=rough, rng=rng, grit=0.28)
    # vogal aberta /a/–/ɛ/: formantes acompanham F0 (grito real sobe F1 com o pitch)
    f1 = np.maximum(np.interp(t, [0, 0.3, dur], [620, 780, 680]), 1.15 * f0)
    f2 = np.maximum(np.interp(t, [0, 0.3, dur], [1250, 1480, 1320]), f1 + 450)
    f3 = np.clip(f2 + 900, 2200, 2900)
    voiced = voice_tract(src, rng, f1, f2, f3, bw_mul=1.15, aspir=0.22, drift=0.85)
    voiced = peaking(voiced, 700, 1.8, 5.0)  # peito / corpo
    # voz manda; raspagem/ar só coloram (evita chiado de synth no agudo)
    scrape = resonator(rng.standard_normal(len(t)), 1100, 2.2) * np.interp(
        t, [0, 0.1, 0.35, dur], [0.55, 0.35, 0.12, 0.04])
    breath_in = bandpass(rng.standard_normal(len(t)), 1400, 1.0) * np.interp(
        t, [0, 0.08, 0.2, dur], [0.7, 0.35, 0.08, 0.03])
    mixed = peak(voiced) + 0.16 * peak(scrape) + 0.12 * peak(breath_in)
    mixed = lowpass(mixed, 4200, 2)
    env = np.interp(t, [0, 0.06, 0.22, 0.9, dur - 0.15, dur], [0, 0.35, 1.0, 0.85, 0.35, 0])
    # micro-soluços de pânico (envelope, não pitch chirp)
    for _ in range(int(rng.integers(1, 3))):
        tc = rng.uniform(0.35, max(0.4, dur - 0.4))
        w = np.exp(-((t - tc) / 0.045) ** 2)
        env = env * (1.0 - 0.28 * w)
    dry = np.tanh(1.25 * peak(mixed) * env)
    return room_echo(dry, ((0.08, 0.2), (0.19, 0.1)), int(rng.integers(1, 9999)), lp=2100)


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


def sob(rng):
    """Carpideira calma: choro baixo de mulher, soluços entrecortados, ~7 s em loop.

    Voz aguda (~330 Hz) que treme e cai no fim de cada soluço, com muito ar; entre
    um e outro, uma inspiração curta e chiada (o "hic" do choro).
    """
    dur = 7.0
    t = np.arange(int((dur + 0.5) * RATE)) / RATE
    env = np.zeros_like(t)
    f0 = np.full_like(t, 330.0)
    start = 0.0
    while start < dur + 0.5:
        length = rng.uniform(0.45, 0.9)
        k = (t >= start) & (t < start + length)
        u = (t[k] - start) / length
        env[k] = np.sin(np.pi * u) ** 1.5 * rng.uniform(0.6, 1.0)
        f0[k] = rng.uniform(300, 380) * (1 - 0.18 * u)  # cada soluço cai
        gasp = (t >= start + length) & (t < start + length + 0.12)  # inspiração
        env[gasp] = 0.35 * np.sin(np.pi * (t[gasp] - start - length) / 0.12)
        start += length + rng.uniform(0.25, 0.6)
    f0 = f0 * (1 + 0.025 * np.sin(2 * np.pi * 6.5 * t))  # voz tremendo
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    voice = sum(np.sin(k * phase) / (k * k) for k in range(1, 10))
    breath = rng.standard_normal(len(t))
    sig = 0.6 * voice + 0.5 * breath
    formants = resonator(sig, 800, 5) + 0.7 * resonator(sig, 1200, 6) + 0.3 * resonator(sig, 2800, 8)
    return loopable(formants * env, 0.5)


def wail(rng):
    """Carpideira acordada (0048→redo): lamento feminino de pânico (vibe Witch L4D).

    Pulso glotal + formantes abertos; sobe, desafina, falha a voz, volta em aflição.
    Sem chip/serra — aspiração e quebra de garganta carregam o terror.
    """
    dur = rng.uniform(3.3, 4.0)
    t = tsec(nsamp(dur))
    # F0 feminino alto, contorno de lamento (não glissando de synth)
    f_start = rng.uniform(300, 380)
    f_hi = rng.uniform(560, 720)   # lamento aflito, não guincho de sirene
    f_mid = rng.uniform(480, 600)
    f_end = rng.uniform(260, 340)
    fail_t = rng.uniform(1.45, 1.9)
    knots_t = [0, 0.25, 0.7, fail_t, fail_t + 0.35, 2.6, dur]
    knots_f = [f_start, f_start * 1.2, f_hi, f_hi * 0.92, f_mid * 0.7, f_mid, f_end]
    f0 = np.exp(lowpass(np.interp(t, knots_t, np.log(knots_f)), 6.0, 2))
    # tremor de choro (vibrato irregular ~6 Hz) + flutter de pânico
    cry = 0.028 * np.sin(2 * np.pi * (5.8 + 1.5 * smooth_noise(rng, len(t), 0.6)) * t)
    cry = cry + 0.012 * smooth_noise(rng, len(t), 12)
    f0 = f0 * (1 + cry)
    # falha: F0 cai e a voz vira quase sopro
    fail = (t > fail_t) & (t < fail_t + 0.45)
    f0 = f0.copy()
    f0[fail] *= np.linspace(1.0, 0.72, fail.sum())
    src = glottal_source(f0, oq=0.58, tilt=1.25, rough=0.15 + 0.55 * fail.astype(float),
                         rng=rng, grit=0.22 + 0.25 * fail.astype(float))
    # formantes /a/ aflita (Witch): F1 acompanha F0 pra manter corpo de voz humana
    f1 = np.maximum(np.interp(t, [0, 0.8, fail_t, dur], [750, 900, 680, 800]), 1.1 * f0)
    f2 = np.maximum(np.interp(t, [0, 0.8, fail_t, dur], [1450, 1680, 1350, 1550]), f1 + 500)
    f3 = np.clip(f2 + 1000, 2400, 3100)
    aspir = 0.18 + 0.35 * fail.astype(float) + 0.1 * smoothstep((t - 0.1) / 0.5)
    voiced = voice_tract(src, rng, f1, f2, f3, bw_mul=1.25, aspir=aspir, drift=1.0)
    voiced = peaking(voiced, 850, 1.6, 6.0)  # peito feminino
    # inspiração chiada antes do pico e no fail (banda média — não hiss branco)
    gasp = bandpass(rng.standard_normal(len(t)), 1600, 1.1)
    gasp_env = np.exp(-((t - 0.08) / 0.06) ** 2) + 0.7 * np.exp(-((t - fail_t) / 0.08) ** 2)
    mixed = peak(voiced) + 0.18 * peak(gasp) * gasp_env
    mixed = lowpass(mixed, 4800, 2)
    env = np.interp(t, [0, 0.1, 0.45, fail_t, fail_t + 0.25, 2.8, dur],
                    [0, 0.5, 1.0, 0.55, 0.4, 0.75, 0])
    # soluços curtos no lamento (aflição, não metrônomo)
    for _ in range(int(rng.integers(2, 4))):
        tc = rng.uniform(0.5, dur - 0.5)
        env = env * (1.0 - 0.35 * np.exp(-((t - tc) / 0.05) ** 2))
    dry = np.tanh(1.35 * peak(mixed) * env)
    return room_echo(dry, ((0.12, 0.22), (0.28, 0.12), (0.52, 0.07)),
                     int(rng.integers(1, 9999)), lp=2600)


def ambient_scream(rng, style=None):
    """Grito/sofrimento humano distante (0048→redo).

    Referências de vibe (recriadas, sem sample): grito longe, sofrimento, choro, desespero.
    Variantes estruturais reais — não pitch shift. Passa-baixa + reverb = cidade/névoa.
    `style`: 0 grito distante · 1 sofrimento · 2 choro · 3 desespero (None = sorteia).
    """
    if style is None:
        style = int(rng.integers(0, 4))
    style = int(style) % 4
    sex = "f" if rng.random() > (0.4 if style in (2, 3) else 0.5) else "m"
    f_mul = rng.uniform(1.18, 1.38) if sex == "f" else 1.0

    if style == 0:  # grito humano distante (shriek curto)
        dur = rng.uniform(1.15, 1.65)
        f_lo, f_hi = rng.uniform(200, 270) * f_mul, rng.uniform(560, 720) * f_mul
        knots_t = [0, 0.07, 0.32, dur]
        knots_f = [f_lo, f_hi, f_hi * 0.88, f_lo * 0.92]
        env_k = ([0, 0.04, 0.18, dur - 0.22, dur], [0, 0.9, 1.0, 0.35, 0])
        rough0, grit0, aspir0 = 0.2, 0.24, 0.22
        sobs = 0
    elif style == 1:  # sofrimento: gemido/aflição que sobe e quebra
        dur = rng.uniform(2.2, 3.1)
        f_lo, f_hi = rng.uniform(160, 230) * f_mul, rng.uniform(360, 480) * f_mul
        knots_t = [0, 0.35, 0.9, 1.7, 2.3, dur]
        knots_f = [f_lo * 0.85, f_lo, f_hi, f_hi * 0.75, f_lo * 1.05, f_lo * 0.7]
        env_k = ([0, 0.2, 0.7, 1.5, dur - 0.45, dur], [0, 0.45, 0.85, 1.0, 0.4, 0])
        rough0, grit0, aspir0 = 0.35, 0.32, 0.28
        sobs = int(rng.integers(1, 3))
    elif style == 2:  # choro de desespero: soluços em série (F0 cai em cada um)
        dur = rng.uniform(2.4, 3.4)
        f_base = rng.uniform(240, 340) * f_mul
        # monta fraseado de soluços
        t = tsec(nsamp(dur))
        f0 = np.full_like(t, f_base * 0.7)
        env = np.zeros_like(t)
        tc = rng.uniform(0.05, 0.15)
        while tc < dur - 0.25:
            length = rng.uniform(0.28, 0.55)
            k = (t >= tc) & (t < tc + length)
            u = (t[k] - tc) / length
            env[k] = np.maximum(env[k], (np.sin(np.pi * u) ** 1.35) * rng.uniform(0.55, 1.0))
            f0[k] = f_base * rng.uniform(0.92, 1.12) * (1.0 - 0.22 * u)
            # inspiração chiada entre soluços
            gap = rng.uniform(0.08, 0.2)
            g = (t >= tc + length) & (t < tc + length + gap * 0.7)
            env[g] = np.maximum(env[g], 0.22 * np.sin(np.pi * (t[g] - tc - length) / (gap * 0.7 + 1e-9)))
            tc += length + gap
        f0 = f0 * (1 + 0.03 * smooth_noise(rng, len(t), 8) + 0.015 * smooth_noise(rng, len(t), 22))
        cry = 0.035 * np.sin(2 * np.pi * (6.2 + smooth_noise(rng, len(t), 0.7)) * t)
        f0 = f0 * (1 + cry)
        rough = 0.2 + 0.25 * (1.0 - env)  # mais rachado nos buracos
        src = glottal_source(f0, oq=0.56, tilt=1.28, rough=rough, rng=rng, grit=0.3)
        f1 = np.maximum(780 * f_mul / 1.2, 1.05 * f0)
        f2 = f1 + rng.uniform(550, 750)
        f3 = np.clip(f2 + 950, 2300, 3000)
        voiced = voice_tract(src, rng, f1, f2, np.full_like(t, f3), bw_mul=1.45,
                             aspir=0.3 + 0.2 * (1.0 - env), drift=1.15)
        gasp = bandpass(rng.standard_normal(len(t)), 1500, 1.0)
        mixed = peak(voiced) + 0.2 * peak(gasp) * (1.0 - env) * 0.5
        dry = peak(mixed) * np.clip(env, 0, 1)
        dry = lowpass(dry, rng.uniform(1000, 1400), 3)
        dry = highpass(dry, 100, 1)
        wet = room_echo(dry, ((0.35, 0.42), (0.7, 0.24), (1.15, 0.12)),
                        int(rng.integers(1, 9999)), lp=1000)
        return wet + 0.25 * reverb_wet(wet, 2.6, 0.18, 750, int(rng.integers(1, 9999)))
    else:  # desespero: crescendo longo, pico de pânico, queda quebrada
        dur = rng.uniform(2.0, 2.9)
        f_lo, f_hi = rng.uniform(190, 260) * f_mul, rng.uniform(520, 700) * f_mul
        peak_t = rng.uniform(0.9, 1.35)
        knots_t = [0, 0.25, peak_t, peak_t + 0.2, dur]
        knots_f = [f_lo * 0.8, f_lo * 1.1, f_hi, f_hi * 0.65, f_lo * 0.75]
        env_k = ([0, 0.15, peak_t, peak_t + 0.15, dur - 0.35, dur],
                 [0, 0.4, 1.0, 0.7, 0.35, 0])
        rough0, grit0, aspir0 = 0.3, 0.34, 0.26
        sobs = int(rng.integers(2, 4))

    if style != 2:
        t = tsec(nsamp(dur))
        f0 = np.exp(lowpass(np.interp(t, knots_t, np.log(knots_f)), 6.5, 2))
        # tremor irregular (não LFO limpo) + flutter de aflição
        f0 = f0 * (1
                   + 0.022 * smooth_noise(rng, len(t), 7)
                   + 0.012 * smooth_noise(rng, len(t), 18)
                   + 0.01 * np.sin(2 * np.pi * (5.5 + 1.8 * smooth_noise(rng, len(t), 0.5)) * t))
        rough = rough0 + 0.15 * smoothstep((t - 0.3) / max(0.4, dur - 0.6))
        src = glottal_source(f0, oq=0.52, tilt=1.3, rough=rough, rng=rng, grit=grit0)
        if sex == "f":
            f1b, f2b, f3b = 820.0, 1580.0, 2800.0
        else:
            f1b, f2b, f3b = 680.0, 1280.0, 2350.0
        f1a = np.maximum(np.full_like(t, f1b), 1.05 * f0) * (1 + 0.1 * smooth_noise(rng, len(t), 0.5))
        f2a = np.maximum(np.full_like(t, f2b), f1a + 480) * (1 + 0.07 * smooth_noise(rng, len(t), 0.4))
        f3a = np.full_like(t, f3b)
        voiced = voice_tract(src, rng, f1a, f2a, f3a, bw_mul=1.4, aspir=aspir0, drift=1.05)
        env = np.interp(t, env_k[0], env_k[1])
        for _ in range(sobs):
            tc = rng.uniform(0.35, max(0.5, dur - 0.45))
            env = env * (1.0 - 0.4 * np.exp(-((t - tc) / 0.055) ** 2))
        # ar de boca nos buracos do envelope (sofrimento/choro)
        breath = bandpass(rng.standard_normal(len(t)), 1400, 1.0)
        mixed = peak(voiced) + 0.16 * peak(breath) * (1.0 - np.clip(env, 0, 1))
        dry = peak(mixed) * env
        dry = lowpass(dry, rng.uniform(1050, 1450), 3)
        dry = highpass(dry, 110, 1)
        wet = room_echo(dry, ((0.32, 0.4), (0.65, 0.22), (1.1, 0.12)),
                        int(rng.integers(1, 9999)), lp=1050)
        wet = wet + 0.24 * reverb_wet(wet, 2.5, 0.16, 780, int(rng.integers(1, 9999)))
        return wet


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


# ------------------------------------------------- aparelhos do Outro Mundo (sprint 0034)
# TV, rádio, caixa de som e rádio de carro: o Outro Mundo tentando falar pelos aparelhos.
# Proposta e mixagem: guia sonoro da sprint 0034. Saem por ns.write (RMS ~ -12 dBFS, pico
# <= -1 dBFS decodificado); o volume relativo vai no media/scripts/NOM_sounds.txt.
SEED_DEV = SEED + 800
TV_LINE = 15750.0  # chiado de linha do tubo (PAL-M); bem baixo, nem todo mundo ouve
TV_FIELD = 59.94


def saida(x, k=3.0):
    """Estágio de saída do aparelho saturando de leve: ruído gaussiano tem crista natural de
    12-13 dB, que o limitador não tira sem baixar tudo; o aparelho forçado tira."""
    s = k * np.std(x) + 1e-12
    return np.tanh(x / s) * s


def fades(x, fin=0.12, fout=0.35):
    t = tsec(len(x))
    d = len(x) / RATE
    return x * smoothstep(t / fin) * np.clip((d - t) / fout, 0, 1)


def neve(rng, n):
    """TV fora do ar: ruído branco no alto-falante da TV, com o zumbido do sincronismo
    vertical (pulsos a 59,94 Hz no ruído e um buzz de harmônicos) e o fio agudo do tubo."""
    t = tsec(n)
    pulse = np.abs(np.sin(np.pi * TV_FIELD * t)) ** 24
    snow = rng.standard_normal(n) * (0.82 + 0.35 * pulse)
    snow = alto_falante(snow, lo=150, hi=7000, res=1100, res_db=4, drive=1.1)
    snow = lowpass(snow, 5200, 4)  # alto-falante de TV não passa muito de 5-6 kHz
    ph = phase_of(np.full(n, TV_FIELD))
    buzz = alto_falante(sum(np.sin(k * ph) / k for k in range(2, 40)), lo=150, hi=6000)
    return norm(snow) + 0.18 * norm(buzz)


def tela(x, fio=0.012):
    """Tudo o que sai da TV passa pelo alto-falante dela (até ~5-6 kHz); o fio agudo do tubo
    (15,75 kHz) não vem do alto-falante, vem do tubo, então entra depois, bem baixo."""
    t = tsec(len(x))
    y = lowpass(x, 5600, 4)
    return y + fio * np.std(y) * np.sin(2 * np.pi * TV_LINE * t) * (np.abs(x) > 0)


def dev_tv():
    """TV fora do ar com algo tentando atravessar (8 s).
    0-1,6 s neve. 1,6-3,2 s a neve encolhe e a própria estática forma quase-palavras
    (ruído passando por formantes que derivam, sílabas ao contrário). 3,45 s um tom de teste
    fura por 0,6 s e corta com estalo. 4,3-6,3 s quase-voz, agora com um fio de vozeado
    (sussurro que quase vira voz). 6,35 s estalo forte e a neve volta, mais alta por um
    instante; 7,6-8 s some."""
    rng = np.random.default_rng(SEED_DEV + 1)
    d = 8.0
    n = nsamp(d)
    t = tsec(n)
    snow = neve(rng, n)
    duck = 1 - 0.55 * window(t, 1.6, 3.2, 0.25, 0.15) - 0.65 * window(t, 4.3, 6.3, 0.3, 0.05) \
        - 0.8 * window(t, 3.45, 4.05, 0.01, 0.01) + 0.35 * window(t, 6.35, 6.7, 0.003, 0.3)
    v = np.zeros(n)
    put(v, 1.6, quase_voz(rng, 1.6, sussurro=1.0, sil_rate=3.5))
    put(v, 4.3, quase_voz(rng, 2.0, f0=118, sussurro=0.35, sil_rate=3.0) * 1.1)
    v = alto_falante(v, lo=180, hi=6000, res=1100, res_db=4)
    test = np.zeros(n)
    k = nsamp(0.6)
    tt = tsec(k)
    put(test, 3.45, np.sin(phase_of(1000 * (1 + 0.004 * np.sin(2 * np.pi * 5 * tt)))) * ramp_out(k, 3)
        * smoothstep(tt / 0.004))
    test = alto_falante(test, lo=180, hi=6000)
    pops = np.zeros(n)
    put(pops, 4.05, estalo(rng, True) * 1.0)
    put(pops, 6.35, estalo(rng, True) * 1.6)
    put(pops, 3.2, estalo(rng, True) * 0.5)
    ref = np.std(snow)
    out = snow * duck + 1.25 * ref * v / (np.std(v[np.abs(v) > 1e-9]) + 1e-12) \
        + 0.9 * ref * test / (np.std(test[np.abs(test) > 1e-9]) + 1e-12) + 2.2 * ref * pops
    return fades(tela(out), 0.12, 0.4)


def dev_tv_red():
    """Vermelha (8 s): a neve mais áspera, com uma respiração pesada e rouca por baixo
    (modulação de ~90 Hz, a garganta); a sirene ao contrário cresce dentro do chiado duas
    vezes e corta seco; aos 7,2 s a TV corta pro silêncio total (eles estão vindo)."""
    rng = np.random.default_rng(SEED_DEV + 2)
    d = 8.0
    n = nsamp(d)
    t = tsec(n)
    snow = neve(rng, n)
    rough = 1 - 0.45 * (0.5 + 0.5 * np.sin(phase_of(90 * (1 + 0.1 * smooth_noise(rng, n, 5))))) ** 3
    br = alto_falante(respiracao(rng, n, periodo=2.4, aspero=0.7, t0=0.9), lo=200, hi=5500, res=900, res_db=6)
    sw = np.zeros(n)
    put(sw, 2.2, sirene_invertida(rng, 1.4, 640, 430) * 0.7)
    put(sw, 5.0, sirene_invertida(rng, 1.6, 700, 450) * 1.0)
    sw = alto_falante(sw, lo=200, hi=5000, res=1000, res_db=4)
    pops = np.zeros(n)
    put(pops, 3.6, estalo(rng, True) * 1.2)
    put(pops, 6.6, estalo(rng, True) * 1.5)
    put(pops, 7.72, estalo(rng, False) * 0.5)
    ref = np.std(snow)
    breath_env = smoothstep((t - 0.9) / 1.0)
    out = snow * rough * (1 - 0.3 * np.abs(br) / (np.max(np.abs(br)) + 1e-12)) \
        + 1.3 * ref * norm(br) * breath_env + 1.1 * ref * sw / (np.std(sw[sw != 0]) + 1e-12) * 0.5 \
        + 2.0 * ref * pops
    cut = np.clip((7.2 + 0.003 - t) / 0.003, 0, 1)
    out = tela(out * cut) + lowpass(2.0 * ref * pops * (t > 7.5), 5600, 4)
    return fades(out, 0.08, 0.05)


def dev_tv_black():
    """Preta (8 s): no escuro, a TV é a única luz. O zumbido do tubo e da rede domina, a neve
    é fraca e cai em degraus (a imagem apagando), brasas estalam de leve; o motivo de três
    bipes atravessa em período exato (2,0 s) e na terceira vez só sai uma nota; aos 6,9 s a
    TV desliga (estalo de descarga, o fio agudo despenca) e sobram dois tiques do tubo
    esfriando."""
    rng = np.random.default_rng(SEED_DEV + 3)
    d = 8.0
    n = nsamp(d)
    t = tsec(n)
    off = 6.9
    hum = alto_falante(zumbido_rede(rng, n, f=TV_FIELD), lo=90, hi=5000, res=600, res_db=3)
    snow = neve(rng, n)
    lvl = 0.55 - 0.18 * smoothstep((t - 1.8) / 0.05) - 0.17 * smoothstep((t - 3.4) / 0.05) - 0.1 * smoothstep((t - 5.2) / 0.05)
    sig = np.zeros(n)
    for i, t0 in enumerate((2.4, 4.4, 6.4)):
        m = motivo() if i < 2 else motivo(quantas=1)
        put(sig, t0, m)
    sig = alto_falante(sig, lo=200, hi=5000)
    emb = crepitar(rng, n, 3.0, 0.5, off - 0.1, 1500, 4500)
    ref = np.std(norm(hum))
    alive = np.clip((off + 0.003 - t) / 0.003, 0, 1)
    # desligar: descarga do tubo e o fio agudo despencando em 0,35 s
    k = nsamp(0.5)
    tt = tsec(k)
    zap = bandpass(rng.standard_normal(k), 2500, 0.8) * np.exp(-tt / 0.02) \
        + 0.8 * np.sin(phase_of(70 * (1 + np.exp(-tt / 0.03)))) * np.exp(-tt / 0.05)
    fall = np.sin(phase_of(TV_LINE * np.exp(-tt / 0.25))) * np.exp(-tt / 0.12) * 0.05
    death = np.zeros(n)
    put(death, off, peak(zap) + fall)
    ticks = np.zeros(n)
    put(ticks, 7.35, estalo(rng, False) * 0.35)
    put(ticks, 7.78, estalo(rng, False) * 0.25)
    out = tela((0.9 * norm(hum) + lvl * snow + 1.2 * norm(sig) * (sig != 0) + 1.4 * emb / (np.max(np.abs(emb)) + 1e-12)) * alive) \
        + 1.6 * ref * death + 1.5 * ref * lowpass(ticks, 6000, 2)
    return fades(out, 0.15, 0.1)


def dial(rng, n, plan):
    """Posição do dial (0..1) por pontos (t, p) com movimento de mão (tremor leve)."""
    t = tsec(n)
    ts, ps = zip(*plan)
    p = np.interp(t, ts, ps)
    p = lowpass_ctrl(p, 3, 1)
    return p + 0.002 * smooth_noise(rng, n, 4)


def sintonia(rng, n, p, stations, lock=None, lock_t=None):
    """Varredura: chiado com crepitação atmosférica; perto de cada portadora o chiado
    aquieta, entra zumbido e o assobio de batimento desce até zero e sobe de novo.
    Devolve (som, aquietamento 0..1)."""
    t = tsec(n)
    hiss = chiado_radio(rng, n)
    q = np.zeros(n)
    whistle = np.zeros(n)
    for pk in stations:
        dist = p - pk
        g = np.exp(-(dist / 0.035) ** 2)
        q = np.maximum(q, g)
        fb = np.abs(dist) * 40000 + 30  # assobio de batimento: ~2 kHz a 0,05 do ponto, zero em cima
        whistle += np.sin(phase_of(fb)) * np.exp(-(dist / 0.05) ** 2)
    if lock is not None:
        g = np.exp(-((p - lock) / 0.02) ** 2)
        q = np.maximum(q, g * smoothstep((t - lock_t) / 0.3) if lock_t else g)
    carrier_hum = zumbido_rede(rng, n, harmonics=((1, 0.3), (2, 1.0), (3, 0.3)))
    out = norm(hiss) * (1 - 0.75 * q) + 0.8 * canal_am(whistle) + 0.12 * canal_am(carrier_hum, 100, 3000) * q
    return out, q


def dev_radio():
    """Rádio varrendo estações mortas (9 s). 0-4,6 s: o dial passa por cinco portadoras sem
    nada (assobio de batimento, aquietamento, zumbido); passa um pouco do ponto e volta.
    4,6 s: trava numa portadora. 5,1-8,3 s: a "voz que não é voz": entonação de fala, formantes
    que nunca firmam vogal, sílabas ao contrário, desvanecimento de rádio. 8,4 s: some no chiado."""
    rng = np.random.default_rng(SEED_DEV + 4)
    d = 9.0
    n = nsamp(d)
    t = tsec(n)
    plan = [(0, 0.03), (0.6, 0.1), (1.4, 0.26), (2.0, 0.33), (2.9, 0.55), (3.5, 0.7), (4.2, 0.885), (4.55, 0.862), (9, 0.86)]
    p = dial(rng, n, plan)
    base, q = sintonia(rng, n, p, (0.12, 0.27, 0.41, 0.58, 0.73), lock=0.86, lock_t=4.4)
    v = canal_am(quase_voz(rng, 3.2, f0=128, sussurro=0.1, sil_rate=3.4)) * 1.0
    vv = np.zeros(n)
    put(vv, 5.1, v)
    vv = vv * desvanecimento(rng, n, fundo=0.5)
    ref = np.std(base[:nsamp(4)])
    out = base * (1 - 0.5 * window(t, 5.1, 8.3, 0.2, 0.3)) + 2.4 * ref * vv / (np.std(v) + 1e-12)
    return fades(lowpass(saida(out, 2.2), 3400, 4), 0.1, 0.4)


def dev_radio_red():
    """Vermelha (8 s): o dial vai e volta rápido, como mão desesperada; trava aos 3,8 s numa
    respiração pesada e rouca no microfone, com a sirene ao contrário longe dentro do chiado;
    corte seco aos 7,6 s."""
    rng = np.random.default_rng(SEED_DEV + 5)
    d = 8.0
    n = nsamp(d)
    t = tsec(n)
    plan = [(0, 0.2), (0.5, 0.62), (0.9, 0.35), (1.4, 0.8), (1.8, 0.15), (2.3, 0.55), (2.7, 0.4), (3.2, 0.7),
            (3.6, 0.505), (8, 0.5)]
    p = dial(rng, n, plan)
    base, q = sintonia(rng, n, p, (0.1, 0.24, 0.33, 0.46, 0.61, 0.69, 0.84), lock=0.5, lock_t=3.6)
    br = canal_am(respiracao(rng, n, periodo=2.0, aspero=0.75, t0=3.9))
    sw = np.zeros(n)
    put(sw, 5.1, sirene_invertida(rng, 1.5, 620, 420))
    sw = lowpass(canal_am(sw), 1500, 2)
    pops = np.zeros(n)
    put(pops, 6.6, estalo(rng, True))
    ref = np.std(base[:nsamp(3)])
    out = base + 1.7 * ref * norm(br) * smoothstep((t - 3.9) / 0.3) + 0.6 * ref * sw / (np.std(sw[sw != 0]) + 1e-12) \
        + 1.5 * ref * pops
    cut = np.clip((7.6 + 0.003 - t) / 0.003, 0, 1)
    return fades(lowpass(saida(out, 2.2), 3400, 4) * cut, 0.08, 0.05)


def dev_radio_black():
    """Preta (9 s): varredura lenta; trava aos 3,2 s numa portadora morta: o chiado aquieta
    até quase silêncio e sobra o zumbido. Uma contagem de cinco pulsos, cada um um semitom
    abaixo (3,8 a 6,8 s), e então o motivo de três bipes. 8,4 s: a portadora cai, o chiado
    volta por um instante e o rádio morre."""
    rng = np.random.default_rng(SEED_DEV + 6)
    d = 9.0
    n = nsamp(d)
    t = tsec(n)
    plan = [(0, 0.05), (1.5, 0.3), (2.6, 0.52), (3.1, 0.6), (9, 0.6)]
    p = dial(rng, n, plan)
    base, q = sintonia(rng, n, p, (0.14, 0.38), lock=0.6, lock_t=2.9)
    deep = 1 - 0.7 * smoothstep((t - 3.2) / 0.4) * (1 - window(t, 8.4, 8.75, 0.01, 0.01))
    count = np.zeros(n)
    for i in range(5):
        put(count, 3.8 + 0.75 * i, bipe(0.13, 740 * 2 ** (-i / 12)))
    put(count, 7.2, motivo())
    count = canal_am(count)
    pops = np.zeros(n)
    put(pops, 8.4, estalo(rng, True))
    put(pops, 8.75, estalo(rng, True) * 0.7)
    ref = np.std(base[:nsamp(2.5)])
    alive = np.clip((8.75 + 0.003 - t) / 0.003, 0, 1)
    out = (base * deep + 0.9 * ref * norm(count) * (count != 0)) * alive + 1.3 * ref * pops
    return fades(out, 0.1, 0.1)


def dev_speaker():
    """Caixa de som de poste (7 s): zumbido de terra (60 e 180 Hz) na corneta; pulsos graves no
    andar de alguém pesado (intervalos ~0,37 s, irregulares, fortes e fracos alternando);
    microfonia nasce em 2,15 kHz, cresce, ondula e é cortada seca; depois de mais pulsos, uma
    segunda microfonia, um trítono abaixo, mais curta. Corneta com eco de rua."""
    rng = np.random.default_rng(SEED_DEV + 7)
    d = 7.0
    n = nsamp(d)
    hum = zumbido_rede(rng, n, harmonics=((1, 0.8), (2, 0.4), (3, 1.0), (5, 0.4), (7, 0.2)))
    pulses = np.zeros(n)

    def thump(strong):
        k = nsamp(0.3)
        tt = tsec(k)
        f = 55 * (1 + 0.6 * np.exp(-tt / 0.015))
        x = np.sin(phase_of(f)) * np.exp(-tt / (0.05 if strong else 0.035))
        x = x + 0.25 * highpass(rng.standard_normal(k), 1500, 2) * np.exp(-tt / 0.002)
        return x * smoothstep(tt / 0.001)

    for t0, cnt in ((0.6, 6), (4.75, 4)):
        tc = t0
        for i in range(cnt):
            strong = i % 2 == 0
            put(pulses, tc, thump(strong) * (1.0 if strong else rng.uniform(0.35, 0.6)))
            tc += 0.37 * rng.uniform(0.8, 1.3)

    def feedback(t0, t1, f0, gmax):
        k = nsamp(t1 - t0)
        tt = tsec(k)
        f = f0 * (1 + 0.004 * np.sin(2 * np.pi * 4.5 * tt) + 0.002 * smooth_noise(rng, k, 3))
        grow = np.exp((tt - (t1 - t0)) / 0.28)
        x = np.tanh(1.6 * np.sin(phase_of(f)) * grow * gmax) / np.tanh(1.6)
        x = x * (1 + 0.15 * np.sin(2 * np.pi * 7 * tt)) * ramp_out(k, 2)
        out = np.zeros(n)
        put(out, t0, x)
        return out

    fb = feedback(1.25, 2.95, 2150, 1.0) + feedback(4.35, 5.4, 2150 / 1.414, 0.7)
    pops = np.zeros(n)
    put(pops, 2.95, estalo(rng, True))
    put(pops, 5.4, estalo(rng, True) * 0.8)

    def corneta(x):
        y = lowpass(highpass(x, 350, 3), 5000, 3)
        y = peaking(y, 1800, 1.5, 6)
        s = np.std(y) * 3 + 1e-12
        return np.tanh(1.2 * y / s) * s

    dry = 0.45 * norm(corneta(hum)) + 2.6 * corneta(pulses) / (np.max(np.abs(corneta(pulses))) + 1e-12) \
        + 1.2 * corneta(fb) / (np.max(np.abs(fb)) + 1e-12) + 1.6 * pops
    # o grave do pulso também chega direto (a caixa vibra o poste): sem a corneta
    dry = dry + 0.9 * lowpass(pulses, 200, 2) / (np.max(np.abs(pulses)) + 1e-12)
    wet = reverb_wet(dry, 1.0, 0.04, 3000, SEED_DEV + 71, echoes=((0.15, 0.6), (0.38, 0.35)))
    return fades(dry + 0.18 * wet, 0.2, 0.4)


def dev_car():
    """Rádio de carro ligando sozinho, ouvido de fora (8 s). 0-1,25 s: só o ar da rua.
    1,25 s: o relé estala dentro do carro; 1,4 s: o alto-falante dá o "tum" de ligar e o
    rádio já entra alto, em chiado. Ele busca estação sozinho: quatro saltos (mudo, pedaço
    de assobio ou portadora, mudo de novo). 4,6 s: trava, e uma contagem de cinco sílabas,
    cada uma mais grave. 7,5 s: desliga com estalo. Tudo abafado pela lataria: graves de
    cabine fortes, quase nada acima de 1 kHz, painel vibrando nas sílabas mais fortes."""
    rng = np.random.default_rng(SEED_DEV + 8)
    d = 8.0
    n = nsamp(d)
    t = tsec(n)
    on, off = 0.95, 7.5
    radio_sig = norm(chiado_radio(rng, n))
    seek_t = (1.9, 2.55, 3.25, 3.95)
    gate = np.ones(n)
    snippets = np.zeros(n)
    for i, s0 in enumerate(seek_t):
        gate *= 1 - window(t, s0, s0 + 0.32, 0.004, 0.004)
        k = nsamp(0.2)
        tt = tsec(k)
        if i % 2 == 0:
            x = np.sin(phase_of(np.linspace(rng.uniform(600, 1500), rng.uniform(80, 300), k)))
        else:
            x = canal_am(zumbido_rede(rng, k, harmonics=((2, 1.0), (3, 0.4)))[:k] + 0.4 * rng.standard_normal(k))
        put(snippets, s0 + 0.32, norm(canal_am(x)) * smoothstep(tt / 0.005) * ramp_out(k, 4) * 1.2)
    after = smoothstep((t - 4.6) / 0.02)
    gate = gate * (1 - 0.88 * after)
    sil = np.zeros(n)
    for i in range(5):
        s = quase_voz(rng, 0.26, f0=135 * 2 ** (-i * 1.5 / 12), sussurro=0.15, sil_rate=50, reverso=False, decai=0.5)  # 0,26 s: uma sílaba só
        put(sil, 4.85 + 0.55 * i, peak(s))
    sil = canal_am(sil)
    sil = sil / (np.std(sil[np.abs(sil) > 1e-6]) + 1e-12)  # pelo RMS: a sílaba tem crista de ~18 dB
    radio_mix = radio_sig * gate + snippets + 1.7 * sil * after
    radio_mix = saida(radio_mix, 2.0) * window(t, on, off, 0.01, 0.004)
    rpop = np.zeros(n)
    k = nsamp(0.25)
    tt = tsec(k)
    put(rpop, on, np.sin(phase_of(40 * (1 + np.exp(-tt / 0.01)))) * np.exp(-tt / 0.06))
    put(rpop, off, 0.6 * np.sin(phase_of(45 * np.ones(k))) * np.exp(-tt / 0.04))
    relay = np.zeros(n)
    k2 = nsamp(0.05)
    put(relay, 0.8, highpass(rng.standard_normal(k2), 800, 2) * np.exp(-tsec(k2) / 0.002))
    inside = radio_mix + 2.5 * rpop + 1.2 * relay / (np.max(np.abs(relay)) + 1e-12)
    # lataria: passa-baixa forte, ressonância de cabine, painel vibrando quando a sílaba é forte
    shell = lowpass(inside, 850, 3)
    shell = peaking(shell, 115, 2.0, 6)
    env = np.sqrt(np.maximum(lowpass(sil ** 2, 20, 1), 0))
    env = env / (np.max(env) + 1e-12)
    rattle = norm(bandpass(rng.standard_normal(n), 950, 3.0)) * np.clip(env - 0.45, 0, None) * 2 * after
    street = 0.03 * norm(lowpass(rng.standard_normal(n), 400, 2)) + 0.01 * norm(bandpass(rng.standard_normal(n), 2500, 0.6))
    dry = norm(shell) + 0.35 * lowpass(rattle, 1500, 2) + street
    wet = reverb_wet(dry, 0.6, 0.01, 2500, SEED_DEV + 81)
    return fades(dry + 0.15 * wet, 0.1, 0.3)


def dev_burst():
    """Presságio (3 s): todo aparelho perto estoura em estática junto com a tela, até a
    sirene entrar por cima (o cliente corta). Chiado de aparelho (centro ~1 kHz, nunca o
    2,4 kHz contínuo do Sem-rosto) que nasce baixo e cresce em curva, como a estática da tela;
    a crepitação adensa, três rajadas de arco, um sussurro de quase-palavras afogado no meio;
    no fim, estalo forte e corte seco. Também é o chiado do aparelho perto do Sem-rosto."""
    rng = np.random.default_rng(SEED_DEV + 9)
    d = 3.0
    n = nsamp(d)
    t = tsec(n)
    grow = 0.12 + 0.88 * np.clip(t / 2.7, 0, 1) ** 2
    hiss = norm(chiado_radio(rng, n))
    st, _ = estatica(rng, n, grow, lambda x: 20 + 120 * (x / d) ** 2, lambda x: 1 + 6 * (x / d) ** 2,
                     rajadas=((1.15, 0.18, 0.6), (1.9, 0.25, 0.9), (2.45, 0.3, 1.2)), lp=3000)
    v = np.zeros(n)
    put(v, 1.4, quase_voz(rng, 1.1, sussurro=1.0, sil_rate=4.0))
    v = canal_am(v)
    pops = np.zeros(n)
    put(pops, 2.82, estalo(rng, True))
    alive = np.clip((2.82 + 0.003 - t) / 0.003, 0, 1)
    mix = (hiss * grow + 1.4 * norm(st) + 0.6 * grow * v / (np.std(v[np.abs(v) > 1e-9]) + 1e-12)) * alive + 2.0 * pops
    return fades(lowpass(saida(alto_falante(mix, lo=200, hi=4000, res=1100, res_db=4), 2.4), 3400, 4), 0.02, 0.1)


DEVICES = [
    ("NOM_DevTv", dev_tv, 10.5), ("NOM_DevTvRed", dev_tv_red, 10.5), ("NOM_DevTvBlack", dev_tv_black, 11.0),
    ("NOM_DevRadio", dev_radio, 10.5), ("NOM_DevRadioRed", dev_radio_red, 10.5),
    ("NOM_DevRadioBlack", dev_radio_black, 11.5), ("NOM_DevSpeaker", dev_speaker, 10.5),
    ("NOM_DevCar", dev_car, 11.0), ("NOM_DevBurst", dev_burst, 10.5),
]


# ------------------------------------------------- sirenes oficiais (sprint 0034, tarefa 3)
# Os protótipos que o Johan aprovou, portados em scripts/sirenes/ (síntese sem mudança). Aqui
# cada um é encurtado pra 10,6 s sem mudar o tom, ganha o passa-baixa da distância e o eco de
# cidade (com 1,2 s de cauda: 11,8 s no total) e é gravado com o RMS do protótipo. Tocam a
# 150–500 tiles do jogador, 5 de uma vez (shared/NOM_SirenSpotsRules.lua); quem baixa o volume
# com a distância é o FMOD (distanceMin/distanceMax em media/scripts/NOM_sounds.txt).
SIREN_CONTENT_S = 10.6
SIREN_TAIL_S = 1.2
SIREN_DIST_LP = 4000.0  # ~300 m de ar: -3 dB em 4 kHz, -12 dB em 8 kHz
# reflexões de fachada e morro: (atraso s, ganho, passa-baixa Hz); cada uma mais longe e escura
ECO_TAPS = ((0.31, 0.45, 2800), (0.56, 0.34, 2200), (0.84, 0.25, 1700), (1.13, 0.18, 1350), (1.47, 0.12, 1050))
ECO_CAUDA = 0.35  # reverb distante (rt60 2,6 s, escuro), com a energia do sinal seco vezes isto

# nome do som -> (módulo em scripts/sirenes, sirene do protótipo). A branca_engolida da v7 é a
# da v5 byte a byte: entra uma vez só, senão o coro poderia tocar a mesma duas vezes. A semente
# do eco vem da posição na lista: som novo entra no fim, senão os já gerados mudam. As da v9
# partem da versão seca do protótipo (a do jogo já tinha distância e cidade).
OFICIAIS = [
    ("NOM_SirenWhite1", sv8, "branca_a"), ("NOM_SirenWhite2", sv5, "branca_engolida"),
    ("NOM_SirenWhite3", sv3, "branca_radio"), ("NOM_SirenWhite4", sv2, "branca_a_fita_limpa"),
    ("NOM_SirenWhite5", sv2, "branca_b_manivela"), ("NOM_SirenWhite6", sv1, "branca_melhorada"),
    ("NOM_SirenRed1", sv7, "vermelha_garganta"), ("NOM_SirenRed2", sv6, "vermelha_ataque"),
    ("NOM_SirenRed3", sv4, "vermelha_uivo"), ("NOM_SirenRed4", sv3, "vermelha_uivo"),
    ("NOM_SirenRed5", sv2, "vermelha_b_uivo"), ("NOM_SirenRed6", sv2, "vermelha_c_duas_fitas"),
    ("NOM_SirenBlack1", sv8, "preta_a"), ("NOM_SirenBlack2", sv8, "preta_b"),
    ("NOM_SirenBlack3", sv7, "preta_apagao"), ("NOM_SirenBlack4", sv5, "preta_inalada"),
    ("NOM_SirenBlack5", sv4, "preta_b_apagao"), ("NOM_SirenBlack6", sv4, "preta_c_brasa"),
    ("NOM_SirenBlack7", sv3, "preta_c_brasa"), ("NOM_SirenBlack8", sv3, "preta_b_apagao"),
    ("NOM_SirenBlack9", sv2, "preta_fita"), ("NOM_SirenBlack10", sv1, "preta_c_silencio"),
    ("NOM_SirenWhite7", sv9, "branca_1"), ("NOM_SirenWhite8", sv9, "branca_2"), ("NOM_SirenWhite9", sv9, "branca_3"),
    ("NOM_SirenRed7", sv9, "vermelha_1"), ("NOM_SirenRed8", sv9, "vermelha_2"), ("NOM_SirenRed9", sv9, "vermelha_3"),
    ("NOM_SirenBlack11", sv9, "preta_1"), ("NOM_SirenBlack12", sv9, "preta_2"), ("NOM_SirenBlack13", sv9, "preta_3"),
]


def fim_util(x, abaixo_db=20.0, passo=0.25):
    """Onde o som acaba de verdade: depois da última janela a menos de `abaixo_db` do RMS do
    arquivo. O que vem depois é cauda quase muda, que o eco de cidade substitui."""
    k = nsamp(passo)
    lim = rms(x) * 10 ** (-abaixo_db / 20)
    vivas = [i for i in range(0, len(x) - k + 1, k) if rms(x[i:i + k]) >= lim]
    return min(len(x), vivas[-1] + 2 * k) if vivas else len(x)


def encurtar(x, n_out, quadro=2048, tol=512):
    """Muda a duração pra `n_out` amostras sem mudar o tom (WSOLA): recorta quadros de 46 ms
    do original em passos maiores e sobrepõe em passos fixos; cada quadro é procurado (±11,6 ms)
    onde melhor continua a onda do anterior, pra emenda não bater fase."""
    fator = n_out / len(x)
    hop = quadro // 2
    w = np.hanning(quadro + 1)[:-1]
    frames = int(np.ceil(n_out / hop)) + 1
    fim_x = int(np.ceil((frames + 1) * hop / fator)) + 2 * tol + 2 * quadro
    xp = np.concatenate([np.zeros(tol), x, np.zeros(max(0, fim_x - len(x)))])
    out = np.zeros(frames * hop + quadro)
    wsum = np.zeros_like(out)
    delta = 0
    for k in range(frames):
        start = int(round(k * hop / fator)) + tol + delta
        out[k * hop:k * hop + quadro] += w * xp[start:start + quadro]
        wsum[k * hop:k * hop + quadro] += w
        nat = xp[start + hop:start + hop + quadro]
        nxt = int(round((k + 1) * hop / fator)) + tol
        delta = int(np.argmax(np.correlate(xp[nxt - tol:nxt + tol + quadro], nat, "valid"))) - tol
    return out[:n_out] / np.maximum(wsum[:n_out], 1e-3)


def eco_cidade(x, seed):
    """A sirene ouvida a 150–500 tiles numa cidade vazia: o ar come o agudo, e chegam as
    reflexões de prédios e morros (0,3 a 1,5 s depois, cada vez mais baixas e escuras; os
    atrasos variam ±8% por sirene, pra cinco juntas não ecoarem iguais) e a cauda de reverb
    distante. Devolve o sinal com `SIREN_TAIL_S` a mais no fim."""
    rng = np.random.default_rng(seed)
    n = len(x) + nsamp(SIREN_TAIL_S)
    direto = np.concatenate([lowpass(x, SIREN_DIST_LP, 2), np.zeros(n - len(x))])
    out = direto.copy()
    for d, g, fc in ECO_TAPS:
        k = nsamp(d * rng.uniform(0.92, 1.08))
        out[k:] += g * lowpass(direto, fc, 2)[:n - k]
    out += ECO_CAUDA * reverb_wet(direto, 2.6, 0.12, 1500, seed)
    return out


def sirene_oficial(fn, seed):
    """Sinal pronto pra gravar: encurtado, com distância e eco, e fim composto (a cauda do eco
    morre num fade de 0,6 s, nunca num degrau). Devolve (sinal, crest_db do protótipo)."""
    x, crest = fn()
    n_c = nsamp(SIREN_CONTENT_S)
    if len(x) > n_c:
        x = x[:max(fim_util(x), n_c)]
    if len(x) > n_c:
        x = encurtar(x, n_c)
    x = np.concatenate([x, np.zeros(n_c - len(x))])
    x = x * np.clip((SIREN_CONTENT_S - tsec(n_c)) / 0.25, 0, 1)
    y = eco_cidade(x, seed)
    d = len(y) / RATE
    return y * np.clip((d - tsec(len(y))) / 0.6, 0, 1), crest


# Gritos oficiais da 0048: Johan + ElevenLabs SFX → import_elevenlabs_screams.py
ELEVENLABS_SCREAMS = (
    "NOM_CorredorScream", "NOM_CorredorScream2", "NOM_CorredorScream3",
    "NOM_CarpideiraScream", "NOM_CarpideiraScream2", "NOM_CarpideiraScream3",
    "NOM_AmbientScream1", "NOM_AmbientScream2", "NOM_AmbientScream3", "NOM_AmbientScream4",
)


def main():
    only = set(sys.argv[1:])

    def want(*names):
        return not only or any(name in only for name in names)

    if only & set(ELEVENLABS_SCREAMS):
        print(
            "slots ElevenLabs (Johan): use "
            "python3 scripts/import_elevenlabs_screams.py <pasta-refs> "
            + " ".join(sorted(only & set(ELEVENLABS_SCREAMS))),
            file=sys.stderr,
        )

    # click() era o primeiro consumidor do rng compartilhado com scream(); sozinho com SEED
    # continua byte-igual. CorredorScream* não regenera por síntese (ELEVENLABS_SCREAMS).
    if want("NOM_EstaladorClick"):
        write("NOM_EstaladorClick", click(np.random.default_rng(SEED)))
    # sprint 0005 em diante: um gerador e uma semente por som
    singles = [
        ("NOM_FogDrone", drone, 1), ("NOM_FogMetal", metal, 2), ("NOM_RadioStatic", radio_static, 3),
        ("NOM_CarpideiraSob", sob, 6),        # sprint 0011: Carpideira (4 e 5 eram as sirenes antigas)
        # CarpideiraScream* : ElevenLabs (import_elevenlabs_screams.py), não wail()
    ]
    for name, fn, k in singles:
        if want(name):
            write(name, fn(np.random.default_rng(SEED + k)))
    # AmbientScream* : ElevenLabs — não regenerar com ambient_scream()
    os.makedirs(OUT, exist_ok=True)
    for name, fn, crest in DEVICES:  # sprint 0034: aparelhos do Outro Mundo
        if want(name):
            ns.write(os.path.join(OUT, name + ".ogg"), fn(), crest_db=crest)
    for i, (name, mod, proto) in enumerate(OFICIAIS):  # sprint 0034: sirenes oficiais
        if want(name):
            sig, crest = sirene_oficial(mod.SIRENES[proto], SEED + 900 + i)
            ns.write(os.path.join(OUT, name + ".ogg"), sig, crest_db=crest)


if __name__ == "__main__":
    main()
