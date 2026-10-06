"""Síntese da sirene oficial portada do protótipo v8 (sprint 0034, tarefa 3).

Código nosso (numpy), sem amostra de terceiros. O corpo das funções é o do protótipo que o
Johan aprovou, sem mudança: quem encurta, põe o eco de cidade e grava é o
`scripts/gen_sounds.py`. Semente fixa.
"""
import numpy as np

import nom_synth as S

SEED = 8008
DUR = 15.0
N = S.nsamp(DUR)
T = S.tsec(N)
SEMI = 2 ** (1 / 12)
# reflexões de prédios e morros, borradas pela névoa: (atraso s, ganho)
ECOS_NEVOA = ((0.9, 0.8), (1.75, 0.55), (2.7, 0.35))
ECOS_RUA = ((0.21, 0.6), (0.47, 0.45), (0.83, 0.3))


def win(t0, t1, a=0.02, r=0.02):
    return S.window(T, t0, t1, a, r)


def fim(x, t0=14.1):
    """A cauda some até 15 s (o arquivo nunca termina num degrau)."""
    return x * (1 - S.smoothstep((T - t0) / (DUR - t0 - 0.03)))


def nevoa(x, dist, seed, rt60=3.6, echoes=()):
    """Fonte a `dist` (0 perto, 1 no fundo da névoa): perde agudo, ganha reverb e cai de nível."""
    lp = 6500 * (1 - dist) + 1100 * dist
    y = S.lowpass(x, lp, 2)
    wet = 0.2 + 0.65 * dist
    w = S.reverb_wet(y, rt60, 0.015 + 0.06 * dist, 4000 - 2200 * dist, seed, echoes)
    return ((1 - wet) * y + wet * w) * 10 ** (-10 * dist / 20)


def ar_nevoa(rng):
    """Ar parado da névoa: rumor grave quase inaudível, só pra não haver silêncio digital."""
    return S.norm(S.lowpass(S.ar_da_cidade(rng, N), 350, 2))


def zumbido_luz(rng):
    """O som da luz: rede de 60 Hz e reator de lâmpada, abafado."""
    return S.norm(S.lowpass(S.zumbido_rede(rng, N), 1400, 2))


def disjuntor(rng):
    """Disjuntor da cidade desarmando: baque grave, estalo e anel metálico curto."""
    n = S.nsamp(0.5)
    tt = S.tsec(n)
    ph = 2 * np.pi * (46 * tt + 34 * 0.03 * (1 - np.exp(-tt / 0.03)))
    x = np.sin(ph) * np.exp(-tt / 0.09)
    x += 0.22 * np.sin(2 * np.pi * 2150 * tt) * np.exp(-tt / 0.05)
    x += 0.12 * np.sin(2 * np.pi * 3370 * tt) * np.exp(-tt / 0.03)
    e = S.estalo(rng, True)
    x[:len(e)] += 0.8 * e
    return x


def lampada_queima(rng):
    """Lâmpada queimando: tique de vidro agudo e um chiado de filamento que morre."""
    n = S.nsamp(0.35)
    tt = S.tsec(n)
    x = 0.5 * np.sin(2 * np.pi * 4200 * tt) * np.exp(-tt / 0.012)
    x += 0.35 * S.bandpass(rng.standard_normal(n), 3000, 1.5) * np.exp(-tt / 0.07)
    e = S.estalo(rng, True)
    x[:len(e)] += e
    return x


def fumaca(rng, periodo=3.4):
    """Fumaça saindo: sopro de faixa média que respira devagar."""
    x = S.norm(S.bandpass(rng.standard_normal(N), 520, 0.6) + 0.4 * S.bandpass(rng.standard_normal(N), 2600, 0.8))
    breath = 0.35 + 0.65 * (0.5 - 0.5 * np.cos(2 * np.pi * T / periodo)) ** 2
    return x * breath * (1 + 0.3 * S.smooth_noise(rng, N, 1.5))


def brasas(rng, t0, rate=7.0):
    """Crepitar de brasa que vai adensando a partir de t0."""
    return S.crepitar(rng, N, rate, t0, DUR - 0.05) * S.smoothstep((T - t0) / 5.0)


