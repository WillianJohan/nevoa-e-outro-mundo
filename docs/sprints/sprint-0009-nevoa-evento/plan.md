# Névoa como evento — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A névoa vira um evento do mod (hora aleatória, ~1 a cada 3 dias de jogo, 2–6 h), anunciado por uma sirene 30 s reais antes; fora dele a névoa do jogo é 0.

**Architecture:** Regra pura nova `shared/NOM_FogEventRules.lua` (sorteio do intervalo e da duração, máquina de estado salva, contagem regressiva). Servidor novo `server/NOM_FogEvent.lua`: dono do `ModData.fog` (`night`, `inNight`, `next`, `endAt`), agenda no `OnClimateTick`, conta a sirene no `OnTick` com `getTimestampMs()` e liga a flag por `NOM_World.setFog`. `NOM_Fog` passa a ler o período do evento. `NOM_ClimateLook` vira dono do canal de névoa: escreve sempre (0 ou a densidade do evento com rampa) e desliga o override da névoa que o jogo religa a cada minuto. Sirene: som procedural, `shared/NOM_Siren.lua` toca local; no MP vai pelo comando `siren`.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python + numpy + ffmpeg pro som.

**Spec:** [README da sprint](README.md) (decisões do Johan, 05/10/2026) + brief da sprint 0009.

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit, `next()`; `unpack`, não `table.unpack`; nada de `%d` com float.
- Lógica autoritativa no servidor (`if isClient() then return end`); lógica pura em `shared/` sem API do jogo; testes contra fakes que imitam o jogo.
- Clima: servidor, `OnClimateTick`, valor absoluto, `setModdedInterpolate(1)`, nunca acumular.
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode `Classe.metodo` + offset).
- Texto do jogador por tradução PT-BR e EN; sandbox no namespace `NevoaEOutroMundo`.
- Nada copiado de outro mod nem do jogo; som gerado por `scripts/gen_sounds.py` e listado no `CREDITS.md`.
- O look da névoa (tint, dessaturação, ambient) segue mais escuro que a vanilla em todo caminho (testes `rules_fog_darker_*` verdes).

## Pesquisa (bytecode B42.21, `projectzomboid.jar` instalado) que decide o desenho

- **Ordem por minuto de jogo** (`ClimateManager.update` 363–461): servidor/solo roda
  `updateSandboxOverrides()` (377) → `updateValues()` (381) → `weatherPeriod.update()` (392)
  → `OnClimateTick` (402) → `ClimateColor.calculate`/`ClimateFloat.calculate` (411–458).
  Tudo que liga override de névoa roda **antes** do nosso evento, e o `calculate` depois.
- **`ClimateFloat.calculate`** (0–…): admin primeiro (`isAdminOverride` → `final = adminValue`,
  sai); depois a camada modded no interno; depois, se `isOverride && interpolate > 0`,
  `final = lerp(interpolate, isOverrideValue ? overrideInternal : internal, override)`.
- **Quem liga o override da névoa:**
  - Sandbox (`updateSandboxOverrides` 471–675): `fogOverride = (ClimateCycle == 6 && FogCycle != 2) ? 4 : FogCycle`;
    **só na troca** de `fogOverride` (555–561) chama `setEnableOverride(>1)` e `setOverrideValue(>1)`;
    `== 2` ("sem névoa") faz `setOverride(0, 1)`; `>= 3` sorteia `setOverride(Rand(0.1, 1), t)`
    a cada hora (635–672), e `setOverride` religa `isOverride` (`ClimateFloat.setOverride` 0–15).
    Com override de valor, **a névoa do mod nunca chegaria na tela**.
  - `WeatherPeriod.updateCurrentStage` (chamado só de `WeatherPeriod.update` 354, a cada
    minuto com período ativo): `setOverride(0, linearT)`, `setOverride(0, 1)` e, em
    estágios de névoa, `setOverride(fogStrength, t)` (895–906, 1259–1270). Não é de valor:
    puxa o nosso interno pra 0 ou **soma névoa vanilla** por cima.
  - `setEnableOverride(Z)` só grava `isOverride` (0–5); não mexe em `isOverrideValue`.
  - `ClimateManager.save` grava só os valores de admin (`saveAdmin`, 167–172): desligar o
    override não vai pro save.
