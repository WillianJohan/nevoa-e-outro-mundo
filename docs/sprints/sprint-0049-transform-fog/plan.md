# Transform 100% + identidade por cor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Em toda névoa (branca/vermelha/preta) todo zumbi com outfit vira monstro; a cor define o clima (cotidiano / agitação / Tição).

**Architecture:** Sorteio puro em `NOM_VariantRules` (ADR-006): na branca, pesos do sandbox cobrem 100% via seleção proporcional (`floor(hash/Q × total)` nas faixas). Vermelha e preta intactas. Identidade em `NOM_ColorIdentityRules` (puro): wander só na branca (Estalador elegível), cooldown do grito e velocidade do Estalador na vermelha. Servidor decide wander/grito; quem simula aplica (`doZombieSpeed` / `pathToLocationF`, pz-api-notes §2.1 / §27; ADR-002/005).

**Tech Stack:** Lua Kahlua 5.1 subset, luajit nos testes, shared puro + server/client existentes.

## Global Constraints

- Nada copiado de outros mods; evidência de API em pz-api-notes.
- Shared sem API do jogo; `if isClient() then return end` em server/.
- Texto jogador: chaves PTBR + EN.
- Docs/comentários em português BR.
- Não mergear na staging; PR draft. Não tocar Sons II (#4).

---

### Task 1: Regras de identidade (puro)

**Files:**
- Create: `mod/42/media/lua/shared/NOM_ColorIdentityRules.lua`
- Create: `tests/test_color_identity_rules.lua`
- Modify: `tests/run.lua` (registrar o teste)

**Interfaces:**
- Produces: `mood(red, black) -> "white"|"red"|"black"`; `wanderAllowed(mood)`; `canWanderKind(kind, mood)`; `screamCooldownHours(mood)`; `estaladorSpeed(mood) -> 2|nil`; constantes `SCREAM_WHITE`, `SCREAM_RED`.

- [ ] **Step 1: testes que falham** — mood, wander só white, canWanderKind (nil/estalador na white), scream red < white, estaladorSpeed red = 2.
- [ ] **Step 2: implementação mínima** do módulo puro.
- [ ] **Step 3: `luajit tests/run.lua test_color_identity` verde.**
- [ ] **Step 4: commit.**

### Task 2: Branca 100% (pesos renormalizados)

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_VariantRules.lua`
- Modify: `tests/test_variant_rules.lua`
- Modify: docs GDD/ADR/traduções (Task 5 pode juntar docs)

**Interfaces:**
- Consumes: hash/Q existentes.
- Produces: `variant(id, period, cfg, red, black)` na branca cobre 100% com pesos; `screamReady(lastAt, now, mood)` usa cooldown por cor.

- [ ] **Step 1: testes novos** `variant_rules_white_full_coverage`, `variant_rules_white_weights_proportional`, `variant_rules_white_disabled_kind_stays_normal`; ajustar defaults 14% → 100% com razões 5:3:3:3; `screamReady` com mood.
- [ ] **Step 2: ver falhar.**
- [ ] **Step 3: implementação** — seleção `r = floor(hash/Q * total)` nas faixas; screamReady opcional mood via ColorIdentity.
- [ ] **Step 4: testes variant_rules verdes; commit.**

### Task 3: NightRules — Estalador rápido na vermelha

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_NightRules.lua`
- Modify: `mod/42/media/lua/shared/NOM_NightStats.lua`
- Modify: `tests/test_night_rules.lua`, `tests/test_night_stats.lua` (casos red)

- [ ] **Step 1: teste** wanted(estalador, mood red) → speed 2 + sight/hearing iguais.
- [ ] **Step 2: passar `mood` em wanted; NightStats calcula mood com fog.**
- [ ] **Step 3: verdes; commit.**

### Task 4: Wander + grito por cor

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_Wander.lua`, `server/NOM_WanderServer.lua`, `server/NOM_Variants.lua`, `server/NOM_DebugServer.lua` (se mensagem)
- Modify: `tests/test_wander.lua`, `tests/test_variants.lua` (cooldown), traduções UI se mensagem debug

- [ ] **Step 1: testes** wander recusa red/black; Estalador elegível na white; scream usa cooldown red.
- [ ] **Step 2: fio** ColorIdentity nos três pontos.
- [ ] **Step 3: verdes; commit.**

### Task 5: Docs + índice + HANDOFF mínimo

**Files:**
- Modify: `docs/gdd/monsters.md`, `docs/gdd/sandbox.md`, `docs/architecture/adr-006-*.md`, `docs/sprints/README.md`, Translate PTBR/EN Sandbox (+ UI se precisar), README da sprint

- [ ] **Step 1: texto** branca 100% pesos; tooltips “peso relativo”.
- [ ] **Step 2: `./run-tests.sh` completo.**
- [ ] **Step 3: commit; push; draft PR → staging.**
