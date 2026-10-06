"""Síntese da sirene oficial portada do protótipo v5 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

from sirenes import RATE_GEN, SEED_GEN

RATE = RATE_GEN
SEED = SEED_GEN + 500
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
    """Filtro que varia no tempo: quadros Hann com 50% de sobreposição (somam 1), cada um
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


def peak(x):
    return x / (np.max(np.abs(x)) + 1e-12)


def rms(x):
    return np.sqrt(np.mean(x ** 2))


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


def ramp_out(n, ms=3.0):
    """Corte seco sem degrau: rampa de alguns ms no fim (degrau faz o Vorbis estourar)."""
    m = max(1, int(ms / 1000 * RATE))
    w = np.ones(n)
    w[-m:] = np.linspace(1, 0, m)
    return w


def rotor(p, t_on, t_full, t_off, tau_up=1.5, tau_down=2.2):
    """Rotação de sirene de rotor (0..1) no tempo p: ganha rotação (1 - e^-x), segura e
    perde rotação exponencialmente ao desligar."""
    x = p - t_on
    up = np.where(x < 0, 0.0, (1 - np.exp(-np.maximum(x, 0) / tau_up)) / (1 - np.exp(-(t_full - t_on) / tau_up)))
    up = np.minimum(up, 1.0)
    down = np.exp(-np.maximum(p - t_off, 0) / tau_down)
    return np.where(p < t_full, up, 1.0) * down


def rotor_tone(ph, f):
    """Timbre de sirene de rotor: harmônicos ímpares fortes, pares fracos, corneta em ~1,1 kHz."""
    x = harm(ph, f, range(1, 26, 2), 1.0) + 0.15 * harm(ph, f, range(2, 16, 2), 1.4)
    return x + 0.6 * bandpass(x, 1100, 1.2)


def poisson(rng, rate, t0, t1):
    """Instantes de um processo de Poisson com taxa rate(t) (eventos/s)."""
    out, tc = [], t0
    while True:
        tc += rng.exponential(1 / rate(tc))
        if tc >= t1:
            return out
        out.append(tc)


def estalo_madeira(rng):
    """Estalo seco de madeira perto (tábua que cede sob um passo): clique + modos do corpo."""
    n = int(0.25 * RATE)
    tt = tsec(n)
    body = np.zeros(n)
    for fq, dec, a in ((185, 0.045, 1.0), (410, 0.03, 0.8), (735, 0.02, 0.6), (1260, 0.012, 0.45), (2300, 0.006, 0.3)):
        body += a * np.sin(2 * np.pi * fq * rng.uniform(0.97, 1.03) * tt + rng.uniform(0, 6.28)) * np.exp(-tt / dec)
    click = highpass(rng.standard_normal(n), 1500, 2) * np.exp(-tt / 0.0012)
    e = peak(body) * np.minimum(1, tt / 0.0008) + 0.6 * peak(click)
    return peak(e)


