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
- Mudança de flag dispara um evento interno (`NOM_World.onChange(fn)`,
  `fn("night"|"fog", valor)` só na borda), consumido pelos outros sistemas no
  servidor. O Eco usa a borda de fim da noite. Os clientes recebem as duas flags
  por comando do servidor (`night` desde a sprint 0003, `fog` desde a 0005), e
  quem entra no meio pergunta o estado.
- Cada período (uma noite, uma névoa) tem um número próprio, contado pelo servidor
  e salvo com o mundo, usado pelo sorteio de variantes ([monsters.md](monsters.md)):
  a noite pro Estalador e o Corredor, a névoa pro Sem-rosto.
