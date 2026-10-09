# Sprint 0059 — Arrasto / Rastejante (spike §3.5)

| Campo | Valor |
|-------|-------|
| Status | `em teste` (PR draft) |
| Branch | `feature/0059-arrasto-6d17` (saiu da `staging`) |
| Plano | [plan.md](plan.md) |
| Origem | Johan 2026-10-09: continuar após LookForce; [refinamento §3.5](../../proximos-passos-refinamento.md) caminho A |

## Objetivo

Protótipo jogável do **Arrasto**: mesmo esqueleto de zumbi, **sempre crawler**, velocidade
shambler lenta (`doZombieSpeed(3)`), só na névoa **vermelha ou preta**. Critério do spike:
numa sessão, “isso não parece um zumbi andando na minha direção”.

## O que entrou

- `shared/NOM_ArrastoRules` — `enabled(red|black)`, `speedDeg=3`, `ATTACK_RANGE=2`, sons stub,
  mark `ModData.NOM_arrasto`.
- `shared/NOM_Arrasto` — `apply` / `clear` / `is` (`setCrawler` + `doZombieSpeed`).
- `server/NOM_ArrastoServer.force` — recusa fora de vermelha/preta (skip só no debug).
- Debug: `NOM.arrasto()` + cartão **Arrasto** na seção Monstros do `NOM.panel()`.

## Como voltar

- Remover os três `NOM_Arrasto*` e o op `arrasto` em DebugRules/Server/Console/painel.
- Chaves `UI_NOM_Debug_C_Arrasto*` nas traduções.

## Testes

- `test_arrasto_rules` — cor, crawler, speed, range, sons ≠ grito, mark/is.
- `test_arrasto` — apply marca crawler lento; force só red/black; skipColor.
- `test_debug` / `test_debug_rules` / `test_debug_panel` — pedido, parse, botão + HELP.

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh` na branch (ou staging após merge), reiniciar, `-debug`.
2. `NOM.setRedFog(true)` (ou preta), `NOM.spawn(3)`, aproximar de um zumbi.
3. `NOM.arrasto()` ou painel → Monstros → **Arrasto** → Agora.
4. Esperado: o mais perto rasteja lento (pose crawler); log `[NOM] debug arrasto id=…`.
5. `NOM.setFog(true)` (branca): o comando deve recusar (“só na névoa vermelha ou preta”).
6. Julgamento do Johan: ainda lê “zumbi deitado” ou já “presença baixa”? Sons/IA ficam pra depois.

## Pendências que a próxima fatia herda

- IA de proximidade (`ATTACK_RANGE`) + sons de arrasto (não grito).
- Spawn/ritmo se o spike passar (não forçar só no debug).
- MP dedicado: quem simula precisa aplicar (hoje o op marca no processo do servidor).
