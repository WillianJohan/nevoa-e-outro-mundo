# Balanceamento, MP e performance — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deixar o mod pronto pra uma única sessão de teste in-game do Johan: pendências que dá pra provar sem o jogo resolvidas, caminhos quentes medidos e travados por teste, comandos de debug pra forçar estados, roteiro in-game consolidado, remoção do mod de um save analisada, presets e defaults documentados.

**Architecture:** Nada muda no desenho (ADR-002/005/006/007). Os comandos de debug são um arquivo de cliente (`client/NOM_Debug.lua`, só existe com `getDebug()`) que manda tudo pro servidor por `sendClientCommand` (no solo o mesmo comando vira `OnClientCommand` local), e um arquivo de servidor (`server/NOM_DebugServer.lua`) que confere `getDebug()` (e a permissão de debug no dedicado) antes de escrever em duas tabelas de "forçado": `NOM_World.forced` (noite e névoa, lidas no `update`) e `NOM_VariantRules.forced` (variante por `persistentOutfitID`, lida no sorteio — servidor e clientes usam o mesmo sorteio, então todos concordam). Performance: o `NOM_NightStats` dorme de dia depois de uma passada limpa; o estalo e a varredura do Sem-rosto olham tabela Lua/ID antes de qualquer outra chamada Java.

**Tech Stack:** Lua 5.1 (Kahlua) do Project Zomboid B42.20.4; testes com luajit (`./run-tests.sh`).

**Spec:** [README da sprint](README.md), [sandbox.md](../../gdd/sandbox.md), READMEs das sprints 0001–0005 (pendências), [pz-api-notes](../../architecture/pz-api-notes.md).

## Global Constraints

- Kahlua: sem `//`, sem `goto`, sem operadores de bit; `unpack`, não `table.unpack`; nada de `string.format("%d")` com float.
- Lógica de jogo no servidor (`lua/server/`, começa com `if isClient() then return end`); lógica pura em `lua/shared/` sem API do jogo, testada com luajit e registrada em `tests/run.lua`.
- Código com API do jogo testado contra fakes que imitam o jogo (como `tests/test_climate_look.lua`).
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode).
- Nada copiado de outro mod nem do jogo.
- Todo texto visível ao jogador por chave de tradução, PTBR e EN. (Linhas de console de debug não são texto de jogador.)
- Comandos de debug não fazem **nada** fora do `-debug`.
- O jogo não roda aqui: o que precisa do jogo vai pro `docs/teste-in-game.md`.

## Pesquisa (bytecode B42.20.4) que decide o desenho

- **`sendClientCommand` no solo:** `GlobalObject.sendClientCommand(IsoPlayer, …)` fora do MP chama `SinglePlayerClient.sendClientCommand`, que manda o `playerIndex` (0–3) e o servidor local dispara `OnClientCommand` com o jogador. A versão de 3 argumentos passa `null` (índice -1): o debug usa a de 4, com `getSpecificPlayer(0)`.
- **Permissão no dedicado:** `player:getRole():hasCapability(Capability.UseDebugContextMenu)` (CONFIRMED `server/ClientCommands.lua:1280`, `client/DebugUIs/DebugContextMenu.lua:27`).
- **Presets de sandbox:** `GlobalObject.getSandboxPresets()` (0–104) só lista `*.cfg` de `LuaManager.getSandboxCacheDir()` (a pasta do usuário); os vanilla são 5 nomes fixos em `client/OptionScreens/SandboxOptions.lua:891-895`. Mod não tem como entregar preset: fica documentado.
- **Remoção do mod:** `PersistentOutfits.getOutfit(I)` devolve 0 com índice fora da lista (offsets 40–58) e `dressInOutfit` sai com 0 (6–10); `SandboxOptions.load(ByteBuffer)` loga e pula opção desconhecida (95–110); `readLuaFile` só lê as opções conhecidas (`fromTable`, 235–272); `GlobalModData.load` lê qualquer tabela sem validar a chave; `ClimateManager.save` só grava os valores de admin (`ClimateFloat.saveAdmin`), não a camada modded.

## Review Focus

1. Debug chamado num jogo sem `-debug` (servidor dedicado normal com cliente malicioso mandando `debug`): nada muda (`debug_server_ignores_without_debug`, `debug_server_requires_capability_on_dedicated`).
2. Dia longo depois de uma noite com horda: zumbi que ainda tem stats da noite não pode ficar preso porque o `NightStats` dormiu cedo (`stats_day_idle_only_after_clean_pass`).
3. Zumbi novo por dia com o `NightStats` dormindo e noite seguinte: tem que voltar a aplicar (`stats_day_idle_wakes_at_night`).
4. Variante forçada num zumbi Eco: Eco nunca é variante, mesmo forçado (`stats_forced_variant_skips_eco`).
5. `NOM_Debug.fog(nil)`/`night(nil)` devolvem o controle ao clima (`debug_force_clears_back_to_climate`).

