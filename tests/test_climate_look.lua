-- NOM_ClimateLook contra um clima falso que IMITA o jogo (bytecode do B42.20):
-- uma vez por minuto de jogo, updateValues() volta o interno pro vanilla e
-- dispara OnClimateTick; depois, a cada frame, calculate() faz o lerp da camada
-- modded NO PRÓPRIO valor interno (internal = lerp(interp, internal, modded)).
require "NOM_Rules"

local LOOK_FILE = "mod/42/media/lua/server/NOM_ClimateLook.lua"

local function lerp(t, a, b) return a + (b - a) * t end
local function near(a, b) return math.abs(a - b) < 1e-4 end

local function newColor(c)
    return {
        c = c,
        getRedFloat = function(s) return s.c[1] end,
        getGreenFloat = function(s) return s.c[2] end,
        getBlueFloat = function(s) return s.c[3] end,
        getAlphaFloat = function(s) return s.c[4] end,
    }
end

local function newColorInfo(ext, int)
    return {
        ext = { unpack(ext) }, int = { unpack(int) },
        getExterior = function(s) return newColor(s.ext) end,
        getInterior = function(s) return newColor(s.int) end,
        setExterior = function(s, r, g, b, a) s.ext = { r, g, b, a } end,
        setInterior = function(s, r, g, b, a) s.int = { r, g, b, a } end,
    }
end

