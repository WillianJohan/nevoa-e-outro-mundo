# Sprint 0069: almas em silêncio — plano

> Code review só no fim (AGENTS.md).

## Objetivo

Tirar o coro contínuo de gemidos das almas, sem mexer na população nem no TTL (decisão do Johan,
2026-10-12: "tirar o som de nascer e sumir; manter só o grupo da leva e um gemido de evento mais
espaçado"). Diagnóstico no [README](README.md).

## Tarefas

1. **Testes primeiro:** `fxSound` só pro grupo, intervalo do grupo, evento ≥ 60 s; no servidor,
   a leva seguinte não repete o grupo dentro do intervalo e o debug ignora o intervalo.
2. **Shared:** `NOM_AlmaRules.fxSound`, `groupSoundDue`, `GROUP_SOUND_GAP_MS = 60000`,
   `SOUND_EVENT_MS = 90000`.
3. **Server:** `spawnForCluster` respeita `groupSoundDue` (`S.groupAt`), menos na leva de debug.
4. **Client:** `NOM_AlmaClient.fx` toca só o que o `fxSound` devolve; a rajada visual fica.
5. **Docs:** README, índice das sprints e HANDOFF.

## Critérios

- `./run-tests.sh` verde.
- Merge `--no-ff` na `staging`, push e `scripts/dev-sync.sh`.