---

### Task 1: Pendência da 0001 — ramo `ClimateCycle == 6`

**Files:** Modify `tests/test_climate_look.lua` (opção `climateCycle` no `setup`, teste novo).

O ramo `sv.ClimateCycle == 6` de `fogValueOverride()` (nevasca eterna) não tem teste (review round 4 da 0001). A estalada duplicada da 0004 já foi corrigida na 0005 (`ai_click_is_local_on_mp_client`): só conferir.

- [ ] **Step 1:** `setup` aceita `opts.climateCycle` (`SandboxVars.ClimateCycle = opts.climateCycle or 1`). Teste:

```lua
    -- ClimateCycle 6 (nevasca eterna) liga o override de valor da névoa mesmo
    -- com FogCycle normal (bytecode updateSandboxOverrides): ler o final
    look_blizzard_override_uses_final = function()
        local env = setup({ tod = 12, fog = 0.1, K = 10, sandbox = { FogThreshold = 0.5 }, climateCycle = 6 })
        local f = env.floats[5]
        f.override, f.overrideInterp, f.overrideValue, f.overrideInternal = 0.7, 0.5, true, 0.5
        env.run(5)
        assert(NOM_World.fog == true, "nevasca eterna ignorada: leu o interno")
    end,
```

- [ ] **Step 2:** Rodar com o ramo comentado no `NOM_ClimateLook` (`or sv.ClimateCycle == 6` removido): FAIL. Voltar o ramo: PASS. Commit.

### Task 2: Performance — caminhos quentes travados por teste

**Files:** Create `tests/calls.lua`; Modify `shared/NOM_NightStats.lua`, `shared/NOM_VariantAI.lua`, `shared/NOM_SemRosto.lua`; tests `test_night_stats.lua`, `test_variant_ai.lua`, `test_semrosto.lua`, `test_eco.lua`.

**Produces:** `tests/calls.lua` → `function(objs) -> { n = número de chamadas }` (embrulha toda função dos objetos falsos).

Orçamento (vai pro `docs/architecture/README.md`):

| Sistema | Quando | Trabalho |
|---|---|---|
| `NightStats.tick` | todo tick, à noite e na passada do amanhecer | ≤ `BATCH` (20) zumbis + 5 leituras de sandbox; de dia, depois de uma passada limpa, **zero** |
| `VariantAI` `OnZombieUpdate` | todo frame, todo zumbi | zumbi comum: 2 consultas Lua, zero Java |
| `VariantAI` estalo | 1/min à noite | `list:get` por zumbi; zero chamada no zumbi comum |
| `SemRosto.scan` | a cada 10 ticks, só na névoa | 1 chamada (`getPersistentOutfitID`) por zumbi comum |
| `Eco.scan` | a cada 10 min de jogo, à noite | `(2·EcoRadius+1)²` squares por jogador (squares repetidos lidos 1×) + 1 chamada por zumbi |

- [ ] **Step 1: testes que falham**

`tests/calls.lua`:
```lua
-- Conta chamadas de método em objetos falsos (cada uma é uma ida ao Java no jogo).
return function(objs)
    local c = { n = 0 }
    for _, o in ipairs(objs) do
        for k, v in pairs(o) do
            if type(v) == "function" then
                o[k] = function(...) c.n = c.n + 1; return v(...) end
            end
        end
    end
    return c
end
```

`test_night_stats.lua`:
```lua
    stats_day_idle_only_after_clean_pass = function()
        local G = setup()
        local zs = {}
        for i = 1, 300 do zs[i] = G.spawn() end
        NOM_NightStats.setNight(true)
        G.converge()
        NOM_NightStats.setNight(false)
        G.converge() -- passada do amanhecer: devolve todos
        for _, z in ipairs(zs) do assert(z.md.NOM_night == nil, "ficou com stat da noite") end
        G.converge() -- passada limpa
        local c = dofile("tests/calls.lua")(zs)
        local reads = 0
        local orig = getSandboxOptions
        getSandboxOptions = function() reads = reads + 1; return orig() end
        G.tick(50)
        getSandboxOptions = orig
        assert(c.n == 0 and reads == 0, "de dia ocioso e mexeu: zumbi=" .. c.n .. " sandbox=" .. reads)
    end,
    stats_day_idle_wakes_at_night = function()
        local G = setup()
        G.spawn()
        G.converge(); G.converge()
        local z = G.spawn() -- nasce com o NightStats dormindo
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.speedType == 1, "não acordou à noite")
    end,
```

