# Sprint 0068: população de almas — plano

> Code review só no fim (AGENTS.md). PR draft → `staging`; **não mergear** sem Johan.

## Objetivo

Implementar a regra de população da [proposta névoas v2](https://github.com/WillianJohan/nevoa-e-outro-mundo/blob/staging/docs/proposta-nevoas-v2.md) (espelho no Agent Store).

## Tarefas

1. **Shared** — `NOM_AlmaRules`: faixas por cor, `spawnNeed`, cluster MP, TTL, branca só crawler.
2. **Server** — `NOM_AlmaServer`: tick 5 s, zonas, contagem no raio.
3. **Painel / debug / sandbox** — sliders vermelha, defaults, PTBR+EN.
4. **Testes** — `test_alma_rules`, `test_alma`, `test_panel_params`.
5. **Docs** — README desta sprint.

## Critérios

- `./run-tests.sh` verde.
- Sem `dev-sync` (Johan synca depois).
