# Sprint 0002 — Eco

| Campo | Valor |
|-------|-------|
| Status | backlog |
| Branch | `sprint/0002-eco` |
| Plano | a escrever (`plan.md`) |
| GDD | [monsters.md#eco](../../gdd/monsters.md#eco), [ADR-003](../../architecture/adr-003-eco-spawnado.md) |

## Objetivo

À noite, os corpos perto do jogador soltam Ecos, que somem ao morrer e ao amanhecer.

## Critérios de aceite

- [ ] **Spike primeiro:** escolhida a técnica de "morrer sem cadáver", testada em solo **e** MP. Resultado registrado em Aprendizados
- [ ] Corpo a até `EcoRadius` de um jogador solta um Eco durante a noite (checagem periódica, não só no início)
- [ ] Cada corpo solta Eco uma única vez (`NOM_ecoReleased`), inclusive depois de salvar e recarregar
- [ ] Corpo queimado ou enterrado não solta Eco
- [ ] Teto `EcoMaxPerPlayer` respeitado — testado com uma pilha de 60+ corpos
- [ ] Eco morto não deixa cadáver nem loot
- [ ] Ao amanhecer, todos os Ecos somem
- [ ] Textura fantasmagórica aplicada (final ou placeholder registrado em Pendências)
- [ ] Toggle e números do Eco no sandbox
- [ ] `./run-tests.sh` cobre a elegibilidade do corpo (raio, já liberado, teto)

## Checkpoints

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões
