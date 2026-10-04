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
(`lua/client/`) só aplica clima, som e overlays.

No solo o jogo executa servidor e cliente no mesmo processo, então o código é o
mesmo nos dois modos.

## Consequências

- Overlays de névoa são deliberadamente locais (sem sync): cada jogador vê o
  próprio pesadelo, e não há custo de rede.
- Teste de MP é obrigatório antes de fechar sprint que mexe em `server/`.
