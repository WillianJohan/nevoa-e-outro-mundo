# ADR-002 — Lógica no servidor, cliente só renderiza

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |

## Contexto

O mod vai pro Workshop e precisa funcionar em solo e em MP. Em MP, zumbis são
simulados pelo servidor; decisões tomadas no cliente divergem entre jogadores.

## Decisão

Toda decisão de jogo (flags night/fog, sorteio, spawn, comportamento) roda em
`lua/server/`. O servidor avisa os clientes por `sendServerCommand`. O cliente
(`lua/client/`) só toca som e desenha overlays.

No solo o jogo executa servidor e cliente no mesmo processo, então o código é o
mesmo nos dois modos.

## Consequências

- Overlays de névoa são deliberadamente locais (sem sync): cada jogador vê o
  próprio pesadelo, e não há custo de rede.
- Teste de MP é obrigatório antes de fechar sprint que mexe em `server/`.
- O **visual do clima também é do servidor** (`NOM_ClimateLook`, em
  `server/`): ele calcula as flags night/fog (`NOM_World`) e escreve na camada
  modded do clima. O jogo já manda o valor final do clima pros clientes, que
  aplicam como override por cima do próprio cálculo — escrever no cliente não
  teria efeito em MP. O cliente que precisar das flags (som, overlays, sprint
  0005) recebe por evento de servidor; esses eventos nascem junto do primeiro
  consumidor de cliente.
- Exceção de limpeza: `client/NOM_EcoClient.lua` apaga o Eco que o servidor já
  removeu (`ecoGone`), porque `removeFromWorld` no servidor não avisa o cliente.
  Ele não decide nada.