def diafone(rng, t0, dur, f0, grunt=0.5, drop=0.78, growl=0.0, glide=1.0, n=N):
    """Buzina de névoa (diafone): pistão que corta o ar, som de palheta rico em harmônicos,
    corneta com ressonância. Começa com um ronco curto de pressão subindo; no fim, o
    "grunhido": a pressão cai e o tom despenca pra f0*drop. `glide` sobe o tom ao longo do
    toque (antinatural: a buzina que grita); `growl` é aspereza de garganta (~33 Hz)."""
    t = S.tsec(n)
    u = t - t0
    f = f0 * (0.88 + 0.12 * S.smoothstep(u / 0.18))
    f = f * (1 + (glide - 1) * S.smoothstep(u / dur))
    f = f * (1 - (1 - drop) * S.smoothstep((u - (dur - grunt)) / grunt))
    f = f * (1 + 0.003 * S.smooth_noise(rng, n, 2.0))
    ph = S.phase_of(f, rng.uniform(0, 6.28))
    src = S.harm(ph, f, range(1, 48), 0.85)
    src = S.peaking(src, 420, 1.5, 6)
    src = S.peaking(src, 1250, 2.0, 3)
    env = S.smoothstep(u / 0.09) * (1 - S.smoothstep((u - (dur - 0.7 * grunt)) / (0.7 * grunt)))
    dark = S.lowpass(src, 500, 2)
    x = dark + env ** 1.5 * (src - dark)  # pressão menor = som mais escuro
    blat = S.bandpass(rng.standard_normal(n), 300, 0.7) * np.exp(-np.maximum(u, 0) / 0.05) * (u >= 0)
    air = S.bandpass(rng.standard_normal(n), 900, 0.8) * 0.06
    x = S.norm(x) + 0.8 * S.peak(blat) + S.norm(air) * 0.06
    if growl > 0:
        rate = 33 * (1 + 0.15 * S.smooth_noise(rng, n, 6))
        x = x * (1 - growl * (0.5 + 0.5 * np.sin(S.phase_of(rate))) ** 2)
    x = np.tanh(1.6 * x / 3.0) * env
    return x


def branca_a(rng):
    """O Chamado e a Resposta: a sirene da cidade chama; dois segundos depois a névoa responde
    meio tom abaixo, de longe. No segundo chamado a resposta já vem de perto."""
    v_call = win(0.15, 5.2) + win(8.0, 10.6)
    v_resp = win(2.15, 7.2) + win(10.0, 12.6)
    f_call = S.motor_tensao(v_call, 480, 0.0, 0.9, 1.6)
    f_resp = S.motor_tensao(v_resp, 480 / SEMI, 0.0, 0.95, 1.6)
    call = S.sirene(rng, f_call, drive=1.5, tilt=1.1, rot_period=7.0, ar=0.08)
    resp = S.sirene(rng, f_resp, drive=1.3, tilt=1.2, rot_period=5.3, ar=0.05)
    split = S.smoothstep((T - 9.5) / 0.4)  # entre as respostas o rotor quase parou
    x = nevoa(call, 0.35, SEED + 11, echoes=ECOS_RUA)
    x += nevoa(resp * (1 - split), 0.9, SEED + 12, rt60=4.5, echoes=ECOS_NEVOA)
    x += 1.15 * nevoa(resp * split, 0.3, SEED + 13, rt60=3.0)
    x += 0.02 * ar_nevoa(rng)
    plan = {"voz": {"chamado": f_call, "resposta": f_resp},
            "checar": [(4.5, "chamado"), (6.8, "resposta"), (10.4, "chamado"), (12.4, "resposta")],
            "eventos": [(0.15, "chamado liga", "sobe"), (2.15, "resposta liga", "sobe")]}
    return fim(x), 10.8, plan


