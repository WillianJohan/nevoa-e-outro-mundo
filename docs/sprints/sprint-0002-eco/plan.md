# Sprint 0002 — Eco: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** À noite, corpos a até `EcoRadius` de um jogador soltam um Eco (uma vez na vida), que morre sem cadáver nem loot e some ao amanhecer.

**Architecture:** Regra pura de elegibilidade (`NOM_EcoRules`, testada no `luajit`) + um módulo de servidor (`server/NOM_Eco.lua`) que varre corpos a cada 10 minutos de jogo, spawna com `addZombiesInOutfit` num outfit próprio (`NOM_Eco`, definido em `media/clothing/clothing.xml` só com itens vanilla por GUID) e limpa no amanhecer. A noite vem de `NOM_World` (sprint 0001), que passa a avisar as bordas de flag por listener. A identidade do Eco sobrevive ao descarregar do chunk pelo `persistentOutfitID` (o `modData` do zumbi não sobrevive). Um arquivo de cliente minúsculo só apaga o fantasma local quando o servidor manda (MP).

**Tech Stack:** Project Zomboid B42.20.4 (Lua via Kahlua, subset de Lua 5.1), `luajit` para testes, bash.

**Spec:** [README da sprint](README.md) (objetivo e critérios), [GDD monsters#eco](../../gdd/monsters.md#eco), [GDD sandbox](../../gdd/sandbox.md), [ADR-002](../../architecture/adr-002-autoridade-servidor.md), [ADR-003](../../architecture/adr-003-eco-spawnado.md), [pz-api-notes §1 e §7](../../architecture/pz-api-notes.md).

## Global Constraints

- Mod id e namespace de sandbox: `NevoaEOutroMundo`. Globais e arquivos Lua com prefixo `NOM_`.
- Kahlua: nada de `//`, `goto`, bit ops, `table.unpack` (usar `unpack`), `string.format("%d")` em float.
- Lógica de jogo no servidor (`lua/server/`, primeira linha `if isClient() then return end`). Lógica pura em `lua/shared/` sem API do jogo.
- Todo texto visível por chave de tradução, PTBR e EN, em `media/lua/shared/Translate/<LANG>/*.json`.
- Sandbox: `EcoEnabled` (true), `EcoMaxPerPlayer` (30), `EcoRadius` (40).
- Nada copiado de outros mods; outfit referencia itens vanilla por GUID (dado, não arquivo copiado).
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode). O que só o jogo responde vira fallback + linha no roteiro in-game.
- Comentários e docs em português do Brasil.

## Evidência levantada antes do plano (bytecode B42.20.4)

| Pergunta | Resposta | Evidência |
|---|---|---|
| `OnZombieCreate` existe e quando dispara | `VirtualZombieManager.createRealZombieAlways(dir, isDead, outfitId, ...)` dispara `OnZombieCreate(zombie)` **antes** de pôr o zumbi em `IsoCell.getZombieList()`; com `isDead` vira corpo e não dispara | bytecode `createRealZombieAlways(IsoDirections;ZII)` offsets 39–79 |
| ordem no spawn | `addZombiesInOutfit` chama `createRealZombieAlways` (dispara o evento) e **só depois** `dressInPersistentOutfit(outfit)` e `setHealth(health)` | bytecode `GlobalObject.addZombiesInOutfit(...ZZ)` offsets 136, 314, 410; 6 args usa health 1.0 |
| o que sobrevive ao chunk | `createZombieOutsideWorld` limpa o visual, faz `setPersistentOutfitID(id)` sem vestir (`dressInRandomOutfit=false`) e sorteia a vida pela toughness | bytecode `createZombieOutsideWorld` offsets 197–230, 645–786 |
| `getOutfitName()` no `OnZombieCreate` | volta `nil` num zumbi recarregado: só lê o `HumanVisual`, que foi limpo; vestir é preguiçoso (`ModelManager.dressInRandomOutfit` → `dressInPersistentOutfitID`) | bytecode `IsoZombie.getOutfitName`, `ModelManager.dressInRandomOutfit` offsets 116–128 |
| formato do `persistentOutfitID` | bit 31 = feminino, bits 16–30 = índice do outfit na lista ordenada por nome, bits 0–15 = semente (0 se o outfit não usa semente, senão 1..500); outfit inexistente devolve 0 | bytecode `PersistentOutfits.pickOutfitMale/getOutfit/applyOutfit` |
| vestir de novo por ID | `dressInPersistentOutfitID(id)` é público e chama `dressInNamedOutfit(nome)`; depois disso `getOutfitName()` responde | bytecode `IsoZombie.dressInPersistentOutfitID`, `PersistentOutfits.applyOutfit` offset 70 |
| outfit de mod | `OutfitManager.loaded()` lê `media/clothing/clothing.xml` da pasta de versão (`42/`) e da `common/` de cada mod e **acrescenta** outfits novos | bytecode `OutfitManager.loaded` offsets 3–314 |
| `modData` de zumbi reaproveitado | `IsoZombie.resetForReuse` faz `getModData():wipe()` | bytecode offsets 528–538 |
| `modData` do corpo salva | `IsoDeadBody.save` → `IsoMovingObject.save` grava `table` (`KahluaTable.save`) e `load` relê; o construtor copia o `modData` do personagem e o `persistentOutfitID` | bytecode `IsoMovingObject.save` 104–133, `.load` 89–118; `IsoDeadBody.<init>` 906, 1121–1128 |
| `OnDeadBodySpawn` no dedicado | **não dispara**: `if (... && !GameServer.server) triggerEvent("OnDeadBodySpawn")` | bytecode `IsoDeadBody.<init>` offsets 1298–1311 |
| `OnZombieDead` | `IsoZombie.onKilled`: `DoZombieInventory()` (fora do cliente) → `OnZombieDead(zombie)` → `DoDeath(...)`; corpo nasce depois | bytecode `IsoZombie.onKilled` 38–63 |
| `removeCorpse(body, false)` no servidor | manda `RemoveCorpseFromMap` por `sendToRelative` | bytecode `IsoGridSquare.removeCorpse` 45–74 |
| queimar corpo | `IsoDeadBody.Burn` troca por objeto `burnedCorpse` e chama `removeCorpse` | bytecode `IsoDeadBody.Burn` 142–204 |
| `removeFromWorld` no cliente | chama `GameClient.removeZombieFromCache(z)` e tira da lista da célula | bytecode `IsoZombie.removeFromWorld` 146–167 |
| sandbox `integer` | aceito no parser de opção de mod | string `integer` em `zombie/sandbox/CustomSandboxOptions` |

