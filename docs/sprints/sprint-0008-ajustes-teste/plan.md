# Ajustes do primeiro teste in-game — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Variantes a 15% cada, Eco só de quem morreu antes do anoitecer atual, e uma noite claramente mais escura e fria que a vanilla, com log de debug que prova no `console.txt` que os valores chegam no jogo.

**Architecture:** Nenhum arquivo novo de código. `NOM_Config`/`sandbox-options.txt` mudam três defaults. `NOM_EcoRules.syncNight` passa a guardar a hora de mundo em que o período abriu e ganha `diedBeforeNight`; `NOM_NightCount` passa a hora atual e expõe `start()`; a varredura do `NOM_Eco` pula corpo com `getDeathTime()` depois do início da noite. `NOM_Rules.LOOKS` troca os canais (sai a luz global "intensity", entra `ambient`; o tint ganha alfa) e ganha `skyMod`; `NOM_ClimateLook` escreve o alfa e loga canal a canal.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes).

**Spec:** [README da sprint](README.md) + brief da sprint 0008 (pedido do Johan) + [pz-api-notes §10](../../architecture/pz-api-notes.md) (escrito nesta sprint).

> **Emenda (05/10/2026, no meio da sprint):** o Johan trocou o pedido 1. No lugar
> da Task 1 (15/15/15), **todo monstro, menos o Eco, só na névoa**, padrão 5/2/5, um
> sorteio só por período de névoa com faixas contíguas na ordem de
> `NOM_VariantRules.KINDS` (pronto pra Carpideira no fim). Feito com TDD em
> `NOM_VariantRules` (`variant(id, period, cfg)`, `semRosto` vira a faixa dele,
> `semRostoConfig` sai), `NOM_NightRules.wanted` (variante também de dia),
> `NOM_NightStats` (lê `NOM_FogState`), `NOM_VariantAI`, `NOM_Variants` (período de
> névoa, grito de dia sem compensar a audição da noite) e testes. ADR-006 emendada.

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit, `next()`; `unpack`, não `table.unpack`; nada de `%d` com float.
- Lógica autoritativa no servidor (`if isClient() then return end`); lógica pura em `shared/` sem API do jogo; fakes que imitam o jogo, não stubs.
- Clima: servidor, `OnClimateTick`, valor absoluto, `setModdedInterpolate(1)`, nunca acumular (Aprendizado 3 da sprint 0001).
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode `Classe.metodo` + offset).
- Texto do jogador por tradução PTBR e EN; sandbox no namespace `NevoaEOutroMundo`.
- Nada copiado de outro mod nem do jogo. Comentários e docs em PT-BR com acento.

## Pesquisa (bytecode B42.21, jar idêntico ao instalado) que decide o desenho