- **Névoa vanilla dentro do `updateValues`:** o interno da névoa é recalculado todo minuto
  (1019–1037, ou 0 em 1144–1149) e, ainda dentro do `updateValues`, puxa a luz global pra
  `colFog*` (1644–1770), a dessaturação (1062–1138, 1277–1312), corta nuvem (1199–1222) e
  sobe a umidade (1315–1341). Isso roda antes da camada modded: zerar o canal de névoa
  **não** desfaz esse cinza. É o mesmo resultado do `FogCycle` "Sem névoa" da vanilla
  (override de valor 0 também só mexe no final). Aceito e documentado (ADR-009).
- **Quem lê a névoa final:** `getFogIntensity()` = `finalValue` (0–7); `updateFx` (77–83),
  `updateViewDistance` (9–12) leem o final. O render da névoa e a visão seguem o mod.
- **Pausa:** `GameTime.isGamePaused()` (exposto como global `isGamePaused()`, CONFIRMED
  `client/ISUI/ISJoystickButtonRadialMenu.lua:68`): no dedicado, `Players` vazio e
  `PauseEmpty`; no cliente de MP, `GameClient.IsClientPaused`; no solo, velocidade 0.
  `IngameState.onTick` só dispara `OnTick` (0–11).

## Review Focus

1. **Save da sprint 0008 salvo com névoa natural aberta** (`fog.inNight = true`, sem `endAt`) — esperado: fecha sem contar período e agenda o próximo. Teste `fog_event_rules_closes_stale_0008_save` (Task 1).
2. **`FogMinHours` maior que `FogMaxHours`** — esperado: troca os dois, nunca duração negativa. Teste `fog_event_rules_duration_within_bounds` (Task 1).
3. **Jogo pausado / travada longa durante a sirene** — esperado: a contagem para; um frame de 10 s conta no máximo 1 s. Teste `fog_event_rules_countdown_pauses_and_caps` (Task 1) e `fog_event_paused_holds_countdown` (Task 3).
4. **Recarregar durante a contagem da sirene** — esperado: a sirene toca de novo e a contagem recomeça (o `next` continua no passado). Teste `fog_event_reload_during_siren_restarts` (Task 3).
5. **Override de névoa ligado pelo jogo durante o evento** (chuva, `FogCycle` "Sem névoa") — esperado: a névoa final é a do evento, não 0. Teste `look_event_fog_wins_over_overrides` (Task 4).

---

### Task 1: Regra pura do evento (`NOM_FogEventRules`)

**Files:**
- Create: `mod/42/media/lua/shared/NOM_FogEventRules.lua`
- Test: `tests/test_fog_event_rules.lua` (registrar em `tests/run.lua`)

**Interfaces:**
- Produces: `R.SIREN_MS = 30000`, `R.MAX_STEP_MS = 1000`, `R.DENSITY = 0.85`;
  `R.config(get) → { everyDays, minHours, maxHours }`;
  `R.gapHours(everyDays, r) → horas` (`r` em [0, 1));
  `R.durationHours(minH, maxH, r) → horas`;
  `R.update(state, now, cfg, rand) → "siren" | "end" | nil` (`state = { night, inNight, next, endAt }`, `now` em horas de mundo, `rand()` em [0, 1));
  `R.start(state, now, cfg, rand) → bool`; `R.stop(state, now, cfg, rand)`;
  `R.countdown(remainingMs, dtMs, paused) → ms`.

- [ ] **Step 1: testes**