`test_variant_ai.lua`:
```lua
    ai_click_touches_only_estaladores = function()
        local G = setup()
        local zs = {}
        for i = 1, 300 do zs[i] = G.zombie({ x = i, y = 0 }) end
        local before = 0
        for _, z in ipairs(zs) do before = before + z.calls end
        G.minutes(10)
        local after = 0
        for _, z in ipairs(zs) do after = after + z.calls end
        assert(after == before, "estalo chamou zumbi comum: " .. (after - before))
    end,
```

`test_semrosto.lua`:
```lua
    semrosto_scan_one_call_per_common_zombie = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        local zs = {}
        for i = 1, 200 do zs[i] = G.zombie({ x = 100 + i % 20, y = 120 + math.floor(i / 20), id = G.COMMON }) end
        local c = dofile("tests/calls.lua")(zs)
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(c.n <= #zs * 3, "varredura chamou demais: " .. c.n)
    end,
```

`test_eco.lua` (usa o fake da sprint 0002): varredura com 2000 zumbis comuns e corpos fora do raio lê no máximo `(2R+1)²` squares por jogador — se o teste `eco_overlapping_players_scan_each_square_once` já prova a parte dos squares, só somar a contagem de chamadas no zumbi comum (≤ 1 por zumbi por varredura).

- [ ] **Step 2:** Rodar: os três primeiros falham (NightStats sempre mexe, estalo lê `hasModData` de todo zumbi, `isSemRosto` faz 4 chamadas).

- [ ] **Step 3: implementação**

`NOM_NightStats`: estado `idle` e `sweep = { seen = 0, applied = 0 }`.
```lua
-- De dia, uma passada inteira sem nada a devolver = ninguém tem stat da noite:
-- dorme até a próxima mudança de flag. Zumbi que volta do virtual ou é
-- reaproveitado nasce limpo (modData novo/zerado), então nada novo aparece de dia.
-- ponytail: zumbi pulado na passada (lista mudou embaixo do cursor) e de novo na
-- seguinte fica com o stat da noite até ir pro virtual; improvável, aceito.
local idle = false
local sweep = { seen = 0, applied = 0 }
```
No `tick`: `if idle then return end` antes de `getCell()`; de dia, somar `n` (e os da fila) em `sweep.seen` e `applied` em `sweep.applied`; quando `seen >= size`: `idle = applied == 0 and #queue == 0`, zera. `setNight` zera `idle` e `sweep`. `enqueue` de dia com `idle`: só limpa `variants[z]`, não enfileira.

`NOM_VariantAI.clicks`: `if NOM_NightStats.variants[z] == "estalador" and z:getModData().NOM_variant == "estalador" and not z:isDead() and ZombRand(CLICK_ODDS) == 0`.

`NOM_SemRosto.isSemRosto`: ID e sorteio primeiro, `isDead`/Eco depois:
```lua
    if not period then return false end
    cfg = cfg or NOM_VariantRules.semRostoConfig(NOM_Config.get)
    if not NOM_VariantRules.semRosto(z:getPersistentOutfitID(), period, cfg) then return false end
    if z:isDead() then return false end
    return not ((z:hasModData() and z:getModData().NOM_eco) or z:getOutfitName() == ECO_OUTFIT)
```

- [ ] **Step 4:** `./run-tests.sh`: tudo verde. Commit (`perf: …`).

### Task 3: Estados forçados (puro) e regras do debug

**Files:** Modify `shared/NOM_World.lua`, `shared/NOM_VariantRules.lua`; Create `shared/NOM_DebugRules.lua`, `tests/test_debug_rules.lua`; tests `test_world.lua`, `test_variant_rules.lua`, `test_night_stats.lua`.

**Produces:**
- `NOM_World.forced = { night = nil|bool, fog = nil|number }` — lido em `NOM_World.update`.
- `NOM_VariantRules.forced = { [persistentOutfitID] = "estalador"|"corredor"|"semrosto" }` — `variant()` devolve estalador/corredor forçado; `semRosto()` devolve true se forçado (com período conhecido).
- `NOM_DebugRules.parse(args) -> args limpos | nil` (ops `night` {value bool|nil}, `fog` {value número 0..1 preso|nil}, `variant` {id ≠ 0, kind ∈ KINDS|nil}, `spawnEco`, `status`).
- `NOM_DebugRules.line(prefix, t) -> "prefix k1=v1 k2=v2"` em ordem alfabética.

