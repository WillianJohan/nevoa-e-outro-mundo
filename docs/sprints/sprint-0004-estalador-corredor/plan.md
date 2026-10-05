# Estalador e Corredor noturno — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** À noite, parte dos zumbis vira Estalador (cego, guiado por som, estala) ou Corredor (sprinter que grita e chama a horda), e volta a ser comum ao amanhecer.

**Architecture:** A variante é **derivada, não guardada** (ADR-006): `NOM_VariantRules.variant(persistentOutfitID, noite, cfg)` é uma função pura e determinística. O servidor já conta noites (`ModData` global, Eco); o contador sai do `NOM_Eco` pra `server/NOM_NightCount.lua` e viaja junto da mensagem `night`. Quem simula o zumbi (ADR-005) calcula a mesma resposta: `NOM_NightStats` aplica o perfil da variante (stats) e grava `modData.NOM_variant` em memória; `NOM_VariantAI` faz a regra de cego, o estalo local e detecta o Corredor pegando alvo; o servidor (`server/NOM_Variants.lua`) decide o grito (cooldown, `sendPlaySound` + `addSound`).

**Tech Stack:** Lua 5.1 (Kahlua) do Project Zomboid B42.20.4; testes com luajit (`./run-tests.sh`); sons gerados com Python (numpy) + ffmpeg.

**Spec:** [README da sprint](README.md), [monsters.md](../../gdd/monsters.md#estalador), [ADR-001](../../architecture/adr-001-variantes-por-moddata.md), [ADR-005](../../architecture/adr-005-quem-simula-aplica.md), [pz-api-notes](../../architecture/pz-api-notes.md).

## Global Constraints

- Kahlua: sem `//`, sem `goto`, sem operadores de bit; `unpack`, não `table.unpack`; nada de `string.format("%d")` com float.
- Lógica de jogo no servidor (`lua/server/`, começa com `if isClient() then return end`); lógica pura em `lua/shared/` sem API do jogo.
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode).
- Nada copiado de outro mod; sons gerados por script nosso, registrados no `CREDITS.md`.
- Todo texto visível por chave de tradução, PTBR e EN; sandbox no namespace `NevoaEOutroMundo`.
- Ecos (e futuros especiais) nunca são variantes.
- Sem força nem dano por zumbi ou à noite (decisão do autor); agarrão letal só se existir caminho real de dano por golpe.

## Pesquisa (bytecode B42.20.4) que decide o desenho

- **`persistentOutfitID` chega igual ao cliente**: `ZombiePacket.set` grava `getPersistentOutfitID()` em `outfitId`; `NetworkZombieSimulator.parseZombie` (offsets 140–152) chama `createRealZombieAlways(outfitId, …)` → `PersistentOutfits.getOutfit(id)` devolve o mesmo ID quando válido → `createZombieOutsideWorld`. Fecha o UNKNOWN da pz-api-notes §3.1.
- **Visão não cega**: `updateVisionRadius` prende em 10–20 tiles; visão "ruim" ainda vê a 10. A alavanca real: `OnZombieUpdate` dispara em `IsoZombie.updateInternal` (offset 696) **antes** de `IsoGameCharacter.update` (1029, máquina de estados). O spot vem de `IsoPlayer.TestZombieSpotPlayer` → `IsoZombie.spotted` → `spottedNew`, que só faz `setTarget`. O próprio jogo "cega" assim: `spottedNew` 191–208 faz `setTarget(null)` se `isUseless()`, e 209–235 se o square tem fumaça. `setTarget`, `getTarget`, `isRemoteZombie` públicos em `IsoZombie`; `isSneaking`, `isRunning`, `isSprinting` públicos em `IsoGameCharacter`.
- **Sem dano por golpe**: `AttackState.triggerPlayerReaction` → `BodyDamage.AddRandomDamageFromZombie(zumbi, …)` lê só `crawling`, `inactive`, `scratch/laceration` do zumbi e o `ZombieLore.Strength` global; nenhum evento Lua nesse caminho. `OnPlayerGetDamage` só sai de `BodyDamage.Update` (POISON, HUNGRY, SICK, BLEEDING, THIRST), `Hit` (arma), queda, fogo, carro. `OnWeaponHitCharacter`/`OnHitZombie` saem de `Hit` com arma. Agarrão letal → **pendência**.
- **Alvo do zumbi só existe no dono**: o servidor não recebe `target` (só `PFBData` restaura no cliente que assume a posse). O Corredor que pega alvo é visto no dono e reportado ao servidor.
- **Visual por outfit muda o ID**: vestir outro outfit troca o `persistentOutfitID`, e a variante é função dele. `addVisualBandage` existe mas não tem remoção. Visual fica pendência; o aviso é sonoro.

## Review Focus