```lua
require "NOM_FogEventRules"
local R = NOM_FogEventRules
local function seq(...) local v, i = { ... }, 0; return function() i = i + 1; return v[(i - 1) % #v + 1] end end
local cfg = { everyDays = 3, minHours = 2, maxHours = 6 }
return {
    fog_event_rules_gap_within_bounds = function()
        assert(R.gapHours(3, 0) == 36 and math.abs(R.gapHours(3, 0.999999) - 108) < 1e-3)
        local sum, n = 0, 1000
        for i = 0, n - 1 do sum = sum + R.gapHours(3, (i + 0.5) / n) end
        assert(math.abs(sum / n - 72) < 1e-6, "média ≠ 3 dias")
    end,
    fog_event_rules_duration_within_bounds = function()
        assert(R.durationHours(2, 6, 0) == 2 and R.durationHours(2, 6, 0.5) == 4)
        assert(R.durationHours(6, 2, 0) == 2, "min > max não troca")
        assert(R.durationHours(3, 3, 0.7) == 3)
    end,
    fog_event_rules_schedules_then_sirens = function()
        local s = {}
        assert(R.update(s, 10, cfg, seq(0.5)) == nil and s.next == 10 + 72)
        assert(R.update(s, 81.9, cfg, seq(0.5)) == nil)
        assert(R.update(s, 82, cfg, seq(0.5)) == "siren")
        assert(R.update(s, 83, cfg, seq(0.5)) == "siren", "sirene some antes de começar")
    end,
    fog_event_rules_period_once_per_event = function()
        local s = { next = 0 }
        assert(R.start(s, 5, cfg, seq(0.25)) and s.night == 1 and s.inNight and s.endAt == 8)
        assert(not R.start(s, 6, cfg, seq(0)), "evento dentro de evento")
        assert(s.night == 1)
        assert(R.update(s, 7.9, cfg, seq(0)) == nil and s.inNight)
        assert(R.update(s, 8, cfg, seq(0)) == "end" and not s.inNight and s.endAt == nil and s.next == 8 + 36)
        R.start(s, 50, cfg, seq(0))
        assert(s.night == 2)
    end,
    fog_event_rules_closes_stale_0008_save = function()
        local s = { night = 4, inNight = true }
        assert(R.update(s, 100, cfg, seq(0)) == nil)
        assert(s.inNight == false and s.night == 4 and s.next == 136)
    end,
    fog_event_rules_countdown_pauses_and_caps = function()
        assert(R.countdown(30000, 16, false) == 29984)
        assert(R.countdown(30000, 16, true) == 30000, "pausado contou")
        assert(R.countdown(30000, 10000, false) == 29000, "travada comeu a sirene")
        assert(R.countdown(30000, -5, false) == 30000)
    end,
}
```

- [ ] **Step 2:** `./run-tests.sh` → FAIL (módulo não existe).
- [ ] **Step 3: implementação**

```lua
-- Regras puras do evento de névoa (sprint 0009): sem API do jogo.
NOM_FogEventRules = {}
local R = NOM_FogEventRules
R.SIREN_MS = 30000     -- sirene: 30 s reais antes da névoa
R.MAX_STEP_MS = 1000   -- um frame nunca desconta mais que isto (travada, volta da pausa)
R.DENSITY = 0.85       -- névoa do evento cheia (0..1, canal FLOAT_FOG_INTENSITY)

function R.config(get)
    return { everyDays = get("FogEventEveryDays"), minHours = get("FogMinHours"), maxHours = get("FogMaxHours") }
end
function R.gapHours(everyDays, r) return everyDays * 24 * (0.5 + r) end
function R.durationHours(a, b, r)
    local lo, hi = math.min(a, b), math.max(a, b)
    return lo + (hi - lo) * r
end
function R.update(state, now, cfg, rand)
    if state.inNight and state.endAt == nil then state.inNight = false end
    if state.inNight then
        if now < state.endAt then return nil end
        R.stop(state, now, cfg, rand)
        return "end"
    end
    if state.next == nil then state.next = now + R.gapHours(cfg.everyDays, rand()) end
    if now >= state.next then return "siren" end
    return nil
end
function R.start(state, now, cfg, rand)
    if state.inNight then return false end
    state.night = (state.night or 0) + 1
    state.inNight = true
    state.endAt = now + R.durationHours(cfg.minHours, cfg.maxHours, rand())
    state.next = nil
    return true
end
function R.stop(state, now, cfg, rand)
    state.inNight = false
    state.endAt = nil
    state.next = now + R.gapHours(cfg.everyDays, rand())
end
function R.countdown(remaining, dt, paused)
    if paused then return remaining end
    return remaining - math.min(math.max(dt, 0), R.MAX_STEP_MS)
end
return R
```

