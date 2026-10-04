# Sprint 0001 — Estado do mundo e clima dark: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ao anoitecer ou quando a névoa sobe, o jogo escurece e muda de cor sozinho, com transição suave, em solo e em MP.

**Architecture:** Lógica pura (`NOM_Rules`) decide noite/névoa e calcula o "look" alvo; é testada com `luajit` fora do jogo. `NOM_World` lê o clima do jogo e alimenta as regras. `NOM_Atmosphere` (cliente) aplica o look pela camada **modded** do `ClimateManager` (`setEnableModded` / `setModdedValue` / `setModdedInterpolate`), que mistura nosso valor com o valor vanilla — não substitui o clima.

**Tech Stack:** Project Zomboid B42.20 (Lua via Kahlua, subset de Lua 5.1), `luajit` para testes, bash.

**Spec:** [GDD world-states](../../gdd/world-states.md), [GDD atmosphere#clima](../../gdd/atmosphere.md#clima), [GDD sandbox](../../gdd/sandbox.md), [ADR-002](../../architecture/adr-002-autoridade-servidor.md), [ADR-004](../../architecture/adr-004-clima-antes-de-shader.md). Critérios: [README da sprint](README.md).

## Global Constraints

- Jogo: `/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid`, B42.20.4. Dedicated server em `/mnt/stuff/steam/steamapps/common/Project Zomboid Dedicated Server`.
- Mod id: `NevoaEOutroMundo`. Sandbox namespace: `NevoaEOutroMundo`. Todo global e arquivo Lua com prefixo `NOM_`.
- Layout B42.20 (confirmado em mods instalados): `mod/42/mod.info` + `mod/42/media/...` + pasta `mod/common/` existente.
- Lua do mod usa só o subset 5.1: nada de `//`, `goto`, operadores bit a bit, `table.unpack` (usar `unpack`).
- Tradução B42.20 é JSON: `media/lua/shared/Translate/<LANG>/Sandbox.json`. Nenhum texto visível fora de chave.
- Transição: 30 segundos reais (`TRANSITION_SECONDS = 30`).
- Defaults do sandbox: `DarkEnabled = true`, `DarkIntensity = 1.0` (0–2), `FogThreshold = 0.5` (0.05–1).

## Review Focus

1. **Névoa oscilando em volta do limite** → o efeito não pode piscar liga/desliga. Histerese de 0.05 (Task 2, teste `fog_hysteresis_*`).
2. **Save antigo ou sandbox sem a página do mod** (`SandboxVars.NevoaEOutroMundo == nil`) → usa defaults, não quebra (Task 3, teste `config_missing_*`).
3. **Toggle desligado no meio do jogo** → o efeito desce suave até zero e o clima volta 100% vanilla (`setEnableModded(false)`) (Task 2 `mix_zero_*` + Task 5 checklist).
4. **Lag, pausa ou alt-tab** (dt gigante num tick) → a transição não pula; dt limitado a 1s (Task 2, teste `ramp_clamps_dt`).
5. **Noite e névoa juntas** → cada canal pega o mais forte dos dois, sem somar além de 1 (Task 2, teste `mix_overlap_*`).

---

### Task 1: Ambiente de dev e esqueleto do mod

**Files:**
- Create: `mod/42/mod.info`
- Create: `mod/common/.gitkeep`
- Create: `run-tests.sh`
- Create: `tests/run.lua`
- Create: `tests/test_smoke.lua`

**Interfaces:**
- Produces: `./run-tests.sh` — roda `tests/run.lua` com `luajit`; cada arquivo de teste retorna uma tabela `{ nome = function() ... end }`; exit 0 se tudo passa, 1 se algo falha. `package.path` já inclui `mod/42/media/lua/shared/?.lua`.

- [ ] **Step 0: Abrir a branch da sprint**

Run: `git checkout -b sprint/0001-estado-e-clima main`

- [ ] **Step 1: Instalar luajit**

Run: `brew install luajit && luajit -v`
Expected: `LuaJIT 2.1...`

- [ ] **Step 2: Criar o runner de testes**

`tests/run.lua`:

```lua
package.path = "mod/42/media/lua/shared/?.lua;" .. package.path

local FILES = {
    "tests/test_smoke.lua",
}

local pass, fail = 0, 0
for _, file in ipairs(FILES) do
    local tests = dofile(file)
    for name, fn in pairs(tests) do
        local ok, err = pcall(fn)
        if ok then
            pass = pass + 1
        else
            fail = fail + 1
            print("FAIL " .. file .. " :: " .. name .. "\n  " .. tostring(err))
        end
    end
end

print(string.format("total=%d passou=%d falhou=%d", pass + fail, pass, fail))
os.exit(fail == 0 and 0 or 1)
```

`tests/test_smoke.lua`:

```lua
return {
    runner_works = function()
        assert(1 + 1 == 2)
    end,
}
```

`run-tests.sh`:

```bash
#!/usr/bin/env bash
# Testa a lógica pura do mod (sem o jogo). Exit code 0 = tudo passou.
cd "$(dirname "$0")" || exit 1
luajit tests/run.lua
```

Run: `chmod +x run-tests.sh && ./run-tests.sh; echo "EXIT=$?"`
Expected: `total=1 passou=1 falhou=0` e `EXIT=0`

- [ ] **Step 3: Provar que o runner falha alto**

Trocar temporariamente `1 + 1 == 2` por `1 + 1 == 3`.
Run: `./run-tests.sh; echo "EXIT=$?"`
Expected: linha `FAIL tests/test_smoke.lua :: runner_works` e `EXIT=1`. Desfazer a troca.

- [ ] **Step 4: Criar o esqueleto do mod**

`mod/42/mod.info`:

```
name=Névoa e Outro Mundo
id=NevoaEOutroMundo
author=Johan
modversion=0.1.0
description=Noite agressiva estilo The Last of Us e névoa do Outro Mundo estilo Silent Hill.
```

`mod/common/.gitkeep`: arquivo vazio (o B42 espera a pasta `common/`).

- [ ] **Step 5: Linkar o mod na pasta de mods do jogo**

Run: `mkdir -p ~/Zomboid/mods && ln -sfn "$PWD/mod" ~/Zomboid/mods/NevoaEOutroMundo && ls -l ~/Zomboid/mods/`
Expected: `NevoaEOutroMundo -> .../nevoa-e-outro-mundo/mod`

- [ ] **Step 6: Verificar no jogo (Johan)**

1. Steam → Project Zomboid → Propriedades → Opções de inicialização: `-debug`.
2. Abrir o jogo → Mods. **Esperado:** "Névoa e Outro Mundo" aparece na lista e ativa.
3. Ativar, voltar ao menu, abrir `~/Zomboid/console.txt` e buscar `NevoaEOutroMundo`. **Esperado:** mod carregado, nenhum `ERROR` com o id.

Se não aparecer: o symlink pode não ser seguido pelo jogo. Trocar por cópia (`cp -r mod ~/Zomboid/mods/NevoaEOutroMundo`) e registrar em Aprendizados.

- [ ] **Step 7: Commit**

```bash
git add mod run-tests.sh tests
git commit -m "feat: esqueleto do mod e runner de testes"
```

---

### Task 2: Regras puras (`NOM_Rules`)

**Files:**
- Create: `mod/42/media/lua/shared/NOM_Rules.lua`
- Create: `tests/test_rules.lua`
- Modify: `tests/run.lua` (lista `FILES`)

**Interfaces:**
- Produces (global `NOM_Rules`):
  - `NOM_Rules.isNight(tod, dawn, dusk) -> boolean` — horas em float 0–24.
  - `NOM_Rules.isFog(intensity, threshold, wasFog) -> boolean` — histerese `NOM_Rules.FOG_HYSTERESIS = 0.05`.
  - `NOM_Rules.ramp(current, active, dt, duration) -> number` — 0..1, dt limitado a [0, 1].
  - `NOM_Rules.CHANNELS = { "desaturation", "light", "fog", "tint" }`
  - `NOM_Rules.mix(nightRamp, fogRamp, intensity) -> { [channel] = { value = number|{r,g,b}|nil, weight = number } }` — `weight` em 0..1.

- [ ] **Step 1: Escrever os testes**

`tests/test_rules.lua`:

```lua
require "NOM_Rules"

local function near(a, b) return math.abs(a - b) < 1e-6 end

return {
    night_after_dusk = function()
        assert(NOM_Rules.isNight(22, 6, 21) == true)
    end,
    night_before_dawn = function()
        assert(NOM_Rules.isNight(3, 6, 21) == true)
    end,
    day_midday = function()
        assert(NOM_Rules.isNight(12, 6, 21) == false)
    end,
    night_starts_exactly_at_dusk = function()
        assert(NOM_Rules.isNight(21, 6, 21) == true)
    end,
    day_starts_exactly_at_dawn = function()
        assert(NOM_Rules.isNight(6, 6, 21) == false)
    end,

    fog_turns_on_at_threshold = function()
        assert(NOM_Rules.isFog(0.5, 0.5, false) == true)
        assert(NOM_Rules.isFog(0.49, 0.5, false) == false)
    end,
    fog_hysteresis_keeps_on_slightly_below = function()
        assert(NOM_Rules.isFog(0.47, 0.5, true) == true)
    end,
    fog_hysteresis_turns_off_below_band = function()
        assert(NOM_Rules.isFog(0.44, 0.5, true) == false)
    end,

    ramp_goes_up = function()
        assert(near(NOM_Rules.ramp(0, true, 0.5, 30), 0.5 / 30))
    end,
    ramp_goes_down = function()
        assert(near(NOM_Rules.ramp(1, false, 0.5, 30), 1 - 0.5 / 30))
    end,
    ramp_caps_at_bounds = function()
        assert(NOM_Rules.ramp(0.999, true, 1, 30) == 1)
        assert(NOM_Rules.ramp(0.001, false, 1, 30) == 0)
    end,
    ramp_clamps_dt = function()
        -- 10 minutos de pausa num tick não pode virar transição instantânea
        assert(near(NOM_Rules.ramp(0, true, 600, 30), 1 / 30))
        assert(NOM_Rules.ramp(0.5, true, -5, 30) == 0.5)
    end,

    mix_zero_when_both_off = function()
        local look = NOM_Rules.mix(0, 0, 1)
        for _, ch in ipairs(NOM_Rules.CHANNELS) do
            assert(look[ch].weight == 0, ch)
        end
    end,
    mix_night_only_has_no_fog_channel = function()
        local look = NOM_Rules.mix(1, 0, 1)
        assert(look.fog.weight == 0)
        assert(look.desaturation.weight > 0)
        assert(look.tint.weight > 0)
    end,
    mix_intensity_scales_weight = function()
        local half = NOM_Rules.mix(1, 0, 0.5)
        local full = NOM_Rules.mix(1, 0, 1)
        assert(near(half.desaturation.weight * 2, full.desaturation.weight))
    end,
    mix_overlap_takes_strongest_not_sum = function()
        local both = NOM_Rules.mix(1, 1, 1)
        local fog = NOM_Rules.mix(0, 1, 1)
        assert(near(both.desaturation.weight, fog.desaturation.weight))
        assert(both.tint.value == fog.tint.value)
    end,
    mix_weight_never_exceeds_one = function()
        local look = NOM_Rules.mix(1, 1, 2)
        for _, ch in ipairs(NOM_Rules.CHANNELS) do
            assert(look[ch].weight <= 1, ch)
        end
    end,
}
```

Em `tests/run.lua`, trocar `FILES` por:

```lua
local FILES = {
    "tests/test_smoke.lua",
    "tests/test_rules.lua",
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./run-tests.sh; echo "EXIT=$?"`
Expected: erro `module 'NOM_Rules' not found` e `EXIT=1`.

- [ ] **Step 3: Implementar**

`mod/42/media/lua/shared/NOM_Rules.lua`:

```lua
-- Lógica pura: sem API do jogo, testável com ./run-tests.sh.
NOM_Rules = {}

NOM_Rules.FOG_HYSTERESIS = 0.05
NOM_Rules.CHANNELS = { "desaturation", "light", "fog", "tint" }

-- value = alvo da camada modded do clima; weight = quanto puxar até ele (0..1).
NOM_Rules.LOOKS = {
    night = {
        desaturation = { value = 1, weight = 0.25 },
        light        = { value = 0, weight = 0.25 },
        tint         = { value = { 0.55, 0.65, 0.95 }, weight = 0.3 },
    },
    fog = {
        desaturation = { value = 1, weight = 0.6 },
        light        = { value = 0, weight = 0.15 },
        fog          = { value = 1, weight = 0.3 },
        tint         = { value = { 0.75, 0.68, 0.55 }, weight = 0.4 },
    },
}

function NOM_Rules.isNight(tod, dawn, dusk)
    return tod >= dusk or tod < dawn
end

function NOM_Rules.isFog(intensity, threshold, wasFog)
    if wasFog then
        return intensity >= threshold - NOM_Rules.FOG_HYSTERESIS
    end
    return intensity >= threshold
end

function NOM_Rules.ramp(current, active, dt, duration)
    dt = math.max(0, math.min(1, dt))
    local step = dt / duration
    if active then
        return math.min(1, current + step)
    end
    return math.max(0, current - step)
end

function NOM_Rules.mix(nightRamp, fogRamp, intensity)
    local out = {}
    for _, ch in ipairs(NOM_Rules.CHANNELS) do
        local n = NOM_Rules.LOOKS.night[ch]
        local f = NOM_Rules.LOOKS.fog[ch]
        local nw = n and n.weight * nightRamp or 0
        local fw = f and f.weight * fogRamp or 0
        local pick = (fw > nw) and f or n
        out[ch] = {
            value = pick and pick.value,
            weight = math.min(1, math.max(nw, fw) * intensity),
        }
    end
    return out
end

return NOM_Rules
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./run-tests.sh; echo "EXIT=$?"`
Expected: `total=18 passou=18 falhou=0`, `EXIT=0`.

- [ ] **Step 5: Commit**

```bash
git add mod/42/media/lua/shared/NOM_Rules.lua tests
git commit -m "feat: regras puras de noite, névoa e look"
```

---

### Task 3: Sandbox options e configuração

**Files:**
- Create: `mod/42/media/sandbox-options.txt`
- Create: `mod/42/media/lua/shared/NOM_Config.lua`
- Create: `mod/42/media/lua/shared/Translate/PTBR/Sandbox.json`
- Create: `mod/42/media/lua/shared/Translate/EN/Sandbox.json`
- Create: `tests/test_config.lua`
- Modify: `tests/run.lua` (lista `FILES`)
- Modify: `docs/gdd/sandbox.md` (defaults decididos)

**Interfaces:**
- Produces: `NOM_Config.get(key) -> value` — lê `SandboxVars.NevoaEOutroMundo[key]`, cai em `NOM_Config.DEFAULTS[key]` se ausente. Chaves: `DarkEnabled`, `DarkIntensity`, `FogThreshold`.

- [ ] **Step 1: Escrever os testes**

`tests/test_config.lua`:

```lua
require "NOM_Config"

return {
    config_missing_sandboxvars_uses_default = function()
        SandboxVars = nil
        assert(NOM_Config.get("FogThreshold") == 0.5)
        assert(NOM_Config.get("DarkEnabled") == true)
    end,
    config_missing_page_uses_default = function()
        SandboxVars = {}
        assert(NOM_Config.get("DarkIntensity") == 1.0)
    end,
    config_reads_sandbox_value = function()
        SandboxVars = { NevoaEOutroMundo = { FogThreshold = 0.8 } }
        assert(NOM_Config.get("FogThreshold") == 0.8)
    end,
    config_false_is_not_missing = function()
        SandboxVars = { NevoaEOutroMundo = { DarkEnabled = false } }
        assert(NOM_Config.get("DarkEnabled") == false)
    end,
}
```

Em `tests/run.lua`, adicionar `"tests/test_config.lua",` em `FILES`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `./run-tests.sh; echo "EXIT=$?"`
Expected: `module 'NOM_Config' not found`, `EXIT=1`.

- [ ] **Step 3: Implementar a config**

`mod/42/media/lua/shared/NOM_Config.lua`:

```lua
NOM_Config = {}

NOM_Config.DEFAULTS = {
    DarkEnabled = true,
    DarkIntensity = 1.0,
    FogThreshold = 0.5,
}

function NOM_Config.get(key)
    local vars = SandboxVars and SandboxVars.NevoaEOutroMundo
    if vars and vars[key] ~= nil then
        return vars[key]
    end
    return NOM_Config.DEFAULTS[key]
end

return NOM_Config
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./run-tests.sh; echo "EXIT=$?"`
Expected: `total=22 passou=22 falhou=0`, `EXIT=0`.

- [ ] **Step 5: Sandbox e traduções**

`mod/42/media/sandbox-options.txt`:

```
VERSION = 1,

option NevoaEOutroMundo.DarkEnabled = {
    type = boolean, default = true,
    page = NevoaEOutroMundo, translation = NevoaEOutroMundo.DarkEnabled,
}

option NevoaEOutroMundo.DarkIntensity = {
    type = double, min = 0.0, max = 2.0, default = 1.0,
    page = NevoaEOutroMundo, translation = NevoaEOutroMundo.DarkIntensity,
}

option NevoaEOutroMundo.FogThreshold = {
    type = double, min = 0.05, max = 1.0, default = 0.5,
    page = NevoaEOutroMundo, translation = NevoaEOutroMundo.FogThreshold,
}
```

`mod/42/media/lua/shared/Translate/PTBR/Sandbox.json`:

```json
{
    "Sandbox_NevoaEOutroMundo": "Névoa e Outro Mundo",
    "Sandbox_NevoaEOutroMundo.DarkEnabled": "Clima sombrio à noite e na névoa",
    "Sandbox_NevoaEOutroMundo.DarkEnabled_tooltip": "Escurece, dessatura e tinge o mundo à noite e com névoa forte.",
    "Sandbox_NevoaEOutroMundo.DarkIntensity": "Intensidade do clima sombrio",
    "Sandbox_NevoaEOutroMundo.DarkIntensity_tooltip": "0 desliga o efeito, 1 é o padrão, 2 é o dobro.",
    "Sandbox_NevoaEOutroMundo.FogThreshold": "Névoa que acorda o Outro Mundo",
    "Sandbox_NevoaEOutroMundo.FogThreshold_tooltip": "Intensidade de névoa (0 a 1) a partir da qual o Outro Mundo começa."
}
```

`mod/42/media/lua/shared/Translate/EN/Sandbox.json`:

```json
{
    "Sandbox_NevoaEOutroMundo": "Fog and Otherworld",
    "Sandbox_NevoaEOutroMundo.DarkEnabled": "Dark climate at night and in fog",
    "Sandbox_NevoaEOutroMundo.DarkEnabled_tooltip": "Darkens, desaturates and tints the world at night and in heavy fog.",
    "Sandbox_NevoaEOutroMundo.DarkIntensity": "Dark climate intensity",
    "Sandbox_NevoaEOutroMundo.DarkIntensity_tooltip": "0 disables the effect, 1 is default, 2 is double.",
    "Sandbox_NevoaEOutroMundo.FogThreshold": "Fog that wakes the Otherworld",
    "Sandbox_NevoaEOutroMundo.FogThreshold_tooltip": "Fog intensity (0 to 1) at which the Otherworld begins."
}
```

Validar JSON: `for f in mod/42/media/lua/shared/Translate/*/Sandbox.json; do python3 -m json.tool "$f" >/dev/null || echo "INVÁLIDO: $f"; done; echo JSON-OK`
Expected: `JSON-OK`

- [ ] **Step 6: Registrar defaults no GDD**

Em `docs/gdd/sandbox.md`, na tabela de números, trocar as linhas:

```
| `FogThreshold` | [world-states.md](world-states.md) |
| `DarkIntensity` | [atmosphere.md](atmosphere.md) |
```

por:

```
| `FogThreshold` (0.5, faixa 0.05–1) | [world-states.md](world-states.md) |
| `DarkIntensity` (1.0, faixa 0–2) | [atmosphere.md](atmosphere.md) |
```

- [ ] **Step 7: Verificar no jogo (Johan)**

Novo jogo → Sandbox → página "Névoa e Outro Mundo". **Esperado:** 3 opções com textos em PT-BR (com o jogo em português), tooltips aparecendo.

- [ ] **Step 8: Commit**

```bash
git add mod tests docs/gdd/sandbox.md
git commit -m "feat: sandbox options, config com defaults e traduções"
```

---

### Task 4: Estado do mundo (`NOM_World`)

**Files:**
- Create: `mod/42/media/lua/shared/NOM_World.lua`
- Modify: `docs/architecture/adr-002-autoridade-servidor.md`

**Interfaces:**
- Consumes: `NOM_Rules.isNight`, `NOM_Rules.isFog`, `NOM_Config.get("FogThreshold")`.
- Produces: `NOM_World.update() -> NOM_World` com campos `night: boolean`, `fog: boolean`, `tod`, `dawn`, `dusk`, `fogIntensity` (números, para debug). Roda em qualquer lado (cliente ou servidor), porque o clima já é sincronizado pelo jogo.

Este arquivo chama API do jogo e não tem teste em `luajit`. A lógica que importa já está testada em `NOM_Rules`; aqui o teste é o print no console.

- [ ] **Step 1: Implementar**

`mod/42/media/lua/shared/NOM_World.lua`:

```lua
require "NOM_Rules"
require "NOM_Config"

-- Flags derivadas do clima, que o jogo já sincroniza entre servidor e clientes.
NOM_World = { night = false, fog = false }

function NOM_World.update()
    local clim = getClimateManager()
    NOM_World.tod = getGameTime():getTimeOfDay()
    NOM_World.dawn = clim:getDawn()
    NOM_World.dusk = clim:getDusk()
    NOM_World.fogIntensity = clim:getFogIntensity()
    NOM_World.night = NOM_Rules.isNight(NOM_World.tod, NOM_World.dawn, NOM_World.dusk)
    NOM_World.fog = NOM_Rules.isFog(NOM_World.fogIntensity, NOM_Config.get("FogThreshold"), NOM_World.fog)
    return NOM_World
end

local lastNight, lastFog
local function logChanges()
    local w = NOM_World.update()
    if w.night ~= lastNight or w.fog ~= lastFog then
        print(string.format("[NOM] night=%s fog=%s tod=%.2f dawn=%.2f dusk=%.2f fogI=%.2f",
            tostring(w.night), tostring(w.fog), w.tod, w.dawn, w.dusk, w.fogIntensity))
        lastNight, lastFog = w.night, w.fog
    end
end

if getDebug() then
    Events.EveryOneMinute.Add(logChanges)
end

return NOM_World
```

- [ ] **Step 2: Verificar no jogo (Johan)**

Em `-debug`, num save novo:
1. Debug menu → Time: pular para 20:00, depois 22:00. **Esperado em `console.txt`:** linha `[NOM] night=true ...` aparece ao passar do `dusk`, com `dawn`/`dusk` em horas plausíveis (ex: ~5–7 e ~19–22).
2. Debug menu → Climate → forçar `FOG_INTENSITY` acima de 0.5. **Esperado:** `[NOM] ... fog=true`.
3. Baixar para 0.47. **Esperado:** continua `fog=true` (histerese). Baixar para 0.40. **Esperado:** `fog=false`.

Se `getDawn()`/`getDusk()` não retornarem horas (ex: valores 0 ou nil), registrar em Aprendizados e usar `clim:getCurrentDay()` para achar o campo certo antes de seguir.

- [ ] **Step 3: Ajustar o ADR-002**

Em `docs/architecture/adr-002-autoridade-servidor.md`, adicionar ao fim de `## Consequências`:

```markdown
- As flags night/fog são **derivadas do clima**, que o jogo já sincroniza: o
  cliente calcula as próprias (`NOM_World`, em `shared/`) sem mensagem de rede.
  O servidor continua dono de toda decisão de gameplay (sorteio, spawn); os
  eventos de servidor nascem na sprint 0002, junto do primeiro consumidor.
```

- [ ] **Step 4: Commit**

```bash
git add mod/42/media/lua/shared/NOM_World.lua docs/architecture/adr-002-autoridade-servidor.md
git commit -m "feat: estado do mundo derivado do clima"
```

---

### Task 5: Atmosfera (`NOM_Atmosphere`)

**Files:**
- Create: `mod/42/media/lua/client/NOM_Atmosphere.lua`

**Interfaces:**
- Consumes: `NOM_World.update()`, `NOM_Rules.ramp`, `NOM_Rules.mix`, `NOM_Config.get("DarkEnabled")`, `NOM_Config.get("DarkIntensity")`.
- API do jogo (confirmada no bytecode do B42.20): `ClimateFloat:setEnableModded(bool)`, `:setModdedValue(float)`, `:setModdedInterpolate(float)`; `ClimateColor:setModdedValue(ClimateColorInfo)`; construtor `ClimateColorInfo.new(r,g,b,a, r,g,b,a)` (exterior, interior). Constantes `ClimateManager.FLOAT_DESATURATION`, `FLOAT_GLOBAL_LIGHT_INTENSITY`, `FLOAT_FOG_INTENSITY`, `COLOR_GLOBAL_LIGHT`.

- [ ] **Step 1: Implementar**

`mod/42/media/lua/client/NOM_Atmosphere.lua`:

```lua
require "NOM_World"

local TRANSITION_SECONDS = 30

local FLOATS = {
    desaturation = ClimateManager.FLOAT_DESATURATION,
    light = ClimateManager.FLOAT_GLOBAL_LIGHT_INTENSITY,
    fog = ClimateManager.FLOAT_FOG_INTENSITY,
}

local state = { nightRamp = 0, fogRamp = 0, lastMs = nil }
local tintInfo = {} -- cache: tabela de cor do NOM_Rules -> ClimateColorInfo

local function applyFloat(clim, id, ch)
    local f = clim:getClimateFloat(id)
    if ch.weight <= 0 then
        f:setEnableModded(false)
        return
    end
    f:setEnableModded(true)
    f:setModdedValue(ch.value)
    f:setModdedInterpolate(ch.weight)
end

local function applyTint(clim, ch)
    local c = clim:getClimateColor(ClimateManager.COLOR_GLOBAL_LIGHT)
    if ch.weight <= 0 then
        c:setEnableModded(false)
        return
    end
    local rgb = ch.value
    tintInfo[rgb] = tintInfo[rgb] or ClimateColorInfo.new(rgb[1], rgb[2], rgb[3], 1, rgb[1], rgb[2], rgb[3], 1)
    c:setEnableModded(true)
    c:setModdedValue(tintInfo[rgb])
    c:setModdedInterpolate(ch.weight)
end

local function onTick()
    local now = getTimestampMs()
    local dt = state.lastMs and (now - state.lastMs) / 1000 or 0
    state.lastMs = now

    local enabled = NOM_Config.get("DarkEnabled")
    local w = NOM_World.update()
    state.nightRamp = NOM_Rules.ramp(state.nightRamp, enabled and w.night, dt, TRANSITION_SECONDS)
    state.fogRamp = NOM_Rules.ramp(state.fogRamp, enabled and w.fog, dt, TRANSITION_SECONDS)

    local look = NOM_Rules.mix(state.nightRamp, state.fogRamp, NOM_Config.get("DarkIntensity"))
    local clim = getClimateManager()
    for ch, id in pairs(FLOATS) do
        applyFloat(clim, id, look[ch])
    end
    applyTint(clim, look.tint)
end

Events.OnTick.Add(onTick)
```

- [ ] **Step 2: Verificar no jogo — solo (Johan)**

Em `-debug`, save novo com defaults:
1. Pular para 12:00. **Esperado:** visual vanilla.
2. Pular para 22:00 e esperar ~30s reais. **Esperado:** escurece aos poucos, cores mais frias/azuladas, levemente dessaturado. Sem corte seco.
3. Forçar névoa 0.8. **Esperado:** em ~30s, bem dessaturado, tom sépia/cinza, névoa mais densa que a vanilla.
4. Abrir o Debug → Climate e conferir que `DESATURATION` e `GLOBAL_LIGHT` mostram valor modded ativo.
5. Admin/sandbox: `DarkEnabled = false` (ou recomeçar save com ele desligado). **Esperado:** efeito some suave em ~30s e o visual volta ao vanilla.
6. `DarkIntensity = 2`. **Esperado:** efeito visivelmente mais forte que com 1.
7. Pausar o jogo por 1 minuto à noite e despausar. **Esperado:** nada pula.

Se o look estiver forte/fraco demais, ajustar só os `weight` em `NOM_Rules.LOOKS` (os testes continuam passando) e registrar os valores escolhidos em Checkpoints.

Se `ClimateColorInfo.new` falhar no console: registrar em Aprendizados e trocar por `c:getModdedValue()` + `:setExterior(r,g,b,1)` + `:setInterior(r,g,b,1)` (métodos confirmados no bytecode).

- [ ] **Step 3: Rodar os testes de novo**

Run: `./run-tests.sh; echo "EXIT=$?"`
Expected: `falhou=0`, `EXIT=0`.

- [ ] **Step 4: Commit**

```bash
git add mod/42/media/lua/client/NOM_Atmosphere.lua mod/42/media/lua/shared/NOM_Rules.lua
git commit -m "feat: clima sombrio à noite e na névoa"
```

---

### Task 6: Multiplayer e fechamento da sprint

**Files:**
- Modify: `docs/sprints/sprint-0001-estado-e-clima/README.md`
- Modify: `docs/sprints/README.md` (status na tabela)
- Modify: `docs/architecture/README.md` (árvore do mod com o layout real)

- [ ] **Step 1: Servidor dedicado com o mod (Johan + Claude)**

1. Rodar o dedicated server uma vez para gerar `~/Zomboid/Server/servertest.ini`:
   `cd "/mnt/stuff/steam/steamapps/common/Project Zomboid Dedicated Server" && ./start-server.sh` → criar senha de admin → parar com `quit`.
2. Em `~/Zomboid/Server/servertest.ini`: `Mods=\NevoaEOutroMundo` (o B42 usa `\` antes do id; confirmar no console).
3. Subir o servidor de novo. **Esperado em `server-console.txt`:** mod carregado, sem `ERROR` com `NOM_`.
4. Entrar pelo cliente em `127.0.0.1`. Como admin: `/setTimeOfDay 22` (ou painel admin → Climate) e forçar névoa.
   **Esperado:** cliente escurece igual ao solo.
5. Segundo cliente (amigo): **esperado** escurece junto. Sem amigo disponível, registrar em Pendências que o teste com 2 clientes fica para a sprint 0006.

- [ ] **Step 2: Atualizar a árvore no `docs/architecture/README.md`**

Trocar o bloco `## Estrutura do mod` pelo layout real:

```
mod/
  42/mod.info
  42/media/
    sandbox-options.txt
    lua/shared/NOM_Rules.lua        lógica pura (sem API do jogo), testável
    lua/shared/NOM_Config.lua       sandbox + defaults
    lua/shared/NOM_World.lua        flags night/fog derivadas do clima
    lua/shared/Translate/<LANG>/    traduções em JSON (B42.20)
    lua/server/NOM_Variants.lua     (sprint 0002+) marca/desmarca, spawn de Ecos
    lua/server/NOM_Behaviors.lua    (sprint 0003+) comportamento
    lua/client/NOM_Atmosphere.lua   clima, som, rádio
    lua/client/NOM_Overlays.lua     (sprint 0005) sangue/ferrugem locais
  common/                           exigida pelo B42
tests/                              asserts de lua puro (./run-tests.sh)
```

- [ ] **Step 3: Fechar o README da sprint**

Em `docs/sprints/sprint-0001-estado-e-clima/README.md`: marcar cada critério com **como** foi confirmado (linha de console, passo do checklist, saída do `run-tests.sh`), colar a última saída de `./run-tests.sh`, preencher Checkpoints, Aprendizados (symlink, `getDawn`/`getDusk`, `Mods=\`, valores finais dos `weight`) e Pendências. `Status: concluída`.

Em `docs/sprints/README.md`: 0001 → `concluída`, 0002 → `planejada`.

- [ ] **Step 4: Commit e merge**

```bash
git add docs
git commit -m "docs: fecha sprint 0001"
git checkout main && git merge --no-ff sprint/0001-estado-e-clima
git push origin main
git branch -d sprint/0001-estado-e-clima
```