**Render da noite.** `RenderSettings$PlayerRenderSettings.updateRenderSettings`:
- lê `getGlobalLight`, `getGlobalLightIntensity`, `getAmbient`, `getDayLightStrength`, `getNightStrength`, `getDesaturation` (offsets 19–70). `cmGlobalLightIntensity` só é gravado (34) e nunca lido aqui; o único leitor é `ThunderStorm.applyLightningForPlayer` (relâmpago). **`FLOAT_GLOBAL_LIGHT_INTENSITY` não escurece nada.**
- `darkness = 1 − dayLightStrength` (202–209); `desaturation = cmDesaturation × (1 − darkness)` (594–606 e 805–817). **À noite (`dayLightStrength` 0) a dessaturação vai a zero.** O shader `screen.frag` só usa `DesaturationVal` (o `blendOverlay(Light…)` está comentado).
- `blendColor` = cor **exterior** da luz global e `blendIntensity` = **alfa** dela (224–246; `isExterior` é forçado `true` em 212). `rmod/gmod/bmod = lerp(1, cor dessaturada, alfa)` (662–725).
- `ambient = n + (1 − n) × ambient do clima`, `n` = `NightDarkness` do sandbox (tableswitch 306: 1 → 0, 2 → 0.07, 3 → 0.15, 4 → 0.25) `+ 0.075 × lua × night` (293–454). O piso vem depois do clima: **a camada do mod não muda `n`.**
- `GameTime.getSkyLightLevel` (10–77): luz do céu por canal = `clamp(2 × mod × ambient)`, vai pro `LightingJNI.stateEndFrame` (`LightingJNI.update` 282–332, junto de `rmod/gmod/bmod`, `ambient`, `night`).
- Vanilla de madrugada (`ClimateValues.updateValues` 1132–1268): `nightStrength = 1`, `dayLightStrength = 0`, `ambient = dayLightStrength = 0`; luz global = `colNight` (0.33, 0.33, 0.33, alfa 0.4; `ClimateManager.<init>` 250–269). Ou seja: ambient, daylight e night **já estão no extremo**; só a cor/alfa da luz global tem folga. `mod` vanilla = 1 − 0.4 × 0.67 = 0.73.
- O tint antigo puxava a cor pra (0.55, 0.65, 0.95) com o alfa vanilla: `mod` subia (0.76/0.80). **A noite do mod ficava um pouco mais clara.** O save do teste usa `NightDarkness = 3` (`map_sand.bin`).
- `ClimateFloat.calculate`/`ClimateColor.calculate` aplicam a camada modded a todo canal (loop em `ClimateManager.update` 416–478); `Color.interp` mistura o alfa (34–109). Na chuva, `WeatherPeriod.update` 684–696 põe `globalLight.setOverride(cloudColor, t)` (não é de valor: mistura em cima do nosso interno).
- Admin vanilla: o slider "Darkness" mexe em `DAYLIGHT_STRENGTH`, `NIGHT_STRENGTH` e `AMBIENT` juntos (`client/ISUI/AdminPanel/ISAdmPanelClimate.lua:362-365`); a cor da luz tem sliders R/G/B/A (`:367-380`).

**Hora da morte do corpo.** `IsoDeadBody.deathTime` (float, horas de mundo):
`<init>(IsoGameCharacter,…)` 1333–1341 grava `GameTime.getWorldAgeHours()`; `save` 444–449 grava, `load` 593–598 relê sem checar versão; `addToWorld` 128–161 troca `-1` (ou valor no futuro) por agora. `getDeathTime()` é público e usado no vanilla (`shared/Definitions/animal/ButcheringUtil.lua:568`). **Fallback por `OnZombieDead` não é necessário.**

**Sorteio das variantes.** `NOM_VariantRules.variant`: um `roll` 0–99 por zumbi e noite; `< e` Estalador, `< e + c` Corredor. As faixas são contíguas e não se sobrepõem: cada um sai com a própria chance; com 15/15, 30% da noite. Sem-rosto tem sorteio próprio (sal diferente) por névoa.

## Review Focus

1. **Save antigo aberto no meio da noite** (sem a hora de início guardada) — esperado: sem erro, o início vira a hora da carga. Teste: `rules_sync_night_migrates_open_night` (Task 2).
2. **Corpo com `deathTime` −1** (nunca entrou no mundo, ou vindo de outro mod) — esperado: tratado como antigo, solta Eco. Teste: `rules_died_before_night` (Task 2).
3. **Noite forçada pelo `NOM_Debug` de dia** — esperado: a noite abre na hora em que foi forçada; corpo de antes solta. Teste: `eco_forced_night_counts_from_forcing` (Task 2).
4. **`DarkIntensity` 0 à noite** — esperado: nenhuma escrita no clima. Teste: `look_intensity_zero_touches_nothing` (Task 3).
5. **Sem `-debug`** — esperado: nenhum `print` do clima. Teste: `look_debug_log_silent_without_debug` (Task 4).

---

