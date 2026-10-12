# Sprint 0056 — Estalador: 3 ritmos de click

| Campo | Valor |
|-------|-------|
| Status | em andamento |
| Branch | `sprint/0056-estalador-ritmos` |
| Plano | [plan.md](plan.md) |
| Âncoras | [0048](../sprint-0048-sons-ii/README.md) (clicker), [0037](../sprint-0037-sonar-estalador/README.md) (sonar) |

## Objetivo

Três padrões de burst do Estalador (Johan, 2026-10-09), parametrizáveis no `NOM.panel()`:

| Variação | Ritmo |
|----------|--------|
| **A** | Várias estaladas seguidas (comportamento 0048) |
| **B** | `tac` — 500 ms — `tac` — 500 ms — `tac` — 800 ms — `tac` |
| **C** | `tac` — 1 s — `tac` — 1 s — `tac``tac` (double ~65 ms) — 2 s — `tac` — 3 s — `tac` |

**Regra de escolha:** a cada estalo o servidor avança o rodízio **A→B→C→A**. Debug pode forçar uma variação (`NOM.sonarBurst`) e ajustar gaps (`NOM.sonarGaps`, alvo = forçado ou **B** no Auto).

Ripples (mod3 ou anel na tela) acompanham **cada** tac. O achado do sonar continua **um** anel por burst.

## O que entra

- `shared/NOM_SonarRules.lua`: `BURST_GAPS`, `burstBeats` / force / gaps; mensagem `b`
- Servidor escolhe e manda `b`; cliente agenda ripples + tacs atrasados
- `NOM_EstaladorClick.ogg` = tac curto (agenda um por batida)
- Painel: Agora / Auto / A / B / C / Gap− / Gap+ / Gaps (reset)
- `NOM.sonarBurst(mode)`, `NOM.sonarGaps(delta|"reset")` + HELP

## Critérios de aceite

- [ ] No jogo, ouvir A, B e C distintos (Auto ou forçado + `NOM.sonar()`)
- [ ] Gap± muda o ritmo do alvo; Gaps restaura
- [ ] Ripples em cada tac; um find por burst; agachado/casa/MP intactos
- [x] Testes verdes (`./run-tests.sh`)

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh` nesta branch; reiniciar; só mod **Staging**.
2. Névoa + Estalador (ou `NOM.sonar()`): ouvir rodízio A→B→C.
3. Painel → Tempestade → Sonar: **B** + Agora; depois Gap+ algumas vezes e Agora de novo.
4. **C** + Agora: double colado e pausas longas.
5. **Gaps** (reset) + **Auto**.
