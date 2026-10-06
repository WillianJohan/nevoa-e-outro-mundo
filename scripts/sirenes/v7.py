"""Síntese da sirene oficial portada do protótipo v7 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

from sirenes import RATE_GEN, SEED_GEN
from nom_synth import (lowpass_ctrl, ar_da_cidade, bandpass, canal_am, cidade, crepitar, estatica, estalo,
    highpass, motivo, motor_ondulante, motor_tensao, norm, nsamp, peak, phase_of, put, ramp_out, sirene,
    sirene_invertida, smooth_noise, smoothstep, tsec, tv_filter, zumbido_rede, harm)

SEED = SEED_GEN + 700
DUR = 15.0
N = nsamp(DUR)


def resposta_quebrada(rng, dur, f_lo, ratio=1.5, t_break=0.45):
    """Última resposta no chiado: tom áspero (modulação de ~85 Hz) que salta uma quinta pra
    cima no meio, como voz falhando de registro; banda de rádio."""
    n = nsamp(dur)
    tt = tsec(n)
    f = f_lo * np.where(tt < t_break * dur, 1.0, ratio) * (1 + 0.01 * smooth_noise(rng, n, 8))
    f = lowpass_ctrl(f, 25, 1)
    ph = phase_of(f)
    x = harm(ph, f, range(1, 14), 1.2)
    rough = 1 - 0.6 * (0.5 + 0.5 * np.sin(phase_of(85 * (1 + 0.1 * smooth_noise(rng, n, 6))))) ** 3
    env = smoothstep(tt / 0.08) * ramp_out(n, 4)
    return canal_am(peak(x) * rough * env)


def vermelha_garganta():
    """0-2,5 s: sirene de ataque sobe, motor saudável, estática média.
    2,5-12,9 s: tom ondulante sem parar (~2,2 s por ciclo, 420-720 Hz); o rotor desbalanceia
    aos poucos: modulação na rotação do eixo (f/6 = 70-120 Hz) e meia-oitava batendo, mais
    forte no topo de cada ciclo. Segunda sirene de outro bairro, longe e fora de fase.
    Estática agressiva crescendo; em 6,2, 9,1 e 11,6 s a estática devolve a sirene invertida
    (banda de rádio, cada vez mais alta e mais perto do tom real).
    12,9 s: motor desliga, tom cai em ~1,5 s; em 13,75 s a última resposta salta uma quinta e
    corta; sobra chiado e um estalo."""
    rng = np.random.default_rng(SEED + 1)
    t = tsec(N)
    fa = motor_ondulante(rng, DUR, 0.1, 12.9, 720, 420, 840, 0.9, 2.0, 0.6)
    fb = motor_ondulante(rng, DUR, 0.9, 12.75, 680, 400, 800, 1.05, 1.9, 0.7)
    top = np.clip((fa - 430) / 260, 0.25, 1.0)
    wob = 0.8 * smoothstep((t - 2.5) / 8.5) * top
    a = sirene(rng, fa, drive=2.6, tilt=0.9, rot_period=7.5, ar=0.13, ports=6, wobble=wob)
    b = sirene(rng, fb, drive=2.0, tilt=1.0, rot_period=9.5, ar=0.1)
    sir = cidade(a, 0.3, 9000, SEED + 11) + 0.38 * cidade(b, 0.65, 2400, SEED + 12)
    sir = norm(sir) + 0.04 * ar_da_cidade(rng, N)

    nivel = 0.5 + 0.9 * smoothstep(t / 13.5)
    rajadas = [(2.9, 0.14, 0.45), (5.0, 0.2, 0.55), (7.0, 0.18, 0.7), (8.3, 0.3, 0.8), (10.3, 0.4, 1.0),
               (11.2, 0.25, 1.05), (12.4, 0.45, 1.15), (13.3, 0.3, 0.9), (14.3, 0.35, 0.8)]
    quedas = [(4.3, 0.06), (7.6, 0.08), (9.9, 0.07), (11.05, 0.1), (12.95, 0.09)]
    st, gate = estatica(rng, N, nivel, lambda x: np.interp(x, [0, 15], [70, 260]),
                        lambda x: np.interp(x, [0, 15], [1.2, 5.0]), rajadas, quedas, lp=7000)

    ref = np.std(sir[:nsamp(10)])
    resp = np.zeros(N)
    for t_end, d, ftop, fbot, g in ((6.2, 0.7, 560, 400, 0.35), (9.1, 0.8, 600, 420, 0.5),
                                    (11.6, 0.9, 650, 430, 0.7)):
        r = canal_am(sirene_invertida(rng, d, ftop, fbot, rt60=0.8))
        put(resp, t_end - d, peak(r) * g)
        put(st, t_end, estalo(rng, True) * 0.7)  # o corte seco da resposta estala
    put(resp, 13.75, peak(resposta_quebrada(rng, 0.62, 470)) * 0.75)
    put(st, 13.75 + 0.62, estalo(rng, True) * 0.9)
    resp = resp * ref * 1.15

    out = sir * gate + 1.7 * st * ref + resp
    return out * smoothstep(t / 0.05) * np.clip((DUR - t) / 0.35, 0, 1)


def baque_disjuntor(rng):
    """Disjuntor/transformador desarmando: baque grave e seco (peso no subgrave, cai -20 dB
    em ~0,1 s), corpo de caixa metálica e o arco curto."""
    n = nsamp(0.6)
    tt = tsec(n)
    f = 46 * (1 + 0.5 * np.exp(-tt / 0.02))
    sub = np.sin(phase_of(f)) * np.exp(-tt / 0.045)
    body = (np.sin(2 * np.pi * 92 * tt) * np.exp(-tt / 0.03) + 0.6 * np.sin(2 * np.pi * 233 * tt) * np.exp(-tt / 0.02)
            + 0.35 * np.sin(2 * np.pi * 611 * tt) * np.exp(-tt / 0.012))
    clack = highpass(rng.standard_normal(n), 1200, 2) * np.exp(-tt / 0.003)
    arc = bandpass(rng.standard_normal(n), 3000, 0.7) * np.exp(-tt / 0.03) * (tt < 0.07)
    e = 1.0 * sub + 0.55 * peak(body) + 0.5 * peak(clack) + 0.35 * peak(arc)
    return peak(e * smoothstep(tt / 0.0008))


def preta_apagao():
    """0-4,3 s: zumbido da rede (60 Hz, 120 Hz forte, poste e transformador) e a sirene
    subindo normal. 4,3 / 6,7 / 8,7 s: três quedas de tensão: o tom afunda e volta só em parte,
    o zumbido treme, arco elétrico, e o som inteiro perde brilho em degrau (14k, 6,5k, 3,6k,
    2,2k Hz). 10,4 s: o disjuntor desarma (baque grave e seco), o zumbido morre na hora, a
    sirene desacelera sem força até um gemido grave. No chiado que sobra: o motivo de três
    bipes em 11,9 s e de novo em 13,6 s (período exato), cortado na segunda nota.
    14,1-14,8 s: duas ou três brasas perto, quase nada. Fim no escuro."""
    rng = np.random.default_rng(SEED + 2)
    t = tsec(N)
    sags = [(4.3, 0.3, 0.45, 0.85), (6.7, 0.22, 0.5, 0.7), (8.7, 0.15, 0.55, 0.56)]
    t_off = 10.4
    kt, kv, prev = [0.0], [1.0], 1.0
    for t0, low, d, rec in sags:
        kt += [t0, t0 + 0.02, t0 + d, t0 + d + 0.2]
        kv += [prev, low, low, rec]
        prev = rec
    kt += [t_off, t_off + 0.015]
    kv += [prev, 0.0]
    volt = np.interp(t, kt, kv)
    flick = 1 - 0.07 * np.clip(smooth_noise(rng, N, 6), 0, None) * smoothstep((t - 4.0) / 2)
    volt = volt * flick
    f = motor_tensao(volt, 640, 0.25, 1.0, 1.1)
    tail = t >= t_off
    f = np.where(tail, f[np.argmax(tail)] * np.exp(-(t - t_off) / 1.6), f)
    vl = lowpass_ctrl(volt, 2, 1)
    sir = sirene(rng, f, drive=1.6, tilt=1.05, rot_rate=np.clip(vl, 0, 1) / 8.0, ar=0.1)
    sir = norm(cidade(sir, 0.4, 9000, SEED + 21)) + 0.03 * ar_da_cidade(rng, N)

    surge = sum(np.exp(-np.maximum(t - t0, 0) / 0.6) * (t >= t0) for t0, *_ in sags)
    hum = zumbido_rede(rng, N) * (0.16 + 0.22 * surge) * (0.4 + 0.6 * np.clip(vl, 0, 1)) \
        * (1 + 0.25 * smooth_noise(rng, N, 7) * np.clip(surge, 0, 1))
    hum = hum * (1 - smoothstep((t - t_off) / 0.015)) * smoothstep(t / 0.25)

    # escuridão em degraus: o brilho do som cai a cada queda e de vez no apagão
    steps = [(0.0, 14000), (4.3, 5000), (6.7, 2600), (8.7, 1600), (t_off, 950)]

    def fc_at(tc):
        lf = np.log(steps[0][1])
        for t0, fc in steps[1:]:
            lf = lf + (np.log(fc) - lf) * smoothstep((tc - t0) / 0.08)
        if tc > t_off:
            lf = lf + (np.log(520) - np.log(950)) * smoothstep((tc - t_off) / 3.5)
        return np.exp(lf)

    lit = tv_filter(sir + hum, lambda fr, tc: 1 / np.sqrt(1 + (fr / fc_at(tc)) ** 6), frame=2048)
    ref = np.std(lit[:nsamp(4)])

    nivel = 0.5 * (0.35 + 0.65 * np.clip(vl, 0, 1)) * np.where(t < t_off, 1.0, 0.0)
    rajadas = []
    for t0, low, d, _ in sags:
        rajadas += [(t0 + 0.005, d * 0.8, 1.0 + (1 - low)), (t0 + d * 0.5, 0.12, 0.6)]
    rajadas += [(t_off + 0.004, 0.35, 1.6)]
    quedas = [(t0 + 0.02, 0.05) for t0, *_ in sags]
    st, gate = estatica(rng, N, nivel + 0.6 * (np.abs(t - t_off - 0.15) < 0.25), lambda x: 50.0 if x < t_off else 1.0,
                        lambda x: 0.6 if x < t_off else 0.05, rajadas, quedas, lp=7000)
    # a estática escurece junto, 250 ms atrasada: o clarão do arco passa, depois o escuro fecha
    st = tv_filter(st, lambda fr, tc: 1 / np.sqrt(1 + (fr / (1.15 * fc_at(tc - 0.25))) ** 6), frame=2048)

    # o chiado que sobra no escuro: rádio fraco, banda estreita, sumindo
    hiss = canal_am(rng.standard_normal(N), 280, 3500)
    hiss = norm(hiss) * smoothstep((t - t_off - 0.2) / 0.6) * (0.55 - 0.3 * smoothstep((t - 12) / 3)) \
        * (1 + 0.3 * smooth_noise(rng, N, 2)) * np.clip((DUR - 0.2 - t) / 0.4, 0, 1)

    sig = np.zeros(N)
    m1 = motivo()
    put(sig, 11.9, m1)
    m2 = motivo(quantas=2)
    cut = nsamp(0.26 + 0.11 + 0.15)  # a segunda nota é cortada no meio
    m2 = m2[:cut] * ramp_out(cut, 3)
    put(sig, 11.9 + 1.7, m2)
    sig = canal_am(sig, 300, 3000) * (1 + 0.15 * smooth_noise(rng, N, 5))
    put(st, 11.9 + 1.7 + 0.52, estalo(rng, True) * 0.5)

    thump = np.zeros(N)
    put(thump, t_off, baque_disjuntor(rng))
    embers = crepitar(rng, N, 4.5, 14.1, 14.8, 1500, 4500)

    out = (lit * gate + 1.5 * st * ref + 0.16 * ref * hiss + 0.55 * ref * sig
           + 3.2 * ref * thump + 0.9 * ref * embers)
    return out * smoothstep(t / 0.05) * np.clip((DUR - t) / 0.2, 0, 1)


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "vermelha_garganta": lambda: (vermelha_garganta(), 10.0),
    "preta_apagao": lambda: (preta_apagao(), 10.4),
}
