# Debug amigável (NOM.* + painel) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No jogo em `-debug`, o Johan testa o mod com comandos curtos (`NOM.fog()`, `NOM.spawn(5)`, `NOM.help()`) e com um painel de botões aberto por tecla, sem decorar `NOM_Debug.*`.

**Architecture:** Três camadas, cada uma num arquivo. (1) Transporte: `client/NOM_Debug.lua` continua mandando ao servidor e passa a expor `NOM_Debug.send`; o servidor (`server/NOM_DebugServer.lua`) ganha as operações `time` e `spawn` e o `toggle` da névoa, com a mesma porta (`-debug` + permissão no dedicado) e o `NOM_DebugRules.parse` conferindo tudo. (2) Atalhos: `client/NOM_Console.lua` cria a tabela global `NOM` (só cliente com `-debug`): toggles sem argumento invertem o estado local, `god`/`noclip`/`invisible` são locais como no painel de admin do vanilla, `help` lista tudo em PT-BR. (3) Painel: `client/NOM_DebugPanel.lua`, um `ISCollapsableWindow` de botões que chamam `NOM.*`, aberto pela tecla da página de opções do mod (`PZAPI.ModOptions:addKeyBind`, só com `-debug`) ou por `NOM.panel()`.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), `./run-tests.sh`.

**Spec:** [README da sprint](README.md) (objetivo e critérios), pedido do Johan no brief da 0020.

## Evidência (B42.21 instalado)

| Uso | Evidência |
|---|---|
| Autocomplete do console é só Java | `UIDebugConsole.InitSuggestionEngine` 0–15: `LuaManager$GlobalObject.getDeclaredMethods()` → `globalLuaMethods`; função Lua nunca entra |
| `PZAPI.ModOptions` tem tecla | `client/PZAPI/ModOptions.lua:182-204` (`addKeyBind(id, nome, tecla, dica)`, `getValue()` = código), `:276-280` (save), `:326-327` (load); tela: `MainOptions.lua:2987-3010` |
| `Keyboard.KEY_F7` | constante no `org/lwjglx/input/Keyboard.class`; nenhum Lua vanilla usa F7 (só F1–F6, F8, F10, F11 em `shared/keyBinding.lua` e `WorldMapEditor.lua:209`) |
| `ISCollapsableWindow` | `client/ISUI/ISCollapsableWindow.lua` (`new`, `createChildren`, `close` = `setVisible(false)`); exemplo de debug com botões e tecla: `client/DebugUIs/ISFilmingToolsUI.lua` |
| Lembrar posição | `ISLayoutManager.RegisterWindow(nome, ISCollapsableWindow, janela)` (`client/TimedActions/ISBBQInfoAction.lua:29`; `ISLayoutManager.lua:6-60` grava x/y no layout) |
| God / noclip / invisível | `client/ISUI/AdminPanel/ISAdminPowerUI.lua:31-53` (`is/setInvisible`, `is/setGodMod`, `is/setNoClip`) e `:403` (`sendPlayerExtraInfo(player)` depois de mudar) |
| Hora | `getGameTime():setTimeOfDay(h)` (`client/LastStand/LastStandSetup.lua:63`); no MP o relógio é do servidor (`GameTime` tem `syncClock`/`TimeSync`) |
| Spawn | `addZombiesInOutfit(x, y, z, n, outfit, femaleChance)` (pz-api-notes §1.3); outfit `nil` vale (`ISSpawnHordeUI.lua:73, 276`) |
| Frente do jogador | `player:getForwardDirection():getDirection()` em radianos (`shared/Fishing/FishingRod.lua:286`) |
| Botão | `ISButton:new(x, y, w, h, título, alvo, onclick)`, `onclick(alvo, botão)` (`ISButton.lua:47, 479`); `setTitle` (`:282`) |

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit, `next()`; `unpack`; resto de hora pelo `NOM_Math.mod`.
- Nada de `NOM` nem painel sem `-debug`; servidor confere `-debug` e a permissão de debug no dedicado (ADR-002).
- `NOM_Debug.*` continuam iguais (docs antigas valem).
- Todo texto do painel por chave `UI_NOM_Debug*`, PT-BR e EN, sem `%` sozinho.
- Spawn limitado a 50 por chamada e a 10 tiles do jogador (o servidor confere).

## Review Focus