def branca_engolida():
    """0-4 s: sirene de defesa civil cheia e aberta, cidade brilhante com reflexões.
    4-11 s: a névoa chega no som: passa-baixa de 9 kHz a 300 Hz em curva lenta, o reverb
    fica curto, escuro e abafado (as reflexões somem), o tom escorrega um pouco; o volume é
    compensado pra cair pouco: some a definição, não a intensidade (ouvido tampado).
    11-15 s: sobra um sopro grave da sirene (quase só pressão), um zumbido fino de ouvido
    entra devagar e, perto do fim, um único estalo seco e próximo, sem eco. Silêncio."""
    rng = np.random.default_rng(SEED + 1)
    t = tsec()
    s = rotor(t, 0.05, 2.6, 10.6, tau_up=0.85, tau_down=1.6)
    slide = 1 - 0.07 * smoothstep((t - 4) / 7)
    f = (40 + 500 * s) * slide * (1 + 0.003 * smooth_noise(rng, N, 1.5))
    ph = 2 * np.pi * np.cumsum(f) / RATE
    amp = (0.04 + 0.96 * s ** 1.2) * (0.85 + 0.15 * np.cos(2 * np.pi * t / 5.0))
    dry = rotor_tone(ph, f) * amp

    bright = reverb_wet(dry, 3.2, 0.03, 8000, SEED + 11,
                        echoes=((0.21, 0.9), (0.47, 0.75), (0.83, 0.6), (1.35, 0.45), (2.1, 0.3)))
    dark = reverb_wet(dry, 0.3, 0.0, 650, SEED + 12)
    m = smoothstep((t - 4) / 5.5)
    mix = dry + 0.65 * (1 - m) * bright + 0.35 * m * dark

    def log_fc(tc):
        if tc < 3.5:
            return np.log(18000)
        if tc < 4.0:
            return np.log(18000) + (np.log(9000) - np.log(18000)) * (tc - 3.5) / 0.5
        if tc < 11.0:
            u = (tc - 4.0) / 7.0
            u = u * u * (3 - 2 * u)
            return np.log(9000) + (np.log(300) - np.log(9000)) * u
        return np.log(300) + (np.log(200) - np.log(300)) * min(1.0, (tc - 11.0) / 4.0)

    muff = tv_filter(mix, lambda fr, tc: 1 / np.sqrt(1 + (fr / np.exp(log_fc(tc))) ** 6))
    env_in = np.sqrt(np.maximum(lowpass(mix ** 2, 2.5, 1), 1e-12))
    env_out = np.sqrt(np.maximum(lowpass(muff ** 2, 2.5, 1), 1e-12))
    comp = np.clip((env_in / env_out) ** 0.65, 1.0, 4.5)
    comp = comp * (1 - smoothstep((t - 10.5) / 3.5) * 0.25)
    siren = muff * comp

    pressure = lowpass(rng.standard_normal(N), 70, 2)
    pressure = norm(pressure) * rms(siren[:int(10 * RATE)]) * 0.35 * smoothstep((t - 9.5) / 2.0) \
        * (1 - smoothstep((t - 12.5) / 2.0))
    siren = (siren + pressure) * (1 - smoothstep((t - 12.6) / 1.6))

    ref = rms(siren[:int(10 * RATE)])
    tin_f = 6500 * (1 + 0.0006 * smooth_noise(rng, N, 0.5))
    tinn = np.sin(2 * np.pi * np.cumsum(tin_f) / RATE) * smoothstep((t - 11.0) / 2.6) \
        * (1 - smoothstep((t - 14.1) / 0.85)) * ref * 0.055

    snap = np.zeros(N)
    put(snap, 13.65, estalo_madeira(rng) * ref * 2.6)
    return siren + tinn + snap


def swell_invertido(rng, dur, f0, rt60):
    """Nota de sirene tocada ao contrário: na versão direta ataca forte, o tom cai e a cauda
    de reverb some; invertida, cresce do nada (tom subindo) e corta seco no ataque."""
    n = int(dur * RATE)
    tt = tsec(n)
    f = f0 * (1 - 0.3 * smoothstep(tt / dur))
    ph = 2 * np.pi * np.cumsum(f) / RATE + rng.uniform(0, 6.28)
    x = rotor_tone(ph, f) * np.exp(-tt / (0.28 * dur))
    x = 0.35 * x + 0.65 * reverb_wet(x, rt60, 0.02, 3000, int(rng.integers(1 << 30)))
    return peak(x[::-1]) * ramp_out(n)


