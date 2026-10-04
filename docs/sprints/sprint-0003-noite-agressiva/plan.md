# Sprint 0003 — Noite agressiva: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** À noite, todo zumbi fica mais rápido, percebe mais longe e é chamado até o jogador; a lanterna ligada ao ar livre vira farol; tudo volta ao normal ao amanhecer e o Eco fica lento.

**Architecture:** O servidor decide (flag `night` do `NOM_World`, caça e lanterna por `addSound`). Quem simula o zumbi aplica: no solo, o próprio processo; no MP, cada cliente nas suas cópias, avisado pelo servidor (`night`). A aplicação troca `ZombieLore.Speed/Sight/Hearing/Cognition` do sandbox, chama `DoZombieStats()` + `doZombieSpeed(degrau)` e restaura o sandbox na mesma chamada. Um laço em lotes por tick (round-robin) leva cada zumbi ao perfil certo (dia, noite, Eco); nada precisa sobreviver no zumbi: o jogo re-sorteia os stats quando ele volta do virtual, e o laço reaplica.

**Tech Stack:** Project Zomboid B42.20.4 (Lua via Kahlua, subset de Lua 5.1), `luajit` para testes, bash.

**Spec:** [README da sprint](README.md), [GDD night.md](../../gdd/night.md), [GDD sandbox.md](../../gdd/sandbox.md), [ADR-002](../../architecture/adr-002-autoridade-servidor.md), [pz-api-notes §2](../../architecture/pz-api-notes.md#2-agressividade-noturna-sprint-0003).

## Global Constraints

- Mod id e namespace de sandbox: `NevoaEOutroMundo`. Globais e arquivos Lua com prefixo `NOM_`.
- Kahlua: nada de `//`, `goto`, bit ops, `table.unpack` (usar `unpack`), `string.format("%d")` em float.
- Lógica de jogo autoritativa em `lua/server/` (primeira linha `if isClient() then return end`); cliente em `lua/client/` (`if not isClient() then return end`). Regra pura em `lua/shared/` sem API do jogo.
- Todo texto visível por chave de tradução, PTBR e EN, em `media/lua/shared/Translate/<LANG>/*.json`.
- Sandbox: `NightFaster`, `NightSharperSenses`, `NightHunt` (booleanos), `NightSpeedMult`, `NightSenseMult`, `HuntIntervalMinutes`, `HuntRadius`.
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode). O que só o jogo responde vira fallback + linha no roteiro in-game.
- Nada copiado de outros mods. Comentários e docs em português do Brasil.

## Evidência levantada antes do plano (bytecode B42.20.4)