- [ ] **Step 1: testes**

```lua
-- test_world.lua
    world_forced_overrides_climate_and_clears = function()
        local world = load(12)
        NOM_World.forced.night = true
        NOM_World.forced.fog = 0.8
        NOM_World.update(0)
        assert(NOM_World.night and NOM_World.fog and NOM_World.fogIntensity == 0.8)
        NOM_World.forced.night, NOM_World.forced.fog = nil, nil
        NOM_World.update(0)
        assert(not NOM_World.night and not NOM_World.fog, "não voltou pro clima")
        world.tod = 23
        NOM_World.forced.night = false
        NOM_World.update(0)
        assert(not NOM_World.night, "false forçado ignorado")
    end,
-- test_variant_rules.lua
    variant_rules_forced_wins = function()
        local cfg = { estaladorOn = false, corredorOn = false, estaladorChance = 0, corredorChance = 0 }
        NOM_VariantRules.forced[123] = "corredor"
        assert(NOM_VariantRules.variant(123, 1, cfg) == "corredor")
        assert(NOM_VariantRules.variant(123, nil, cfg) == nil, "noite desconhecida")
        NOM_VariantRules.forced[123] = "semrosto"
        assert(NOM_VariantRules.variant(123, 1, cfg) == nil)
        assert(NOM_VariantRules.semRosto(123, 1, { semRostoOn = false, semRostoChance = 0 }))
        NOM_VariantRules.forced[123] = nil
        assert(not NOM_VariantRules.semRosto(123, 1, { semRostoOn = false, semRostoChance = 0 }))
    end,
-- test_night_stats.lua
    stats_forced_variant_skips_eco = function()
        local G = setup()
        local eco = G.spawn({ id = 77, outfit = "NOM_Eco" })
        local z = G.spawn({ id = 78 })
        NOM_VariantRules.forced[77], NOM_VariantRules.forced[78] = "corredor", "corredor"
        NOM_NightStats.setNight(true, 1)
        G.converge()
        NOM_VariantRules.forced[77], NOM_VariantRules.forced[78] = nil, nil
        assert(eco.md.NOM_variant == nil and eco.speedType == 3, "Eco virou Corredor")
        assert(z.md.NOM_variant == "corredor")
    end,
-- test_debug_rules.lua: parse aceita/recusa (op desconhecida, kind inválido, id 0,
-- fog fora de faixa preso, value de tipo errado) e line ordena.
```

- [ ] **Step 2:** FAIL. **Step 3:** implementar (`NOM_World.update`: `local f = NOM_World.forced; if f.fog ~= nil then fogIntensity = f.fog end`; noite: `if f.night ~= nil then night = f.night end`). **Step 4:** PASS, registrar `test_debug_rules.lua` no `tests/run.lua`, commit.

### Task 4: Comandos de debug (cliente e servidor) e `NOM_Eco.spawnAt`

**Files:** Create `client/NOM_Debug.lua`, `server/NOM_DebugServer.lua`, `tests/test_debug.lua`; Modify `server/NOM_Eco.lua` (`NOM_Eco.spawnAt`, `NOM_Eco.loaded`), `tests/test_eco.lua`.

**Interfaces:**
- Consumes: Task 3 (`NOM_World.forced`, `NOM_VariantRules.forced`, `NOM_DebugRules`).
- Produces (console Lua do jogo, só com `-debug`): `NOM_Debug.night(true|false|nil)`, `NOM_Debug.fog(0..1|nil)`, `NOM_Debug.spawnEco()`, `NOM_Debug.variant("estalador"|"corredor"|"semrosto"|nil)` (zumbi mais perto do jogador 0), `NOM_Debug.status()`.
- Comandos: cliente→servidor `debug {op, …}` (4 args, jogador 0); servidor→cliente `debugReply {msg}` (só dedicado), `debugVariant {id, kind}` (todos, só dedicado).
- `NOM_Eco.spawnAt(x, y, z) -> bool` (só à noite, conta na noite atual como os outros); `NOM_Eco.loaded() -> número de Ecos carregados`.