## Decisões

1. **Identidade do Eco = outfit `NOM_Eco` reconhecido pela chave do `persistentOutfitID`.** Chave = `floor(id / 65536)` (índice + sexo). A chave é aprendida em cada spawn e guardada em `ModData.getOrCreate("NevoaEOutroMundo").ecoOutfitKeys`. No `OnZombieCreate`, zumbi com chave conhecida é vestido pelo próprio ID (o que o jogo faria depois) e confirmado por `getOutfitName() == "NOM_Eco"`; se não bater, a chave é velha (lista de mods mudou) e sai do conjunto. Custo se errado: Eco recarregado vira zumbi comum (não some de dia).
2. **Marca em memória:** `z:getModData().NOM_eco = true`. Vale só enquanto o zumbi está carregado (é reaplicada no `OnZombieCreate`) e é copiada pro corpo, que assim é reconhecido.
3. **Sem cadáver:** `OnZombieDead` limpa o inventário e enfileira a posição; o `OnTick` procura no 3×3 em volta corpo com `NOM_eco` e chama `removeCorpse(body, false)`, por até `CORPSE_TICKS` ticks. Fallback: a varredura periódica remove qualquer corpo `NOM_eco` que encontrar. `OnDeadBodySpawn` não serve (não dispara no dedicado).
4. **Amanhecer:** `NOM_World.onChange(fn)` avisa a borda `night` → `false`; o Eco remove todos os Ecos carregados (`removeFromWorld` + `removeFromSquare`) e, em MP, manda `ecoGone` com os `onlineID`s; o cliente apaga o fantasma local. Eco que volta de chunk de dia é removido no tick seguinte ao `OnZombieCreate` (não dá pra remover dentro do evento: o zumbi ainda vai entrar na lista da célula).
5. **Fraqueza:** só vida baixa (`setHealth(0.3)`, reaplicada no `OnZombieCreate`). Lento e dano baixo ficam pra sprint 0003, que cria o swap de `ZombieLore` + `DoZombieStats`. Pendência registrada.
6. **Teto:** por jogador, Ecos vivos a até `EcoRadius` dele contam no teto; spawna no máximo `EcoMaxPerPlayer - perto`, corpos mais próximos primeiro.
7. **Varredura:** `EveryTenMinutes`, quadrado de raio `EcoRadius` no andar do jogador.

## Review Focus