def preta_a(rng):
    """A Resposta no Escuro: a cidade chama com luz (zumbido de rede); a energia cai, o motor
    morre em queda lenta; do escuro responde uma sirene uma oitava abaixo. A cidade tenta
    religar, pisca e falha. Sobram brasas e fumaça."""
    pisca = [(11.55, 11.72), (11.88, 12.14), (12.24, 12.62)]
    # a rede já chega fraca: quedas de tensão desde o primeiro segundo (a sirene oscila e o
    # zumbido treme junto), é o que separa a preta da branca logo no começo
    queda = 1 - 0.3 * S.smoothstep((S.smooth_noise(rng, N, 3.0) - 0.4) / 0.6)
    v_call = win(0.1, 4.1, 0.02, 0.005) * queda + sum(0.8 * win(a, b, 0.004, 0.004) for a, b in pisca)
    f_call = S.motor_tensao(v_call, 470, 0.0, 0.9, 2.6)
    religa = T >= 11.4  # aqui o rotor já parou (< 30 Hz): a tentativa vira uma voz com nível próprio
    call = S.sirene(rng, f_call * ~religa, drive=1.5, tilt=1.1, rot_period=7.0, ar=0.08)
    call += 0.55 * S.sirene(rng, f_call * religa, drive=1.8, tilt=1.1, rot_period=7.0, ar=0.08)
    v_resp = win(6.3, 11.0, 0.3, 0.02)
    f_resp = S.motor_tensao(v_resp, 235, 0.0, 2.0, 2.4)
    resp = S.sirene(rng, f_resp, drive=1.8, tilt=1.3, rot_period=9.0, ar=0.03, ports=2, wobble=np.full(N, 0.55))
    luz = win(0.0, 4.1, 0.05, 0.004) * queda ** 2 + sum(win(a, b, 0.003, 0.003) for a, b in pisca)
    x = nevoa(call, 0.4, SEED + 31, echoes=ECOS_RUA)
    x += 1.6 * nevoa(S.lowpass(resp, 700, 2), 0.75, SEED + 32, rt60=5.0, echoes=ECOS_NEVOA)
    x += 0.1 * zumbido_luz(rng) * luz
    S.put(x, 4.1, 0.9 * disjuntor(rng))
    for a, _ in pisca:
        S.put(x, a, 0.3 * S.estalo(rng, True))
    S.put(x, 12.62, 0.5 * disjuntor(rng))
    x += 0.35 * brasas(rng, 4.3)
    x += 0.025 * fumaca(rng) * S.smoothstep((T - 5.0) / 5.0)
    x += 0.02 * ar_nevoa(rng)
    plan = {"voz": {"chamado": f_call, "resposta": f_resp},
            "checar": [(3.8, "chamado"), (10.8, "resposta"), (12.55, "chamado")],
            "seco": [(10.8, "resposta", resp), (12.55, "chamado", call)],
            "eventos": [(4.1, "disjuntor (energia cai)", "pico"), (12.62, "religar falha", "pico")]}
    return fim(x, 14.3), 12.0, plan


def preta_b(rng):
    """A Buzina Afogada: cada toque vem mais grave e mais escuro, a luz da cidade tremendo;
    o terceiro engasga no meio, a lâmpada queima, e sobram brasas e fumaça no escuro."""
    # cada toque murcha (o tom cai ao longo dele): a buzina ficando sem ar desde o primeiro
    b = diafone(rng, 0.3, 3.4, 123.0, grunt=0.6, drop=0.78, glide=0.95)
    b += diafone(rng, 4.9, 3.2, 110.0, grunt=0.6, drop=0.75, glide=0.93)
    b += diafone(rng, 9.3, 1.75, 98.0, grunt=0.35, drop=0.5, glide=0.95)
    y = nevoa(b, 0.4, SEED + 61, rt60=4.0, echoes=ECOS_NEVOA)
    knots_t = [0.0, 4.4, 4.7, 8.8, 9.2, 11.0, 15.0]
    knots_f = [3500, 3500, 900, 900, 500, 150, 150]

    def escurece(f, tc):
        fc = np.interp(tc, knots_t, knots_f)
        return 1 / np.sqrt(1 + (f / fc) ** 8)

    x = S.tv_filter(y, escurece)
    trem = 1 - 0.5 * (S.smooth_noise(rng, N, 9.0) > 0.6) * (0.4 + 0.6 * S.smoothstep((T - 4.7) / 0.3))
    luz = win(0.0, 11.05, 0.05, 0.004) * trem
    x += 0.1 * zumbido_luz(rng) * luz
    S.put(x, 11.05, 0.7 * lampada_queima(rng))
    sub = np.sin(2 * np.pi * 38 * T) * (0.6 + 0.4 * S.smooth_noise(rng, N, 0.5))
    x += 0.05 * sub * S.smoothstep((T - 5.0) / 6.0)
    x += 0.35 * brasas(rng, 11.1, 8.0)
    x += 0.03 * S.lowpass(fumaca(rng, 3.8), 1200, 2) * S.smoothstep((T - 11.0) / 2.0)
    x += 0.02 * ar_nevoa(rng)
    murcha = [(0.3, 3.4, 123.0, 0.95), (4.9, 3.2, 110.0, 0.93)]
    f_plan = sum(f * (1 + (g - 1) * S.smoothstep((T - t0) / d)) * win(t0 + 0.7, t0 + d - 0.8, 0.01, 0.01)
                 for t0, d, f, g in murcha)
    plan = {"voz": {"buzina": f_plan},
            "checar": [(1.8, "buzina"), (6.4, "buzina")],
            "eventos": [(11.05, "lâmpada queima", "pico")]}
    return fim(x, 14.3), 13.0, plan


# nome -> () -> (sinal, crest_db do protótipo)
SIRENES = {
    "branca_a": lambda: branca_a(np.random.default_rng(SEED + 0))[:2],
    "preta_a": lambda: preta_a(np.random.default_rng(SEED + 200))[:2],
    "preta_b": lambda: preta_b(np.random.default_rng(SEED + 500))[:2],
}
