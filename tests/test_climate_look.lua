-- NOM_ClimateLook contra um clima falso que IMITA o jogo (bytecode do B42.20):
-- uma vez por minuto de jogo, updateValues() volta o interno pro vanilla e
-- dispara OnClimateTick; depois, a cada frame, calculate() faz o lerp da camada
-- modded NO PRÓPRIO valor interno (internal = lerp(interp, internal, modded)).
require "NOM_Rules"
require "NOM_FogEventRules"

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

    -- ClimateManager$ClimateFloat do jogo: admin primeiro, camada modded no
    -- interno, override por cima (de valor: ignora o interno). setOverride religa
    -- o override; setEnableOverride só mexe no isOverride. O que o JOGO faz nos
    -- campos (sandbox, WeatherPeriod) não entra em calls: calls é só o que o mod chama.
    local function float(name, vanilla)
        local f = { vanilla = vanilla, internal = vanilla, final = vanilla, modded = 0, interp = 0, isModded = false,
            isOverride = false, isOverrideValue = false, override = 0, overrideInterp = 0, overrideInternal = 0 }
        function f:getInternalValue() return self.internal end
        function f:getFinalValue() return self.final end
        function f:isEnableOverride() return self.isOverride end
        function f:getOverride() return self.override end
        function f:getOverrideInterpolate() return self.overrideInterp end
        function f:setEnableOverride(on) self.isOverride = on; calls[#calls + 1] = name .. ":override=" .. tostring(on) end
        function f:setEnableModded(on) self.isModded = on; calls[#calls + 1] = name .. (on and ":on" or ":off") end
        function f:setModdedValue(v) self.modded = v end
        function f:setModdedInterpolate(w) self.interp = w end
        function f:reset() self.internal = self.vanilla end
        function f:gameSetOverride(v, t) self.override, self.overrideInterp, self.isOverride = v, t, true end
        function f:calculate()
            if self.admin ~= nil then
                self.final = self.admin
                return
            end
            if self.isModded and self.interp > 0 then
                self.internal = lerp(self.interp, self.internal, self.modded)
            end
            if self.isOverride and self.overrideInterp > 0 then
                local base = self.isOverrideValue and self.overrideInternal or self.internal
                self.final = lerp(self.overrideInterp, base, self.override)
            else
                self.final = self.internal
            end
        end
        return f
    end

    local floats = {
        [0] = float("f0", 0.2),  -- dessaturação
        [5] = float("f5", 0),    -- névoa
        [9] = float("f9", 0.5),  -- ambient (0 de madrugada no jogo; 0.5 pra ver a mistura)
    }
    -- noite de lua cheia do jogo (server/Climate/ClimateMain.lua:20-22): cinza 0.33,
    -- alfa 0.8 no exterior; interior azulado 0.12/0.13/0.4, alfa 0.4
    local VANILLA_EXT, VANILLA_INT = { 0.33, 0.33, 0.33, 0.8 }, { 0.12, 0.13, 0.4, 0.4 }
    local color = { internal = newColorInfo(VANILLA_EXT, VANILLA_INT), modded = newColorInfo(VANILLA_EXT, VANILLA_INT),
        interp = 0, isModded = false }
    color.final = newColorInfo(VANILLA_EXT, VANILLA_INT)
    function color:getInternalValue() return self.internal end
    function color:getFinalValue() return self.final end
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

    -- COLOR_NEW_FOG (id 1): a cor que o ImprovedFog desenha (update 132–174). O
    -- interno nasce 0.9/0.9/0.95/1 (<init> 324–361) e o jogo NUNCA volta ele: o
    -- updateValues não escreve, então reset() não existe aqui. O calculate é o mesmo
    -- da luz (modded no próprio interno), com o override por cima (calculate 61–97),
    -- que a tempestade liga todo minuto (WeatherPeriod.updateCurrentStage 909–957).
    local FOG_VANILLA = { 0.9, 0.9, 0.95, 1 }
    local fogColor = { internal = newColorInfo(FOG_VANILLA, FOG_VANILLA), modded = newColorInfo(FOG_VANILLA, FOG_VANILLA),
        interp = 0, isModded = false, isOverride = false, overrideInterp = 0 }
    fogColor.final = newColorInfo(FOG_VANILLA, FOG_VANILLA)
    function fogColor:getInternalValue() return self.internal end
    function fogColor:getFinalValue() return self.final end
    function fogColor:setEnableModded(on) self.isModded = on; calls[#calls + 1] = "fogColor" .. (on and ":on" or ":off") end
    function fogColor:setModdedValue(info) self.modded = newColorInfo(info.ext, info.int) end
    function fogColor:setModdedInterpolate(w) self.interp = w end
    function fogColor:isEnableOverride() return self.isOverride end
    function fogColor:setEnableOverride(on) self.isOverride = on; calls[#calls + 1] = "fogColor:override=" .. tostring(on) end
    function fogColor:gameSetOverride(rgba, t)
        self.override, self.overrideInterp, self.isOverride = newColorInfo(rgba, rgba), t, true
    end
    function fogColor:calculate()
        if self.isModded and self.interp > 0 then
            for _, k in ipairs({ "ext", "int" }) do
                for i = 1, 4 do self.internal[k][i] = lerp(self.interp, self.internal[k][i], self.modded[k][i]) end
            end
        end
        local out = newColorInfo(self.internal.ext, self.internal.int)
        if self.isOverride and self.overrideInterp > 0 then
            for _, k in ipairs({ "ext", "int" }) do
                for i = 1, 4 do out[k][i] = lerp(self.overrideInterp, self.internal[k][i], self.override[k][i]) end
            end
        end
        self.final = out
    end
    local colors = { [0] = color, [1] = fogColor }

    ClimateManager = { FLOAT_DESATURATION = 0, FLOAT_GLOBAL_LIGHT_INTENSITY = 1, FLOAT_FOG_INTENSITY = 5,
        FLOAT_AMBIENT = 9, COLOR_GLOBAL_LIGHT = 0 }
    ClimateColorInfo = {
        new = function(r, g, b, a, r2, g2, b2, a2) return newColorInfo({ r, g, b, a }, { r2, g2, b2, a2 }) end,
    }
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {}, FogCycle = opts.fogCycle or 1, ClimateCycle = opts.climateCycle or 1 }
    isClient = function() return opts.client == true end
    getDebug = function() return opts.debug == true end
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
        getClimateColor = function(_, id) return colors[id] end,
    }
    getClimateManager = function() return clim end

    NOM_World = nil
    package.loaded["NOM_World"] = nil
    dofile(LOOK_FILE)

    local K = opts.K or 10
    local env = { calls = calls, world = world, floats = floats, color = color, fogColor = fogColor, minutes = 0 }
    -- updateSandboxOverrides (bytecode 471–675): fogOverride = 4 com nevasca eterna
    -- (ClimateCycle 6) e FogCycle ≠ 2, senão o FogCycle; só na TROCA liga/desliga o
    -- override de valor ("sem névoa" põe 0); névoa eterna (≥ 3) sorteia de hora em hora.
    local lastFogOverride
    local function sandboxOverrides()
        local sv, f = SandboxVars, floats[5]
        local fo = (sv.ClimateCycle == 6 and sv.FogCycle ~= 2) and 4 or sv.FogCycle
        if fo ~= lastFogOverride then
            lastFogOverride = fo
            f.isOverride, f.isOverrideValue = fo > 1, fo > 1
            if fo == 2 then f:gameSetOverride(0, 1) elseif fo >= 3 then f.overrideInternal = 0.5 end
        end
        if fo >= 3 and env.minutes % 60 == 0 then f:gameSetOverride(0.7, 1) end
    end
    -- Um minuto de jogo: overrides do sandbox, updateValues, WeatherPeriod (env.weather
    -- = { fog, t }: setOverride todo minuto), OnClimateTick; calculate em todo frame.
    function env.minute()
        for frame = 1, K do
            if frame == 1 then
                floats[5].vanilla = world.fog
                for _, f in pairs(floats) do f:reset() end
                color:reset()
                sandboxOverrides()
                if env.weather then floats[5]:gameSetOverride(env.weather.fog, env.weather.t) end
                if env.storm then fogColor:gameSetOverride(env.storm, 0.8) end
                for _, h in ipairs(handlers.climate) do h(clim) end
                env.minutes = env.minutes + 1
            end
            for _, f in pairs(floats) do f:calculate() end
            color:calculate()
            fogColor:calculate()
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

-- chamadas do mod fora do canal de névoa (que é sempre do mod, ADR-009)
local function notFog(calls)
    local out = {}
    for _, c in ipairs(calls) do if c:sub(1, 3) ~= "f5:" then out[#out + 1] = c end end
    return out
end

local DENSITY = NOM_FogEventRules.DENSITY

local function sameColor(a, b)
    for i = 1, 4 do if not near(a[i], b[i]) then return false end end
    return true
end
local function fmtColor(c) return string.format("%.3f,%.3f,%.3f,%.3f", c[1], c[2], c[3], c[4]) end

local function nightWeight(ch, intensity)
    return NOM_Rules.mix(1, 0, intensity or 1)[ch].weight
end

return {
    -- (a) o valor final é a mistura única, por mais frames que rodem entre ticks de clima
    look_does_not_compound_between_climate_ticks = function()
        for _, K in ipairs({ 1, 10, 150 }) do
            local env = setup({ tod = 23, K = K })
            env.run(40)
            local a = env.floats[9]
            local want = 0.5 * (1 - nightWeight("ambient"))
            assert(near(a.final, want), string.format("K=%s ambient %.4f, esperado %.4f", K, a.final, want))
            assert(near(env.floats[0].final, 0.2), "K=" .. K .. " mexeu na dessaturação à noite (o render zera)")
            local tint, w = NOM_Rules.LOOKS.night.tint.value, nightWeight("tint")
            assert(near(env.color.final.ext[1], 0.33 + (tint[1] - 0.33) * w), "K=" .. K .. " tint exterior composto")
            assert(near(env.color.final.int[3], 0.4 + (tint[3] - 0.4) * w), "K=" .. K .. " tint interior composto")
            -- o alfa é a força da cor (blendIntensity): é ele que escurece
            assert(near(env.color.final.ext[4], 0.8 + (tint[4] - 0.8) * w), "K=" .. K .. " alfa não escrito")
        end
    end,

    -- (b) DarkIntensity muda o resultado, não só a velocidade
    look_dark_intensity_changes_final_value = function()
        local finals = {}
        for _, I in ipairs({ 0.5, 1, 2 }) do
            local env = setup({ tod = 23, K = 150, sandbox = { DarkIntensity = I } })
            env.run(40)
            finals[#finals + 1] = -env.floats[9].final
        end
        assert(finals[1] < finals[2] - 0.01 and finals[2] < finals[3] - 0.01,
            string.format("finais iguais: %.3f %.3f %.3f", finals[1], finals[2], finals[3]))
    end,



    -- transição em minutos de jogo: 20 ticks de clima, seja qual for o tempo real
    look_transition_takes_twenty_game_minutes = function()
        local env = setup({ tod = 23, K = 10 })
        local full = 0.5 * (1 - nightWeight("ambient"))
        env.run(19)
        assert(env.floats[9].final > full + 1e-4, "cheio antes de 20 minutos de jogo")
        env.run(1)
        assert(near(env.floats[9].final, full), "não chegou cheio em 20 minutos de jogo")
    end,


    -- (e) desligar no sandbox desce em rampa e desliga a camada uma vez só
    look_toggle_off_ramps_down_then_disables_once = function()
        local env = setup({ tod = 23, K = 10 })
        env.run(40)
        local full = env.floats[9].final
        SandboxVars.NevoaEOutroMundo.DarkEnabled = false
        env.run(1)
        local mid = env.floats[9].final
        assert(mid > full + 1e-4 and mid < 0.5 - 1e-4, string.format("sem rampa: %.4f (cheio %.4f)", mid, full))
        env.run(40)
        assert(near(env.floats[9].final, 0.5), "não voltou ao vanilla")
        assert(count(env.calls, "f9:on") == 1, "liga uma vez só")
        assert(count(env.calls, "f9:off") == 1, "desliga uma vez só")
        assert(count(env.calls, "tint:off") == 1)
        assert(count(env.calls, "f5:on") == 1 and count(env.calls, "f5:off") == 0, "canal de névoa: liga uma vez e fica")
    end,

    -- DarkIntensity 0 à noite: peso zero em todo canal, nenhuma escrita
    look_intensity_zero_touches_nothing = function()
        local env = setup({ tod = 23, K = 10, sandbox = { DarkIntensity = 0 } })
        env.run(40)
        assert(#notFog(env.calls) == 0, "escreveu com intensidade 0: " .. table.concat(env.calls, ","))
    end,
    -- (f) cliente de MP nunca escreve no clima: o visual vem do servidor
    look_mp_client_writes_nothing = function()
        local env = setup({ tod = 23, K = 10, client = true })
        env.run(40)
        assert(#env.calls == 0, "cliente escreveu no clima: " .. table.concat(env.calls, ","))
        assert(env.floats[5].isModded == false, "cliente mexeu na névoa")
        assert(near(env.floats[0].final, 0.2), "cliente mexeu na dessaturação")
    end,


    -- log de -debug pra conferir no console.txt se o valor chega no jogo: na borda
    -- da rampa e uma vez por hora de jogo à noite, um bloco com vanilla, escrito e
    -- final de cada canal
    look_debug_log_on_edges_and_hourly = function()
        local lines, orig = {}, print
        print = function(msg) lines[#lines + 1] = msg end
        local ok, err = pcall(function()
            local env = setup({ tod = 23.5, K = 3, debug = true })
            local function blocks()
                local n = 0
                for _, l in ipairs(lines) do if l:find("[NOM] clima tint", 1, true) then n = n + 1 end end
                return n
            end
            local function advance() env.world.tod = (env.world.tod + 1 / 60) % 24 end
            env.run(19, advance)
            assert(blocks() == 0, "logou antes da borda")
            env.run(1, advance)
            assert(blocks() == 1, "borda da rampa sem bloco: " .. blocks())
            env.run(9, advance) -- 23:59, mesma hora
            assert(blocks() == 1, "logou todo minuto")
            env.run(3, advance) -- passou da meia-noite
            assert(blocks() == 2, "hora nova sem bloco: " .. blocks())
            local amb
            for _, l in ipairs(lines) do if l:find("[NOM] clima ambient", 1, true) then amb = l end end
            assert(amb and amb:find("vanilla=0.50", 1, true) and amb:find("escrito=", 1, true) and amb:find("final=", 1, true),
                "linha do ambient: " .. tostring(amb))
            local tint
            for _, l in ipairs(lines) do if l:find("[NOM] clima tint", 1, true) then tint = l end end
            assert(tint:find("vanilla=0.33,0.33,0.33,0.80", 1, true) and tint:find("luz=", 1, true), "linha do tint: " .. tint)
            local cor
            for _, l in ipairs(lines) do if l:find("[NOM] clima corNevoa", 1, true) then cor = l end end
            assert(cor and cor:find("final=0.90,0.90,0.95,1.00", 1, true), "linha da cor da névoa: " .. tostring(cor))
        end)
        print = orig
        assert(ok, err)
    end,
    look_debug_log_silent_without_debug = function()
        local n, orig = 0, print
        print = function() n = n + 1 end
        local ok, err = pcall(function()
            local env = setup({ tod = 23.5, K = 3 })
            env.run(90, function() env.world.tod = (env.world.tod + 1 / 60) % 24 end)
        end)
        print = orig
        assert(ok, err)
        assert(n == 0, "imprimiu sem -debug: " .. n)
    end,

    -- (d) dia sem evento: só o canal de névoa, ligado uma vez, em 0
    look_idle_day_touches_only_fog = function()
        local env = setup({ tod = 12, K = 10 })
        env.run(50)
        assert(#notFog(env.calls) == 0, "mexeu no clima de dia sem efeito: " .. table.concat(env.calls, ","))
        assert(count(env.calls, "f5:on") == 1, "névoa: " .. table.concat(env.calls, ","))
        assert(env.floats[5].final == 0)
    end,

    -- névoa natural do jogo não existe (Johan, 05/10): final 0 fora do evento, com
    -- o look ligado ou desligado
    look_fog_zero_outside_event = function()
        for _, enabled in ipairs({ true, false }) do
            local env = setup({ tod = 7, fog = 0.9, K = 10, sandbox = { DarkEnabled = enabled } })
            env.run(1)
            assert(env.floats[5].final == 0, "névoa natural passou no 1º minuto: " .. env.floats[5].final)
            env.run(30, function() env.world.fog = math.random() end)
            assert(env.floats[5].final == 0 and NOM_World.fog == false, "névoa natural passou")
        end
    end,
    -- chuva/tempestade (WeatherPeriod) religa o override todo minuto, inclusive
    -- com névoa de estágio (setOverride(fogStrength, t)): final continua 0
    look_fog_zero_under_weather_period_override = function()
        local env = setup({ tod = 12, fog = 0.4, K = 10 })
        env.weather = { fog = 0.8, t = 0.7 }
        env.run(30)
        assert(env.floats[5].final == 0, "névoa do WeatherPeriod: " .. env.floats[5].final)
        env.weather = { fog = 0, t = 0.5 }
        env.run(5)
        assert(env.floats[5].final == 0)
    end,
    -- FogCycle (névoa eterna, sem névoa) e nevasca eterna: override de valor; fora
    -- do evento, final 0
    look_fog_zero_under_fog_cycle_override = function()
        for _, sb in ipairs({ { fogCycle = 4 }, { fogCycle = 3 }, { fogCycle = 2 }, { climateCycle = 6 } }) do
            local env = setup({ tod = 12, fog = 0.3, K = 10, fogCycle = sb.fogCycle, climateCycle = sb.climateCycle })
            env.run(130)
            assert(env.floats[5].final == 0, "FogCycle " .. tostring(sb.fogCycle) .. ": " .. env.floats[5].final)
        end
    end,
    -- evento: a névoa sobe até DENSITY em 20 minutos de jogo e desce em 20; vale com
    -- o look desligado (a névoa é o evento, não o look)
    look_event_fog_ramps_in_and_out = function()
        local env = setup({ tod = 12, fog = 0, K = 10, sandbox = { DarkEnabled = false } })
        env.run(5)
        NOM_World.setFog(true)
        env.run(10)
        local mid = env.floats[5].final
        assert(mid > 0 and mid < DENSITY, "sem rampa: " .. mid)
        env.run(10)
        assert(near(env.floats[5].final, DENSITY), "não chegou cheia: " .. env.floats[5].final)
        env.run(30)
        assert(near(env.floats[5].final, DENSITY), "composta: " .. env.floats[5].final)
        NOM_World.setFog(false)
        env.run(19)
        assert(env.floats[5].final > 0, "cortou seco")
        env.run(1)
        assert(env.floats[5].final == 0, "não voltou a 0")
    end,
    -- com chuva, FogCycle "sem névoa" ou névoa eterna, a do evento é a que fica
    look_event_fog_wins_over_overrides = function()
        for _, sb in ipairs({ { fogCycle = 2 }, { fogCycle = 4 }, { climateCycle = 6 }, { weather = true } }) do
            local env = setup({ tod = 12, fog = 0.9, K = 10, fogCycle = sb.fogCycle, climateCycle = sb.climateCycle })
            if sb.weather then env.weather = { fog = 0, t = 1 } end
            NOM_World.setFog(true)
            env.run(80)
            assert(near(env.floats[5].final, DENSITY), "override venceu o evento: " .. env.floats[5].final)
        end
    end,
    -- admin (painel de clima) passa por cima de tudo, e o mod não briga
    look_admin_fog_still_wins = function()
        local env = setup({ tod = 12, K = 10 })
        env.floats[5].admin = 0.3
        env.run(5)
        assert(env.floats[5].final == 0.3)
        NOM_World.setFog(true)
        env.run(25)
        assert(env.floats[5].final == 0.3)
    end,
    -- névoa vermelha (sprint 0010): luz puxada pro LOOKS.redFog e névoa pintada de
    -- vermelho, valor absoluto, sem acumular por mais frames que rodem
    look_red_fog_tints_without_compounding = function()
        for _, K in ipairs({ 1, 10, 150 }) do
            local env = setup({ tod = 12, K = K })
            NOM_World.setFog(true, true)
            env.run(40)
            local look = NOM_Rules.mix(0, 1, 1, 1)
            local t, w = look.tint.value, look.tint.weight
            assert(near(env.color.final.ext[1], 0.33 + (t[1] - 0.33) * w), "K=" .. K .. " luz vermelha composta")
            assert(near(env.color.final.ext[2], 0.33 + (t[2] - 0.33) * w))
            assert(env.color.final.ext[1] > env.color.final.ext[2] + 0.1, "luz não ficou vermelha")
            assert(sameColor(env.fogColor.final.ext, NOM_Rules.RED_FOG_COLOR), "K=" .. K .. " névoa " .. fmtColor(env.fogColor.final.ext))
            assert(sameColor(env.fogColor.final.int, NOM_Rules.RED_FOG_COLOR), "interior da névoa")
            env.run(30)
            assert(sameColor(env.fogColor.final.ext, NOM_Rules.RED_FOG_COLOR), "K=" .. K .. " névoa composta")
        end
    end,
    -- a cor da névoa entra e sai em rampa de 20 minutos de jogo, como a densidade
    look_red_fog_color_ramps = function()
        local env = setup({ tod = 12, K = 10 })
        NOM_World.setFog(true, true)
        env.run(10)
        local mid = env.fogColor.final.ext
        assert(mid[2] < 0.9 - 1e-3 and mid[2] > NOM_Rules.RED_FOG_COLOR[2] + 1e-3, "sem rampa: " .. fmtColor(mid))
    end,
    -- o interno da cor da névoa não volta sozinho: ao fim o mod escreve o vanilla e
    -- só depois desliga a camada; o próximo evento normal vem branco
    look_red_fog_color_restored_after = function()
        local env = setup({ tod = 12, K = 10 })
        NOM_World.setFog(true, true)
        env.run(40)
        NOM_World.setFog(false)
        env.run(40)
        assert(sameColor(env.fogColor.final.ext, NOM_Rules.FOG_COLOR), "ficou vermelha: " .. fmtColor(env.fogColor.final.ext))
        assert(sameColor(env.fogColor.internal.ext, NOM_Rules.FOG_COLOR), "interno sujo")
        assert(env.fogColor.isModded == false, "camada da cor ficou ligada")
        assert(count(env.calls, "fogColor:on") == 1 and count(env.calls, "fogColor:off") == 1)
        NOM_World.setFog(true)
        env.run(40)
        assert(sameColor(env.fogColor.final.ext, NOM_Rules.FOG_COLOR), "névoa normal vermelha")
    end,
    -- tempestade com névoa religa o override da cor todo minuto: na vermelha, o mod
    -- desliga; fora dela, a tempestade pinta como sempre
    look_red_fog_color_wins_storm_override = function()
        local storm = { 0.5, 0.45, 0.4, 1 }
        local env = setup({ tod = 12, K = 10 })
        env.storm = storm
        NOM_World.setFog(true, true)
        env.run(40)
        assert(sameColor(env.fogColor.final.ext, NOM_Rules.RED_FOG_COLOR), "tempestade venceu: " .. fmtColor(env.fogColor.final.ext))
        NOM_World.setFog(true, false)
        env.run(40)
        assert(not sameColor(env.fogColor.final.ext, NOM_Rules.RED_FOG_COLOR), "vermelho depois do fim")
        assert(env.fogColor.final.ext[2] > env.fogColor.final.ext[1] - 0.2, "resto de vermelho")
    end,
    -- névoa normal e dia sem evento: a cor da névoa nunca é tocada
    look_normal_fog_touches_no_fog_color = function()
        local env = setup({ tod = 12, K = 10 })
        env.run(10)
        NOM_World.setFog(true)
        env.run(40)
        NOM_World.setFog(false)
        env.run(40)
        for _, c in ipairs(env.calls) do assert(c:sub(1, 8) ~= "fogColor", "mexeu na cor: " .. c) end
    end,
    -- a cor da névoa é do evento (como a densidade): vale com o look desligado
    look_red_fog_color_without_dark = function()
        local env = setup({ tod = 12, K = 10, sandbox = { DarkEnabled = false } })
        NOM_World.setFog(true, true)
        env.run(40)
        assert(sameColor(env.fogColor.final.ext, NOM_Rules.RED_FOG_COLOR))
        assert(near(env.color.final.ext[1], 0.33), "luz pintada com o look desligado")
    end,
}