1. **Servidor reinicia com Ecos em chunk descarregado** → de dia, Eco recarregado some; à noite volta como Eco (vida baixa, sem cadáver). Teste `eco_reloaded_by_day_is_removed_next_tick`, `eco_reloaded_at_night_stays_weak` (Task 4).
2. **Spawn falha** (zumbis desligados, `addZombiesInOutfit` vazio) → corpo não é marcado, nada quebra. Teste `eco_spawn_failure_keeps_body_unreleased` (Task 3).
3. **Outfit do mod não carregou** (`persistentOutfitID` 0) → nunca aprende a chave 0, senão todo zumbi sem outfit viraria Eco. Teste `eco_outfit_missing_learns_nothing` (Task 3).
4. **Dois jogadores perto da mesma pilha** → cada corpo solta um Eco só; cada jogador tem o próprio teto. Teste `eco_two_players_share_bodies_once` (Task 3).
5. **Corpo de Eco no chão** (remoção falhou) → nunca solta Eco e a varredura remove. Teste `eco_corpse_is_swept_and_never_releases` (Task 4).

---

### Task 1: Sandbox do Eco

**Files:**
- Modify: `mod/42/media/sandbox-options.txt`, `mod/42/media/lua/shared/NOM_Config.lua`, `mod/42/media/lua/shared/Translate/{PTBR,EN}/Sandbox.json`, `docs/gdd/sandbox.md`
- Test: `tests/test_config.lua`

**Interfaces:** Produces `NOM_Config.get("EcoEnabled"|"EcoMaxPerPlayer"|"EcoRadius")`.

- [ ] **Step 1: teste que falha**

```lua
config_eco_defaults = function()
    SandboxVars = nil
    assert(NOM_Config.get("EcoEnabled") == true)
    assert(NOM_Config.get("EcoMaxPerPlayer") == 30)
    assert(NOM_Config.get("EcoRadius") == 40)
end,
config_sandbox_and_translations_have_every_option = function()
    -- toda opção do sandbox-options.txt tem default, rótulo e tooltip nas duas línguas
end,
```

- [ ] **Step 2:** `./run-tests.sh` → FAIL (`EcoEnabled` nil).
- [ ] **Step 3:** defaults em `NOM_Config.DEFAULTS`; opções no `sandbox-options.txt`:

```
option NevoaEOutroMundo.EcoEnabled = { type = boolean, default = true, page = NevoaEOutroMundo, translation = NevoaEOutroMundo.EcoEnabled, }
option NevoaEOutroMundo.EcoMaxPerPlayer = { type = integer, min = 0, max = 200, default = 30, ... }
option NevoaEOutroMundo.EcoRadius = { type = integer, min = 5, max = 100, default = 40, ... }
```
  e chaves `Sandbox_NevoaEOutroMundo.Eco*` (+ `_tooltip`) em PTBR e EN.
- [ ] **Step 4:** `./run-tests.sh` → PASS.
- [ ] **Step 5:** commit `feat: opções de sandbox do Eco`.

### Task 2: Regras puras do Eco

**Files:**
- Create: `mod/42/media/lua/shared/NOM_EcoRules.lua`
- Test: `tests/test_eco_rules.lua` (registrar em `tests/run.lua`)

**Interfaces:** Produces
- `NOM_EcoRules.outfitKey(id) -> number` (`math.floor(id / 65536)`; `nil` para id 0)
- `NOM_EcoRules.pick(cands, radius, quota) -> {cand...}`: `cand = { dist2, animal, released, eco, ... }`; devolve os elegíveis (não animal, não liberado, não corpo de Eco, `dist2 <= radius²`), mais perto primeiro, no máximo `quota`.
- `NOM_EcoRules.quota(cap, near) -> number` (`max(0, cap - near)`)

- [ ] **Step 1: testes que falham**

```lua
rules_key_separates_index_and_sex = function()
    local male = 7 * 65536 + 123
    local female = 7 * 65536 + 5 - 2147483648 -- bit 31 ligado, int com sinal
    assert(NOM_EcoRules.outfitKey(male) == NOM_EcoRules.outfitKey(7 * 65536 + 499))
    assert(NOM_EcoRules.outfitKey(male) ~= NOM_EcoRules.outfitKey(female))
    assert(NOM_EcoRules.outfitKey(0) == nil)
end,
rules_pick_filters_and_caps = function() ... end,   -- 60 corpos, quota 30 → 30, os mais perto
rules_pick_respects_radius_circle = function() ... end, -- canto do quadrado fica de fora
rules_quota_never_negative = function() assert(NOM_EcoRules.quota(30, 45) == 0) end,
```
- [ ] **Step 2:** FAIL (módulo não existe). **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit `feat: regras puras do Eco`.

