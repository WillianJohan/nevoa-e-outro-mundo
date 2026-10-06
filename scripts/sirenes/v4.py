"""Síntese da sirene oficial portada do protótipo v4 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

from sirenes import RATE_GEN, SEED_GEN

RATE = RATE_GEN
SEED = SEED_GEN + 200  # mesma da v2: a branca e o uivo saem dos mesmos sorteios
DUR = 15.0
N = int(round(DUR * RATE))
NYQ_SAFE = 18000.0
INTENSIDADE = 0.4  # "reduza em 60% o efeito do rádio" (1.0 = cadeia da v3)


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


def lag(target, tau, rate=RATE):
    """Inércia de 1ª ordem (constante de tempo tau em s, que pode variar no tempo),
    calculada a 1 kHz e interpolada de volta."""
    step = max(1, rate // 1000)
    tgt = target[::step]
    taus = np.broadcast_to(tau, target.shape)[::step]
    out = np.empty(len(tgt))
    v = tgt[0]
    dt = step / rate
    for i in range(len(tgt)):
        v += (tgt[i] - v) * min(1.0, dt / taus[i])
        out[i] = v
    return np.interp(np.arange(len(target)), np.arange(len(tgt)) * step, out)


def wow(rng, t, w=0.01, fl=0.003, rnd=0.004, wf=0.55, ff=7.3):
    """Velocidade relativa: oscilação lenta, rápida e deriva aleatória (usado só na branca
    e no uivo, que foram aprovados assim)."""
    return (1 + w * np.sin(2 * np.pi * wf * t + rng.uniform(0, 6.28))
            + fl * np.sin(2 * np.pi * ff * t + rng.uniform(0, 6.28))
            + rnd * smooth_noise(rng, len(t), 3))


def cyc_profile(u, rise=0.4, hold=0.15):
    """Perfil 0..1 de um ciclo de sirene (u em 0..1): sobe, segura, desce."""
    fall = 1 - rise - hold
    return np.where(u < rise, smoothstep(u / rise),
                    np.where(u < rise + hold, 1.0, 1 - smoothstep((u - rise - hold) / fall)))


def saida(x, rng, hiss=0.05, lp=5000, hp=90, drive=1.4, bump=0.15):
    """Último estágio: realce grave leve, banda limitada, saturação branda e chiado."""
    x = norm(x)
    x = x + bump * bandpass(x, 110, 1.2)
    x = highpass(lowpass(x, lp, 2), hp, 2)
    x = x / (np.max(np.abs(x)) + 1e-12)
    x = np.tanh(drive * x) / np.tanh(drive)
    h = highpass(rng.standard_normal(N), 1500, 1) + 0.5 * bandpass(rng.standard_normal(N), 5000, 0.7)
    return norm(x) + hiss * norm(h * (1 + 0.12 * smooth_noise(rng, N, 4)))


def banda(x, lo=350, hi=2700):
    return lowpass(highpass(x, lo, 4), hi, 4)


def rumo(v_cheio, v_limpo, k):
    """Interpolação geométrica: k=1 dá o valor do efeito cheio, k=0 o valor limpo
    (pra cortes de filtro, que se afastam proporcionalmente rumo à banda cheia)."""
    return v_limpo * (v_cheio / v_limpo) ** k


def megafone_longe(x, rng, direto=None, portadora=None, rajada=None, intensidade=INTENSIDADE):
    """A cadeia da branca_c_radio (v2), igual pra todas as sirenes. Com intensidade=1 é a
    da v3; com k < 1 cada parte do efeito cai pra k:
    1. distância: pré-atraso (60 ms × k), cauda de cidade aberta (RT60 2,5 s, mistura
       30% × k) e perda de agudos na cauda (amortecimento de 3 kHz rumo a 20 kHz);
    2. banda estreita (350-2700 Hz, abrindo rumo a 20 Hz-20 kHz) e saturação de
       alto-falante pequeno (força × k);
    3. desvanecimento lento (profundidade × k), chiado em banda com estalos e apito fraco
       de 1450 Hz (amplitudes × k);
    4. banda de novo (300-3200 Hz, abrindo igual) com saturação leve e chiado de fundo (× k).
    `direto`: soma depois da distância (som do próprio aparelho, ex.: bipe do rádio).
    `portadora` (0..1 no tempo): aparelho ligado; desligado, o chiado cai quase a zero.
    `rajada`: instante em que a transmissão cai com rajada de chiado (squelch)."""
    k = intensidade
    t = tsec()

    def band(y, lo, hi):
        return banda(y, rumo(lo, 20.0, k), rumo(hi, 20000.0, k))

    x = reverb(x, rt60=2.5, predelay=0.06 * k, wet=0.3 * k, damp=rumo(3000, 20000.0, k), seed=SEED + 41)
    carrier = np.ones(N) if portadora is None else portadora
    prog = norm(x) + (0.0 if direto is None else direto)
    prog = band(prog, 350, 2700)
    prog = np.tanh(max(3.5 * k, 1e-3) * prog / np.max(np.abs(prog)))
    fading = np.clip(1 + 0.22 * k * smooth_noise(rng, N, 0.6), 0.35, 1.3)
    static = band(rng.standard_normal(N), 350, 2700) + (rng.random(N) > 0.9985) * rng.standard_normal(N) * 5
    static = norm(static) * (1 + 0.3 * smooth_noise(rng, N, 5))
    whine = 0.08 * k * np.sin(2 * np.pi * np.cumsum(1450 + 40 * smooth_noise(rng, N, 0.3)) / RATE)
    level = carrier * (0.2 + 0.25 * (1.3 - fading)) + (1 - carrier) * 0.05
    if rajada is not None:
        level = level + np.exp(-np.maximum(t - rajada, 0) / 0.12) * (t >= rajada) * 1.6
    rx = norm(prog) * fading * carrier + static * level * k + whine * carrier
    rx = band(np.tanh(max(1.3 * k, 1e-3) * rx / np.max(np.abs(rx))), 300, 3200)
    return saida(rx, rng, hiss=0.05 * k, lp=rumo(5000, 20000.0, k), hp=rumo(90, 20.0, k),
                 drive=max(1.4 * k, 1e-3), bump=0.15 * k)


def vermelha_uivo():
    """O uivo da v2 (escolhido): a sirene se dobra num uivo com vibrato irregular, quebras
    de registro, ar, formantes largos que derivam (sem vogal) e um rosnado sub antes da
    cauda descendente. Sem o reverb e a fita próprios da v2: a distância agora é a do
    megafone longe."""
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
    return fade(megafone_longe(x, rng), 0.05, 0.4)


def disjuntor(rng):
    """Baque de disjuntor desarmando: estalo do relé, clangor metálico curto e baque grave."""
    n = int(0.7 * RATE)
    tt = np.arange(n) / RATE
    thump = np.sin(2 * np.pi * 46 * tt) * np.exp(-tt / 0.11) + 0.6 * np.sin(2 * np.pi * 92 * tt + 1) * np.exp(-tt / 0.05)
    clank = bandpass(rng.standard_normal(n), 1100, 2.5) * np.exp(-tt / 0.018)
    relay = highpass(rng.standard_normal(n), 2500, 2) * np.exp(-tt / 0.0015)
    return 1.0 * peak(thump) + 0.45 * peak(clank) + 0.3 * peak(relay)


def preta_b_apagao():
    """A sirene começa pelo megafone longe; a energia cai em degraus (com uma piscada antes
    de cada queda). Cada queda: baque de disjuntor perto e o zumbido do transformador que
    desce; a sirene fica mais lenta, mais grave e mais fraca. Na última o rotor roda livre
    até parar e sobra só o hum elétrico, perto, morrendo no escuro."""
    rng = np.random.default_rng(SEED + 12)
    t = tsec()
    drops = [3.0, 5.9, 8.4, 10.5, 12.2]
    levels = [1.0, 0.62, 0.38, 0.22, 0.1, 0.0]
    power = np.full(N, levels[0])
    for td, lv in zip(drops, levels[1:]):
        power[t >= td] = lv
    for td in drops:  # piscada: a energia falha e volta um instante antes de cair
        a = int((td - 0.32) * RATE)
        power[a:a + int(0.06 * RATE)] *= 0.55
    final = drops[-1]
    tau_spd = np.where(t < final, 0.7, 1.3)
    speed = lag(np.sqrt(power), tau_spd)

    cyc = np.cumsum(speed / 3.2) / RATE + 0.1
    s = cyc_profile(cyc % 1, 0.45, 0.1)
    f = (280 + 330 * s) * speed
    ph = 2 * np.pi * np.cumsum(f) / RATE + rng.uniform(0, 6.28)
    sir = harm(ph, f, range(1, 16), 0.95)
    sir = (sir + bandpass(sir, 1000, 1.3)) * speed
    carrier = np.clip(lag(power, np.where(t < final, 0.25, 0.9)), 0, 1) ** 0.5

    ph_lag = lag(power, 0.35)
    fh = 60 * (0.62 + 0.38 * ph_lag) * np.where(t < final, 1.0, np.interp(t, [final, DUR], [1.0, 0.75]))
    phh = 2 * np.pi * np.cumsum(fh) / RATE
    hum = sum(a * np.sin(h * phh) for h, a in ((1, 0.7), (2, 1.0), (3, 0.45), (4, 0.5), (5, 0.2), (6, 0.3),
                                               (8, 0.15), (10, 0.1)))
    hum = np.tanh(1.6 * hum / np.max(np.abs(hum)))  # chapas do transformador vibrando
    surge = sum(np.exp(-np.maximum(t - td, 0) / 0.5) * (t >= td) for td in drops)
    hum_amp = (0.3 + 0.7 * surge) * np.where(t < final, 0.5 + 0.5 * ph_lag, 0.9 * np.exp(-(t - final) / 2.0))
    hum = norm(hum) * hum_amp * smoothstep(t / 0.3)

    rng_d = np.random.default_rng(SEED + 122)
    thumps = np.zeros(N)
    for td in drops:
        d = disjuntor(rng_d)
        k = int(td * RATE)
        seg = d[:N - k]
        thumps[k:k + len(seg)] += seg
    # com a banda aberta, parte do grave cabe no megafone: o amplificador dele está na mesma
    # rede, então zumbe junto e dá um tranco no alto-falante a cada queda
    far = megafone_longe(norm(sir) + 0.3 * hum + 0.5 * thumps, rng, portadora=carrier)
    near = reverb(0.4 * hum + 0.8 * thumps, rt60=0.6, predelay=0.01, wet=0.2, damp=4000, seed=SEED + 121)
    return fade(far + near, 0.01, 0.4)


def poisson(rng, rate, t0=0.0, t1=DUR):
    """Instantes de um processo de Poisson com taxa rate(t) (eventos/s)."""
    out, tc = [], t0
    while True:
        tc += rng.exponential(1 / rate(tc))
        if tc >= t1:
            return out
        out.append(tc)


def put(buf, k, e):
    if k < N:
        seg = e[:N - k]
        buf[k:k + len(seg)] += seg


def brasa(rng):
    """Brasa perto: leito de fogo baixo (ronco e chiado), estalos secos de lenha e carvão
    (miúdos, estouros com corpo e chiado de seiva, e tinidos de carvão), tudo crescendo."""
    t = tsec()
    out = np.zeros(N)
    grow = 0.25 + 0.75 * smoothstep(t / 13)
    for tc in poisson(rng, lambda x: np.interp(x, [0, 15], [4, 45])):  # estalinhos
        n = int(rng.uniform(0.002, 0.006) * RATE)
        e = rng.standard_normal(n) * np.exp(-np.arange(n) / (rng.uniform(0.0004, 0.0015) * RATE))
        e = bandpass(np.concatenate([e, np.zeros(256)]), rng.uniform(2500, 8000), 0.8)
        put(out, int(tc * RATE), peak(e) * rng.uniform(0.08, 0.35) * np.interp(tc, t, grow))
    for tc in poisson(rng, lambda x: np.interp(x, [0, 15], [0.25, 2.2])):  # estouros de lenha
        n = int(0.05 * RATE)
        tt = np.arange(n) / RATE
        body = np.sin(2 * np.pi * rng.uniform(250, 900) * tt) * np.exp(-tt / rng.uniform(0.005, 0.012))
        crack = highpass(rng.standard_normal(n), 1000, 2) * np.exp(-tt / 0.002)
        e = peak(0.7 * peak(body) + peak(crack))
        if rng.random() < 0.45:  # chiado de seiva logo depois
            m = int(rng.uniform(0.06, 0.2) * RATE)
            sz = highpass(rng.standard_normal(m), 3000, 2) * np.exp(-np.arange(m) / (m / 3)) * 0.12
            e = np.concatenate([e, np.zeros(max(0, m - n))])
            e[:m] += sz
        put(out, int(tc * RATE), e * rng.uniform(0.35, 0.8) * np.interp(tc, t, grow))
    for tc in poisson(rng, lambda x: np.interp(x, [0, 15], [0.15, 1.0])):  # tinidos de carvão
        n = int(0.12 * RATE)
        tt = np.arange(n) / RATE
        fq = rng.uniform(2500, 5500)
        dec = rng.uniform(0.015, 0.04)
        e = (np.sin(2 * np.pi * fq * tt) + 0.6 * np.sin(2 * np.pi * fq * 1.47 * tt)) * np.exp(-tt / dec)
        e = e * np.minimum(1, tt / 0.0005)
        put(out, int(tc * RATE), peak(e) * rng.uniform(0.06, 0.18) * np.interp(tc, t, grow))
    roar = lowpass(rng.standard_normal(N), 350, 2) * (1 + 0.5 * smooth_noise(rng, N, 2))
    sizzle = highpass(rng.standard_normal(N), 4000, 1) * (1 + 0.6 * smooth_noise(rng, N, 6))
    bed = (0.1 * norm(roar) + 0.035 * norm(sizzle)) * grow
    out = lowpass(out, 7000, 2)  # ataque menos cortante: o Vorbis estoura em estalo seco demais
    return reverb(out + bed, rt60=0.4, predelay=0.005, wet=0.12, damp=6000, seed=SEED + 131)


def preta_c_brasa():
    """Sirene muito grave e lenta, quase um sopro (tom rico, fundamental 65-140 Hz, com ar
    passando), pelo megafone longe, por baixo de uma brasa perto que cresce. No fim a sirene
    some (o megafone desliga) e fica só a brasa estalando."""
    rng = np.random.default_rng(SEED + 13)
    t = tsec()
    env = smoothstep(t / 2.0) * (1 - smoothstep((t - 9.3) / 3.0))
    s = cyc_profile((t / 6.5 + 0.05) % 1, 0.45, 0.15)
    f = 65 * (140 / 65) ** s * (1 + 0.004 * smooth_noise(rng, N, 2))
    ph = 2 * np.pi * np.cumsum(f) / RATE + rng.uniform(0, 6.28)
    tone = harm(ph, f, range(1, 40), 1.1)
    breath = bandpass(rng.standard_normal(N), 700, 0.6) * (0.4 + 0.6 * s) * (1 + 0.3 * smooth_noise(rng, N, 3))
    sir = (0.6 * norm(tone) + 0.9 * norm(breath)) * env * (0.5 + 0.5 * s)
    far = megafone_longe(sir, rng, portadora=np.clip(env * 1.3, 0, 1))
    near = brasa(rng)
    return fade(far + 12.0 * near, 0.3, 0.3)


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "vermelha_uivo": lambda: (vermelha_uivo(), 9.6),
    "preta_b_apagao": lambda: (preta_b_apagao(), 10.2),
    "preta_c_brasa": lambda: (preta_c_brasa(), 9.0),
}