### Task 1: Chances 15/15/15 (substituída pela emenda acima)

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_Config.lua`, `mod/42/media/sandbox-options.txt`
- Test: `tests/test_config.lua`, `tests/test_variant_rules.lua`

**Interfaces:** Produces: `NOM_Config.DEFAULTS.EstaladorChance/CorredorChance/SemRostoChance = 15`.

- [ ] **Step 1: testes que falham.** Em `test_config.lua`, `config_variant_defaults`/`config_fog_defaults` esperam 15; teste novo `config_sandbox_defaults_match_lua` lê `default = N` de cada opção numérica do `sandbox-options.txt` e compara com `NOM_Config.DEFAULTS`. Em `test_variant_rules.lua`:

```lua
    -- padrão do pedido do Johan: ~15% de cada, ~30% da noite, Sem-rosto ~15% da névoa
    variant_rules_default_chances = function()
        require "NOM_Config"
        local ids = realIDs()
        local c = R.config(NOM_Config.get)
        local s = R.semRostoConfig(NOM_Config.get)
        for night = 1, 3 do
            local n = count(ids, night, c)
            local e, k = n.estalador / #ids * 100, n.corredor / #ids * 100
            assert(math.abs(e - 15) < 1.5 and math.abs(k - 15) < 1.5, string.format("E %.1f%% C %.1f%%", e, k))
            assert(math.abs(e + k - 30) < 2, "total " .. (e + k))
            local sr = 0
            for _, id in ipairs(ids) do if R.semRosto(id, night, s) then sr = sr + 1 end end
            assert(math.abs(sr / #ids * 100 - 15) < 1.5, "Sem-rosto " .. sr / #ids * 100)
        end
    end,
```

- [ ] **Step 2:** `./run-tests.sh` → falham os três.
- [ ] **Step 3:** defaults 15 no `NOM_Config` e `default = 15` nas três opções do `sandbox-options.txt`.
- [ ] **Step 4:** `./run-tests.sh` → passa.
- [ ] **Step 5:** commit `feat: Estalador, Corredor e Sem-rosto com 15% por padrão`.

### Task 2: Eco só de quem morreu antes do anoitecer

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_EcoRules.lua`, `mod/42/media/lua/server/NOM_NightCount.lua`, `mod/42/media/lua/server/NOM_Eco.lua`
- Test: `tests/test_eco_rules.lua`, `tests/test_eco.lua` (fake: `getWorldAgeHours`, corpo com `deathTime`), fakes de `getGameTime` que carregam o `NOM_NightCount` (`tests/test_debug.lua`, `tests/test_night.lua`, `tests/test_variants.lua`, `tests/test_night_and_fog.lua`, `tests/fog_world.lua` se carregar)

**Interfaces:**
- Produces: `NOM_EcoRules.syncNight(state, isOn, now)` — `now` opcional (horas de mundo); ao abrir guarda `state.start = now`; aberto sem `start` (save antigo) também guarda. `NOM_EcoRules.diedBeforeNight(deathTime, start) → bool` (`start` nil ou `deathTime < 0` → true; senão `deathTime < start`). `NOM_NightCount.start() → número|nil`.

- [ ] **Step 1: testes de regra que falham** (`test_eco_rules.lua`):

```lua
    rules_sync_night_records_start = function()
        local s = {}
        NOM_EcoRules.syncNight(s, true, 100.5)
        assert(s.start == 100.5)
        NOM_EcoRules.syncNight(s, true, 101)
        assert(s.start == 100.5, "início andou no meio da noite")
        NOM_EcoRules.syncNight(s, false, 110)
        NOM_EcoRules.syncNight(s, true, 124.5)
        assert(s.start == 124.5)
    end,
    rules_sync_night_migrates_open_night = function()
        local s = { night = 4, inNight = true }
        assert(NOM_EcoRules.syncNight(s, true, 130) == 4)
        assert(s.start == 130)
    end,
    rules_died_before_night = function()
        assert(NOM_EcoRules.diedBeforeNight(99, 100) == true)
        assert(NOM_EcoRules.diedBeforeNight(100.2, 100) == false)
        assert(NOM_EcoRules.diedBeforeNight(-1, 100) == true, "sem hora de morte = antigo")
        assert(NOM_EcoRules.diedBeforeNight(150, nil) == true, "início desconhecido não bloqueia")
    end,
```

- [ ] **Step 2:** falham. **Step 3:** implementar em `NOM_EcoRules`:

```lua
function NOM_EcoRules.syncNight(state, isNight, now)
    if isNight and not state.inNight then
        state.night = (state.night or 0) + 1
        state.start = now
    elseif isNight and state.start == nil then
        state.start = now -- save de antes da sprint 0008, aberto de noite
    end
    state.inNight = isNight
    return state.night or 0
end

function NOM_EcoRules.diedBeforeNight(deathTime, start)
    return start == nil or deathTime < 0 or deathTime < start
end
```

- [ ] **Step 4: testes do mundo falso que falham** (`test_eco.lua`): o fake ganha `G.world.age` (padrão 1000), `getWorldAgeHours`, corpo com `deathTime` (padrão 0; o do `G.kill` nasce com `G.world.age`, como `IsoDeadBody.<init>` 1333–1341) e `G.setTime(tod, age)`:

```lua
    eco_killed_tonight_waits_next_night = function()
        local G = setup() -- noite abre na hora 1000
        G.world.age = 1001
        local zz = G.normalZombie(103, 103)
        G.kill(zz)
        G.tick(10)
        G.tenMinutes()
        assert(#G.ecos() == 0, "Eco nasceu do zumbi recém-morto")
        G.setTime(7, 1009)
        G.setTime(21, 1024)
        G.tenMinutes()
        assert(#G.ecos() == 1, "não soltou na noite seguinte")
    end,
    eco_died_before_dusk_releases_tonight = function()
        local G = setup({ tod = 12 })
        local zz = G.normalZombie(103, 103)
        G.kill(zz)
        G.tick(10)
        G.setTime(21, 1009)
        G.tenMinutes()
        assert(#G.ecos() == 1)
    end,
    eco_forced_night_counts_from_forcing = function()
        local G = setup({ tod = 12 })
        G.body(103, 103, 0, { deathTime = 999 })
        NOM_World.forced.night = true
        G.setTime(12, 1001)
        G.tenMinutes()
        assert(#G.ecos() == 1)
        NOM_World.forced.night = nil
    end,
```

- [ ] **Step 5:** `NOM_NightCount.current()` passa `getGameTime():getWorldAgeHours()` (CONFIRMED `ButcheringUtil.lua:594`); `NOM_NightCount.start()` devolve `state().start`. Em `NOM_Eco`, `startScan` guarda `start = NOM_NightCount.start()`, e `bodiesAround` só põe em `cands` o corpo com `NOM_EcoRules.diedBeforeNight(b:getDeathTime(), start)`; os outros contam em `s.waiting` e saem no log `esperando=N`.
- [ ] **Step 6:** `./run-tests.sh` → passa (fakes de `getGameTime` que carregam `NOM_NightCount` ganham `getWorldAgeHours`).
- [ ] **Step 7:** commit `feat: Eco só nasce de quem morreu antes do anoitecer`.

### Task 3: Noite escura pela cor e alfa da luz global

**Files:**
- Modify: `mod/42/media/lua/shared/NOM_Rules.lua`, `mod/42/media/lua/server/NOM_ClimateLook.lua`
- Test: `tests/test_rules.lua`, `tests/test_climate_look.lua`

**Interfaces:**
- Produces: `NOM_Rules.CHANNELS = { "desaturation", "ambient", "fog", "tint" }`; tint `value = { r, g, b, a }`; `NOM_Rules.skyMod(r, g, b, a) → mr, mg, mb` (= `1 − a × (1 − c)`, `PlayerRenderSettings` 662–725); `NOM_Rules.VANILLA_NIGHT = { 0.33, 0.33, 0.33, 0.4 }`.

```lua
NOM_Rules.LOOKS = {
    night = {
        ambient = { value = 0, weight = 0.5 },
        tint    = { value = { 0.10, 0.14, 0.30, 0.85 }, weight = 0.6 },
    },
    fog = {
        desaturation = { value = 1, weight = 0.6 },
        ambient      = { value = 0, weight = 0.3 },
        fog          = { value = 1, weight = 0.3 },
        tint         = { value = { 0.45, 0.40, 0.32, 0.75 }, weight = 0.5 },
    },
}
```

- [ ] **Step 1: testes que falham.** `test_rules.lua`: `mix_night_only_has_no_fog_channel` passa a exigir `ambient` e `tint` > 0 e `desaturation` = 0 (morta à noite); `rules_night_darker_and_colder_than_vanilla`: com `DarkIntensity` 1, a cor da noite cheia misturada com `VANILLA_NIGHT` dá `skyMod` ≤ 70% da vanilla em r/g e azul > vermelho; com 2, ≤ 40% em r. `test_climate_look.lua`: fake ganha o float 9 (`ambient`), perde o 1, cor vanilla = `colNight`; `look_does_not_compound…` confere `ambient` e o alfa do tint; `look_intensity_zero_touches_nothing` (noite, `DarkIntensity` 0 → nenhuma chamada).
- [ ] **Step 2:** falham. **Step 3:** `LOOKS`/`CHANNELS`/`skyMod`; `mix` mistura 4 componentes no tint; `NOM_ClimateLook` troca `light` por `ambient = ClimateManager.FLOAT_AMBIENT` (CONFIRMED `PopupColorEdit.lua:64`) e o `blendColor` mistura o alfa (`value[4]`).
- [ ] **Step 4:** `./run-tests.sh` → passa. **Step 5:** commit `fix: noite escurece pela cor e alfa da luz global (o canal que o render usa)`.

### Task 4: Log de debug canal a canal

**Files:** Modify `mod/42/media/lua/server/NOM_ClimateLook.lua`; Test `tests/test_climate_look.lua`.

**Interfaces:** Consumes `NOM_Rules.skyMod`. Produces linhas `[NOM] clima <canal> vanilla=… escrito=… final=…` e `[NOM] clima tint vanilla=r,g,b,a escrito=… final=… luz=mr,mg,mb`.

- [ ] **Step 1: testes que falham:** `look_debug_log_on_edges_and_hourly` (`getDebug` true, `print` capturado: na borda da rampa sai uma linha por canal; 60 minutos de noite depois, mais um bloco; 59, não); `look_debug_log_silent_without_debug`.
- [ ] **Step 2:** falham. **Step 3:** `logChannels(rows)` chamado quando `edged` ou quando a hora (`math.floor(NOM_World.tod)`) muda com `NOM_World.night`; `final` é o `getFinalValue()` lido no `OnClimateTick`, ou seja o do minuto anterior (comentado no código).
- [ ] **Step 4:** passa. **Step 5:** commit `diag: log do clima canal a canal (vanilla, escrito, final)`.

### Task 5: Documentação

- [ ] pz-api-notes §10 (render da noite e `deathTime`, com offsets), ADR-008 (noite pela luz global; emenda a ADR-004) indexada no `architecture/README.md`; GDD `atmosphere.md` (canais novos, piso do sandbox, vinheta e efeitos de tela só na névoa forte), `monsters.md` (Eco: morto antes do anoitecer; chances 15), `sandbox.md` (defaults, presets Leve 5/5/5 · Padrão 15/15/15 · Pesadelo 25/25/25, revisão das chances), `Overview.md` (decisões de 05/10), `teste-in-game.md` (o que esperar da noite), README; README da sprint `em teste` com roteiro in-game; roadmap.
- [ ] Commit `docs: sprint 0008 em teste`.