1. Zumbi cujo `persistentOutfitID` muda depois de nascer (`addZombiesInOutfit` veste depois do `OnZombieCreate`) — a variante segue o ID atual na próxima passada (`stats_variant_follows_outfit_id`).
2. Eco cujo ID cairia numa variante — continua Eco, lento, sem estalo nem grito (`stats_eco_never_variant`, `variants_server_ignores_eco`).
3. Alvo que pisca (perde e reacha o jogador) — o servidor segura o grito pelo cooldown (`variants_scream_cooldown`).
4. Amanhecer com Estalador agachado do lado — de dia nenhuma regra de cego, nenhum estalo (`ai_day_does_nothing`).
5. Cliente que entra no meio da noite antes da resposta do `nightState` — sem número de noite não há variante (`variant_rules_needs_night_number`, `night_client_takes_night_number`).

---

### Task 1: Opções de sandbox

**Files:** `mod/42/media/sandbox-options.txt`, `mod/42/media/lua/shared/NOM_Config.lua`, `Translate/PTBR|EN/Sandbox.json`, `tests/test_config.lua`.

- [ ] Teste `config_variant_defaults` (EstaladorEnabled true, CorredorEnabled true, EstaladorChance 5, CorredorChance 10, CorredorScreamRadius 40). Rodar: falha.
- [ ] Opções no sandbox (`integer` 0–100 nas chances, 5–100 no raio), defaults no `NOM_Config`, rótulo + tooltip PTBR/EN. `config_every_option_has_default_and_translations` cobre as traduções.
- [ ] `./run-tests.sh` verde. Commit.

### Task 2: Regra pura da variante

**Files:** Create `mod/42/media/lua/shared/NOM_VariantRules.lua`, `tests/test_variant_rules.lua`; register in `tests/run.lua`.

**Produces:** `NOM_VariantRules.variant(id, night, cfg) -> "estalador" | "corredor" | nil`, cfg = `{ estaladorOn, corredorOn, estaladorChance, corredorChance }`; `NOM_VariantRules.config(get)` monta o cfg a partir de `NOM_Config.get`; `NOM_VariantRules.screamReady(lastAt, now) -> bool` (cooldown `SCREAM_COOLDOWN_HOURS = 0.5`).

```lua
local M = 2147483647 -- primo de Mersenne; h * A < 2^53, conta exata em double
local A = 48271      -- minstd
local function mix(h)
    h = (h * A) % M
    return (h + math.floor(h / 65536) * 31) % M -- dobra não linear, sem bit ops
end
function NOM_VariantRules.variant(id, night, cfg)
    if not id or id == 0 or not night then return nil end
    local h = mix(mix(id % M + 1) + night * 7919)
    local roll = mix(h) % 100
    local e = cfg.estaladorOn and cfg.estaladorChance or 0
    local c = cfg.corredorOn and cfg.corredorChance or 0
    if roll < e then return "estalador" end
    if roll < e + c then return "corredor" end
    return nil
end
```

- [ ] Testes: determinístico (mesmo id+noite → mesma resposta), id negativo (bit 31) funciona, id 0 e noite nil → nil, chances 0/100, toggles, taxa ≈ chance em 20 000 IDs reais (formato `índice << 16 + semente`, ±1.5 p.p.), noite seguinte re-sorteia (≥ 50% dos Estaladores mudam), soma > 100 não quebra, `screamReady`.
- [ ] Implementar, verde, commit.

### Task 3: Contador de noites compartilhado e número da noite nos clientes

**Files:** Create `mod/42/media/lua/server/NOM_NightCount.lua`; Modify `server/NOM_Eco.lua` (usa o contador; poda quando a noite muda), `server/NOM_Night.lua` (manda `night` junto do `on`, inclusive no `nightState`; no solo `setNight(on, night)`), `shared/NOM_NightStats.lua` (`setNight(on, night)`, campo `nightNumber`), `client/NOM_NightClient.lua`; tests `test_night.lua`, `test_night_client.lua`, `test_eco.lua`.

**Produces:** `NOM_NightCount.current() -> número | nil` (nil antes do primeiro `OnClimateTick`); dados continuam em `ModData["NevoaEOutroMundo"].eco.{night,inNight}` (save existente não muda).

- [ ] Testes: `night_mp_sends_night_number` (borda e `nightState` levam `night`), `night_sp_passes_night_number`, `night_client_takes_night_number`; os testes do Eco seguem verdes (ordem dos listeners não importa: `syncNight` é por estado).
- [ ] Implementar, verde, commit.

### Task 4: Perfil das variantes no `NOM_NightStats`

**Files:** `shared/NOM_NightRules.lua` (`wanted(night, kind, dayTier, cfg)`, `kind` = nil | "eco" | "estalador" | "corredor"), `shared/NOM_NightStats.lua`, `tests/test_night_rules.lua`, `tests/test_night_stats.lua`.