| Pergunta | Resposta | Evidência |
|---|---|---|
| O que `DoZombieStats()` relê | `sight` e `hearing` **sempre** (1..3 do sandbox; 4 = `Rand(3)+1`, 5 = `Rand(2)+2`); `cognition` só se o sandbox é 1 (vira 1) ou 4 (re-sorteia); `strength` **só se o campo ainda é -1**; `memory` com o campo em -1 **ou** sempre que o sandbox é 5/6 (aleatório, re-sorteia); termina em `doZombieSpeed()` e `initCanCrawlUnderVehicle()` (sorteio) | `IsoZombie.DoZombieStats` offsets 0–485 |
| Velocidade por zumbi | `doZombieSpeed(I)` é público. `determineZombieSpeed(t)` devolve `t` se `t ≠ -1`. `doZombieSpeedInternal`: `lore.speed==3 ou t==3` → arrastado; senão 2/3 de chance de `doFakeShambler(t)`; senão `lore==2 ou t==2` → rápido; senão `lore==1 ou t==1` → corredor. **O sandbox manda antes do argumento**: precisa trocar `ZombieLore.Speed` junto | `IsoZombie.doZombieSpeedInternal(I)`, `determineZombieSpeed(I)`, `doZombieSpeedInternal2(I)` |
| `speedType` legível | `getSpeedType()` público; 1 corredor, 2 rápido, 3 arrastado | `IsoZombie.doSprinter/doFastShambler/doShambler` (putfield `speedType`) |
| `setValue` no sandbox sincroniza ou salva? | **Não.** `IntegerConfigOption.setValue(I)`: checa faixa, grava o campo, chama `invokeOnChangeEvent()`, que só chama o callback se houver; só `Core` registra callback (opções do jogo, não do sandbox). Envio é `SandboxOptions.sendToServer()`, salvar é `saveGameFile/saveCurrentGameBinFile`, chamados à parte | `IntegerConfigOption.setValue`, `ConfigOption.invokeOnChangeEvent`; `who` de `setOnChangeCallback` |
| Nome da opção | `getOptionByName("ZombieLore.Speed")` (mapa por `ConfigOption.getName()`); `Speed` 4 valores, `Sight`/`Hearing` 5, `Cognition` 4 | `SandboxOptions.addOption/getOptionByName`, `SandboxOptions$ZombieLore.<init>` |
| Força por zumbi | **Impossível depois do nascimento**: `strength` só é sorteado com o campo em -1, e `createZombieOutsideWorld` chama `DoZombieStats` (offset 421) **antes** do `OnZombieCreate`. E `strength` só serve pra bater em porta/janela/barricada/carro | `VirtualZombieManager.createZombieOutsideWorld`; `who` do campo `IsoZombie.strength` |
| Dano no jogador | Não é por zumbi: `BodyDamage.AddRandomDamageFromZombie` lê o `ZombieLore.Strength` **global** na hora do golpe, na máquina que simula o zumbi (`AttackState.triggerPlayerReaction`); nenhum evento Lua com o zumbi (`OnPlayerGetDamage` só sai de `BodyDamage.Update`/`BodyPart.DamageUpdate`: veneno, fome, sangramento...) | `AddRandomDamageFromZombie` 151–190; `AttackState.triggerPlayerReaction` 367–400 |
| Visão | raio = `20 − penalidade de luz/chuva/névoa`, ×1.75 se `sight==1` **ou sandbox==1**, ×0.35 se `sight==3` **ou sandbox==3**, ÷ item vestido; preso entre 10 e 20 | `IsoZombie.getVisionRadiusAdjusted`, `updateVisionRadius` |
| Audição | `getHearingMultiplier(zumbi)`: 3.0 / 1.0 / 0.45 pelo campo `hearing` do zumbi | `WorldSoundManager.getHearingMultiplier(I)` e `(IsoZombie)` |
| MP: velocidade | Zumbi remoto copia `walkType` e `speedMod` do pacote (`NetworkZombieAI.parse` só se `isRemoteZombie()`); o servidor aceita o `walkType` do dono (`NetworkZombiePacker.applyZombie`). Mudança feita só no servidor é sobrescrita | bytecode citado |
| MP: `OnZombieCreate` no cliente | dispara: `NetworkZombieSimulator.parseZombie` → `createRealZombieAlways` | offset 152 |
| `addSound` no servidor | põe na lista, no popman (virtuais) e manda `GameServer.sendWorldSound` aos clientes | `WorldSoundManager.addSound(...S)` 264–330 |
| Lanterna no servidor | `getActiveLightItem()` = item na mão ou preso com `isEmittingLight()` (`canEmitLight` e, se ativável, `isActivated`); o vanilla sincroniza o liga/desliga com `syncItemActivated` | `IsoPlayer.getActiveLightItem`, `InventoryItem.isEmittingLight`; `client/ISUI/ISInventoryPaneContextMenu.lua:2882-2883` |
| Ao ar livre | `square:isOutside()` | `server/Farming/SFarmingSystem.lua:156` |

## Decisões

