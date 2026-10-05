# Sprint 0005 — Sem-rosto e atmosfera da névoa

| Campo | Valor |
|-------|-------|
| Status | em andamento |
| Branch | `sprint/0005-sem-rosto-e-nevoa` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md#sem-rosto](../../gdd/monsters.md#sem-rosto), [atmosphere.md](../../gdd/atmosphere.md) |

## Objetivo

Quando a névoa sobe, o Outro Mundo acorda: o som muda, o rádio chia, o chão se cobre de sangue e o Sem-rosto caça.

## Critérios de aceite

- [ ] Sem-rosto só existe com névoa ≥ `FogThreshold` e volta a ser zumbi comum quando ela baixa
- [ ] Olhado ou iluminado, some e reaparece mais perto, fora do campo de visão
- [ ] Rádio chia mais forte quanto mais perto, sem exigir rádio no inventário
- [ ] Ambiente troca para drone + ruídos metálicos na névoa, com transição
- [ ] Overlays de sangue/ferrugem surgem aos poucos perto do jogador e somem com a névoa, sem sobrar sprite no mapa depois de salvar e recarregar
- [ ] Overlays são locais: em MP, cada cliente vê os seus
- [ ] Noite + névoa juntas: todos os sistemas ativos ao mesmo tempo sem conflito
- [ ] Toggles no sandbox

## Checkpoints

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação da sprint
