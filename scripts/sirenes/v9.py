"""Síntese da sirene oficial portada do protótipo v9 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

import nom_synth as S

SEED = 9009
RATE = S.RATE


def ctx(dur):
    n = S.nsamp(dur)
    return n, S.tsec(n)


def fecha(x, t, dur, fade=0.9):
    """O fim já vem composto (o motor parando, a bateria morrendo); a rampa final só garante
    que o arquivo não termina num degrau."""
    return x * (1 - S.smoothstep((t - (dur - fade)) / fade)) * S.smoothstep(t / 0.004)


def cyc_profile(u, rise=0.4, hold=0.15):
    """Perfil 0..1 de um ciclo de sirene (u em 0..1): sobe, segura, desce."""
    fall = 1 - rise - hold
    return np.where(u < rise, S.smoothstep(u / rise),
                    np.where(u < rise + hold, 1.0, 1 - S.smoothstep((u - rise - hold) / fall)))


def contator(rng):
    """Contator da sirene fechando ou abrindo: estalo seco e corpo metálico curto."""
    n = S.nsamp(0.09)
    tt = S.tsec(n)
    clack = S.highpass(rng.standard_normal(n), 1800, 2) * np.exp(-tt / 0.002)
    corpo = np.sin(2 * np.pi * 170 * tt) * np.exp(-tt / 0.014) + 0.5 * np.sin(2 * np.pi * 560 * tt) * np.exp(-tt / 0.007)
    return S.peak(0.7 * S.peak(clack) + S.peak(corpo)) * S.smoothstep(tt / 0.0005)


def pop(rng):
    """Tranco do cone quando o amplificador liga ou desliga."""
    n = S.nsamp(0.15)
    tt = S.tsec(n)
    return S.peak(np.sin(2 * np.pi * 90 * tt) * np.exp(-tt / 0.03) + 0.5 * rng.standard_normal(n) * np.exp(-tt / 0.003))


def transformador(rng):
    """Transformador de bairro estourando: baque grave e seco, arco crepitando, clangor."""
    n = S.nsamp(0.7)
    tt = S.tsec(n)
    f = 44 * (1 + 0.5 * np.exp(-tt / 0.02))
    sub = np.sin(S.phase_of(f)) * np.exp(-tt / 0.06) + 0.6 * np.sin(2 * np.pi * 92 * tt + 1) * np.exp(-tt / 0.04)
    clank = S.bandpass(rng.standard_normal(n), 1100, 2.5) * np.exp(-tt / 0.02)
    arco = np.zeros(n)
    for tc in S.poisson(rng, lambda x: 500.0, 0.0, 0.32):
        S.put(arco, tc, S.estalo(rng, False) * rng.uniform(0.2, 0.9) * np.exp(-tc / 0.15))
    buzz = S.bandpass(rng.standard_normal(n), 2200, 0.6) * (0.35 + 0.65 * np.abs(np.sin(2 * np.pi * 60 * tt)) ** 6)
    arco = arco + 0.3 * S.peak(buzz) * np.exp(-tt / 0.1)
    return S.peak(S.peak(sub) + 0.4 * S.peak(clank) + 0.5 * S.peak(arco)) * S.smoothstep(tt / 0.0008)


def girar(x, t, periodo, fase, brilho):
    """Corneta girando no poste: de frente o som chega cheio e brilhante; de costas, mais baixo
    e abafado. `brilho` (0..1 no tempo) é quanto do "de frente" a névoa ainda deixa passar."""
    face = (0.5 + 0.5 * np.cos(2 * np.pi * t / periodo + fase)) ** 1.6
    escuro = S.lowpass(x, 900, 2)
    claro = x - escuro
    return escuro * (0.55 + 0.25 * face) + claro * (0.12 + face * brilho)


def longe(x, d, seed, rt60=3.0):
    """Posição relativa DENTRO da peça (0 = no poste, 1 = no fundo da cidade)."""
    y = S.lowpass(x, 5500 * (1 - d) + 900 * d, 2)
    wet = 0.1 + 0.5 * d
    w = S.reverb_wet(y, rt60, 0.01 + 0.05 * d, 3500 - 1800 * d, seed)
    return ((1 - wet) * y + wet * w) * 10 ** (-12 * d / 20)


def branca_1(rng):
    """Alerta contínuo: a sirene de rotor sobe e SEGURA o tom (o sinal de alerta de verdade);
    o movimento vem da corneta girando, que passa pelo ouvinte a cada 3,9 s. Cada passada chega
    mais apagada: a névoa vai roubando o brilho, sem baixar o volume. Desliga e o rotor para."""
    dur = 10.6
    n, t = ctx(dur)
    v = S.window(t, 0.15, 7.4, 0.01, 0.01) * (1 + 0.01 * S.smooth_noise(rng, n, 0.5))
    f = S.motor_tensao(v, 472, 0.0, 0.85, 1.7)
    per, fase = 3.9, 2.2
    f = f * (1 - 0.0025 * np.sin(2 * np.pi * t / per + fase))  # Doppler leve da boca girando
    sir = S.sirene(rng, f, drive=1.6, tilt=1.08, rot_rate=np.zeros(n), ar=0.08)
    brilho = 1 - 0.85 * S.smoothstep((t - 1.5) / 6.5)
    x = S.norm(girar(sir, t, per, fase, brilho))
    motor = S.norm(S.lowpass(S.zumbido_rede(rng, n), 500, 2)) * S.lowpass_ctrl(v, 8, 1)
    x = x + 0.008 * motor  # quase nada: 60 Hz forte desde o começo é a assinatura da preta
    for tc in (0.15, 7.4):
        S.put(x, tc, 1.2 * contator(rng))
    plan = {"f": {"sirene": f}, "checar": [(3.0, "sirene"), (6.5, "sirene")],
            "eventos": [(0.15, "contator liga"), (7.4, "contator desliga")]}
    return fecha(x, t, dur), plan


def branca_2(rng):
    """A caixa da estação: wail eletrônico (oscilador varrido) num alto-falante de corneta de
    poste, tocado de um cartucho de fita velho (wow, chiado, duas falhas de contato). Sobe,
    desce, sobe; a fita acaba no topo (estalo da emenda), o zumbido do amplificador fica
    sozinho e o amplificador desliga com um tranco no cone."""
    dur = 10.4
    n, t = ctx(dur)
    kt = [0.0, 0.5, 3.1, 3.5, 6.2, 8.2, 9.0]
    kf = [300, 300, 690, 690, 330, 660, 660]
    f = np.exp(S.lowpass_ctrl(np.interp(t, kt, np.log(kf)), 2.5, 1))
    spd = (1 + 0.006 * np.sin(2 * np.pi * 0.62 * t + 1.0) + 0.0025 * np.sin(2 * np.pi * 6.8 * t)
           + 0.003 * S.smooth_noise(rng, n, 3))
    f = f * spd
    ph = S.phase_of(f, 0.3)
    tom = S.harm(ph, f, range(1, 26, 2), 1.05) + 0.12 * S.harm(ph, f, range(2, 10, 2), 1.3)
    t_fim_fita, t_desliga = 8.9, 9.7
    env = S.window(t, 0.5, t_fim_fita, 0.35, 0.004)
    falhas = ((2.35, 0.06), (5.75, 0.09), (7.1, 0.04))
    gate = np.ones(n)
    for t0, d in falhas:
        gate *= 1 - 0.8 * S.window(t, t0, t0 + d, 0.004, 0.006)
    fita = S.window(t, 0.3, t_fim_fita, 0.02, 0.004)
    amp_on = S.window(t, 0.12, t_desliga, 0.004, 0.004)
    chiado = S.norm(S.highpass(rng.standard_normal(n), 1200, 1)) * (1 + 0.15 * S.smooth_noise(rng, n, 4))
    linha = S.norm(tom) * env * gate + 0.06 * chiado * fita + 0.05 * S.zumbido_rede(rng, n) * amp_on
    for t0, d in falhas:
        S.put(linha, t0, 0.8 * S.estalo(rng, True))
        S.put(linha, t0 + d, 0.5 * S.estalo(rng, True))
    S.put(linha, 0.12, 1.5 * pop(rng))
    S.put(linha, t_fim_fita, 1.0 * S.estalo(rng, True))
    S.put(linha, t_desliga, 1.8 * pop(rng))
    x = S.alto_falante(linha, lo=330, hi=4300, res=1250, res_db=6, drive=2.2)
    plan = {"f": {"oscilador": f}, "checar": [(3.3, "oscilador"), (8.6, "oscilador")],
            "eventos": [(0.12, "amplificador liga"), (t_fim_fita, "fita acaba"), (t_desliga, "amplificador desliga")]}
    return fecha(x, t, dur), plan


def branca_3(rng):
    """Duas notas: sirene de dois rotores no mesmo motor (10 e 12 janelas: terça menor, como as
    de dois tons de verdade), cada corneta virada pra um lado. Quando o motor desliga, a névoa
    engole primeiro a voz aguda; a grave desce sozinha, cada vez mais abafada."""
    dur = 10.5
    n, t = ctx(dur)
    v = S.window(t, 0.15, 6.1, 0.01, 0.01) * (1 + 0.008 * S.smooth_noise(rng, n, 0.7))
    fl = S.motor_tensao(v, 405, 0.0, 1.2, 1.9)
    fh = 1.2 * fl
    rot = np.full(n, 1 / 5.6)
    lo = S.sirene(rng, fl, drive=1.5, tilt=1.1, rot_rate=rot, ar=0.07)
    hi = S.sirene(rng, fh, drive=1.5, tilt=1.15, rot_rate=rot, ar=0.05)
    some = 1 - 0.9 * S.smoothstep((t - 4.6) / 4.0)
    x = S.norm(lo) + 0.8 * S.norm(hi) * some

    def abafa(fr, tc):
        fc = np.exp(np.interp(tc, [0.0, 6.0, 10.0], np.log([9000, 9000, 1100])))
        return 1 / np.sqrt(1 + (fr / fc) ** 4)

    x = S.tv_filter(x, abafa)
    for tc in (0.15, 6.1):
        S.put(x, tc, 1.0 * contator(rng))
    plan = {"f": {"grave": fl, "aguda": fh}, "checar": [(3.0, "aguda", 0.08), (5.0, "grave", 0.08)],
            "eventos": [(0.15, "contator liga"), (6.1, "contator desliga")]}
    return fecha(x, t, dur), plan


def vermelha_1(rng):
    """Toque de fogo: a sirene do quartel em pulsos (liga, desliga), o chamado de bombeiro. Os
    pulsos encurtam e o tom fica preso no alto, num uivo nervoso; o rotor desbalanceia e rosna
    (f/6, ~90-130 Hz). A cada pausa o ar responde com estática. O último toque passa do topo
    e o motor larga, caindo com garganta."""
    dur = 10.5
    n, t = ctx(dur)
    v = np.zeros(n)
    tc, pulsos = 0.15, []
    while tc < 7.3:
        frac = (tc - 0.15) / 7.15
        on = 0.9 * (0.32 / 0.9) ** frac
        off = 0.55 * (0.22 / 0.55) ** frac
        v += S.window(t, tc, tc + on, 0.006, 0.006)
        pulsos.append((tc, on, off))
        tc += on + off
    t_ult = tc + 0.1
    v += 1.12 * S.window(t, t_ult, t_ult + 1.35, 0.006, 0.006)
    # inércia curta na descida: cada pausa derruba o tom ~um terço (o "uóp" sobrevive aos ecos)
    f = S.motor_tensao(v, 760, 0.0, 0.55, 0.6)
    wob = (0.12 + 0.6 * S.smoothstep((t - 1.0) / 7.5)) * np.clip((f - 250) / 350, 0.3, 1.0)
    sir = S.sirene(rng, f, drive=2.3, tilt=0.95, rot_period=3.4, ar=0.13, ports=6, wobble=wob)
    ref = np.std(sir[:S.nsamp(8)])
    rajadas = []
    for i, (t0, on, off) in enumerate(pulsos[3:]):
        rajadas.append((t0 + on + 0.02, 0.8 * min(off, 0.2), 0.45 + 0.08 * i))
    rajadas.append((t_ult + 1.36, 0.3, 0.9))
    nivel = (0.35 + 0.6 * S.smoothstep(t / 9.0)) * (1 - 0.85 * S.smoothstep((t - 8.9) / 1.3))
    st, _ = S.estatica(rng, n, nivel, lambda x: 40 + 15 * x, lambda x: 0.8 + 0.25 * x, rajadas, (), lp=6500)
    x = sir + 0.9 * ref * st
    plan = {"f": {"sirene": f}, "checar": [(pulsos[0][0] + 0.9, "sirene"), (t_ult + 1.3, "sirene")],
            "eventos": [(p[0], f"pulso {i + 1}") for i, p in enumerate(pulsos[:3])] + [(t_ult, "último toque")]}
    return fecha(x, t, dur), plan


def vermelha_2(rng):
    """Megafone rasgado: sirene eletrônica num alto-falante de corneta com o cone rasgado.
    Começa em wail, troca pro yelp (a varredura rápida da urgência) que acelera de 2,6 a 4,8
    varreduras por segundo; o rasgo piora: a aba solta bate a ~88 Hz (a garganta) e raspa nos
    picos. No fim volta ao wail caindo e o amplificador desliga."""
    dur = 10.5
    n, t = ctx(dur)
    lf_a = np.log(380) + (np.log(820) - np.log(380)) * S.smoothstep((t - 0.2) / 2.3)
    rate = np.interp(t, [2.6, 7.4], [2.6, 4.8])
    u = (np.cumsum(rate * (t >= 2.6)) / RATE) % 1
    ysh = np.where(u < 0.75, 0.5 - 0.5 * np.cos(np.pi * u / 0.75), 0.5 + 0.5 * np.cos(np.pi * (u - 0.75) / 0.25))
    lf_b = np.log(440) + np.log(2) * ysh
    lf_c = np.log(800) + (np.log(165) - np.log(800)) * (1 - np.exp(-np.maximum(t - 7.4, 0) / 1.1))
    w_b = S.smoothstep((t - 2.6) / 0.06) * (1 - S.smoothstep((t - 7.4) / 0.06))
    w_c = S.smoothstep((t - 7.4) / 0.06)
    lf = lf_a * (1 - w_b - w_c) + lf_b * w_b + lf_c * w_c
    f = np.exp(S.lowpass_ctrl(lf, 35, 1)) * (1 + 0.004 * S.smooth_noise(rng, n, 2))
    ph = S.phase_of(f)
    tom = S.harm(ph, f, range(1, 22, 2), 0.95) + 0.2 * S.harm(ph, f, range(2, 12, 2), 1.2)
    t_desliga = 9.85
    env = S.window(t, 0.2, t_desliga, 0.12, 0.01) * (1 - 0.6 * S.smoothstep((t - 7.6) / 2.0))
    linha = S.norm(tom) * env
    S.put(linha, t_desliga, 2.0 * pop(rng))
    spk = S.alto_falante(linha, lo=420, hi=3600, res=1050, res_db=7, drive=2.8)
    spk = spk / np.std(spk)
    rasgo = S.smoothstep((t - 2.8) / 4.5)
    aba = 1 - 0.55 * rasgo * (0.5 + 0.5 * np.sin(S.phase_of(88 * (1 + 0.08 * S.smooth_noise(rng, n, 5)))))**3
    e = S.env_follow(spk, 30)
    e = e / e.max()
    raspa = S.norm(S.bandpass(rng.standard_normal(n), 2300, 0.9)) * e ** 2 * rasgo
    y = spk * aba + 0.35 * raspa
    y = np.tanh(1.3 * (y / 3 + 0.2 * (y / 3) ** 2))  # cone rasgado: corta torto (harmônicos pares)
    y = S.highpass(y, 60, 2)
    st, _ = S.estatica(rng, n, 0.25 + 0.3 * rasgo, lambda x: 30.0, lambda x: 0.6, (), (), lp=6000)
    x = y + 0.5 * np.std(y) * st * (1 - S.smoothstep((t - t_desliga) / 0.05))
    plan = {"f": {"oscilador": f}, "checar": [(2.4, "oscilador"), (9.3, "oscilador")],
            "eventos": [(2.6, "troca pro yelp"), (7.4, "volta ao wail"), (t_desliga, "amplificador desliga")]}
    return fecha(x, t, dur), plan


def vermelha_3(rng):
    """Motor disparado: a sirene sobe normal e segura; aos 3,4 s a tensão dispara e o rotor
    passa do topo (540 -> ~740 Hz), gritando com mais ar, o eixo desbalanceando (rosnado) e o
    mancal guinchando. O ar responde com rajadas de estática cada vez mais fortes até o
    disjuntor cair aos 7,9 s; o rotor despenca rosnando."""
    dur = 10.6
    n, t = ctx(dur)
    t_cut = 7.9
    volt = np.interp(t, [0, 0.12, 3.4, 7.6, t_cut], [0, 1, 1, 1.42, 1.42])
    volt = volt * (1 + 0.03 * S.smooth_noise(rng, n, 5) * S.smoothstep((t - 3.4) / 3))
    volt = volt * (1 - S.smoothstep((t - t_cut) / 0.006))
    f = S.motor_tensao(volt, 540, 0.1, 0.95, 1.25)
    wob = 0.1 + 0.75 * S.smoothstep((t - 3.6) / 4.3)
    sir = S.sirene(rng, f, drive=2.4, tilt=0.92, rot_period=5.0, ar=0.17, ports=6, wobble=wob)
    ref = np.std(sir[:S.nsamp(7.5)])
    shaft = (0.5 + 0.5 * np.sin(S.phase_of(f / 6))) ** 2
    guincho = S.norm(S.bandpass(rng.standard_normal(n), 2400, 9)) * shaft \
        * S.smoothstep((t - 4.6) / 2) * (1 - S.smoothstep((t - t_cut - 0.3) / 0.8))
    rajadas = [(5.0, 0.12, 0.5), (6.3, 0.16, 0.7), (7.2, 0.2, 0.85), (t_cut, 0.35, 1.1)]
    nivel = (0.25 + 0.5 * S.smoothstep((t - 3) / 5)) * (1 - 0.8 * S.smoothstep((t - t_cut - 0.4) / 1.5))
    st, _ = S.estatica(rng, n, nivel, lambda x: 60.0 if x < t_cut else 15.0,
                       lambda x: 1.2 if x < t_cut else 0.3, rajadas, (), lp=6500)
    x = sir + 0.12 * ref * guincho + 0.85 * ref * st
    S.put(x, t_cut, 1.6 * ref * contator(rng))
    plan = {"f": {"sirene": f}, "checar": [(3.0, "sirene"), (7.5, "sirene")],
            "eventos": [(3.4, "tensão dispara"), (t_cut, "disjuntor cai")]}
    return fecha(x, t, dur), plan


def putt(rng):
    """Um "putt" de motorboating: o cone dá um tranco grave (72 Hz com harmônico de 144 Hz)."""
    n = S.nsamp(0.14)
    tt = S.tsec(n)
    x = np.sin(2 * np.pi * 72 * tt) * np.exp(-tt / 0.05) + 0.5 * np.sin(2 * np.pi * 144 * tt + 0.4) * np.exp(-tt / 0.03)
    x += 0.25 * S.bandpass(rng.standard_normal(n), 900, 1.2) * np.exp(-tt / 0.006)
    return S.peak(x) * S.smoothstep(tt / 0.002)


def preta_1(rng):
    """Bateria morrendo: abre com o zumbido da rede; aos 0,75 s a rede cai (o relé de
    transferência bate) e a sirene eletrônica passa pra bateria, a única coisa que resiste.
    O oscilador barato acompanha a tensão (o wail vai ficando lento e grave), o amplificador
    corta cada vez mais sujo e, quando a bateria não segura, entra o motorboating (o
    amplificador oscilando em pulsos graves que espaçam). O tom morre e sobram os últimos putts."""
    dur = 10.8
    n, t = ctx(dur)
    t_on = 0.75
    vb = np.interp(t, [0, 2, 5, 8, dur], [1.0, 0.93, 0.74, 0.48, 0.3])
    s = cyc_profile(((t - t_on) / 3.5) % 1, 0.45, 0.12) * (t >= t_on)
    vef = S.lowpass_ctrl(vb - 0.07 * s * vb, 20, 1)  # a bateria afunda sob carga, no topo do wail
    f = (270 + 310 * s) * (0.42 + 0.58 * vef)
    ph = S.phase_of(f)
    tom = S.peak(S.harm(ph, f, range(1, 24, 2), 1.0))
    ligado = S.smoothstep((vef - 0.335) / 0.03) * S.smoothstep((t - t_on) / 0.05)
    y = tom * vef ** 1.3 * ligado
    trilho = 0.25 + 0.75 * vef
    y = trilho * np.tanh(2.2 * y / trilho)
    dz = 0.05 * (1 - vef)  # distorção de cruzamento: a bateria fraca não polariza o transistor
    y = np.sign(y) * np.maximum(np.abs(y) - dz, 0)
    t_mb = 5.4
    prof = S.smoothstep((t - t_mb) / 2.6)
    mph = 2 * np.pi * np.cumsum(np.interp(t, [t_mb, 10.4], [5.5, 1.3]) * (t >= t_mb)) / RATE
    pulso = (0.5 + 0.5 * np.cos(mph)) ** 3
    y = y * (1 - 0.85 * prof * (1 - pulso))
    for tc in S.poisson(rng, lambda x: 1.0 + 0.4 * x, 0.3, dur - 0.5):  # contatos oxidados
        S.put(y, tc, 0.15 * S.estalo(rng, False) * rng.uniform(0.3, 1.0))
    spk = S.alto_falante(y, lo=300, hi=3900, res=1150, res_db=5, drive=1.5)
    ref = np.std(spk[:S.nsamp(3)])
    putts = np.zeros(n)
    voltas = np.floor(mph / (2 * np.pi))
    t_putts = t[1:][np.diff(voltas) > 0]
    for tc in t_putts:
        g = np.interp(tc, t, prof) * (0.5 + 0.5 * np.interp(tc, t, vb)) * (1 - S.smoothstep((tc - 9.9) / 0.8))
        S.put(putts, tc, g * putt(rng))
    x = spk + 1.1 * ref * S.lowpass(putts, 500, 2) + 0.5 * ref * S.alto_falante(putts, 300, 3900, 1150, 5, 1.2)
    rede = S.norm(S.lowpass(S.zumbido_rede(rng, n), 1400, 2)) * S.window(t, 0.0, t_on, 0.15, 0.004)
    x = x + 0.5 * ref * rede
    S.put(x, t_on, 2.5 * ref * contator(rng))
    plan = {"f": {"oscilador": f}, "checar": [(t_on + 1.8, "oscilador"), (t_on + 5.3, "oscilador")],
            "eventos": [(t_on, "rede cai, passa pra bateria"), (t_mb, "motorboating começa")]
            + [(float(tc), "putt") for tc in t_putts[-3:]]}
    return fecha(x, t, dur), plan


def explosao(rng):
    """Uma explosão no cilindro do gerador: baque de escape (52 Hz e harmônicos), sopro e válvula."""
    n = S.nsamp(0.09)
    tt = S.tsec(n)
    thud = (np.sin(2 * np.pi * 52 * tt) * np.exp(-tt / 0.022) + 0.55 * np.sin(2 * np.pi * 104 * tt + 0.5) * np.exp(-tt / 0.015)
            + 0.3 * np.sin(2 * np.pi * 175 * tt) * np.exp(-tt / 0.01))
    sopro = S.lowpass(rng.standard_normal(n), 900, 2) * np.exp(-tt / 0.012)
    valvula = S.bandpass(rng.standard_normal(n), 2600, 2) * np.exp(-tt / 0.004)
    return S.peak(S.peak(thud) + 0.5 * S.peak(sopro) + 0.12 * S.peak(valvula)) * S.smoothstep(tt / 0.001)


def preta_2(rng):
    """O gerador: a sirene do posto ligada num gerador a diesel. O motor tosse três vezes (a
    rotação cai, falha explosões, dá um tiro no escapamento) e a sirene afunda junto, cada vez
    mais fraca; o zumbido do alternador (60 Hz, o som da luz) escorrega pra baixo com a
    rotação. Na terceira o motor afoga: as últimas explosões espaçam, a sirene para e sobram
    os tiques do metal esfriando."""
    dur = 10.8
    n, t = ctx(dur)
    kt = [0, 3.5, 3.7, 4.4, 5.8, 6.0, 6.8, 7.5, 7.65, 8.3, 8.45, 10.0, dur]
    kr = [1, 1, 0.74, 0.93, 0.9, 0.6, 0.8, 0.77, 0.5, 0.57, 0.55, 0.0, 0.0]
    r = np.clip(S.lowpass_ctrl(np.interp(t, kt, kr), 4, 1) * (1 + 0.01 * S.smooth_noise(rng, n, 6)), 0, 1)
    tosse = sum(S.window(t, a, b, 0.05, 0.1) for a, b in ((3.5, 3.95), (5.8, 6.3), (7.5, 7.95)))
    p_falha = 0.03 + 0.5 * tosse + 0.25 * (t > 8.45)
    fph = np.cumsum(24 * r) / RATE
    t_exp = t[1:][np.diff(np.floor(fph)) > 0]
    motor, falha = np.zeros(n), np.zeros(n)
    variantes = [explosao(rng) for _ in range(8)]
    for tc in t_exp:
        rr = np.interp(tc, t, r)
        if rr < 0.04:
            continue
        if rng.random() < np.interp(tc, t, p_falha):
            S.put(falha, tc, S.peak(np.hanning(S.nsamp(0.1))))
            continue
        S.put(motor, tc, variantes[int(rng.integers(8))] * (0.3 + 0.7 * rr ** 0.5) * rng.uniform(0.85, 1.1))
    for tc in (5.98, 7.63):  # tiro no escapamento
        e = S.estalo(rng, True)
        S.put(motor, tc, 1.6 * explosao(rng))
        S.put(motor, tc, 1.2 * e)
    volt = r ** 2 * (1 - 0.15 * np.clip(falha, 0, 1)) * S.smoothstep((t - 0.3) / 0.01)
    f = S.motor_tensao(volt, 430, 0.3, 1.0, 1.7)
    sir = S.sirene(rng, f, drive=1.6, tilt=1.12, rot_period=6.8, ar=0.07, ports=2,
                   wobble=0.25 * np.clip(1 - volt, 0, 1))
    ph_alt = S.phase_of(60 * r)
    alt = sum(a * np.sin(k * ph_alt) for k, a in ((1, 0.5), (2, 1.0), (3, 0.4), (5, 0.2)))
    alt = S.norm(np.tanh(1.4 * alt / np.max(np.abs(alt)))) * r
    tiques = np.zeros(n)
    for tc in sorted(rng.uniform(9.3, 10.4, 5)):
        m = S.nsamp(0.05)
        tt = S.tsec(m)
        S.put(tiques, tc, np.sin(2 * np.pi * rng.uniform(1800, 3200) * tt) * np.exp(-tt / 0.012) * rng.uniform(0.4, 1))
    ref = np.std(S.norm(sir)[:S.nsamp(3.5)])
    x = S.norm(sir) + 0.9 * ref * motor + 0.3 * alt + 0.25 * tiques
    S.put(x, 0.3, 1.0 * contator(rng))
    plan = {"f": {"sirene": f}, "checar": [(3.3, "sirene"), (5.6, "sirene")],
            "eventos": [(3.6, "tosse 1"), (5.98, "tiro no escapamento"), (7.63, "tiro e afoga")]}
    return fecha(x, t, dur), plan


def preta_3(rng):
    """Uma por uma: três sirenes de bairros diferentes, graves (uma oitava abaixo das outras
    névoas) e a meio tom uma da outra, batendo. A cidade apaga de fora pra dentro: o
    transformador do bairro mais longe estoura e a sirene de lá morre; depois a do meio; por
    fim a mais perto, com o baque grande. O zumbido da rede cai um degrau a cada uma e some."""
    dur = 10.6
    n, t = ctx(dur)
    vozes = ((0.15, 4.4, 300.0, 0.85, 8.0), (0.7, 6.3, 318.0, 0.55, 6.5), (1.3, 8.1, 283.0, 0.2, 7.3))
    x = np.zeros(n)
    plan_f = {}
    nomes = ("longe", "meio", "perto")
    for i, (a, b, topo, d, per) in enumerate(vozes):
        piscada = 1 - 0.45 * S.window(t, b - 0.4, b - 0.33, 0.004, 0.004)
        v = S.window(t, a, b, 0.01, 0.006) * piscada * (1 + 0.012 * S.smooth_noise(rng, n, 0.8))
        f = S.motor_tensao(v, topo, 0.0, 1.3, 1.6)
        sir = S.sirene(rng, f, drive=1.7, tilt=1.2, rot_period=per, ar=0.06, ports=2, wobble=np.full(n, 0.3))
        sir = S.norm(S.highpass(sir, 90, 2))  # o peso fica só com os baques
        estouro = np.zeros(n)
        S.put(estouro, b, 2.2 * transformador(rng))
        x += longe(sir + estouro, d, SEED + 300 + i)
        plan_f[nomes[i]] = f
    luz = np.interp(t, [0, 4.4, 4.43, 6.3, 6.33, 8.1, 8.12], [1, 1, 0.62, 0.62, 0.3, 0.3, 0.0])
    treme = 1 - 0.3 * sum(np.exp(-np.maximum(t - b, 0) / 0.4) * (t >= b) * np.abs(S.smooth_noise(rng, n, 12))
                          for _, b, *_ in vozes[:2])
    hum = S.norm(S.lowpass(S.zumbido_rede(rng, n), 1200, 2)) * luz * np.clip(treme, 0, 1) * S.smoothstep(t / 0.3)
    x = x + 0.45 * np.std(x[:S.nsamp(4)]) * hum
    # a do fundo fica 10 dB abaixo e cruza a do meio em ~280 Hz: não dá pra medir no mix
    plan = {"f": plan_f, "checar": [(5.5, "meio", 0.06), (7.5, "perto", 0.06)],
            "eventos": [(4.4, "bairro longe apaga"), (6.3, "bairro do meio apaga"), (8.1, "bairro perto apaga")]}
    return fecha(x, t, dur), plan


# nome -> () -> (sinal seco, crest_db do protótipo); a semente de cada uma vinha da posição
# na lista do protótipo (SEED + 100 * i)
SIRENES = {
    "branca_1": lambda: (branca_1(np.random.default_rng(SEED + 0))[0], 10.4),
    "branca_2": lambda: (branca_2(np.random.default_rng(SEED + 100))[0], 10.4),
    "branca_3": lambda: (branca_3(np.random.default_rng(SEED + 200))[0], 10.4),
    "vermelha_1": lambda: (vermelha_1(np.random.default_rng(SEED + 300))[0], 10.2),
    "vermelha_2": lambda: (vermelha_2(np.random.default_rng(SEED + 400))[0], 10.2),
    "vermelha_3": lambda: (vermelha_3(np.random.default_rng(SEED + 500))[0], 10.2),
    "preta_1": lambda: (preta_1(np.random.default_rng(SEED + 600))[0], 11.0),
    "preta_2": lambda: (preta_2(np.random.default_rng(SEED + 700))[0], 10.8),
    "preta_3": lambda: (preta_3(np.random.default_rng(SEED + 800))[0], 11.5),
}