1. **"O servidor decide, quem simula aplica"** (ADR-005, emenda a ADR-002). Servidor: flag `night`, caça, lanterna. Aplicação de stats: no solo (`not isServer()`) pelo próprio servidor; no dedicado, por `client/NOM_NightClient.lua` em todas as cópias locais. Custo se errado: no MP a noite não muda a velocidade (o in-game confirma).
2. **Troca do sandbox com restauração garantida** (`pcall`), na mesma chamada Lua. `Cognition` e `Memory` vão pra 2 durante a troca (neutros: não re-sorteiam). `canCrawlUnderVehicle` é guardado e devolvido (o `DoZombieStats` re-sorteia).
3. **Multiplicador vira degrau.** Velocidade e sentidos do jogo são 3 degraus. `degraus = floor(mult − 0.5)`: 1.0 → 0, 1.5 → 1, 2.5 → 2. Padrão 1.5: um degrau (arrastado → rápido → corredor; visão normal → águia; audição normal → apurada). Sandbox Aleatório (4/5) usa normal como base dos sentidos; velocidade aleatória usa o `speedType` que o zumbi tinha.
4. **Dano e força ficam de fora** (pendência): não existe caminho por zumbi (tabela acima). `NightDamageMult` **não** entra no sandbox: opção que não faz nada é mentira.
5. **Cache só em memória.** `modData.NOM_night` guarda o perfil aplicado (`nil` = intocado/dia). Não é salvo e é zerado no reaproveitamento (`resetForReuse`), exatamente quando o jogo re-sorteia os stats. De dia, zumbi intocado nunca é tocado. `OnZombieDead` apaga a chave (o corpo copia o `modData`).
6. **Laço em lotes:** `BATCH = 20` zumbis por tick, fila do `OnZombieCreate` primeiro dentro do mesmo orçamento, depois round-robin em `getCell():getZombieList()`. Reaplica se o perfil mudou ou se o `speedType` não bate (o jogo re-rolou: `addZombiesInOutfit`, `makeInactive`). Zumbi remoto não tem a velocidade conferida (o pacote manda nela).
7. **Eco:** perfil próprio — arrastado (3), sentidos do dia. Reconhecido por `modData.NOM_eco` (solo) ou `getOutfitName() == "NOM_Eco"` (cliente de MP, onde o `modData` do servidor não chega).
8. **Caça:** a cada `HuntIntervalMinutes` minutos de jogo à noite, `addSound(jogador, x, y, z, HuntRadius, HuntRadius)` na posição de cada jogador vivo (contador em memória de `EveryOneMinute`).
9. **Lanterna:** o zumbi não tem alcance de visão por zumbi além dos degraus (e preso em 20). Aproximação: a cada minuto à noite, jogador com luz ativa num square `isOutside()` gera `addSound` com raio `20 × NightSenseMult` (20 = teto da visão).

## Review Focus

1. **Salvar à noite e carregar de dia** → nenhum zumbi noturno e o sandbox salvo intacto. Teste `stats_reload_by_day_is_untouched` e `stats_sandbox_restored_after_apply` (Task 3).
2. **Erro dentro do `DoZombieStats`** → o sandbox volta mesmo assim. Teste `stats_sandbox_restored_when_stats_throw` (Task 3).
3. **Sandbox "Arrastados"** → a noite ainda promove (o `lore.speed==3` vence o argumento; por isso a troca). Teste `stats_shambler_sandbox_still_promotes` (Task 3).
4. **Horda de 200** → trabalho por tick limitado ao lote. Teste `stats_batch_bounded_with_200` (Task 3).
5. **Zumbi remoto no MP** → laço não briga com o pacote. Teste `stats_remote_speed_not_fought` (Task 3).

---

### Task 1: Sandbox da noite

**Files:**
- Modify: `mod/42/media/sandbox-options.txt`, `mod/42/media/lua/shared/NOM_Config.lua`, `mod/42/media/lua/shared/Translate/{PTBR,EN}/Sandbox.json`
- Test: `tests/test_config.lua`

