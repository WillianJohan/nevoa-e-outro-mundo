# Sprint 0056: Estalador — 3 ritmos (plano)

> TDD primeiro. Code review só no fim da entrega.

## Ordem

| # | Tarefa | Depende |
|---|---|---|
| 1 | Docs sprint | — |
| 2 | Regra pura: A/B/C, rodízio, force, gaps + testes | — |
| 3 | gen_sounds: tac curto + CLICK_BURSTS espelho | 2 |
| 4 | Servidor manda `b`; cliente Fx agenda ripples/tacs | 2 |
| 5 | Debug: `NOM.sonarBurst` / `sonarGaps` + painel + traduções | 2, 4 |
| 6 | `./run-tests.sh`; PR draft → staging | todas |

## Regra de produto

- Default: rodízio por estalo no servidor (`nextBurst`).
- Debug: force A/B/C; Gap± (±50 ms) no alvo (force ou B); reset.
- UI compacta: pills no cartão Sonar (sem slider nativo — o painel 0046 é cartão+pílula).

## Fora

Merge; looks/almas (branches irmãs).
