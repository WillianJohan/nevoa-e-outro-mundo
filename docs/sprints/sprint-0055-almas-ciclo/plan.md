# Sprint 0055: almas ciclo constante — plano

> Code review só no fim da entrega (AGENTS.md). PR draft → staging; **não mergear**.

## Objetivo

Presença constante de almas na névoa (não “de vez em quando”): população 4–20, 68% crawler, nas três cores; tudo ajustável no `NOM.panel()`.

## Restrições

AGENTS.md / ADR-002/005 / Kahlua / evidência de API / PTBR+EN / todo `NOM.*` com botão no painel.

## Tarefas

1. **Regras** — `NOM_AlmaRules`: `refillCount`, cores, `apply`/`reset`/`describe`; testes TDD.
2. **Servidor** — `NOM_AlmaServer`: tick repõe abaixo do mín.; `active` por cor; limpa se cor/fog off.
3. **Debug** — `almaCfg` / `almaStatus` / `almaReset` no parse + server + console + HELP.
4. **Painel** — cartões Alma / Pop / Crawler / Cores (botões ± e toggles; rótulos vivos).
5. **Docs / traduções** — README, índice, sandbox, §3.9.1 emenda, UI PTBR+EN.

## Critérios de aceite

Ver README: ciclo 4–20, 3 cores, 68%, painel parametrizável, testes verdes.
