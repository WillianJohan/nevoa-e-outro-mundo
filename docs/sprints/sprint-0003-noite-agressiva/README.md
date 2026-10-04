# Sprint 0003 — Noite agressiva

| Campo | Valor |
|-------|-------|
| Status | backlog |
| Branch | `sprint/0003-noite-agressiva` |
| Plano | a escrever (`plan.md`) |
| GDD | [night.md](../../gdd/night.md) |

## Objetivo

À noite, todo zumbi fica mais rápido, mais forte, percebe mais longe e caça o jogador.

## Critérios de aceite

- [ ] Velocidade e dano sobem à noite pelos multiplicadores do sandbox e voltam ao normal ao amanhecer
- [ ] Alcance de audição e visão maior à noite; lanterna ligada ao ar livre atrai zumbis de mais longe que de dia
- [ ] Caça ativa: a cada `HuntIntervalMinutes`, zumbis no raio vão até o jogador sem vê-lo
- [ ] Cada um dos 3 comportamentos desliga sozinho pelo toggle
- [ ] Salvar à noite e recarregar de dia não deixa zumbi com stat noturno preso
- [ ] Loop em lotes por tick: sem queda perceptível de FPS numa horda de ~200 zumbis (medido e registrado)
- [ ] `./run-tests.sh` cobre o cálculo dos multiplicadores

## Checkpoints

## Aprendizados

## Pendências que a próxima sprint herda

## Sessões