**Interfaces:** Produces `NOM_Config.get("NightFaster"|"NightSharperSenses"|"NightHunt"|"NightSpeedMult"|"NightSenseMult"|"HuntIntervalMinutes"|"HuntRadius")`.

- [ ] **Step 1: teste que falha**

```lua
config_night_defaults = function()
    SandboxVars = nil
    assert(NOM_Config.get("NightFaster") == true)
    assert(NOM_Config.get("NightSharperSenses") == true)
    assert(NOM_Config.get("NightHunt") == true)
    assert(NOM_Config.get("NightSpeedMult") == 1.5)
    assert(NOM_Config.get("NightSenseMult") == 1.5)
    assert(NOM_Config.get("HuntIntervalMinutes") == 60)
    assert(NOM_Config.get("HuntRadius") == 30)
end,
```
- [ ] **Step 2:** `./run-tests.sh` → FAIL.
- [ ] **Step 3:** defaults; opções (`NightSpeedMult`/`NightSenseMult` double 1.0–3.0; `HuntIntervalMinutes` integer 10–720; `HuntRadius` integer 5–100); rótulo + `_tooltip` PTBR/EN (o teste de tradução já existente cobre).
- [ ] **Step 4:** PASS. **Step 5:** commit `feat: opções de sandbox da noite agressiva`.

### Task 2: Regras puras da noite

**Files:** Create `mod/42/media/lua/shared/NOM_NightRules.lua`; Test `tests/test_night_rules.lua` (registrar em `tests/run.lua`).

**Interfaces:** Produces
- `NOM_NightRules.steps(mult) -> int` (`floor(mult − 0.5)`, 0 abaixo de 1)
- `NOM_NightRules.sharpen(tier, steps) -> int` (`max(1, tier − steps)`)
- `NOM_NightRules.baseSense(v) -> int` (1..3 fica; 4/5 → 2)
- `NOM_NightRules.dayTier(sandboxSpeed, current) -> int` (1..3 do sandbox; senão `current`)
- `NOM_NightRules.wanted(night, eco, dayTier, cfg) -> { key, speed, sight?, hearing? }`; `cfg = { fasterOn, sensesOn, speedMult, senseMult, sight, hearing }`; `key == "day"` quando nada muda
- `NOM_NightRules.ECO_SPEED = 3`, `NOM_NightRules.torchRadius(senseMult) -> int` (`floor(20 × mult)`)
- `NOM_NightRules.huntTick(minutes, interval) -> minutes, due`

- [ ] **Step 1: testes que falham** — `night_rules_steps`, `night_rules_sharpen_clamps`, `night_rules_base_sense_random_is_normal`, `night_rules_day_tier`, `night_rules_wanted_day`, `night_rules_wanted_night_default`, `night_rules_wanted_eco_slow_and_unboosted`, `night_rules_wanted_toggles_off_is_day`, `night_rules_wanted_only_senses`, `night_rules_hunt_tick`, `night_rules_torch_radius`.

```lua
night_rules_wanted_night_default = function()
    local w = NOM_NightRules.wanted(true, false, 2, { fasterOn = true, sensesOn = true,
        speedMult = 1.5, senseMult = 1.5, sight = 2, hearing = 2 })
    assert(w.speed == 1 and w.sight == 1 and w.hearing == 1 and w.key ~= "day")
end,
night_rules_wanted_toggles_off_is_day = function()
    local w = NOM_NightRules.wanted(true, false, 2, { fasterOn = false, sensesOn = false,
        speedMult = 3, senseMult = 3, sight = 2, hearing = 2 })
    assert(w.key == "day" and w.speed == 2 and w.sight == nil)
end,
```
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit `feat: regras puras da noite agressiva`.

### Task 3: Aplicador de stats em lotes (`NOM_NightStats`)

**Files:** Create `mod/42/media/lua/shared/NOM_NightStats.lua`; Test `tests/test_night_stats.lua` (registrar).

Arquivo em `shared/` porque roda no servidor do solo **e** no cliente de MP (como `NOM_World`, usa API do jogo).

