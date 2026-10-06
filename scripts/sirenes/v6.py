"""Síntese da sirene oficial portada do protótipo v6 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

from sirenes import RATE_GEN, SEED_GEN

RATE = RATE_GEN
SEED = SEED_GEN + 600
DUR = 15.0
N = int(round(DUR * RATE))
NYQ_SAFE = 18000.0


def _freqs(n):
    return np.maximum(np.fft.rfftfreq(n, 1 / RATE), 1e-3)


def h_bandpass(f, f0, q):
    return 1 / (1 + 1j * q * (f / f0 - f0 / f))


def bandpass(x, f0, q):
    """Passa-banda de 2 polos por FFT (pico de ganho 1 em f0)."""
    return np.fft.irfft(np.fft.rfft(x) * h_bandpass(_freqs(len(x)), f0, q), len(x))


def lowpass(x, fc, order=2):
    f = _freqs(len(x))
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1 + (f / fc) ** (2 * order)), len(x))


def highpass(x, fc, order=2):
    f = _freqs(len(x))
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1 + (fc / f) ** (2 * order)), len(x))


def smooth_noise(rng, n, fc):
    """Ruído lento (passa-baixa em fc Hz) com desvio padrão ~1: deriva aleatória."""
    x = lowpass(rng.standard_normal(n), fc, 2)
    return x / (np.std(x) + 1e-12)


def smoothstep(x):
    s = np.clip(x, 0, 1)
    return s * s * (3 - 2 * s)


def norm(x):
    return x / (np.std(x) + 1e-12)


def peak(x):
    return x / (np.max(np.abs(x)) + 1e-12)


def fftconv(x, ir):
    n = len(x) + len(ir)
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return y[:len(x)]


def reverb_ir(rt60, predelay, damp, seed, echoes=()):
    """Resposta sintética: cauda de ruído que decai (rt60), escurecendo (damp), com
    reflexões discretas borradas `echoes` = ((atraso s, ganho), ...)."""
    rng = np.random.default_rng(seed)
    n = int(rt60 * 1.15 * RATE)
    t = np.arange(n) / RATE
    ir = rng.standard_normal(n) * 10 ** (-3 * t / rt60) * np.minimum(1, t / 0.01)
    ir = lowpass(ir, damp, 1)
    for delay, gain in echoes:
        k = int(delay * RATE)
        m = int(0.03 * RATE)
        if k + m < n:
            burst = lowpass(rng.standard_normal(m), damp, 1) * np.hanning(m)
            ir[k:k + m] += gain * norm(burst) * np.std(ir[:2000]) * 4
    ir = np.concatenate([np.zeros(int(predelay * RATE)), ir])
    return ir / np.sqrt(np.sum(ir ** 2))


def reverb_wet(x, rt60, predelay, damp, seed, echoes=()):
    """Só o sinal molhado, com a mesma energia do seco."""
    y = fftconv(x, reverb_ir(rt60, predelay, damp, seed, echoes))
    return y * np.std(x) / (np.std(y) + 1e-12)


def harm(phase, f, ks, tilt=1.0):
    """Soma de harmônicos k da fase, com amplitude 1/k^tilt; cada harmônico some antes de
    passar de NYQ_SAFE (f é a frequência instantânea da fundamental)."""
    out = np.zeros_like(phase)
    for k in ks:
        g = np.clip((NYQ_SAFE - k * f) / 2000, 0, 1)
        out += g * np.sin(k * phase) / k ** tilt
    return out


def tsec(n=N):
    return np.arange(n) / RATE


def put(buf, t0, e):
    k = int(round(t0 * RATE))
    if 0 <= k < len(buf):
        seg = e[:len(buf) - k]
        buf[k:k + len(seg)] += seg


def poisson(rng, rate, t0, t1):
    """Instantes de um processo de Poisson com taxa rate(t) (eventos/s)."""
    out, tc = [], t0
    while True:
        tc += rng.exponential(1 / rate(tc))
        if tc >= t1:
            return out
        out.append(tc)
CTRL = 1000  # Hz da simulação do motor


def _to_audio(v):
    tc = np.arange(len(v)) / CTRL
    return np.interp(tsec(), tc, v)


def motor_ondulante(rng, t_start, t_stop, f_hi, f_lo, top, tau_up, tau_dn, tau_stop):
    """Sinal de ataque: o controlador liga o motor até o tom chegar em ~f_hi e desliga até
    cair a ~f_lo, sem parar (os limiares variam um pouco a cada ciclo). Rotação como inércia
    de 1ª ordem: ligado, sobe rumo a `top`; desligado, cai rumo a zero (mais devagar). Em
    `t_stop` o motor desliga de vez. Devolve a frequência fundamental (Hz) no tempo."""
    n = int(DUR * CTRL)
    out = np.zeros(n)
    f, on = 0.0, True
    hi = f_hi * rng.uniform(0.98, 1.02)
    lo = f_lo * rng.uniform(0.97, 1.03)
    dt = 1 / CTRL
    for i in range(n):
        tc = i * dt
        if tc < t_start:
            pass
        elif tc >= t_stop:
            f += (0 - f) * dt / tau_stop
        elif on:
            f += (top - f) * dt / tau_up
            if f >= hi:
                on = False
                lo = f_lo * rng.uniform(0.96, 1.04)
        else:
            f += (0 - f) * dt / tau_dn
            if f <= lo:
                on = True
                hi = f_hi * rng.uniform(0.97, 1.03)
        out[i] = f
    return _to_audio(out)


def sirene(rng, f, drive=1.6, tilt=1.05, rot_rate=None, rot_period=8.0, ar=0.1):
    """Sirene mecânica de rotor/estator: fundamental = rotação × janelas; onda quase
    trapezoidal (harmônicos ímpares, pares fracos), corneta com ressonância, ar soprando
    pelas janelas (cresce com a rotação), volume subindo com a rotação, corneta girando
    (de frente: aberta; de costas: abafada) e saturação da corneta em volume alto."""
    ph = 2 * np.pi * np.cumsum(f) / RATE + rng.uniform(0, 6.28)
    tone = harm(ph, f, range(1, 32, 2), tilt) + 0.08 * harm(ph, f, range(2, 12, 2), 1.5)
    tone = tone + 0.5 * bandpass(tone, 1000, 1.0)
    rpm = np.clip(f / 650, 0, 1.3)
    air = norm(bandpass(rng.standard_normal(N), 1600, 0.7)) * rpm ** 2 * ar * np.std(tone)
    rate = np.ones(N) / rot_period if rot_rate is None else rot_rate
    face = 0.5 + 0.5 * np.cos(2 * np.pi * np.cumsum(rate) / RATE + rng.uniform(0, 6.28))
    x = (tone + air) * (0.45 + 0.55 * face) + (1 - face) * 0.5 * lowpass(tone, 1200, 2)
    x = x * rpm ** 1.6
    return np.tanh(drive * x / (np.max(np.abs(x)) + 1e-12)) / np.tanh(drive)


def cidade(x, wet, lp, seed):
    """Sirene no alto de um poste, ouvida na rua: perda de agudos com a distância, prédios
    devolvendo reflexões e a cauda da cidade aberta."""
    x = lowpass(x, lp, 2)
    return (1 - wet) * x + wet * reverb_wet(x, 2.8, 0.03, 5000, seed,
                                            echoes=((0.18, 0.8), (0.42, 0.6), (0.77, 0.5), (1.25, 0.35), (1.9, 0.2)))


def ar_da_cidade(rng):
    """Fundo da rua: rumor grave e um pouco de vento."""
    return norm(lowpass(rng.standard_normal(N), 300, 2)) + 0.3 * norm(bandpass(rng.standard_normal(N), 900, 0.5))


def _evento_estalo(rng, forte):
    """Um estalo elétrico: impulso de ruído com decaimento curto e um anel agudo."""
    dur = rng.uniform(0.004, 0.02) if forte else rng.uniform(0.0006, 0.003)
    n = int(dur * RATE) + 64
    tt = tsec(n)
    e = rng.standard_normal(n) * np.exp(-tt / (dur / 4))
    e = bandpass(e, rng.uniform(900, 5000), 0.6)
    if forte:
        e = e + 0.5 * np.sin(2 * np.pi * rng.uniform(1500, 3500) * tt) * np.exp(-tt / (dur / 3))
    return peak(e)


def estatica(rng, nivel, crack_rate, pop_rate, rajadas=(), quedas=()):
    """Interferência elétrica: chiado de fundo, crepitação miúda, estalos fortes, rajadas
    (ruído com zumbido de 120 Hz e crepitação densa, como arco/linha de energia) e quedas
    breves. Devolve (estática, gate das quedas pra aplicar na sirene)."""
    t = tsec()
    hiss = lowpass(highpass(rng.standard_normal(N), 250, 2), 7500, 2)
    hiss = norm(hiss) * (1 + 0.25 * smooth_noise(rng, N, 3)) * 0.3 * nivel
    crack = np.zeros(N)
    for tc in poisson(rng, crack_rate, 0.0, DUR - 0.01):
        put(crack, tc, _evento_estalo(rng, False) * rng.lognormal(-1.6, 0.6) * np.interp(tc, t, nivel))
    pops = np.zeros(N)
    for tc in poisson(rng, pop_rate, 0.0, DUR - 0.03):
        put(pops, tc, _evento_estalo(rng, True) * rng.uniform(0.5, 1.2) * np.interp(tc, t, nivel))
    burst = np.zeros(N)
    buzz = (0.35 + 0.65 * np.abs(np.sin(2 * np.pi * 60 * t)) ** 6)
    for t0, dur, g in rajadas:
        env = smoothstep((t - t0) / 0.012) * (1 - smoothstep((t - t0 - dur) / 0.06))
        if not np.any(env > 0):
            continue
        dense = np.zeros(N)
        for tc in poisson(rng, lambda x: 700.0, t0, min(DUR - 0.01, t0 + dur + 0.06)):
            put(dense, tc, _evento_estalo(rng, False) * rng.uniform(0.2, 0.8))
        noise = norm(bandpass(rng.standard_normal(N), 2200, 0.5)) * buzz
        burst += g * env * (0.55 * noise + 1.3 * dense)
        put(pops, t0, _evento_estalo(rng, True) * 1.1 * g)
    gate = np.ones(N)
    for t0, dur in quedas:
        gate *= 1 - 0.92 * smoothstep((t - t0) / 0.005) * (1 - smoothstep((t - t0 - dur) / 0.005))
        put(pops, t0, _evento_estalo(rng, True) * 0.6)
        put(pops, t0 + dur, _evento_estalo(rng, True) * 0.4)
    st = hiss * (0.25 + 0.75 * gate) + 0.9 * crack + 1.1 * pops + burst
    return lowpass(st, 9000, 2), gate


def vermelha_ataque():
    """Sinal de ATAQUE: tom ondulante sem parar (ciclos de ~2,5 s entre ~400 e ~700 Hz),
    urgente e áspero. Duas sirenes de bairros diferentes: uma mais perto, outra longe e
    abafada, com ciclos levemente diferentes (entram e saem de fase). Estática agressiva:
    estalos fortes, rajadas e quedas que aumentam ao longo dos 15 s. No fim o motor desliga
    e o tom cai em ~1,5 s; a interferência continua."""
    rng = np.random.default_rng(SEED + 1)
    t = tsec()
    fa = motor_ondulante(rng, 0.1, 13.3, 700, 400, 820, 1.0, 2.3, 0.65)
    fb = motor_ondulante(rng, 0.85, 13.15, 665, 385, 790, 1.1, 2.0, 0.7)
    a = sirene(rng, fa, drive=2.8, tilt=0.85, rot_period=7.5, ar=0.14)
    b = sirene(rng, fb, drive=2.0, tilt=1.0, rot_period=9.5, ar=0.1)
    sir = cidade(a, 0.33, 9500, SEED + 11) + 0.42 * cidade(b, 0.65, 2600, SEED + 12)
    sir = norm(sir) + 0.04 * ar_da_cidade(rng)

    nivel = 0.55 + 0.95 * smoothstep(t / 14.0)
    rajadas = [(2.7, 0.14, 0.45), (4.9, 0.22, 0.55), (6.6, 0.18, 0.7), (8.1, 0.32, 0.8), (9.3, 0.25, 0.9),
               (10.4, 0.42, 1.0), (11.5, 0.28, 1.1), (12.3, 0.55, 1.2), (13.5, 0.3, 1.0), (14.2, 0.4, 0.9)]
    quedas = [(4.25, 0.06), (7.55, 0.09), (9.85, 0.07), (11.2, 0.12), (12.95, 0.1)]
    st, gate = estatica(rng, nivel, lambda x: np.interp(x, [0, 15], [70, 280]),
                        lambda x: np.interp(x, [0, 15], [1.2, 6.0]), rajadas, quedas)
    out = sir * gate + 1.8 * st
    return out * smoothstep(t / 0.05) * np.clip((DUR - t) / 0.35, 0, 1)


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "vermelha_ataque": lambda: (vermelha_ataque(), 9.8),
}
