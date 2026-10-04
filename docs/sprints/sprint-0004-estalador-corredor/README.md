# Sprint 0004 — Estalador e Corredor noturno

| Campo | Valor |
|-------|-------|
| Status | backlog |
| Branch | `sprint/0004-estalador-corredor` |
| Plano | a escrever (`plan.md`) |
| GDD | [monsters.md](../../gdd/monsters.md#estalador), [ADR-001](../../architecture/adr-001-variantes-por-moddata.md) |

## Objetivo

À noite, parte dos zumbis vira Estalador ou Corredor, e cada um obriga o jogador a jogar diferente.

## Critérios de aceite

- [ ] Sorteio preguiçoso: cada zumbi é sorteado uma vez por noite, inclusive os de chunks carregados depois
- [ ] Desmarcar restaura `NOM_orig` — nenhum zumbi fica Estalador/Corredor de dia, nem depois de salvar e recarregar
- [ ] Estalador ignora visão: jogador agachado e em silêncio passa do lado dele
- [ ] Estalador emite estalo periódico e tem agarrão letal rápido
- [ ] Corredor é comum de dia e sprinter à noite
- [ ] Corredor grita ao ver o jogador e atrai zumbis num raio de `CorredorScreamRadius`
- [ ] Outfit/textura e sons de cada um (finais ou placeholders registrados em Pendências)
- [ ] Toggles e chances no sandbox
- [ ] `./run-tests.sh` cobre o sorteio por período

## Checkpoints

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões
