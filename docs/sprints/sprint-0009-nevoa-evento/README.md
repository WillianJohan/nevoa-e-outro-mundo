# Sprint 0009 — Névoa como evento: sirene e hora aleatória

| Campo | Valor |
|-------|-------|
| Status | em andamento |
| Branch | `sprint/0009-nevoa-evento` |
| Plano | [plan.md](plan.md) |
| GDD | [world-states.md](../../gdd/world-states.md), [atmosphere.md](../../gdd/atmosphere.md), [monsters.md](../../gdd/monsters.md), [sandbox.md](../../gdd/sandbox.md) |
| ADR | [ADR-009](../../architecture/adr-009-nevoa-evento-do-mod.md) (nova) |

## Objetivo

A névoa deixa de ser clima: é um evento do mod, numa hora qualquer do dia, uma vez a
cada ~3 dias de jogo, anunciado por uma sirene 30 segundos reais antes, e dura de 2 a 6
horas de jogo. Fora do evento, não existe névoa nenhuma.

Decisões do Johan (05/10/2026), que **revertem** a decisão do brainstorm "gatilho =
névoa natural do clima":

1. Névoa é evento do mod, em hora aleatória, independente da hora do dia; em média
   uma a cada ~3 dias de jogo (`FogEventEveryDays`, padrão 3).
2. Uma sirene toca 30 segundos **reais** antes da névoa, em todo cliente, alta e
   audível em qualquer lugar.
3. Duração aleatória, 2 a 6 horas de jogo (`FogMinHours`, `FogMaxHours`).
4. Névoa natural vanilla não existe: o mod é dono do canal de névoa (0 fora do
   evento, densa durante, com rampa).

## Critérios de aceite

- [ ] Próximo evento sorteado entre 0,5× e 1,5× de `FogEventEveryDays` depois do fim do
      anterior (média = o valor), e a duração entre `FogMinHours` e `FogMaxHours`.
- [ ] A sirene toca 30 s reais antes da névoa, em todo jogador (solo e MP); pausa não
      consome a contagem.
- [ ] Fora do evento a névoa final é 0, inclusive com névoa natural, com o
      `WeatherPeriod` (chuva/tempestade) e com o `FogCycle` do sandbox; durante o
      evento é densa, com rampa de entrada e saída.
- [ ] Flag de névoa (`NOM_World.fog`) e número do período vêm do evento; Sem-rosto,
      variantes, som, overlays, vinheta e debug seguem funcionando.
- [ ] Próximo evento, fim do evento atual e número do período ficam no `ModData`
      global e sobrevivem a salvar/carregar; o período conta uma vez por evento.
- [ ] MP: o servidor decide e avisa; quem entra no meio do evento recebe o estado.
- [ ] `NOM_Debug.fog(true[, pular])` começa um evento (com ou sem a espera da
      sirene), `NOM_Debug.fog(false)` termina.
- [ ] Textos do menu (PT-BR e EN) das opções novas; `FogThreshold` removida.
- [ ] Docs: GDD revisado, ADR-009, pz-api-notes, roteiro in-game.

## Checkpoints

- **04/10/2026** — Sprint aberta. Pesquisa no bytecode: ordem do `ClimateManager.update`
  (overrides do sandbox → `updateValues` → `WeatherPeriod.update` → `OnClimateTick` →
  `calculate`), quem liga o override da névoa e quando, `GameTime.isGamePaused`.

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação
