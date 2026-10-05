# Sprint 0008 — Ajustes do primeiro teste in-game

| Campo | Valor |
|-------|-------|
| Status | em andamento |
| Branch | `sprint/0008-ajustes-teste` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md), [atmosphere.md](../../gdd/atmosphere.md#clima), [sandbox.md](../../gdd/sandbox.md) |

## Objetivo

Depois da primeira sessão no jogo: a noite fica claramente mais escura e fria que a
vanilla, os bichos aparecem bem mais (15% cada), e o Eco não nasce do zumbi que
acabou de morrer.

Pedido do Johan (05/10/2026, depois do teste):

1. "a probabilidade dos bixos a noite e na nevoa devem ser grandes ... algo em torno de
   15% em cada tipo de bixo"
2. "o echo só pode nascer no próximo entardecer. se eu matar o zombie e logo em
   seguida ele nascer, é ruim"
3. "a noite parece clara igual dia", e nenhum efeito visível, com `[NOM] nightRamp=1.00`
   no console.

## Critérios de aceite

- [ ] `EstaladorChance`, `CorredorChance` e `SemRostoChance` com padrão 15; cada tipo sai
      em ~15% dos zumbis e o total da noite fica em ~30% (Estalador e Corredor no mesmo
      sorteio, faixas sem sobreposição)
- [ ] Corpo de quem morreu durante a noite atual não solta Eco nesta noite; solta na
      próxima. Corpo de quem morreu antes do anoitecer solta nesta noite
- [ ] A noite escurece pelos canais que o jogo de fato usa pra luz, com peso visível:
      mais escura e mais fria que a vanilla com `DarkIntensity` 1, muito escura com 2
- [ ] Névoa continua forte (dessaturação, névoa mais densa, mundo mais escuro e sépia)
- [ ] Log só de `-debug` na borda da rampa e uma vez por hora de jogo à noite, com
      vanilla, valor escrito e `getFinalValue()` de cada canal
- [ ] Docs: GDD, sandbox (presets), pz-api-notes, ADR e roteiro in-game atualizados

## Checkpoints

- **04/10/2026** — Sprint aberta a partir do primeiro teste no jogo.

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — investigação no bytecode (render da noite, `deathTime`), plano e implementação