1. `NOM.fog()` durante os 30 s da sirene: tem de cancelar, não tocar outra sirene — o servidor decide o toggle (`debug_fog_toggle_cancels_siren`).
2. `NOM.spawn(1000)`, `NOM.spawn(-3)`, `NOM.spawn("x")`: 50, 1 e erro na tela sem mandar nada — `debug_rules_spawn_clamps`, `nom_spawn_clamps_and_aims_ahead`.
3. Cliente malicioso manda `spawn` com x/y longe: o servidor recusa — `debug_server_spawn_rejects_far`.
4. Painel fechado continua pegando clique: fechar tira do UIManager — `debug_panel_close_removes_from_ui`.
5. `NOM.time(25)` / `NOM.time(-1)`: 1 h e 23 h — `nom_time_wraps_hour`.

---

### Task 1: Regras novas (`time`, `spawn`, toggle da névoa)

**Files:** Modify `mod/42/media/lua/shared/NOM_DebugRules.lua`; Test `tests/test_debug_rules.lua`.

**Interfaces:** Produces `NOM_DebugRules.MAX_SPAWN = 50`, `NOM_DebugRules.SPAWN_REACH = 10`, `NOM_DebugRules.clampSpawn(n) -> int|nil`, `parse({op="time", hour})`, `parse({op="spawn", n, outfit, x, y, z})`, `parse({op="fog", toggle=true})`.

- [ ] Testes: `debug_rules_parse_time` (0, 23.5 aceitos; 24, -1, NaN, "x" recusados), `debug_rules_spawn_clamps` (1000→50, -3→1, 2.7→2, NaN/"x"→nil), `debug_rules_parse_spawn` (outfit nil ou string ≤ 64; x/y/z número), `debug_rules_parse_fog_toggle`.
- [ ] Rodar `./run-tests.sh`: falham.
- [ ] Implementar no `parse`:

```lua
elseif op == "time" then
    local h = args.hour
    if type(h) ~= "number" or h ~= h or h < 0 or h >= 24 then return nil end
    return { op = op, hour = h }
elseif op == "spawn" then
    local n = NOM_DebugRules.clampSpawn(args.n)
    if not n then return nil end
    if args.outfit ~= nil and (type(args.outfit) ~= "string" or #args.outfit > 64) then return nil end
    for _, k in ipairs({ "x", "y", "z" }) do
        if type(args[k]) ~= "number" or args[k] ~= args[k] then return nil end
    end
    return { op = op, n = n, outfit = args.outfit, x = args.x, y = args.y, z = args.z }
```

e `toggle` booleano opcional no `fog`.
- [ ] Verde; commit.

### Task 2: Servidor aplica `time`, `spawn`, toggle

**Files:** Modify `mod/42/media/lua/server/NOM_DebugServer.lua`, `mod/42/media/lua/client/NOM_Debug.lua` (`NOM_Debug.send = send`); Test `tests/test_debug.lua`.

- [ ] Testes contra o jogo falso: `debug_time_sets_clock` (`setTimeOfDay` recebe a hora; linha `[NOM] debug hora=13.50`), `debug_server_spawn_in_front` (`addZombiesInOutfit(x, y, z, n, outfit, 50)` com o tile pedido; linha `spawn n=5 criados=5 outfit=-`), `debug_server_spawn_rejects_far`, `debug_fog_toggle_starts_and_stops` (sem nada → sirene; com sirene contando → `stop`; névoa aberta → `stop`), gating igual aos outros (sem `-debug`, sem permissão: nada).
- [ ] Implementar:

```lua
function ops.fog(_, a)
    if a.toggle then
        a.value = not (NOM_World.fog or NOM_FogEvent.status().sirenMs ~= nil)
    end
    ...
end
function ops.time(_, a)
    getGameTime():setTimeOfDay(a.hour)
    return "hora=" .. fmt(a.hour)
end
function ops.spawn(player, a)
    local dx, dy = a.x - player:getX(), a.y - player:getY()
    if dx * dx + dy * dy > R.SPAWN_REACH * R.SPAWN_REACH then return "spawn longe" end
    local list = addZombiesInOutfit(math.floor(a.x), math.floor(a.y), math.floor(a.z), a.n, a.outfit, 50)
    return "spawn n=" .. a.n .. " criados=" .. (list and list:size() or 0) .. " outfit=" .. tostring(a.outfit or "-")
end
```
- [ ] Verde; commit.

### Task 3: Tabela `NOM` (atalhos)

**Files:** Create `mod/42/media/lua/client/NOM_Console.lua`; Test `tests/test_console.lua` (registrar em `tests/run.lua`).

