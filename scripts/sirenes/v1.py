"""Síntese da sirene oficial portada do protótipo v1 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O protótipo tinha 45 s, longe demais dos
10–12 s pedidos pra caber num encurtamento sem mudar o tom. Por isso aqui ele foi refeito
direto na duração nova, com os mesmos timbres e gestos: a branca dá UMA volta (sobe, segura,
cai) em vez de duas, e na preta os surtos de zumbido, o dial e as duas sirenes ao contrário
foram reposicionados no tempo curto. Quem põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

from sirenes import RATE_GEN, SEED_GEN

RATE = RATE_GEN
SEED = SEED_GEN + 100
DUR = 10.6
N = int(DUR * RATE)


def _freqs(n):
    return np.maximum(np.fft.rfftfreq(n, 1 / RATE), 1e-3)


def bandpass(x, f0, q):
    """Passa-banda de 2 polos por FFT (pico de ganho 1 em f0)."""
    f = _freqs(len(x))
    h = 1 / (1 + 1j * q * (f / f0 - f0 / f))
    return np.fft.irfft(np.fft.rfft(x) * h, len(x))


def lowpass(x, fc, order=2):
    f = _freqs(len(x))
    h = 1 / np.sqrt(1 + (f / fc) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x) * h, len(x))


def highpass(x, fc, order=2):
    f = _freqs(len(x))
    h = 1 / np.sqrt(1 + (fc / f) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x) * h, len(x))


def smooth_noise(rng, n, fc):
    """Ruído lento (passa-baixa em fc Hz) com desvio padrão ~1: deriva aleatória."""
    x = lowpass(rng.standard_normal(n), fc, 2)
    return x / (np.std(x) + 1e-12)


def smoothstep(x):
    s = np.clip(x, 0, 1)
    return s * s * (3 - 2 * s)


def fftconv(x, ir):
    n = len(x) + len(ir)
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return y[:len(x)]


def reverb(x, rt60=4.0, predelay=0.06, wet=0.5, damp=3500, seed=0, echoes=()):
    """Reverb por convolução com resposta sintética: cauda de ruído que decai (rt60),
    escurecendo (damp) e reflexões distantes discretas `echoes` = ((atraso s, ganho), ...)."""
    rng = np.random.default_rng(seed)
    n = int(rt60 * 1.15 * RATE)
    t = np.arange(n) / RATE
    ir = rng.standard_normal(n) * 10 ** (-3 * t / rt60) * np.minimum(1, t / 0.03)
    ir = lowpass(ir, damp, 1)
    pre = int(predelay * RATE)
    ir = np.concatenate([np.zeros(pre), ir])
    for delay, gain in echoes:  # prédios longe: eco borrado, não um estalo seco
        k = int(delay * RATE)
        m = int(0.12 * RATE)
        if k + m < len(ir):
            burst = lowpass(rng.standard_normal(m), 1800, 1) * np.hanning(m)
            ir[k:k + m] += gain * burst / (np.std(burst) + 1e-12) * np.std(ir[pre:pre + 4000] + 1e-12) * 3
    ir = ir / np.sqrt(np.sum(ir ** 2))
    y = fftconv(x, ir)
    return (1 - wet) * x + wet * y * np.std(x) / (np.std(y) + 1e-12)


def wave_harm(phase, ks, tilt=1.0):
    return sum(np.sin(k * phase) / k ** tilt for k in ks)


def tsec():
    return np.arange(N) / RATE


def fade(x, fin=0.02, fout=1.5):
    t = tsec()
    return x * np.minimum(1, t / fin) * np.minimum(1, (DUR - t) / fout)


def branca_melhorada():
    """Sirene de defesa civil clássica: sobe devagar (rotor ganhando rotação), segura,
    cai ainda mais devagar; uma volta. Corneta com ressonância, alto-falante velho saturando
    e cidade vazia (reverb longo + reflexões distantes)."""
    rng = np.random.default_rng(SEED + 1)
    t = tsec()
    period = DUR
    u = (t / period) % 1
    up = smoothstep(u / 0.42)
    down = 1 - smoothstep((u - 0.58) / 0.42)
    s = np.where(u < 0.42, up, np.where(u < 0.58, 1.0, down))
    s = s + 0.012 * np.sin(2 * np.pi * 0.9 * t) * np.where((u >= 0.42) & (u < 0.58), 1, 0.3)
    f0 = 190 * (560 / 190) ** s
    amp = (0.3 + 0.7 * np.maximum(s, 0) ** 0.6)  # no fim da volta curta o tremor deixa s < 0 * (1 + 0.16 * np.sin(2 * np.pi * 0.27 * t))  # corneta girando
    phase = 2 * np.pi * np.cumsum(f0) / RATE + rng.uniform(0, 2 * np.pi)
    horn = wave_harm(phase, range(1, 15), 0.9)
    horn = horn + 1.2 * bandpass(horn, 950, 1.2)  # ressonância da corneta
    x = horn * amp
    x = highpass(lowpass(x, 4200, 2), 170, 2)  # alto-falante velho: sem grave nem brilho
    x = x / np.max(np.abs(x))
    x = np.tanh(2.4 * x + 0.25 * x ** 2) + 0.012 * rng.standard_normal(N)  # saturação + chiado
    x = reverb(x, rt60=5.5, predelay=0.09, wet=0.6, damp=3000, seed=SEED + 11,
               echoes=((0.7, 0.9), (1.45, 0.7), (2.4, 0.5), (3.6, 0.3)))
    return fade(x, 0.15, 2.5)


def preta_c_silencio():
    """Quase silêncio: zumbido elétrico (60 Hz + harmônicos, com surtos de buzz), rádio fora
    de sintonia varrendo o dial e uma sirene distante tocada ao contrário, com reverb."""
    rng = np.random.default_rng(SEED + 5)
    t = tsec()
    # zumbido 60 Hz
    hum = np.zeros(N)
    for h, a in ((1, 1.0), (2, 0.55), (3, 0.9), (4, 0.3), (5, 0.35), (6, 0.12), (8, 0.08)):
        hum += a * np.sin(2 * np.pi * 60 * h * t + rng.uniform(0, 6.28))
    hum = hum * (1 + 0.08 * np.sin(2 * np.pi * 0.23 * t) + 0.05 * smooth_noise(rng, N, 2))
    burst = np.zeros(N)
    for tb in (1.8, 5.2, 8.6):
        d = rng.uniform(0.6, 1.4)
        burst[int(tb * RATE):int((tb + d) * RATE)] = 1
    burst = lowpass(burst, 6, 1)
    buzz = highpass(np.tanh(4 * np.sin(2 * np.pi * 120 * t)), 400, 1) * burst
    hum = hum / np.std(hum) * 0.9 + 0.5 * buzz / (np.std(buzz) + 1e-12) * burst
    # rádio varrendo
    centers = np.geomspace(250, 6500, 14)
    bands = [bandpass(rng.standard_normal(N), c, 5) for c in centers]
    knots = rng.uniform(0, len(centers) - 1, 5)  # a mesma velocidade de dial do protótipo
    knots_t = np.linspace(0, DUR, len(knots))
    c = np.interp(t, knots_t, knots)
    # suaviza o "botão do dial": passos com deslizamento
    c = lowpass(c, 0.4, 1)
    radio = np.zeros(N)
    for i, b in enumerate(bands):
        radio += b / (np.std(b) + 1e-12) * np.exp(-((c - i) ** 2) / 1.2)
    radio = radio * (0.5 + 0.5 * np.sin(2 * np.pi * 0.08 * t + 1) ** 2)
    tune = 300 + 1500 * smoothstep((np.sin(2 * np.pi * 0.05 * t + 0.5) + 1) / 2)
    whistle = np.sin(2 * np.pi * np.cumsum(tune) / RATE) * np.exp(-((c - 6) ** 2) / 4) * 0.6
    radio = radio + whistle
    # sirene distante tocada ao contrário
    def distant_siren(seconds, f_lo, f_hi, seed, tail):
        r = np.random.default_rng(seed)
        n = int(seconds * RATE)
        tt = np.arange(n) / RATE
        s = smoothstep(tt / (seconds * 0.4)) * (1 - 0.6 * smoothstep((tt - seconds * 0.55) / (seconds * 0.3)))
        f = f_lo * (f_hi / f_lo) ** s
        ph = 2 * np.pi * np.cumsum(f) / RATE + r.uniform(0, 6.28)
        w = wave_harm(ph, range(1, 10), 1.0) * np.minimum(1, tt / 0.3) * np.minimum(1, (seconds - tt) / 2.0)
        w = lowpass(w, 1700, 2)
        pad = np.concatenate([w, np.zeros(int(tail * RATE))])  # espaço pra cauda do reverb
        pad = reverb(pad, rt60=6.0, predelay=0.12, wet=0.9, damp=2000, seed=seed,
                         echoes=((0.9, 0.6), (2.0, 0.4), (3.2, 0.25)))
        return pad[::-1]
    out = hum * 0.5 + radio / np.std(radio) * 0.42
    for start, seconds, lo, hi, gain, seed, tail in ((2.6, 6.0, 150, 480, 1.0, SEED + 51, 3.0),
                                                     (0.4, 3.0, 210, 360, 0.4, SEED + 52, 3.0)):
        rev = distant_siren(seconds, lo, hi, seed, tail)
        rev = rev / np.std(rev) * gain * 0.75
        i0 = int(start * RATE)
        seg = rev[:max(0, N - i0)]
        env = np.minimum(1, np.arange(len(seg)) / (0.5 * RATE))
        out[i0:i0 + len(seg)] += seg * env
    return fade(out, 0.6, 1.5)


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "branca_melhorada": lambda: (branca_melhorada(), 10.2),
    "preta_c_silencio": lambda: (preta_c_silencio(), 10.2),
}