### Task 3: Borda de noite no NOM_World + spawn do Eco

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_World.lua`
- Create: `mod/42/media/lua/server/NOM_Eco.lua`, `mod/42/media/clothing/clothing.xml`
- Test: `tests/test_world.lua`, `tests/test_eco.lua` (fake que imita o jogo), registrados em `tests/run.lua`

**Interfaces:**
- Produces `NOM_World.onChange(fn)`; `fn(flag, value)` com `flag` `"night"`/`"fog"`, chamada só na borda.
- `NOM_Eco` não exporta nada: se registra em `EveryTenMinutes`, `OnZombieCreate`, `OnZombieDead`, `OnTick` e `NOM_World.onChange`.

O fake de `tests/test_eco.lua` imita o jogo nos pontos que importam:
- `addZombiesInOutfit` dispara `OnZombieCreate` com o ID de zona **antes** de vestir; veste com `pickOutfit` (bit 31 + índice<<16 + semente; 0 se o outfit não existe); vida 1.0; o zumbi só entra em `getZombieList()` depois do evento.
- zumbi recarregado: objeto novo, `modData` vazio, só o `persistentOutfitID`, `getOutfitName()` `nil` até `dressInPersistentOutfitID`.
- morte: inventário cheio → `OnZombieDead` → corpo nasce N ticks depois, com `modData` copiado, possivelmente no square vizinho; `OnDeadBodySpawn` não existe (servidor).
- `ModData.getOrCreate` sobrevive a "reiniciar" o módulo (novo `dofile`).

- [ ] **Step 1: testes que falham** — `world_on_change_fires_only_on_edges`, `eco_spawns_one_per_body_at_night`, `eco_nothing_by_day`, `eco_disabled_spawns_nothing`, `eco_cap_respected_with_60_bodies`, `eco_periodic_scan_catches_new_bodies`, `eco_ignores_animals_and_released`, `eco_released_flag_survives_restart`, `eco_spawn_failure_keeps_body_unreleased`, `eco_outfit_missing_learns_nothing`, `eco_two_players_share_bodies_once`, `eco_spawned_is_weak`, `eco_outfit_xml_has_both_sexes`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar o listener no `NOM_World` e o spawn no `NOM_Eco`:

```lua
local function spawnFrom(body)
    local sq = body:getSquare()
    local list = addZombiesInOutfit(sq:getX(), sq:getY(), sq:getZ(), 1, OUTFIT, 50)
    if not list or list:size() == 0 then return false end
    local z = list:get(0)
    markEco(z)
    learnKey(z:getPersistentOutfitID())
    body:getModData().NOM_ecoReleased = true
    return true
end
```
  `clothing.xml` com `NOM_Eco` masculino e feminino: `Gown_Hospital` (`ae2071bc-0d47-4041-b0a5-28c8cfa46c05`) + `Hat_WeddingVeil` (`edf2b504-261e-4baf-9440-48884d80a8bb`), GUIDs do outfit gerados.
- [ ] **Step 4:** PASS. **Step 5:** commits `feat: NOM_World avisa borda de flag`, `feat: Eco nasce de corpo à noite`.

### Task 4: Morte sem cadáver, amanhecer e recarga

**Files:**
- Modify: `mod/42/media/lua/server/NOM_Eco.lua`
- Create: `mod/42/media/lua/client/NOM_EcoClient.lua`
- Test: `tests/test_eco.lua`, `tests/test_eco_client.lua`

- [ ] **Step 1: testes que falham** — `eco_death_clears_inventory_and_removes_corpse`, `eco_corpse_on_neighbor_square_is_removed`, `eco_normal_zombie_keeps_corpse`, `eco_corpse_is_swept_and_never_releases`, `eco_dawn_removes_all`, `eco_dawn_mp_sends_ids`, `eco_reloaded_by_day_is_removed_next_tick`, `eco_reloaded_at_night_stays_weak`, `eco_stale_key_is_dropped`, `client_removes_ghosts_by_online_id`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar (Decisões 3 e 4). **Step 4:** PASS. **Step 5:** commits `feat: Eco morre sem cadáver nem loot`, `feat: Ecos somem no amanhecer`.

### Task 5: Docs

**Files:** `docs/sprints/sprint-0002-eco/README.md`, `docs/sprints/README.md`, `docs/architecture/{adr-003-eco-spawnado.md,pz-api-notes.md,README.md}`, `docs/gdd/{monsters.md,world-states.md}`.

- [ ] README da sprint: status `em teste`, critérios com evidência ou no Roteiro in-game, checkpoints, aprendizados, pendências, sessão.
- [ ] ADR-003: identidade por outfit, chave `NOM_ecoReleased`, morte por varredura do square.
- [ ] pz-api-notes: corrigir `OnDeadBodySpawn` (não dispara no dedicado), ordem do `OnZombieCreate` no spawn, formato do `persistentOutfitID`, `modData` do corpo CONFIRMED por bytecode.
- [ ] Commit `docs: sprint 0002 em teste`.