**Interfaces:**
- Consumes `NOM_NightRules.*`, `NOM_Config.get`.
- Produces `NOM_NightStats.BATCH`, `NOM_NightStats.night` (bool), `NOM_NightStats.setNight(on)`, `NOM_NightStats.tick()`, `NOM_NightStats.enqueue(z)`, `NOM_NightStats.forget(z)`, `NOM_NightStats.install()` (registra `OnTick`, `OnZombieCreate`, `OnZombieDead`).

O fake imita o bytecode: sandbox com `getOptionByName(nome):getValue()/setValue(v)`; `DoZombieStats` relê `sight`/`hearing` (4/5 sorteiam), `cognition` só em 1/4, chama `doZombieSpeed()` com o `speedType` atual e re-sorteia `canCrawlUnderVehicle`; `doZombieSpeed(t)` com o sandbox mandando antes do argumento; zumbi recarregado é objeto novo com stats do sandbox e `modData` vazio.

- [ ] **Step 1: testes que falham** — `stats_night_boosts_speed_and_senses`, `stats_dawn_restores_day`, `stats_sandbox_restored_after_apply`, `stats_sandbox_restored_when_stats_throw`, `stats_shambler_sandbox_still_promotes`, `stats_eco_slow_and_unboosted`, `stats_eco_by_outfit_name`, `stats_toggles_respected`, `stats_batch_bounded_with_200`, `stats_reload_at_night_reapplies`, `stats_reload_by_day_is_untouched`, `stats_game_reroll_is_detected`, `stats_remote_speed_not_fought`, `stats_keeps_crawl_under_vehicle`, `stats_cognition_not_rerolled`, `stats_day_writes_nothing`, `stats_dead_forgets`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar (troca com `pcall`, perfil por `NOM_NightRules.wanted`, fila + round-robin num orçamento de `BATCH`). **Step 4:** PASS. **Step 5:** commit `feat: stats noturnos aplicados em lotes`.

### Task 4: Servidor — noite, caça e lanterna

**Files:**
- Create: `mod/42/media/lua/server/NOM_Players.lua` (lista de jogadores, extraída do `NOM_Eco`), `mod/42/media/lua/server/NOM_Night.lua`
- Modify: `mod/42/media/lua/server/NOM_Eco.lua` (usa `NOM_Players.all()`), `tests/run.lua` (path de `server/`)
- Test: `tests/test_night.lua`

**Interfaces:** `NOM_Players.all() -> { IsoPlayer... }`. `NOM_Night` não exporta nada.

- [ ] **Step 1: testes que falham** — `night_sp_drives_stats`, `night_mp_broadcasts_edge_only`, `night_mp_replies_state_to_client`, `hunt_every_interval_at_night`, `hunt_resets_by_day_and_toggle`, `torch_outside_at_night_attracts`, `torch_needs_outside_light_night_and_toggle`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS (os testes do Eco seguem verdes). **Step 5:** commit `feat: servidor decide a noite, caça e lanterna`.

### Task 5: Cliente de MP aplica

**Files:** Create `mod/42/media/lua/client/NOM_NightClient.lua`; Test `tests/test_night_client.lua`.

- [ ] **Step 1: testes que falham** — `night_client_inert_outside_mp`, `night_client_follows_server`, `night_client_asks_state_on_join`, `night_client_ignores_other_commands`.
- [ ] **Step 2–5:** FAIL → implementar → PASS → commit `feat: cliente de MP aplica a noite`.

### Task 6: Docs

- ADR-005 nova + índice; ADR-002 (consequência apontando a ADR-005); ADR-003 (Eco lento); `night.md`, `sandbox.md`; `pz-api-notes.md` §2 (UNKNOWNs resolvidos); README da sprint (`em teste`, critérios com evidência, roteiro in-game, checkpoints, aprendizados, pendências); roadmap.
- Commit `docs: sprint 0003 em teste`.