- [ ] **Step 4:** PASS. **Step 5:** commit `feat: regra pura do evento de névoa (intervalo, duração, sirene)`.

### Task 2: Sandbox novo, `FogThreshold` fora, `NOM_World.setFog`

**Files:**
- Modify: `mod/42/media/sandbox-options.txt`, `shared/NOM_Config.lua`, `shared/Translate/{PTBR,EN}/Sandbox.json`, `shared/NOM_Rules.lua` (sai `isFog`, `FOG_HYSTERESIS`, `FOG_EXIT_FLOOR` e o canal `fog` de `LOOKS`/`CHANNELS`), `shared/NOM_World.lua`
- Test: `tests/test_config.lua`, `tests/test_rules.lua`, `tests/test_world.lua`, `tests/test_translations.lua` (se necessário)

**Interfaces:**
- Produces: `NOM_Config` com `FogEventEveryDays = 3` (double 0.5–30), `FogMinHours = 2`, `FogMaxHours = 6` (double 0.5–48); `NOM_World.setFog(on)` (avisa `onChange("fog", on)` só na borda); `NOM_World.update()` só calcula a noite (`forced.night` continua; `forced.fog` e `fogIntensity` saem).

- [ ] **Step 1: testes** — `config_defaults` passa a checar as três opções novas e que `FogThreshold` sumiu do Lua e do `sandbox-options.txt`; `test_world`: `world_set_fog_fires_only_on_edges` (`setFog(true)` duas vezes avisa uma; `update()` não mexe na névoa) e o teste de forçado só com a noite; `test_rules`: saem os testes de `isFog`, `mix_night_only_has_no_fog_channel` vira "nenhum canal `fog` no look".
- [ ] **Step 2:** FAIL. **Step 3:** implementar.

```lua
-- NOM_World
function NOM_World.update()
    local season = getClimateManager():getSeason()
    local wasNight = NOM_World.night
    NOM_World.tod = getGameTime():getTimeOfDay()
    NOM_World.dawn = season:getDawn()
    NOM_World.dusk = season:getDusk()
    NOM_World.night = NOM_Rules.isNight(NOM_World.tod, NOM_World.dawn, NOM_World.dusk)
    if NOM_World.forced.night ~= nil then NOM_World.night = NOM_World.forced.night end
    notify("night", wasNight)
    return NOM_World
end
-- A névoa é evento do mod (server/NOM_FogEvent.lua), não clima.
function NOM_World.setFog(on)
    local was = NOM_World.fog
    NOM_World.fog = on
    notify("fog", was)
end
```

- [ ] **Step 4:** testes que chamavam `NOM_World.update(0.9)` pra ligar a névoa passam a chamar `NOM_World.setFog(true)` (`test_night_and_fog`, `test_variants`, `test_debug`, `test_fog`). PASS. **Step 5:** commit.

### Task 3: Servidor do evento (`NOM_FogEvent`) e `NOM_Fog` lendo dele

**Files:**
- Create: `mod/42/media/lua/server/NOM_FogEvent.lua`, `mod/42/media/lua/shared/NOM_Siren.lua`
- Modify: `server/NOM_Fog.lua` (período vem do evento; sai o `syncNight` e o fechamento de save velho), `client/NOM_FogClient.lua` (comando `siren`), `tests/fog_world.lua` (`G.world.hours`, `isGamePaused`)
- Test: `tests/test_fog_event.lua` (novo), `tests/test_fog.lua`

**Interfaces:**
- Consumes: Task 1 e 2.
- Produces: `NOM_FogEvent.period() → número`, `NOM_FogEvent.siren(skip) → bool` (toca a sirene; `skip` começa a névoa no próximo tick), `NOM_FogEvent.stop() → bool`, `NOM_FogEvent.status() → { next, endAt, sirenMs }`; `NOM_Siren.play()` (toca `NOM_Siren` no jogador 0 por `playSoundLocal`); comando servidor→cliente `siren` (sem args).