- Corredor: velocidade 1 (corredor) à noite mesmo com `NightFaster` desligado; sentidos da noite.
- Estalador: velocidade da noite; visão 3 (ruim), audição 1 (apurada).
- Chave sempre `kind .. ":" ..` quando há variante (nunca "day" à noite).
- `md.NOM_variant` = kind (só Estalador/Corredor), apagado no dia e no `forget`.
- Variante = `NOM_VariantRules.variant(z:getPersistentOutfitID(), NOM_NightStats.nightNumber, cfg)`, Eco primeiro.

- [ ] Testes: `stats_corredor_sprints_at_night_and_returns`, `stats_estalador_blind_and_sharp_ears`, `stats_variant_follows_outfit_id`, `stats_eco_never_variant`, `stats_variant_needs_night_number`, `stats_dead_variant_forgets`, regras puras de `wanted` com `kind`.
- [ ] Implementar, verde, commit.

### Task 5: Comportamento onde o zumbi é simulado (`NOM_VariantAI`)

**Files:** Create `shared/NOM_VariantAI.lua`, `client/NOM_VariantsClient.lua`, `tests/test_variant_ai.lua`.

**Produces:** `NOM_VariantAI.install(report)`; `report(z)` é chamado na borda "Corredor passou a ter um jogador como alvo". Eventos: `OnZombieUpdate` (regra de cego + borda do Corredor, só zumbi local `not isRemoteZombie()`), `OnHitZombie` (Estalador golpeado fica alerta: `md.NOM_alert = true`), `EveryOneMinute` (estalo local em toda cópia: `z:getEmitter():playSound("NOM_EstaladorClick")`).

Regra de cego: à noite, Estalador não alerta, alvo `instanceof(t, "IsoPlayer")` com `t:isSneaking()` e sem `isRunning()`/`isSprinting()` → `z:setTarget(nil)`.

Cliente MP: `report = function(z) sendClientCommand("NevoaEOutroMundo", "corredorSaw", { id = z:getOnlineID() }) end`.

- [ ] Testes contra fake que imita a ordem do jogo (spot → `OnZombieUpdate` → máquina de estados; ataque só com alvo): `ai_estalador_ignores_silent_crouched`, `ai_estalador_hears_walking_player`, `ai_estalador_hit_wakes_it`, `ai_corredor_reports_once_per_acquire`, `ai_remote_untouched`, `ai_day_does_nothing`, `ai_click_only_estalador`, `ai_click_is_spread`, `variants_client_reports_by_online_id`.
- [ ] Implementar, verde, commit.

### Task 6: Servidor decide o grito (`server/NOM_Variants.lua`)

**Files:** Create `server/NOM_Variants.lua`, `tests/test_variants.lua`; Modify `server/NOM_Night.lua` (exporta `NOM_Night.call(src, reach)`, o chamado compensado pela audição).

- Solo: `NOM_VariantAI.install(scream)`. Dedicado: `OnClientCommand "corredorSaw"` → acha o zumbi pelo `onlineID` na `getZombieList()` → `scream(z)`.
- `scream(z)`: noite, não Eco, `variant(...) == "corredor"`, `screamReady(md.NOM_screamAt, worldAgeHours)` → som (`sendPlaySound("NOM_CorredorScream", false, z)` no dedicado, `z:getEmitter():playSound` no solo) + `NOM_Night.call(z, CorredorScreamRadius)`.

- [ ] Testes: `variants_sp_scream_sound_and_call`, `variants_mp_command_finds_zombie`, `variants_scream_cooldown`, `variants_server_ignores_eco`, `variants_server_rejects_non_corredor_and_day`, `variants_scream_reach_is_radius`.
- [ ] Implementar, verde, commit.

### Task 7: Sons procedurais

**Files:** Create `scripts/gen_sounds.py`, `mod/42/media/sound/NOM_EstaladorClick.ogg`, `mod/42/media/sound/NOM_CorredorScream.ogg`, `mod/42/media/scripts/NOM_sounds.txt`, `CREDITS.md`; test `config_sound_scripts_point_to_files` em `tests/test_config.lua`.

Formato do script: igual a `media/scripts/generated/sounds/zombies/sounds_zombie_voice_tutorial.txt:1-12` (`module Base`, `sound X { category = Zombie, clip { file = …, distanceMax = N } }`).

- [ ] Teste: todo `sound` do script aponta pra arquivo que existe, e todo nome usado no Lua existe no script.
- [ ] Gerar com seed fixa, verde, commit.

### Task 8: Documentação

ADR-006 (variantes determinísticas, substitui o mecanismo da ADR-001), status/link na ADR-001, índice em `docs/architecture/README.md`, `monsters.md`, `sandbox.md`, `pz-api-notes.md` (§3.1, §3.2, §3.3), README da sprint (critérios com evidência, Roteiro in-game, Checkpoints, Aprendizados, Pendências, Sessões), `docs/sprints/README.md` → `em teste`. Commit.
