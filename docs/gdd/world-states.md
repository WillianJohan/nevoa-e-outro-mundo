# Estados do mundo

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Sprint | 0001 |

## O que é

O servidor calcula duas flags independentes a partir do jogo:

| flag | condição |
|---|---|
| `night` | hora do jogo entre o pôr e o nascer do sol |
| `fog` | intensidade de névoa do clima ≥ `FogThreshold` (sandbox) |

São flags, não um enum: as duas podem estar ativas ao mesmo tempo.

## Regras

- O gatilho do Outro Mundo é **só a névoa natural do clima**. A névoa do PZ é
  global, então "tem névoa" vale pro mapa inteiro.
- Mudança de flag dispara um evento interno (`onNightStart/End`,
  `onFogStart/End`), consumido pelos outros sistemas e repassado aos clientes.
- Cada período (uma noite, uma névoa) tem um id próprio, usado pelo sorteio de
  variantes ([monsters.md](monsters.md)).