- [ ] **Step 1: testes** (`tests/test_fog_event.lua`, mundo falso com relógio real `G.now` e horas de mundo `G.world.hours`):
  - `fog_event_siren_30_real_seconds_before`: agenda, horas passam do `next` → `OnClimateTick` toca a sirene (solo: som `NOM_Siren` no jogador; dedicado: comando `siren` pra todos); `G.seconds(29.9)` sem névoa; `G.seconds(0.2)` névoa ligada, período 1, comando `fog`.
  - `fog_event_siren_once_while_counting`: vários `OnClimateTick` durante a contagem → uma sirene só.
  - `fog_event_ends_after_duration_and_reschedules`: `endAt` passa → névoa desliga, `next` entre 0,5× e 1,5×.
  - `fog_event_state_survives_reload`: recarregar com o mesmo `globalMD` no meio do evento → `NOM_World.fog` volta ligada no 1º `OnClimateTick`, período igual, `endAt` igual.
  - `fog_event_reload_during_siren_restarts`: recarregar no meio da contagem → sirene de novo, contagem do zero.
  - `fog_event_paused_holds_countdown`: `G.paused = true` por 60 s → sem névoa; despausa, 30 s → névoa.
  - `fog_event_no_compounding_after_long_skip`: horas pulam 30 dias → um evento só.
  - `fog_event_mp_join_mid_event_gets_state`: `fogState` responde `on = true` e o período.
- [ ] **Step 2:** FAIL. **Step 3:** implementar.

```lua
-- server/NOM_FogEvent.lua (resumo)
if isClient() then return end
require "NOM_World"; require "NOM_Config"; require "NOM_FogEventRules"; require "NOM_Siren"
local MODULE, R = "NevoaEOutroMundo", NOM_FogEventRules
NOM_FogEvent = {}
local countdown, lastMs
local function state() local d = ModData.getOrCreate(MODULE); d.fog = d.fog or {}; return d.fog end
local function rand() return ZombRand(10000) / 10000 end
local function now() return getGameTime():getWorldAgeHours() end
local function cfg() return R.config(NOM_Config.get) end
function NOM_FogEvent.period() return state().night or 0 end
function NOM_FogEvent.siren(skip)
    if state().inNight or countdown then return false end
    countdown, lastMs = skip and 0 or R.SIREN_MS, getTimestampMs()
    if isServer() then sendServerCommand(MODULE, "siren", {}) else NOM_Siren.play() end
    return true
end
function NOM_FogEvent.stop()
    countdown = nil
    if not state().inNight then return false end
    R.stop(state(), now(), cfg(), rand)
    NOM_World.setFog(false)
    return true
end
Events.OnClimateTick.Add(function()
    if R.update(state(), now(), cfg(), rand) == "siren" then NOM_FogEvent.siren(false) end
    NOM_World.setFog(state().inNight == true)
end)
Events.OnTick.Add(function()
    if not countdown then return end
    local t = getTimestampMs()
    countdown = R.countdown(countdown, t - lastMs, isGamePaused())
    lastMs = t
    if countdown > 0 then return end
    countdown = nil
    R.start(state(), now(), cfg(), rand)
    NOM_World.setFog(true)
end)
```

`NOM_Fog.period()` passa a ser `return NOM_FogEvent.period()`. `NOM_FogClient` ganha
`elseif command == "siren" then NOM_Siren.play()`.

- [ ] **Step 4:** PASS (e `test_fog.lua` adaptado: `G.setFog(v)` começa/termina evento). **Step 5:** commit.

### Task 4: O look é dono do canal de névoa

**Files:**
- Modify: `mod/42/media/lua/server/NOM_ClimateLook.lua`
- Test: `tests/test_climate_look.lua` (fake de override que imita o jogo: `setOverride` religa `isOverride`, `setEnableOverride` só mexe no `isOverride`, override de valor do sandbox só na troca, `WeatherPeriod` religa todo minuto antes do `OnClimateTick`)

**Interfaces:**
- Consumes: `NOM_World.fog` (Task 2), `NOM_FogEventRules.DENSITY`.