local function setup(opts)
    local calls = {}
    local world = { tod = opts.tod or 12, fog = opts.fog or 0 }

    local function float(name, vanilla)
        local f = { vanilla = vanilla, internal = vanilla, final = vanilla, modded = 0, interp = 0, isModded = false }
        function f:getInternalValue() return self.internal end
        function f:getFinalValue() return self.final end
        function f:isEnableOverride() return self.override ~= nil end
        function f:getOverride() return self.override end
        function f:getOverrideInterpolate() return self.overrideInterp end
        function f:setEnableModded(on) self.isModded = on; calls[#calls + 1] = name .. (on and ":on" or ":off") end
        function f:setModdedValue(v) self.modded = v end
        function f:setModdedInterpolate(w) self.interp = w end
        function f:reset() self.internal = self.vanilla end
        function f:calculate()
            if self.isModded and self.interp > 0 then
                self.internal = lerp(self.interp, self.internal, self.modded)
            end
            if self.override and self.overrideInterp > 0 then
                -- override de valor (FogCycle/ClimateCycle do sandbox) ignora o interno;
                -- o do WeatherPeriod (setOverride(0, t)) mistura em cima do interno
                local base = self.overrideValue and self.overrideInternal or self.internal
                self.final = lerp(self.overrideInterp, base, self.override)
            else
                self.final = self.internal
            end
        end
        return f
    end

    local floats = {
        [0] = float("f0", 0.2),  -- dessaturação
        [1] = float("f1", 0.8),  -- luz global
        [5] = float("f5", 0),    -- névoa
    }
    local VANILLA_EXT, VANILLA_INT = { 0.9, 0.85, 0.8, 1 }, { 0.6, 0.6, 0.6, 1 }
    local color = { internal = newColorInfo(VANILLA_EXT, VANILLA_INT), modded = newColorInfo(VANILLA_EXT, VANILLA_INT),
        interp = 0, isModded = false }
    color.final = newColorInfo(VANILLA_EXT, VANILLA_INT)
    function color:getInternalValue() return self.internal end
    function color:setEnableModded(on) self.isModded = on; calls[#calls + 1] = "tint" .. (on and ":on" or ":off") end
    function color:setModdedValue(info) -- o jogo copia (setTo), não guarda a referência
        self.modded = newColorInfo(info.ext, info.int)
    end
    function color:setModdedInterpolate(w) self.interp = w end
    function color:reset() self.internal = newColorInfo(VANILLA_EXT, VANILLA_INT) end
    function color:calculate()
        if self.isModded and self.interp > 0 then
            for _, k in ipairs({ "ext", "int" }) do
                for i = 1, 4 do
                    self.internal[k][i] = lerp(self.interp, self.internal[k][i], self.modded[k][i])
                end
            end
        end
        self.final = newColorInfo(self.internal.ext, self.internal.int)
    end

    ClimateManager = { FLOAT_DESATURATION = 0, FLOAT_GLOBAL_LIGHT_INTENSITY = 1, FLOAT_FOG_INTENSITY = 5, COLOR_GLOBAL_LIGHT = 0 }
    ClimateColorInfo = {
        new = function(r, g, b, a, r2, g2, b2, a2) return newColorInfo({ r, g, b, a }, { r2, g2, b2, a2 }) end,
    }
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {}, FogCycle = opts.fogCycle or 1, ClimateCycle = opts.climateCycle or 1 }
    isClient = function() return opts.client == true end
    getDebug = function() return false end
    local handlers = { climate = {}, tick = {} }
    Events = {
        OnClimateTick = { Add = function(f) handlers.climate[#handlers.climate + 1] = f end },
        OnTick = { Add = function(f) handlers.tick[#handlers.tick + 1] = f end },
        EveryOneMinute = { Add = function() end },
    }
    getGameTime = function() return { getTimeOfDay = function() return world.tod end } end
    local clim = {
        getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end,
        getFogIntensity = function() return floats[5].final end,
        getClimateFloat = function(_, id) return floats[id] end,
        getClimateColor = function() return color end,
    }
    getClimateManager = function() return clim end

    NOM_World = nil
    package.loaded["NOM_World"] = nil
    dofile(LOOK_FILE)

    local K = opts.K or 10
    local env = { calls = calls, world = world, floats = floats, color = color }
    -- Um minuto de jogo: updateValues + OnClimateTick no 1º frame, calculate em todo frame.
    function env.minute()
        for frame = 1, K do
            if frame == 1 then
                floats[5].vanilla = world.fog
                for _, f in pairs(floats) do f:reset() end
                color:reset()
                for _, h in ipairs(handlers.climate) do h(clim) end
            end
            for _, f in pairs(floats) do f:calculate() end
            color:calculate()
            for _, h in ipairs(handlers.tick) do h() end
        end
    end
    function env.run(n, each)
        for _ = 1, n do
            env.minute()
            if each then each() end
        end
    end
    return env
end

local function count(calls, entry)
    local n = 0
    for _, c in ipairs(calls) do if c == entry then n = n + 1 end end
    return n
end

local function nightWeight(ch, intensity)
    return NOM_Rules.mix(1, 0, intensity or 1)[ch].weight
end

return {
    -- (a) o valor final é a mistura única, por mais frames que rodem entre ticks de clima
    look_does_not_compound_between_climate_ticks = function()
        for _, K in ipairs({ 1, 10, 150 }) do
            local env = setup({ tod = 23, K = K })
            env.run(40)
            local d = env.floats[0]
            local want = 0.2 + (1 - 0.2) * nightWeight("desaturation")
            assert(near(d.final, want), string.format("K=%s dessaturação %.4f, esperado %.4f", K, d.final, want))
            local l = env.floats[1]
            assert(near(l.final, 0.8 * (1 - nightWeight("light"))), "K=" .. K .. " luz composta")
            local tint, w = NOM_Rules.LOOKS.night.tint.value, nightWeight("tint")
            assert(near(env.color.final.ext[1], 0.9 + (tint[1] - 0.9) * w), "K=" .. K .. " tint exterior composto")
            assert(near(env.color.final.int[3], 0.6 + (tint[3] - 0.6) * w), "K=" .. K .. " tint interior composto")
        end
    end,

    -- (b) DarkIntensity muda o resultado, não só a velocidade
    look_dark_intensity_changes_final_value = function()
        local finals = {}
        for _, I in ipairs({ 0.5, 1, 2 }) do
            local env = setup({ tod = 23, K = 150, sandbox = { DarkIntensity = I } })
            env.run(40)
            finals[#finals + 1] = env.floats[0].final
        end
        assert(finals[1] < finals[2] - 0.01 and finals[2] < finals[3] - 0.01,
            string.format("finais iguais: %.3f %.3f %.3f", finals[1], finals[2], finals[3]))
    end,

    -- (c) a névoa do mod não segura a flag quando a névoa vanilla baixa (latch C1)
    look_fog_flag_exits_when_vanilla_fog_drops = function()
        local env = setup({ tod = 12, fog = 0.9, K = 10, sandbox = { FogThreshold = 0.35, DarkIntensity = 2 } })
        local sawFog = false
        env.run(200, function()
            sawFog = sawFog or NOM_World.fog
            env.world.fog = math.max(0, env.world.fog - 0.01)
        end)
        assert(sawFog, "névoa nunca ligou")
        assert(NOM_World.fog == false, "névoa travou ligada")
    end,

    -- (c2) período de clima (WeatherPeriod) puxando a névoa pra 0 com override
    -- que não é de valor: o final mistura o interno, onde mora a névoa do mod
    look_fog_flag_exits_during_weather_period_override = function()
        local env = setup({ tod = 12, fog = 0.9, K = 10, sandbox = { FogThreshold = 0.35, DarkIntensity = 2 } })
        local f = env.floats[5]
        f.override, f.overrideInterp, f.overrideValue = 0, 0.2, false
        local sawFog = false
        env.run(200, function()
            sawFog = sawFog or NOM_World.fog
            env.world.fog = math.max(0, env.world.fog - 0.01)
        end)
        assert(sawFog, "névoa nunca ligou")
        assert(NOM_World.fog == false, "névoa travou ligada no período de clima")
    end,

    -- transição em minutos de jogo: 20 ticks de clima, seja qual for o tempo real
    look_transition_takes_twenty_game_minutes = function()
        local env = setup({ tod = 23, K = 10 })
        local full = 0.2 + (1 - 0.2) * nightWeight("desaturation")
        env.run(19)
        assert(env.floats[0].final < full - 1e-4, "cheio antes de 20 minutos de jogo")
        env.run(1)
        assert(near(env.floats[0].final, full), "não chegou cheio em 20 minutos de jogo")
    end,

    -- (d) dia sem névoa: nenhuma chamada no clima
    look_idle_day_touches_nothing = function()
        local env = setup({ tod = 12, K = 10 })
        env.run(50)
        assert(#env.calls == 0, "chamou o clima de dia sem efeito: " .. table.concat(env.calls, ","))
    end,

    -- (e) desligar no sandbox desce em rampa e desliga a camada uma vez só
    look_toggle_off_ramps_down_then_disables_once = function()
        local env = setup({ tod = 23, K = 10 })
        env.run(40)
        local full = env.floats[0].final
        SandboxVars.NevoaEOutroMundo.DarkEnabled = false
        env.run(1)
        local mid = env.floats[0].final
        assert(mid < full - 1e-4 and mid > 0.2 + 1e-4, string.format("sem rampa: %.4f (cheio %.4f)", mid, full))
        env.run(40)
        assert(near(env.floats[0].final, 0.2), "não voltou ao vanilla")
        assert(count(env.calls, "f0:on") == 1, "liga uma vez só")
        assert(count(env.calls, "f0:off") == 1, "desliga uma vez só")
        assert(count(env.calls, "tint:off") == 1)
        assert(count(env.calls, "f5:on") == 0, "sem névoa, canal de névoa nunca liga")
    end,

    -- (f) cliente de MP nunca escreve no clima: o visual vem do servidor
    look_mp_client_writes_nothing = function()
        local env = setup({ tod = 23, K = 10, client = true })
        env.run(40)
        assert(#env.calls == 0, "cliente escreveu no clima: " .. table.concat(env.calls, ","))
        assert(near(env.floats[0].final, 0.2), "cliente mexeu na dessaturação")
    end,

    -- (g) FogCycle do sandbox: a detecção usa o valor efetivo e não fica piscando
    look_fog_override_uses_final_without_flapping = function()
        local env = setup({ tod = 12, fog = 0.1, K = 10, sandbox = { FogThreshold = 0.5 }, fogCycle = 3 })
        local f = env.floats[5]
        -- final = lerp(0.5, 0.5, 0.7) = 0.6; a fórmula do WeatherPeriod daria 0.4
        f.override, f.overrideInterp, f.overrideValue, f.overrideInternal = 0.7, 0.5, true, 0.5
        f.final = 0.6
        local changes, last = 0, false
        env.run(100, function()
            if NOM_World.fog ~= last then changes = changes + 1; last = NOM_World.fog end
        end)
        assert(NOM_World.fog == true, "override de névoa ignorado")
        assert(changes == 1, "flag piscou " .. changes .. " vezes")
    end,

    -- ClimateCycle 6 (nevasca eterna) liga o override de valor da névoa mesmo com
    -- FogCycle normal (bytecode updateSandboxOverrides): a detecção lê o final.
    -- Pela fórmula do WeatherPeriod daria lerp(0.5, 0.1, 0.7) = 0.4 < 0.5.
    look_blizzard_override_uses_final = function()
        local env = setup({ tod = 12, fog = 0.1, K = 10, sandbox = { FogThreshold = 0.5 }, climateCycle = 6 })
        local f = env.floats[5]
        f.override, f.overrideInterp, f.overrideValue, f.overrideInternal = 0.7, 0.5, true, 0.5
        env.run(5)
        assert(NOM_World.fog == true, "nevasca eterna ignorada: leu o interno")
    end,
}
