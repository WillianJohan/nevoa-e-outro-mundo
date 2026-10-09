# Sprint 0055: almas — ciclo constante + 3 cores + painel

| Campo | Valor |
|-------|-------|
| Status | `em teste` (PR draft → staging; **não mergear** até o Johan jogar) |
| Branch | `sprint/0055-almas-ciclo` (saiu da `staging`) |
| Origem | Johan 2026-10-09: pop 4–20 constante, 68% crawler, white/red/black; params no `NOM.panel()` |
| Plano | [plan.md](plan.md) |
| Precede | [0050 almas esqueléticas](../sprint-0050-almas-esqueletos/README.md) (levas/gap/só branca — **substituído** aqui) |

## O que mudou

- **Ciclo constante:** enquanto a névoa estiver aberta e a cor ligada, mantém **4–20** almas vivas; abaixo de 4 repõe; nunca passa de 20. Gap 45–120 s e levas ~10/15/20 saem.
- **Mix:** **68% crawler** / 32% shambler (era ~70%).
- **Cores:** branca **e** vermelha **e** preta (cada uma ligável/desligável no debug).
- **Mantido da 0050:** só rua, TTL 10/30/60 s, vida 0,25, seek lento, sons/FX, `AlmaEnabled`.
- **Painel (`NOM.panel()`):** cartões compactos com botões no padrão do painel — Agora / Status / Padrão; ± min/max (slider por passos); ± crawler 5%; toggles Branca/Vermelha/Preta (pill verde = ligada).
- **Console:** `NOM.alma()`, `NOM.almaStatus()`, `NOM.almaReset()`, `NOM.almaCfg(campo, valor)`.

## Roteiro de teste no jogo

1. Staging, névoa branca: almas sobem sozinhas até ≥4 e não passam de 20.
2. Matar/esperar TTL até cair abaixo de 4 → repõe.
3. `NOM.setRedFog(true)` / `NOM.setBlackFog(true)`: ciclo continua (cores ligadas).
4. Painel → Monstros → Almas: desligar **Branca** com névoa branca → somem; religar → voltam.
5. ± pop / crawler: status no rodapé reflete; **Padrão** restaura 4–20 / 68% / 3 cores.
6. `NOM.alma()` ainda força um repor (cap 8 no debug).
