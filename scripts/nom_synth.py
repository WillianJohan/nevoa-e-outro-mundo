"""Peças de síntese dos sons do mod (sprint 0034), importadas pelo `gen_sounds.py`.

Tudo é código nosso (numpy). Nenhuma amostra de terceiros é lida aqui.

Saída de `write`: mono, 44,1 kHz, ogg Vorbis q5 via ffmpeg, RMS ~ -12 dBFS e pico <= -1 dBFS
conferido no arquivo DECODIFICADO.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
PEAK = 10 ** (-1.8 / 20)  # -1,8 dBFS antes do Vorbis, que estoura até ~0,7 dB em transientes
CREST_DB = 10.2  # pico/RMS => RMS -12 dBFS com pico em -1,8 dBFS
NYQ_SAFE = 18000.0
MAINS = 60.0  # rede elétrica brasileira


# ----------------------------------------------------------------- utilidades
def tsec(n):
    return np.arange(n) / RATE


def nsamp(dur):
    return int(round(dur * RATE))


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


def lowpass_ctrl(x, fc, order=1, pad_s=2.0):
    """Passa-baixa pra sinal de CONTROLE (tensão, dial): estende as bordas antes do filtro,
    porque o filtro por FFT é circular e o fim vazaria pro começo."""
    k = int(pad_s * RATE)
    y = lowpass(np.concatenate([np.full(k, x[0]), x, np.full(k, x[-1])]), fc, order)
    return y[k:k + len(x)]


def highpass(x, fc, order=2):
    f = _freqs(len(x))
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1 + (fc / f) ** (2 * order)), len(x))


def peaking(x, f0, q, gain_db):
    """Realce (ou corte) de ressonância em f0."""
    g = 10 ** (gain_db / 20) - 1
    return x + g * bandpass(x, f0, q)


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


def window(t, t0, t1, fade_in=0.01, fade_out=0.01):
    """1 entre t0 e t1, com rampas suaves nas bordas."""
    return smoothstep((t - t0) / fade_in) * (1 - smoothstep((t - t1) / fade_out))


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


def phase_of(f, ph0=0.0):
    return 2 * np.pi * np.cumsum(f) / RATE + ph0


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


def poisson(rng, rate, t0, t1):
    """Instantes de um processo de Poisson com taxa rate(t) (eventos/s)."""
    out, tc = [], t0
    while True:
        tc += rng.exponential(1 / max(rate(tc), 1e-6))
        if tc >= t1:
            return out
        out.append(tc)


def env_follow(x, fc=3.0):
    return np.sqrt(np.maximum(lowpass(x ** 2, fc, 1), 1e-12))


# ------------------------------------------------------- finalização e escrita
def limiter_gain(x, thr, k=10):
    """Ganho de um limitador com antecipação (sem distorcer a forma de onda): mínimo do
    ganho necessário numa janela centrada de 2^k amostras, suavizado por média móvel de
    meia janela; assim o ganho nunca passa do necessário em nenhuma amostra."""
    g = np.minimum(1.0, thr / (np.abs(x) + 1e-12))
    m = g.copy()
    for i in range(k):
        s = 1 << i
        m[s:] = np.minimum(m[s:], m[:-s])
    w = 1 << k
    c = np.concatenate([m[w // 2:], np.ones(w // 2)])
    b = w // 2
    cp = np.concatenate([np.ones(b // 2), c, np.ones(b // 2)])
    cs = np.concatenate([[0.0], np.cumsum(cp)])
    return (cs[b:b + len(c)] - cs[:len(c)]) / b


def finalize(x, crest_db=CREST_DB, peak_lin=PEAK):
    """RMS igualado com pico em `peak_lin` (-1,8 dBFS): se o fator de crista (pico/RMS) passa
    do alvo, o limitador baixa os picos (limiar por busca binária); depois o pico é fixado."""
    PEAK = peak_lin  # noqa: N806
    x = x - np.mean(x)
    x = x / rms(x)
    target = 10 ** (crest_db / 20)

    def limited(thr):
        return x * limiter_gain(x, thr)

    def crest(y):
        return np.max(np.abs(y)) / rms(y)

    y = x
    if crest(x) > target:
        lo, hi = 0.2, float(np.max(np.abs(x)))
        for _ in range(30):
            mid = np.sqrt(lo * hi)
            if crest(limited(mid)) > target:
                hi = mid
            else:
                lo = mid
        y = limited(lo)
    return y * min(PEAK / np.max(np.abs(y)), (PEAK / target) / rms(y))


def encode(x, dst):
    pcm = np.round(x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis",
                        "-q:a", "5", "-map_metadata", "-1", "-fflags", "+bitexact", dst], check=True)
    os.unlink(tmp.name)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", dst, "-f", "f32le", "-ac", "1", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


def write(dst, x, crest_db=CREST_DB):
    """Grava o ogg e confere o arquivo decodificado: se o Vorbis estourou -1 dBFS no pico,
    abaixa o ganho e grava de novo. Devolve (RMS dBFS, pico dBFS, duração s)."""
    assert np.all(np.isfinite(x)), dst
    n = len(x)
    # sem energia perto de Nyquist: o Vorbis corta lá em cima e a onda estoura no tempo
    # (medido: +4,8 dB de pico com ruído saturado chegando a 21 kHz)
    x = lowpass(x, 17000, 16)
    limit = 10 ** (-1.05 / 20)
    over_db = 0.0
    for i in range(6):
        # o que o Vorbis estoura vira limitação a mais (pico e crista menores, mesmo RMS)
        z = finalize(x, crest_db - over_db, PEAK * 10 ** (-over_db / 20))
        y = encode(z, dst)
        got = np.max(np.abs(y))
        if got <= limit:
            break
        over_db += 20 * np.log10(got / limit) + 0.1
    else:
        y = encode(z * limit / got * 0.98, dst)
    assert len(y) == n, (dst, len(y), n)
    y = y.astype(np.float64)
    level = 20 * np.log10(rms(y))
    pk = 20 * np.log10(np.max(np.abs(y)))
    print(f"{dst}  ({n / RATE:.3f} s, RMS {level:.1f} dBFS, pico {pk:.2f} dBFS, decodificado)")
    return level, pk, n / RATE


# ----------------------------------------------------------- a sirene física
CTRL = 1000  # Hz da simulação do motor


def _to_audio(v, n):
    tc = np.arange(len(v)) / CTRL
    return np.interp(tsec(n), tc, v)


def motor_ondulante(rng, dur, t_start, t_stop, f_hi, f_lo, top, tau_up, tau_dn, tau_stop):
    """Sinal de ataque: o controlador liga o motor até o tom chegar em ~f_hi e desliga até
    cair a ~f_lo, sem parar. Rotação como inércia de 1ª ordem. Em `t_stop` o motor desliga
    de vez. Devolve a frequência fundamental (Hz) no tempo, na taxa de áudio."""
    m = int(dur * CTRL)
    out = np.zeros(m)
    f, on = 0.0, True
    hi = f_hi * rng.uniform(0.98, 1.02)
    lo = f_lo * rng.uniform(0.97, 1.03)
    dt = 1 / CTRL
    for i in range(m):
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
    return _to_audio(out, nsamp(dur))


def motor_tensao(volt, top, t_start, tau_up, tau_dn):
    """Motor alimentado por uma tensão que varia (0..1, na taxa de áudio): a rotação persegue
    volt*top; sobe com tau_up (torque) e cai com tau_dn (inércia vencendo o atrito)."""
    n = len(volt)
    m = int(n / RATE * CTRL)
    v = np.interp(np.arange(m) / CTRL, tsec(n), volt)
    out = np.zeros(m)
    f = 0.0
    dt = 1 / CTRL
    for i in range(m):
        if i * dt >= t_start:
            tgt = v[i] * top
            f += (tgt - f) * dt / (tau_up if tgt > f else tau_dn)
        out[i] = f
    return _to_audio(out, n)


def sirene(rng, f, drive=1.6, tilt=1.05, rot_rate=None, rot_period=8.0, ar=0.1, ports=0, wobble=None):
    """Sirene mecânica de rotor/estator: fundamental = rotação × janelas; onda quase
    trapezoidal (harmônicos ímpares, pares fracos), corneta com ressonância, ar pelas janelas,
    volume subindo com a rotação, corneta girando e saturação.
    `ports` > 0 liga o rotor desbalanceado: modulação de amplitude na rotação do eixo
    (f/ports) com profundidade `wobble` (array 0..1) — a aspereza grave da sirene."""
    n = len(f)
    ph = phase_of(f, rng.uniform(0, 6.28))
    tone = harm(ph, f, range(1, 32, 2), tilt) + 0.08 * harm(ph, f, range(2, 12, 2), 1.5)
    if ports and wobble is not None:
        shaft = ph / ports
        jit = 1 + 0.15 * smooth_noise(rng, n, 30)
        am = 1 - wobble * (0.5 - 0.5 * np.cos(shaft)) ** 2 * jit
        sub = wobble * 0.35 * np.sin(ph / 2 + 0.3)  # meia-oitava de rotor batendo: dá corpo de garganta
        tone = tone * am + sub
    tone = tone + 0.5 * bandpass(tone, 1000, 1.0)
    rpm = np.clip(f / 650, 0, 1.3)
    air = norm(bandpass(rng.standard_normal(n), 1600, 0.7)) * rpm ** 2 * ar * np.std(tone)
    rate = np.ones(n) / rot_period if rot_rate is None else rot_rate
    face = 0.5 + 0.5 * np.cos(2 * np.pi * np.cumsum(rate) / RATE + rng.uniform(0, 6.28))
    x = (tone + air) * (0.45 + 0.55 * face) + (1 - face) * 0.5 * lowpass(tone, 1200, 2)
    x = x * rpm ** 1.6
    return np.tanh(drive * x / (np.max(np.abs(x)) + 1e-12)) / np.tanh(drive)


def cidade(x, wet, lp, seed):
    """Sirene no alto de um poste, ouvida na rua: perda de agudos, reflexões de prédios."""
    x = lowpass(x, lp, 2)
    return (1 - wet) * x + wet * reverb_wet(x, 2.8, 0.03, 5000, seed,
                                            echoes=((0.18, 0.8), (0.42, 0.6), (0.77, 0.5), (1.25, 0.35), (1.9, 0.2)))


def ar_da_cidade(rng, n):
    return norm(lowpass(rng.standard_normal(n), 300, 2)) + 0.3 * norm(bandpass(rng.standard_normal(n), 900, 0.5))


# ------------------------------------------------------------- a estática
def estalo(rng, forte):
    """Um estalo elétrico: impulso de ruído com decaimento curto e um anel agudo."""
    dur = rng.uniform(0.004, 0.02) if forte else rng.uniform(0.0006, 0.003)
    n = int(dur * RATE) + 64
    tt = tsec(n)
    e = rng.standard_normal(n) * np.exp(-tt / (dur / 4))
    e = bandpass(e, rng.uniform(900, 5000), 0.6)
    if forte:
        e = e + 0.5 * np.sin(2 * np.pi * rng.uniform(1500, 3500) * tt) * np.exp(-tt / (dur / 3))
    return peak(e)


def estatica(rng, n, nivel, crack_rate, pop_rate, rajadas=(), quedas=(), lp=7500):
    """Interferência elétrica: chiado, crepitação miúda, estalos fortes, rajadas (ruído com
    zumbido de 120 Hz e crepitação densa, como arco) e quedas breves.
    Devolve (estática, gate das quedas pra aplicar no sinal)."""
    t = tsec(n)
    dur = n / RATE
    nivel = np.broadcast_to(nivel, (n,)) if np.ndim(nivel) == 0 else nivel
    hiss = lowpass(highpass(rng.standard_normal(n), 250, 2), lp, 2)
    hiss = norm(hiss) * (1 + 0.25 * smooth_noise(rng, n, 3)) * 0.3 * nivel
    crack = np.zeros(n)
    for tc in poisson(rng, crack_rate, 0.0, dur - 0.01):
        put(crack, tc, estalo(rng, False) * rng.lognormal(-1.6, 0.6) * np.interp(tc, t, nivel))
    pops = np.zeros(n)
    for tc in poisson(rng, pop_rate, 0.0, dur - 0.03):
        put(pops, tc, estalo(rng, True) * rng.uniform(0.5, 1.2) * np.interp(tc, t, nivel))
    burst = np.zeros(n)
    buzz = (0.35 + 0.65 * np.abs(np.sin(2 * np.pi * MAINS * t)) ** 6)
    for t0, d, g in rajadas:
        env = smoothstep((t - t0) / 0.012) * (1 - smoothstep((t - t0 - d) / 0.06))
        if not np.any(env > 0):
            continue
        dense = np.zeros(n)
        for tc in poisson(rng, lambda x: 700.0, t0, min(dur - 0.01, t0 + d + 0.06)):
            put(dense, tc, estalo(rng, False) * rng.uniform(0.2, 0.8))
        noise = norm(bandpass(rng.standard_normal(n), 2200, 0.5)) * buzz
        burst += g * env * (0.55 * noise + 1.3 * dense)
        put(pops, t0, estalo(rng, True) * 1.1 * g)
    gate = np.ones(n)
    for t0, d in quedas:
        gate *= 1 - 0.92 * smoothstep((t - t0) / 0.005) * (1 - smoothstep((t - t0 - d) / 0.005))
        put(pops, t0, estalo(rng, True) * 0.6)
        put(pops, t0 + d, estalo(rng, True) * 0.4)
    st = hiss * (0.25 + 0.75 * gate) + 0.9 * crack + 1.1 * pops + burst
    return lowpass(st, min(lp + 1500, 12000), 2), gate


def crepitar(rng, n, rate, t0=0.0, t1=None, lo=1800, hi=6000):
    """Brasa: tiques secos e esparsos de faixa média-alta (sem ritmo, sem tic-tic de Geiger)."""
    t1 = n / RATE - 0.02 if t1 is None else t1
    out = np.zeros(n)
    for tc in poisson(rng, lambda x: rate, t0, t1):
        m = int(rng.uniform(0.002, 0.005) * RATE)
        e = rng.standard_normal(m) * np.exp(-np.arange(m) / (rng.uniform(0.0004, 0.0012) * RATE))
        e = bandpass(np.concatenate([e, np.zeros(256)]), rng.uniform(lo, hi), 0.8)
        put(out, tc, peak(e) * rng.uniform(0.15, 0.6) * (1.8 if rng.random() < 0.12 else 1.0))
    return lowpass(out, 8000, 2)


# ------------------------------------------------- energia elétrica e aparelhos
def zumbido_rede(rng, n, f=MAINS, rouco=0.3, harmonics=((1, 0.6), (2, 1.0), (3, 0.5), (4, 0.35), (5, 0.25), (6, 0.15))):
    """Zumbido de rede/transformador: 60 Hz e harmônicos (o 2º, 120 Hz, domina: magnetostricção),
    um pouco saturado e rouco. É o "som da luz": onde ele some, a luz sumiu."""
    fh = f * (1 + 0.0015 * smooth_noise(rng, n, 0.7))
    ph = phase_of(fh)
    h = sum(a * np.sin(k * ph) for k, a in harmonics)
    h = np.tanh(1.4 * peak(h))
    return norm(h * (1 + rouco * smooth_noise(rng, n, 250) * 0.3))


def bipe(dur, f, h2=-18.0, h3=-15.0, att=0.006, rel=0.02):
    """Bipe quase senoidal (2º e 3º harmônicos fracos), como um tom de teste ou de sinal."""
    n = nsamp(dur)
    tt = tsec(n)
    ph = 2 * np.pi * f * tt
    x = np.sin(ph) + 10 ** (h2 / 20) * np.sin(2 * ph) + 10 ** (h3 / 20) * np.sin(3 * ph)
    env = smoothstep(tt / att) * (1 - smoothstep((tt - dur + rel) / rel))
    return x * env


# Motivo do Outro Mundo (nosso): três notas em intervalos que não resolvem — sobe um trítono
# (600 cents) e desce um semitom. Nada de afinação de referência: notas escolhidas por nós.
MOTIVO = (523.0, 739.6, 698.5)


def motivo(nota=0.26, gap=0.11, notas=MOTIVO, transp=1.0, quantas=3):
    seg = []
    for f in notas[:quantas]:
        seg.append(bipe(nota, f * transp))
        seg.append(np.zeros(nsamp(gap)))
    return np.concatenate(seg)


def alto_falante(x, lo=180, hi=5500, res=1200, res_db=5, drive=1.3):
    """Alto-falante pequeno de aparelho: corta grave e agudo, ressonância do cone, saturação."""
    y = lowpass(highpass(x, lo, 2), hi, 2)
    y = peaking(y, res, 2.0, res_db)
    s = np.std(y) * 3 + 1e-12
    return np.tanh(drive * y / s) * s / drive


def canal_am(x, lo=300, hi=3000):
    """Banda de rádio AM / telefone: 300 Hz a 3 kHz, bordas íngremes."""
    return lowpass(highpass(x, lo, 4), hi, 4)


def desvanecimento(rng, n, fundo=0.25, lento=0.35, rapido=6.0):
    """Desvanecimento seletivo de rádio: quedas lentas e profundas mais um tremor rápido."""
    a = smooth_noise(rng, n, lento)
    b = smooth_noise(rng, n, rapido)
    g = 0.5 + 0.5 * np.tanh(1.2 * a + 0.6)
    return fundo + (1 - fundo) * g * (1 + 0.12 * b)


def chiado_radio(rng, n, centro=1100):
    """Chiado de rádio de banda estreita: ruído colorido + crepitação atmosférica (impulsos),
    com centro BAIXO (~1 kHz) pra não confundir com o chiado do Sem-rosto (2,4 kHz contínuo)."""
    hiss = canal_am(lowpass(rng.standard_normal(n), 700, 1), 250, 3000)  # inclinado pro grave
    hiss = peaking(hiss, centro, 1.0, 4)
    atm = np.zeros(n)
    for tc in poisson(rng, lambda x: 9.0, 0.0, n / RATE - 0.01):
        put(atm, tc, estalo(rng, False) * rng.lognormal(-1.2, 0.7))
    a = canal_am(atm, 250, 3200)
    return norm(hiss) + 3.0 * a / (np.max(np.abs(a)) + 1e-12)


def quase_voz(rng, dur, f0=125.0, sil_rate=3.2, reverso=True, sussurro=0.0, formant_drift=1.0, decai=1.8):
    """A "voz que não é voz": fonte glotal (pulsos com jitter) com entonação de fala,
    filtrada por três formantes que derivam sem nunca firmar uma vogal; sílabas com envelope
    INVERTIDO (cresce devagar e corta seco, como fala tocada ao contrário).
    `sussurro` (0..1) troca a fonte por ruído (estática formando quase-palavras); `decai` é a
    curva da sílaba (menor = sílaba mais cheia)."""
    n = nsamp(dur)
    tt = tsec(n)
    # entonação: frases que caem, com tremor
    phrase = 1.0 + 0.12 * np.cos(2 * np.pi * tt / max(dur / 2.3, 0.6)) - 0.08 * (tt % 1.4) / 1.4
    f = f0 * phrase * (1 + 0.02 * smooth_noise(rng, n, 5) + 0.006 * smooth_noise(rng, n, 40))
    ph = phase_of(f)
    pulses = harm(ph, f, range(1, 40), 1.1)
    src = (1 - sussurro) * norm(pulses) + (sussurro + 0.15) * rng.standard_normal(n)
    d = [smooth_noise(rng, int(dur * 50) + 2, 1.6) for _ in range(3)]
    bases = (rng.uniform(450, 650), rng.uniform(1050, 1500), rng.uniform(2300, 2800))
    spans = (150 * formant_drift, 350 * formant_drift, 300 * formant_drift)

    def formants(fr, tc):
        i = int(np.clip(tc * 50, 0, len(d[0]) - 1))
        return (h_bandpass(fr, bases[0] + spans[0] * d[0][i], 5.0)
                + 0.7 * h_bandpass(fr, bases[1] + spans[1] * d[1][i], 6.0)
                + 0.35 * h_bandpass(fr, bases[2] + spans[2] * d[2][i], 7.0))

    y = tv_filter(np.concatenate([src, np.zeros(4096)]), formants)[:n]
    # sílabas: instantes irregulares; envelope invertido (ataque lento, corte seco)
    env = np.zeros(n)
    tc = rng.uniform(0.02, 0.12)
    while tc < dur - 0.1:
        sd = rng.uniform(0.12, 0.3)
        m = nsamp(sd)
        u = np.linspace(0, 1, m)
        shape = (u ** decai) * ramp_out(m, 6) if reverso else (1 - u) ** decai * smoothstep(u / 0.05)
        put(env, tc, shape * rng.uniform(0.5, 1.0))
        tc += sd + rng.exponential(1 / sil_rate) * 0.6 + 0.04
    env = np.clip(env, 0, 1)
    return peak(y) * env


def sirene_invertida(rng, dur, f_top, f_bot, rt60=1.2):
    """Nota de sirene tocada ao contrário: cresce do nada (tom subindo) e corta seco no topo."""
    n = nsamp(dur)
    tt = tsec(n)
    f = f_top - (f_top - f_bot) * smoothstep(tt / dur)
    ph = phase_of(f, rng.uniform(0, 6.28))
    x = harm(ph, f, range(1, 18, 2), 1.0) * np.exp(-tt / (0.35 * dur))
    x = 0.4 * x + 0.6 * reverb_wet(x, rt60, 0.02, 3500, int(rng.integers(1 << 30)))
    return peak(x[::-1]) * ramp_out(n)


def respiracao(rng, n, periodo=2.6, aspero=0.0, t0=0.0):
    """Respiração pesada perto do microfone: ruído de faixa média que entra e sai; `aspero`
    soma rouquidão (modulação na faixa de ~90 Hz, a aspereza de garganta)."""
    t = tsec(n) - t0
    ph = np.maximum(t, 0) / periodo
    cyc = ph % 1
    si = np.sin(np.pi * np.minimum(cyc, 0.42) / 0.42)
    se = np.sin(np.pi * np.maximum(cyc - 0.5, 0) / 0.5)
    inh = np.where(cyc < 0.42, np.abs(si) ** 1.5, 0.0)
    exh = np.where(cyc >= 0.5, np.abs(se) ** 1.2, 0.0)
    noise = rng.standard_normal(n)
    a = bandpass(noise, 1400, 1.2) * inh * 0.8
    b = bandpass(rng.standard_normal(n), 700, 1.0) * exh
    x = norm(a + b) * (t >= 0)
    if aspero > 0:
        rate = 90 * (1 + 0.1 * smooth_noise(rng, n, 4))
        am = 1 - aspero * (0.5 + 0.5 * np.sin(phase_of(rate))) ** 3
        x = x * am
    return x
