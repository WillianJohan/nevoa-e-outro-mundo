# Sprint 0001 — Estado do mundo e clima dark

| Campo | Valor |
|-------|-------|
| Status | planejada |
| Branch | `sprint/0001-estado-e-clima` |
| Plano | [plan.md](plan.md) |
| GDD | [world-states.md](../../gdd/world-states.md), [atmosphere.md](../../gdd/atmosphere.md#clima), [sandbox.md](../../gdd/sandbox.md) |

## Objetivo

Ao anoitecer ou quando a névoa sobe, o jogo escurece e muda de cor sozinho —
em solo e em MP.

## Critérios de aceite

- [ ] Ambiente de dev pronto: jogo instalado, `-debug` funcionando, pasta `mod/` linkada em `~/Zomboid/mods` (como foi feito, registrado em Aprendizados)
- [ ] Mod aparece e ativa no menu de mods do B42 sem erro no `console.txt`
- [ ] Flags `night` e `fog` mudam na hora certa (forçando hora e névoa no `-debug`)
- [ ] Noite: luz menor, leve dessaturação, tint azulado
- [ ] Névoa: dessaturação forte, tint sépia/cinza, névoa mais densa
- [ ] Transição suave (~30s), sem corte seco
- [ ] Toggle e `DarkIntensity` no sandbox alteram o efeito
- [ ] Em MP (servidor local + 2 clientes), os dois clientes escurecem juntos
- [ ] Todo texto visível sai de chave de tradução (`Translate/PTBR`), nunca string solta no Lua
- [ ] `./run-tests.sh` cobre a máquina de estado de `NOM_Rules.lua` e devolve exit code

## Checkpoints

- **04/10** — Design aprovado em brainstorming; GDD, ADRs e roadmap escritos.

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — brainstorming, GDD, ADRs, repo