- [ ] **Step 1: testes**
  - `look_fog_zero_outside_event` (névoa vanilla 0.9 → final 0; com `DarkEnabled` falso também)
  - `look_fog_zero_under_weather_period_override` (estágio de névoa `setOverride(0.8, 1)` todo minuto → final 0)
  - `look_fog_zero_under_fog_cycle_override` (`FogCycle` 4, override de valor 0.7 → final 0)
  - `look_event_fog_ramps_in_and_out` (`setFog(true)`: sobe até `DENSITY` em 20 minutos de jogo; `setFog(false)`: volta a 0 em 20)
  - `look_event_fog_wins_over_overrides` (`FogCycle` 2 e `WeatherPeriod` ativos: final = `DENSITY`)
  - `look_admin_fog_still_wins` (admin passa por cima, o mod não mexe)
  - `look_idle_day_touches_only_fog` (substitui `look_idle_day_touches_nothing`: só `f5:on` uma vez)
  - Saem: `look_fog_flag_exits_*`, `look_fog_override_uses_final_without_flapping`, `look_blizzard_override_uses_final` (detecção pela névoa vanilla não existe mais).
- [ ] **Step 2:** FAIL. **Step 3:** implementar: `FLOATS` sem `fog`; `state.eventRamp = ramp(eventRamp, w.fog)` (não depende de `DarkEnabled`); todo `OnClimateTick`:

```lua
local function ownFog(f)
    if not applied.fog then f:setEnableModded(true); applied.fog = true end
    if f:isEnableOverride() then f:setEnableOverride(false) end
    f:setModdedValue(NOM_FogEventRules.DENSITY * state.eventRamp)
    f:setModdedInterpolate(1)
end
```

Saem `vanillaFog` e `fogValueOverride`. O log de debug troca `fogI` pela névoa escrita.
- [ ] **Step 4:** PASS. **Step 5:** commit.

### Task 5: Sirene (som e toque)

**Files:**
- Modify: `scripts/gen_sounds.py` (`siren(rng)`), `mod/42/media/scripts/NOM_sounds.txt`, `CREDITS.md`
- Create: `mod/42/media/sound/NOM_Siren.ogg` (gerado)
- Test: `tests/test_credits.lua` (já falha se o `.ogg` não estiver no CREDITS), `tests/test_fog_event.lua` (som no jogador local), `tests/test_fog_client.lua` (`siren` no cliente de MP toca)

- [ ] Sirene de ataque aéreo: tom que sobe ~6 s (180 → 620 Hz), segura, cai, duas vezes (~24 s); harmônicos ímpares (rotor), batimento leve; volume cheio. `NOM_Siren`: `category = World`, sem `loop`, sem `master` (efeitos). `NOM_Siren.play()`: `getSpecificPlayer(0)`; `p:playSoundLocal("NOM_Siren")` e `setVolume(id, 1)`.
- [ ] Commit.

### Task 6: Debug

**Files:** `shared/NOM_DebugRules.lua`, `client/NOM_Debug.lua`, `server/NOM_DebugServer.lua`; testes `test_debug_rules.lua`, `test_debug.lua`.

- [ ] `parse({op="fog", value=true|false|nil, skip=bool|nil})` (nil = false; outro tipo recusa); `NOM_Debug.fog(on, skip)`; servidor: `true` → `NOM_FogEvent.siren(skip)`, `false` → `NOM_FogEvent.stop()`; `status` mostra `nevoa`, `nevoaN`, `proxima`, `fim`, `sirene` (sai `nevoaI`, `forcarNevoa`). Testes: `debug_fog_starts_event_with_siren`, `debug_fog_skip_starts_now`, `debug_fog_false_stops`. Commit.

### Task 7: Docs

- [ ] ADR-009 (nova, indexada), GDD (`world-states`, `atmosphere`, `monsters`, `sandbox` com presets, `Overview` com a decisão de 05/10 revertendo a de 04/10), `pz-api-notes` §11, `docs/architecture/README.md` (estrutura), `docs/teste-in-game.md`, `README.md`, textos do Workshop, roadmap (`em teste`), README da sprint (critérios com evidência, roteiro in-game, aprendizados, pendências). Commit.
