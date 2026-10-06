"""Síntese da sirene oficial portada do protótipo v2 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

from sirenes import RATE_GEN, SEED_GEN

RATE = RATE_GEN
SEED = SEED_GEN + 200
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


def tv_filter(x, hfun, frame=4096):
    """Filtro que varia no tempo: quadros Hann com 50%% de sobreposição (somam 1), cada um
    filtrado por FFT com a resposta hfun(f, t_centro). Quadro no meio de um buffer 2x maior
    pra cauda do filtro não dar a volta."""
    hop = frame // 2
    size = 2 * frame
    w = np.hanning(frame + 1)[:-1]
    pad = frame
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad + frame)])
    y = np.zeros(len(xp) + size)
    f = _freqs(size)
    q = frame // 2
    for i in range(0, len(xp) - frame, hop):
        buf = np.zeros(size)
        buf[q:q + frame] = xp[i:i + frame] * w
        tc = (i + frame / 2 - pad) / RATE
        out = np.fft.irfft(np.fft.rfft(buf) * hfun(f, tc), size)
        j = i - q
        if j < 0:
            out = out[-j:]
            j = 0
        y[j:j + len(out)] += out
    return y[pad:pad + len(x)]


def smooth_noise(rng, n, fc):
    """Ruído lento (passa-baixa em fc Hz) com desvio padrão ~1: deriva aleatória."""
    x = lowpass(rng.standard_normal(n), fc, 2)
    return x / (np.std(x) + 1e-12)


def smoothstep(x):
    s = np.clip(x, 0, 1)
    return s * s * (3 - 2 * s)


def norm(x):
    return x / (np.std(x) + 1e-12)


def fftconv(x, ir):
    n = len(x) + len(ir)
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return y[:len(x)]


def reverb(x, rt60=3.0, predelay=0.05, wet=0.4, damp=3500, seed=0, echoes=()):
    """Reverb por convolução com resposta sintética: cauda de ruído que decai (rt60),
    escurecendo (damp) e reflexões distantes borradas `echoes` = ((atraso s, ganho), ...)."""
    rng = np.random.default_rng(seed)
    n = int(rt60 * 1.15 * RATE)
    t = np.arange(n) / RATE
    ir = rng.standard_normal(n) * 10 ** (-3 * t / rt60) * np.minimum(1, t / 0.03)
    ir = lowpass(ir, damp, 1)
    pre = int(predelay * RATE)
    ir = np.concatenate([np.zeros(pre), ir])
    for delay, gain in echoes:
        k = int(delay * RATE)
        m = int(0.12 * RATE)
        if k + m < len(ir):
            burst = lowpass(rng.standard_normal(m), 1800, 1) * np.hanning(m)
            ir[k:k + m] += gain * norm(burst) * np.std(ir[pre:pre + 4000]) * 3
    ir = ir / np.sqrt(np.sum(ir ** 2))
    y = fftconv(x, ir)
    return (1 - wet) * x + wet * y * np.std(x) / (np.std(y) + 1e-12)


def harm(phase, f, ks, tilt=1.0):
    """Soma de harmônicos k da fase, com amplitude 1/k^tilt; cada harmônico some antes de
    passar de NYQ_SAFE (f é a frequência instantânea da fundamental)."""
    out = np.zeros_like(phase)
    for k in ks:
        g = np.clip((NYQ_SAFE - k * f) / 2000, 0, 1)
        out += g * np.sin(k * phase) / k ** tilt
    return out


def tsec():
    return np.arange(N) / RATE


def fade(x, fin=0.02, fout=1.0):
    t = tsec()
    return x * np.minimum(1, t / fin) * np.clip((DUR - t) / fout, 0, 1)


def wow(rng, t, w=0.01, fl=0.003, rnd=0.004, wf=0.55, ff=7.3):
    """Velocidade relativa da fita: wow (lento), flutter (rápido) e deriva aleatória."""
    return (1 + w * np.sin(2 * np.pi * wf * t + rng.uniform(0, 6.28))
            + fl * np.sin(2 * np.pi * ff * t + rng.uniform(0, 6.28))
            + rnd * smooth_noise(rng, len(t), 3))


def play(spd, f_of_pos, rng, pos0=0.0, ks=range(1, 13), tilt=1.0, ratio=1.0):
    """"Toca" a gravação: a posição no conteúdo avança com a velocidade da fita e o tom
    gravado sai multiplicado por ela. Devolve (onda, posição, frequência instantânea)."""
    pos = pos0 + np.cumsum(spd) / RATE
    f = f_of_pos(pos) * spd * ratio
    phase = 2 * np.pi * np.cumsum(f) / RATE + rng.uniform(0, 6.28)
    return harm(phase, f, ks, tilt), pos, f


def tape_hiss(rng, n=N):
    h = highpass(rng.standard_normal(n), 1500, 1) + 0.5 * bandpass(rng.standard_normal(n), 5000, 0.7)
    return norm(h * (1 + 0.12 * smooth_noise(rng, n, 4)))


def tape(x, rng, hiss=0.05, lp=5000, hp=70, drive=1.6, bump=0.3):
    """Cadeia de gravação: realce de cabeça (~110 Hz), banda limitada, saturação e chiado."""
    x = norm(x)
    x = x + bump * bandpass(x, 110, 1.2)
    x = highpass(lowpass(x, lp, 2), hp, 2)
    x = x / (np.max(np.abs(x)) + 1e-12)
    x = np.tanh(drive * x) / np.tanh(drive)
    return norm(x) + hiss * tape_hiss(rng)


def rotor(p, t_on, t_full, t_off, tau_up=1.5, tau_down=2.2):
    """Rotação de sirene de rotor (0..1) em função do tempo do conteúdo p: ganha rotação
    (1 - e^-x), segura e perde rotação exponencialmente ao desligar."""
    x = p - t_on
    up = np.where(x < 0, 0.0, (1 - np.exp(-np.maximum(x, 0) / tau_up)) / (1 - np.exp(-(t_full - t_on) / tau_up)))
    up = np.minimum(up, 1.0)
    down = np.exp(-np.maximum(p - t_off, 0) / tau_down)
    return np.where(p < t_full, up, 1.0) * down


def cyc_profile(u, rise=0.4, hold=0.15):
    """Perfil 0..1 de um ciclo de sirene (u em 0..1): sobe, segura, desce."""
    fall = 1 - rise - hold
    return np.where(u < rise, smoothstep(u / rise),
                    np.where(u < rise + hold, 1.0, 1 - smoothstep((u - rise - hold) / fall)))


def clicks(times, rng, dur=0.004, fc=2200, q=1.2, gains=None):
    """Estalos curtos (ruído com decaimento exponencial) nos instantes dados."""
    out = np.zeros(N)
    m = int(dur * 6 * RATE)
    env = np.exp(-np.arange(m) / (dur * RATE))
    for i, tc in enumerate(times):
        k = int(tc * RATE)
        if 0 <= k < N - m:
            g = 1.0 if gains is None else gains[i]
            out[k:k + m] += g * rng.standard_normal(m) * env
    return bandpass(out, fc, q)


def preta_fita():
    """A preta_a_fita da v1 condensada em 15 s com o mesmo arco: wow/flutter forte e
    chiado de rádio desde o início; a velocidade cai de ~1 pra ~0,1 (o tom escorrega);
    cortes cada vez mais longos com rádio preenchendo as falhas; grave arrastado no fim."""
    rng = np.random.default_rng(SEED + 1)
    t = tsec()
    grow = 1 + 1.2 * t / DUR
    speed = np.interp(t, [0, 3.3, 8.3, 12.7, 15], [0.97, 0.88, 0.58, 0.28, 0.1])
    wob = 1 + grow * (0.045 * np.sin(2 * np.pi * 0.55 * t) + 0.018 * np.sin(2 * np.pi * 7.3 * t + 1)
                      + 0.012 * smooth_noise(rng, N, 3))
    spd = np.clip(speed * wob, 0.04, None)
    raw, _, _ = play(spd, lambda p: 190 * (600 / 190) ** cyc_profile((p / 4.5) % 1, 0.4, 0.15), rng,
                     ks=range(1, 12), tilt=1.0)
    raw = raw / np.max(np.abs(raw))
    dull = lowpass(raw, 800, 2)  # fita velha perde o brilho conforme morre
    mixk = np.clip(t / 10, 0, 1)
    sir = (1 - mixk) * raw + mixk * dull
    sir = np.tanh(2.0 * sir / np.max(np.abs(sir)))
    sir = sir * np.clip(1 + 0.25 * smooth_noise(rng, N, 12), 0.2, None)  # oxidação oscilando
    mask = np.zeros(N)
    tcur = 0.4
    while tcur < DUR - 0.7:
        frac = tcur / DUR
        d = rng.uniform(0.03, 0.11) * (1 + 3.5 * frac)
        mask[int(tcur * RATE):int((tcur + d) * RATE)] = 1
        tcur += rng.uniform(0.15, 0.75) * (1 - 0.7 * frac) + d
    mask = np.clip(np.convolve(mask, np.ones(150) / 150, "same") * 1.5, 0, 1)
    sir = sir * (1 - 0.97 * mask)
    hiss = bandpass(rng.standard_normal(N), 2600, 0.5) + 0.4 * highpass(rng.standard_normal(N), 4500, 1)
    hiss = norm(hiss) * (1 + 0.35 * np.sin(2 * np.pi * 0.5 * t) * np.sin(2 * np.pi * 2.3 * t))
    tune = 900 + 700 * np.sin(2 * np.pi * 0.2 * t) + 350 * smooth_noise(rng, N, 2.4)
    whistle = np.sin(2 * np.pi * np.cumsum(tune) / RATE) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.33 * t + 2)) ** 3
    crackle = (rng.random(N) > 0.9992) * rng.standard_normal(N) * 6
    radio = hiss + 0.55 * whistle + crackle
    level = np.interp(t, [0, 5, 15], [0.22, 0.4, 0.55]) * (1 + 1.6 * mask)
    fd = np.interp(t, [10, 15], [88, 30]) * (1 + 0.04 * np.sin(2 * np.pi * 0.8 * t))
    ph = 2 * np.pi * np.cumsum(fd) / RATE
    drag = harm(ph, fd, range(1, 8), 1.1) + 0.3 * lowpass(rng.standard_normal(N), 140, 2) * 8
    drag = lowpass(np.tanh(1.8 * drag / np.max(np.abs(drag))), 260, 2)
    drag = drag * smoothstep((t - 10) / 2.7) * (1 + 0.3 * np.sin(2 * np.pi * 0.8 * t))
    sir_env = np.interp(t, [0, 12, 14.3], [1, 1, 0.0])
    out = sir * sir_env / np.std(sir) + level * norm(radio) * 0.55 + 1.3 * norm(drag)
    return fade(out, 0.005, 0.8)


def branca_a_fita_limpa():
    """Sirene de defesa civil (rotor) tocada de uma fita velha: uma subida (rotor ganhando
    rotação), uma segurada e uma descida (rotor perdendo rotação). Corneta girando
    (vem e vai), eco de cidade, wow leve e chiado. Sem falhas."""
    rng = np.random.default_rng(SEED + 2)
    t = tsec()
    spd = wow(rng, t, w=0.007, fl=0.0025, rnd=0.003)
    holder = {}

    def f_of_pos(p):
        s = lowpass(rotor(p, 0.25, 4.6, 9.0, 1.5, 2.1), 3, 1)
        s = s * (1 + 0.006 * smooth_noise(rng, N, 0.7))
        holder["s"] = s
        return 30 + 545 * s

    x, _, f = play(spd, f_of_pos, rng, ks=range(1, 14), tilt=0.95)
    s = holder["s"]
    x = x + 1.1 * bandpass(x, 1000, 1.3)  # ressonância da corneta
    rot = 0.5 + 0.5 * np.cos(2 * np.pi * t / 7.0 + 0.4)  # corneta girando: de frente / de costas
    x = x * (0.55 + 0.45 * rot) + (1 - rot) * 0.6 * lowpass(x, 1300, 2)
    x = x * (0.04 + 0.96 * np.clip(s, 0, 1) ** 1.3)
    x = reverb(x, rt60=3.6, predelay=0.08, wet=0.42, damp=3000, seed=SEED + 21,
               echoes=((0.65, 0.7), (1.4, 0.45), (2.3, 0.25)))
    return fade(tape(x, rng, hiss=0.055, lp=5200, drive=1.5), 0.05, 0.6)


def branca_b_manivela():
    """Sirene mecânica de manivela gravada em fita: cada volta da manivela empurra o rotor
    (o tom sobe em surtos), quem gira cansa, perde fôlego, tenta de novo e larga; o rotor
    roda livre até parar. Ar passando pelas janelas, catraca e engrenagem."""
    rng = np.random.default_rng(SEED + 3)
    t = tsec()
    cr_rate = 1000
    tc = np.arange(int(DUR * cr_rate)) / cr_rate
    effort = np.interp(tc, [0, 0.35, 4.5, 6.0, 7.2, 8.4, 9.0, 10.4, 11.2, 11.8, 15],
                       [0, 1.0, 1.0, 0.8, 0.15, 0.15, 1.0, 1.0, 0.3, 0, 0])
    crank_hz = np.interp(tc, [0, 2, 4.5, 7.2, 8.4, 9.0, 10.4, 11.8, 15],
                         [1.6, 2.2, 2.4, 1.2, 1.1, 2.3, 2.0, 1.1, 1.0])
    cphase = 2 * np.pi * np.cumsum(crank_hz) / cr_rate
    torque = effort * np.maximum(0, np.sin(cphase)) ** 4
    rpm = np.zeros(len(tc))
    v = 0.0
    for i in range(1, len(tc)):
        v += (2.6 * torque[i] - 0.34 * v - 0.02 * (v > 0)) / cr_rate
        v = max(v, 0.0)
        rpm[i] = v
    rpm = rpm / rpm.max()
    turns = np.floor(cphase / (2 * np.pi))
    click_t = tc[1:][np.diff(turns) > 0]
    click_g = np.interp(click_t, tc, effort)
    r = np.interp(t, tc, rpm)
    spd = wow(rng, t, w=0.012, fl=0.004, rnd=0.005)
    f = (25 + 690 * r) * spd
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = harm(phase, f, range(1, 22), 0.75)
    tone = tone * (1 + 0.12 * np.sin(phase / 8))  # 8 janelas no rotor: aspereza na rotação
    tone = tone + 0.15 * np.sin(3.7 * phase) * r  # engrenagem
    air = norm(bandpass(rng.standard_normal(N), 1400, 0.7)) * r ** 2
    ratchet = clicks(click_t + 0.02, rng, 0.003, 2600, 1.5, click_g)
    x = norm(tone) * r ** 1.5 + 0.3 * air + 0.5 * ratchet / np.max(np.abs(ratchet))
    x = reverb(x, rt60=1.8, predelay=0.03, wet=0.3, damp=3500, seed=SEED + 31,
               echoes=((0.45, 0.4), (1.1, 0.25)))
    return fade(tape(x, rng, hiss=0.06, lp=4500, drive=2.0), 0.02, 0.5)


def vermelha_b_uivo():
    """A sirene vai se dobrando num uivo: começa mecânica e estável, ganha vibrato
    irregular, o contorno vira glissando com quebras, o timbre passa de rotor pra uma
    fonte "de garganta" com ar, filtrada por formantes largos que derivam sem parar
    (sugerem voz, nenhuma vogal se firma); no fim um rosnado sub e a cauda descendente."""
    rng = np.random.default_rng(SEED + 6)
    t = tsec()
    m = smoothstep((t - 2.5) / 8.0)  # quanto já virou uivo
    kt = [0, 2.6, 5.0, 6.5, 7.6, 9.5, 10.5, 11.4, 13.0, 15.0]
    kf = [160, 520, 520, 465, 565, 540, 370, 600, 555, 190]
    f0 = np.exp(lowpass(np.interp(t, kt, np.log(kf)), 1.2, 2))
    f0 = f0 * (1 + 0.025 * m * np.sin(2 * np.pi * (5.2 + 0.8 * smooth_noise(rng, N, 0.5)) * t))
    f0 = f0 * (1 + 0.009 * m * smooth_noise(rng, N, 28))  # jitter
    for tb, ratio in ((7.35, 0.82), (12.15, 0.78)):  # quebras de registro
        g = smoothstep((t - tb) / 0.02) * (1 - smoothstep((t - tb - 0.07) / 0.02))
        f0 = f0 * (1 + (ratio - 1) * g)
    spd = wow(rng, t, w=0.01, fl=0.003, rnd=0.004)
    f = f0 * spd
    ph = 2 * np.pi * np.cumsum(f) / RATE
    siren = harm(ph, f, range(1, 15), 0.9)
    siren = siren + 1.0 * bandpass(siren, 950, 1.2)
    throat = harm(ph, f, range(1, 30), 1.35) + 0.5 * smoothstep((t - 10.6) / 1.0) * (1 - smoothstep((t - 13.2) / 1.0)) \
        * harm(ph / 2, f / 2, (1, 3, 5), 1.2)  # rosnado: subharmônico
    breath = rng.standard_normal(N) * (0.25 + 0.35 * smoothstep((t - 9) / 4))
    src = norm(throat) * (1 + 0.15 * m * smooth_noise(rng, N, 9)) + breath
    d1 = smooth_noise(rng, int(DUR * 50) + 1, 0.4)
    d2 = smooth_noise(rng, int(DUR * 50) + 1, 0.3)

    def formants(fr, tc):
        i = min(int(tc * 50), len(d1) - 1) if tc > 0 else 0
        f1 = 500 + 90 * d1[i]
        f2 = 1120 + 220 * d2[i]
        return 1.0 * h_bandpass(fr, f1, 2.6) + 0.55 * h_bandpass(fr, f2, 3.2) + 0.22 * h_bandpass(fr, 2550, 4.5)

    voiced = tv_filter(src, formants)
    amp = np.interp(t, [0, 0.4, 10.1, 10.5, 10.9, 14, 15], [0.1, 1, 1, 0.45, 1, 0.8, 0.3])
    x = ((1 - m) * norm(siren) + m * norm(voiced)) * amp
    x = reverb(x, rt60=4.0, predelay=0.08, wet=0.45, damp=2800, seed=SEED + 61,
               echoes=((0.7, 0.6), (1.6, 0.35)))
    return fade(tape(x, rng, hiss=0.05, lp=5000, drive=1.8), 0.05, 0.4)


def vermelha_c_duas_fitas():
    """Duas gravações da mesma sirene grave tocando juntas, quase em sincronia no início:
    uma acelera e a outra atrasa, o batimento começa lento e grave e vira um ronco;
    os ciclos se desencontram (uma sobe enquanto a outra desce); saturadas juntas
    (intermodulação faz o rumor grave)."""
    rng = np.random.default_rng(SEED + 7)
    t = tsec()
    k = smoothstep(t / DUR)

    def fpos(p):
        return 120 * (430 / 120) ** cyc_profile((p / 5.0) % 1, 0.4, 0.15)

    sa = (1.003 + 0.17 * k ** 1.3) * wow(rng, t, w=0.008, fl=0.006, rnd=0.004, ff=8.1)
    sb = (0.997 - 0.17 * k ** 1.2) * wow(rng, t, w=0.018, fl=0.003, rnd=0.006, wf=0.43)
    tracks = []
    for spd, pos0, lp, seed_off in ((sa, 0.0, 4800, 71), (sb, 0.12, 2600, 72)):
        main, _, _ = play(spd, fpos, rng, pos0, ks=range(1, 15), tilt=0.9)
        sub, _, _ = play(spd, fpos, rng, pos0, ks=(1, 2, 3), tilt=1.0, ratio=0.5)
        tr = norm(main) + 0.6 * norm(sub)
        tr = tape(tr, np.random.default_rng(SEED + seed_off), hiss=0.06, lp=lp, drive=1.7)
        tracks.append(tr)
    x = tracks[0] + 0.9 * tracks[1]
    x = x / np.max(np.abs(x))
    drive = 1.8 + 2.5 * k
    x = np.tanh(drive * (x + 0.2 * x ** 2))
    x = x + 0.5 * norm(lowpass(x, 120, 2)) * np.std(x) * k  # o ronco do batimento
    x = reverb(x, rt60=2.2, predelay=0.04, wet=0.25, damp=3200, seed=SEED + 73)
    return fade(x, 0.01, 0.6)


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "branca_a_fita_limpa": lambda: (branca_a_fita_limpa(), 10.2),
    "branca_b_manivela": lambda: (branca_b_manivela(), 10.2),
    "vermelha_b_uivo": lambda: (vermelha_b_uivo(), 10.2),
    "vermelha_c_duas_fitas": lambda: (vermelha_c_duas_fitas(), 10.2),
    "preta_fita": lambda: (preta_fita(), 10.2),
}
