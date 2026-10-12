# Sprint 0050: almas esqueléticas — plano

> Code review só no fim da entrega (AGENTS.md). PR draft → staging; **não mergear**.

## Objetivo

Na névoa **branca**, levas de almas esqueléticas negras nascem na rua (~70% crawler), buscam o jogador devagar, vivem pouco (TTL 10 s–1 min) e somem com FX negro + sons ElevenLabs do Johan.

## Restrições

AGENTS.md / ADR-002/005 / Kahlua / evidência de API / PTBR+EN / debug no painel.

## Tarefas

1. **Regras puras** — `NOM_AlmaRules` + `test_alma_rules` (gap, leva, TTL, crawler, rua, sons).
2. **Áudio** — `import_elevenlabs_almas.py`, 5 oggs, `NOM_sounds.txt`, CREDITS (Johan+ElevenLabs).
3. **Servidor** — `NOM_AlmaServer`: agenda real, spawn rua, TTL, despawn interior/fim névoa, comando `almaFx`/`almaGone`.
4. **Shared** — `NOM_Alma`: dress (`setSkeleton`), seek, som de evento; NightRules/NightStats kind `alma`; Variants/Wander ignoram.
5. **Cliente** — `NOM_AlmaClient`: FX preto + sons; remove fantasmas no MP.
6. **Sandbox / debug / traduções** — `AlmaEnabled`, `NOM.alma()`, painel, PTBR+EN.
7. **Docs** — README + índice; nota de entrega no Agent Store.

## Evidência de API

| Uso | Status | Onde |
|-----|--------|------|
| `addZombiesInOutfit` longa (crawler, health) | CONFIRMED | pz-api-notes spawn |
| `setSkeleton(true)` | EXISTS (queimado) | pz-api-notes; spike look |
| `pathToLocationF` | CONFIRMED | NOM_Wander / bytecode |
| `square:isOutside()` | CONFIRMED | farming / sonar |
| `removeFromWorld` + comando MP | EXISTS | NOM_Eco |
| `getTimestampMs` | CONFIRMED | FogEvent / Sonar |

## Critérios de aceite

Ver README + §3.9.1 do refinamento (mix, seek, TTL, gap, rua, vida baixa, áudio sem horda).