def preta_inalada():
    """0-3 s: iluminação pública: hum de 60 Hz e reator de vapor (zumbido rouco em 120 Hz),
    duas lâmpadas levemente fora (batimento lento, hipnótico).
    3-11 s: a sirene invertida: 4 swells que crescem do nada e cortam seco, cada um mais
    grave e mais lento; a cada corte a luz pisca (hum some 70-200 ms, com tique elétrico) e
    volta mais fraca e mais instável.
    11-12,8 s: a grande inspiração: tudo junto (sirene, hum, ruído da cidade) invertido,
    cresce e corta no silêncio total; 0,7 s de nada.
    13,5-15 s: no escuro, perto e seco: crepitar baixo de brasa e chiado de fumaça lento
    como uma respiração (o Tição)."""
    rng = np.random.default_rng(SEED + 3)
    t = tsec()
    cuts = [4.4, 6.3, 8.5, 10.8]
    durs = [1.3, 1.6, 1.9, 2.1]
    f0s = [500, 400, 320, 250]
    offs = [0.07, 0.11, 0.16, 0.2]
    t_inhale, t_tic = 12.8, 13.5

    inst = np.zeros(N)
    level = np.ones(N)
    for i, (tc, off) in enumerate(zip(cuts, offs)):
        after = t >= tc + off
        inst[after] = 0.25 * (i + 1)
        level[after] = 0.78 ** (i + 1)
        level[(t >= tc) & (t < tc + off)] = 0.0
    level = np.convolve(level, np.ones(40) / 40, "same")
    fh = 60 * (1 + 0.006 * inst * smooth_noise(rng, N, 3))
    ph = 2 * np.pi * np.cumsum(fh) / RATE
    hum = sum(a * np.sin(h * ph) for h, a in ((1, 1.0), (2, 0.5), (3, 0.6), (5, 0.3), (7, 0.15)))
    lamps = np.zeros(N)
    for det in (1.0, 1.0029):  # 120 Hz e 120,35 Hz: batimento de ~0,35 Hz
        b = np.tanh(5 * np.sin(2 * ph * det + rng.uniform(0, 6.28)))
        b = b * (1 + 0.35 * smooth_noise(rng, N, 400))  # rouquidão
        lamps += 0.6 * lowpass(b, 6000, 2) + 0.4 * highpass(b, 2200, 2)
    light = 0.6 * norm(hum) + 0.5 * norm(lamps)
    unstable = 1 - np.clip(inst * 0.45 * np.abs(smooth_noise(rng, N, 7)), 0, 0.85)
    swallow = 1 + 1.3 * smoothstep((t - 11.0) / (t_inhale - 11.0)) ** 2
    gate = np.clip((t_inhale + 0.003 - t) / 0.003, 0, 1)
    light = light * level * unstable * swallow * smoothstep(t / 0.4) * gate
    ref = rms(light[:int(3 * RATE)])

    ticks = np.zeros(N)
    for tc, off in zip(cuts, offs):
        for tt0, g in ((tc, 1.0), (tc + off, 0.5)):
            n = int(0.03 * RATE)
            e = bandpass(rng.standard_normal(n) * np.exp(-tsec(n) / 0.0015), 3200, 1.5)
            put(ticks, tt0, peak(e) * g * ref * 2.2)

    sw = np.zeros(N)
    for tc, d, f0 in zip(cuts, durs, f0s):
        put(sw, tc - d, swell_invertido(rng, d, f0, rt60=0.9 * d) * ref * 3.4)

    d = t_inhale - 11.0
    n = int(d * RATE)
    tt = tsec(n)
    fa = 190 * (1 - 0.35 * smoothstep(tt / d))
    pha = 2 * np.pi * np.cumsum(fa) / RATE
    phh = 2 * np.pi * np.cumsum(60 * fa / 190) / RATE
    hum_b = np.sin(phh) + 0.5 * np.sin(2 * phh) + 0.6 * np.sin(3 * phh) + 0.3 * np.sin(5 * phh)
    burst = norm(rotor_tone(pha, fa)) + 0.6 * norm(lowpass(rng.standard_normal(n), 900, 2)) + 0.5 * norm(hum_b)
    burst = burst * np.exp(-tt / (0.3 * d))
    burst = 0.3 * burst + 0.7 * reverb_wet(burst, 1.8, 0.02, 2500, SEED + 31)
    inhale = peak(burst[::-1]) * smoothstep(tt / d) ** 0.5 * ramp_out(n)
    big = np.zeros(N)
    put(big, 11.0, inhale * ref * 4.2)

    tic = np.zeros(N)
    for tc in poisson(rng, lambda x: 11.0, t_tic + 0.05, DUR - 0.05):
        n = int(rng.uniform(0.002, 0.005) * RATE)
        e = rng.standard_normal(n) * np.exp(-np.arange(n) / (rng.uniform(0.0004, 0.0012) * RATE))
        e = bandpass(np.concatenate([e, np.zeros(256)]), rng.uniform(1800, 6000), 0.8)
        put(tic, tc, peak(e) * rng.uniform(0.15, 0.6) * (1.8 if rng.random() < 0.12 else 1.0))
    tic = lowpass(tic, 8000, 2) * ref * 1.1
    tb = t - t_tic
    breath = (0.5 - 0.5 * np.cos(2 * np.pi * np.maximum(tb, 0) / 1.3)) ** 1.6
    smoke = bandpass(rng.standard_normal(N), 1500, 0.8) + 0.2 * highpass(rng.standard_normal(N), 4500, 1)
    smoke = lowpass(norm(smoke), 7000, 2) * breath * ref * 0.25
    emb_bed = norm(lowpass(rng.standard_normal(N), 250, 2)) * ref * 0.12
    dark = (tic + smoke + emb_bed) * smoothstep(tb / 0.12) * (t >= t_tic) * np.clip((DUR - t) / 0.25, 0, 1)

    return light + ticks + sw + big + dark


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "branca_engolida": lambda: (branca_engolida(), 10.2),
    "preta_inalada": lambda: (preta_inalada(), 12.0),
}