Servidor (`server/NOM_DebugServer.lua`):
```lua
local function allowed(player)
    if not getDebug() or player == nil then return false end
    if not isServer() then return true end -- solo: o -debug basta
    -- server/ClientCommands.lua:1280
    return player:getRole():hasCapability(Capability.UseDebugContextMenu)
end
```
Cada op devolve uma linha `"[NOM] debug …"`: `print` no console de quem roda o servidor e, no dedicado, `sendServerCommand(player, MODULE, "debugReply", { msg = msg })`. `variant` grava `NOM_VariantRules.forced[id] = kind` e, no dedicado, manda `debugVariant` pra todos. `status` monta `{ hora, noite, nevoa, nevoaI, noiteN, nevoaN, forcarNoite, forcarNevoa, forcados, ecos }`.

Cliente (`client/NOM_Debug.lua`): `if isServer() or not getDebug() then return end` no topo. `status()` imprime a linha local (`NightStats.night/nightNumber`, contagem de variantes por tipo em `NOM_NightStats.variants`, `FogState.on/period`, `NOM_SemRosto.nearest`) e pede a do servidor. `OnServerCommand`: `debugReply` imprime, `debugVariant` grava em `NOM_VariantRules.forced`.

- [ ] **Step 1: testes (`tests/test_debug.lua`)** contra fakes: `getDebug` falso → `NOM_Debug` nil e servidor ignora (`debug_client_absent_without_debug`, `debug_server_ignores_without_debug`); solo: `NOM_Debug.night(true)` → `sendClientCommand(jogador0, …)` → `OnClientCommand` → `NOM_World.forced.night == true` e, depois de `NOM_World.update`, noite (`debug_sp_night_round_trip`); `fog(nil)` limpa (`debug_force_clears_back_to_climate`); dedicado sem capability → nada (`debug_server_requires_capability_on_dedicated`); `variant` acha o mais perto, manda o `persistentOutfitID`, o servidor grava e transmite `debugVariant`, o cliente grava (`debug_variant_nearest_and_broadcast`); args ruins → nada (`debug_server_rejects_bad_args`); `status` imprime as duas linhas (`debug_status_prints_local_and_server`). `test_eco.lua`: `eco_spawn_at_only_at_night` (de dia false; à noite spawna, marca e guarda o ID na noite atual).
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS, registrar no `run.lua`, commit.

### Task 5: Remoção do mod de um save

**Files:** `docs/architecture/pz-api-notes.md` (§8 nova), `docs/architecture/README.md` (Robustez).

- [ ] Inventário do que o mod persiste (ModData global `NevoaEOutroMundo.eco/fog`, `modData` de corpo `NOM_ecoReleased`/`NOM_eco`, `persistentOutfitID` do `NOM_Eco` em zumbi virtual e corpo, opções de sandbox `NevoaEOutroMundo.*`) e o que não persiste (clima modded, stats trocados, useless, IsoMarkers, SearchMode, sons), com o bytecode da seção de pesquisa. Nenhum crash achado: nada a corrigir; o que sobra vai pro roteiro (passo "remover o mod"). Commit.

### Task 6: Presets e revisão dos defaults

**Files:** `docs/gdd/sandbox.md`.

- [ ] Seção "Presets": tabela com todas as 24 opções, colunas padrão / leve / pesadelo, uma linha de motivo por preset, e "como usar" (o jogo não aceita preset de mod: salvar como preset do usuário no menu, `getSandboxPresets` só lê a pasta do usuário).
- [ ] Seção "Revisão dos defaults (2026-10-04)": conta por opção do que o default faz com o sandbox vanilla Apocalypse (`Speed = 4`, `Sight/Hearing = 5`), o que fica e o que o Johan precisa sentir no jogo. Mudanças, se houver, justificadas em Checkpoints. Commit.

### Task 7: Roteiro in-game consolidado

**Files:** Create `docs/teste-in-game.md`.

- [ ] Uma sessão: preparação (link, `-debug`, sandbox de teste), parte SP num save só (dia → anoitecer → noite → névoa → amanhecer), parte MP (dedicado + cliente, depois 2 clientes), remoção do mod, medições (FPS/tick). Cada item com checkbox, linhas esperadas no console e link pro critério da sprint de origem. Usa `NOM_Debug` pra pular esperas. Pedido final: mandar `console.txt` (solo, cliente e servidor). Commit.

### Task 8: Docs da sprint

**Files:** `docs/sprints/sprint-0006-balanceamento-mp/README.md`, `docs/sprints/README.md`, `docs/architecture/README.md` (estrutura, orçamento), `README.md` se preciso.

- [ ] Status `em teste`; critérios marcados com evidência ou apontando pro roteiro; tabela de pendências 0001–0005 (resolvida / roteiro / `later`, com motivo); Checkpoints 04/10/2026; Aprendizados; Pendências; Sessões. Roadmap: 0006 `em teste`. Commit.
