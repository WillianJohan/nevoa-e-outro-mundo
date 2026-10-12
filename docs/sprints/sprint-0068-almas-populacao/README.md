# Sprint 0068: população de almas (névoas v2)

| Campo | Valor |
|---|---|
| Branch | `sprint/0068-almas-populacao` (sai da `staging`) |
| Spec | Proposta névoas v2 (Johan, 2026-10-10) — `docs/proposta-nevoas-v2.md` no Agent Store do projeto |
| Substitui | ciclo 0055/0066 (4–20 / preta 20–40, refill abaixo do mínimo) |

## O que mudou

- **Tick 5 s:** sorteia alvo na faixa da cor, conta esqueletos num **raio de 50 m** e spawna `alvo − atual`.
- **Faixas:** branca **5–30** (só crawler); vermelha **25–50** (crawler + shambler); preta **30–100**.
- **TTL:** **5–15 s** (branca/vermelha); **ilimitado** na preta.
- **MP:** jogadores a ≤ 50 m compartilham **uma** zona (população não dobra).
- **Painel:** sliders separados branca / vermelha / preta + `%` crawler (vermelha/preta).

## Roteiro no jogo

1. Staging, névoa branca: após ~5 s, almas sobem até a faixa; **todas** rastejam.
2. Vermelha: mix crawler/shambler; contagem sobe mais (25–50).
3. Preta: muitas almas (30–100) e **não** somem sozinhas por TTL.
4. Dois jogadores MP colados: população parecida com um jogador só; afastados 100 m: duas zonas.
5. `NOM.almaStatus()` / painel Almas: faixas v2 e contagem.

## Testes

`./run-tests.sh` — `test_alma_rules.lua`, `test_alma.lua`, `test_panel_params.lua`.