**Interfaces:** Consumes `NOM_Debug.send/night/fog/redFog/variant/spawnEco/status`, `NOM_NightStats.night`, `NOM_FogState.on/red`, `NOM_DebugRules.clampSpawn`. Produces `NOM.fog(on, skip)`, `NOM.redFog(on)`, `NOM.night(on)`, `NOM.time(h)`, `NOM.spawn(n, outfit)`, `NOM.variant(kind)`, `NOM.eco()`, `NOM.god(on)`, `NOM.noclip(on)`, `NOM.invisible(on)`, `NOM.status()`, `NOM.help()`, `NOM.panel()`, `NOM.HELP` (lista `{ "NOM.x(...)", "descrição" }`).

- [ ] Testes (jogo falso do `test_debug.lua`, com jogador que tem `getForwardDirection`, `is/setGodMod`, `is/setNoClip`, `is/setInvisible` e `sendPlayerExtraInfo` registrador): `nom_absent_without_debug`, `nom_absent_on_server`, `nom_fog_toggle_goes_to_server`, `nom_fog_explicit_is_old_fog`, `nom_red_and_night_flip_local_state`, `nom_time_wraps_hour`, `nom_spawn_clamps_and_aims_ahead`, `nom_variant_eco_status_alias`, `nom_cheats_toggle_and_sync` (god/noclip/invisible: sem argumento inverte, com argumento fixa, `sendPlayerExtraInfo` a cada mudança), `nom_help_lists_every_command` (todo `NOM.<f>` aparece no `help` e todo item do `HELP` existe), `nom_old_debug_still_works`.
- [ ] Implementar (ver o arquivo; toggles: `if on == nil then on = not <estado> end`).
- [ ] Verde; commit.

### Task 4: Tecla nas opções do mod

**Files:** Modify `mod/42/media/lua/client/NOM_ScreenFxOptions.lua`; Test `tests/test_screen_fx_options.lua`; traduções `UI.json` (PT-BR/EN).

- [ ] Testes: `screenfx_options_debug_key_only_in_debug` (com `getDebug()` → `addKeyBind("DebugPanel", "UI_NOM_DebugPanelKey", Keyboard.KEY_F7, ...)`; sem → nada e `debugPanelKey()` nil), `screenfx_options_debug_key_follows_rebind` (troca `option.key` → `debugPanelKey()` lê o novo), sem PZAPI → F7.
- [ ] Implementar:

```lua
if getDebug() then
    page:addKeyBind("DebugPanel", "UI_NOM_DebugPanelKey", Keyboard.KEY_F7, "UI_NOM_DebugPanelKey_tooltip")
end
function O.debugPanelKey()
    if not getDebug() then return nil end
    return value("DebugPanel", Keyboard.KEY_F7)
end
```
- [ ] Verde; commit.

### Task 5: Painel

**Files:** Create `mod/42/media/lua/client/NOM_DebugPanel.lua`; Test `tests/test_debug_panel.lua`; traduções `UI.json`.

**Interfaces:** Produces `NOM_DebugPanel.toggle()`, `NOM_DebugPanel.instance`, `NOM_DebugPanel.statusText()`.

- [ ] Testes contra um ISUI falso que imita o vanilla (`ISCollapsableWindow:derive`, `ISButton:new(x, y, w, h, título, alvo, onclick)` chamando `onclick(alvo, botão)`, `addToUIManager`/`removeFromUIManager` numa lista, `setVisible`, `ISLayoutManager.RegisterWindow`): `debug_panel_absent_without_debug`, `debug_panel_key_toggles` (tecla da opção abre; de novo fecha; outra tecla nada), `debug_panel_close_removes_from_ui`, `debug_panel_buttons_call_nom` (cada botão chama o `NOM.*` certo: névoa, pular sirene, vermelha, noite/dia/relógio, horas, spawn 1/5/10, quatro variantes, Eco, god, noclip, invisível), `debug_panel_status_refreshes_each_second` (texto muda só depois de 1000 ms), `debug_panel_remembers_position` (`RegisterWindow` uma vez com a janela).
- [ ] Implementar a janela com uma tabela de linhas `{ { chave, função }, ... }`, botões criados num laço, título dos toggles com "sim/não", status no `prerender`.
- [ ] Verde; commit.

### Task 6: Docs

- [ ] README da sprint (critérios com evidência, roteiro in-game, checkpoints, aprendizados, pendências), roadmap (`em teste`), `docs/teste-in-game.md` (tabela de atalhos com `NOM.*` e o painel), README (seção de desenvolvimento), `pz-api-notes.md` §18, estrutura em `docs/architecture/README.md`.
- [ ] Commit.
