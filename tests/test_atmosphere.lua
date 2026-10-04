-- NOM_Atmosphere contra um clima falso: conta as chamadas que ele faz no jogo.
local function setup(tod)
    local calls = {}
    local function channel(name)
        return {
            setEnableModded = function(_, on) calls[#calls + 1] = name .. (on and ":on" or ":off") end,
            setModdedValue = function() end,
            setModdedInterpolate = function() end,
        }
    end
    local floats, color = {}, channel("tint")
    local world = { tod = tod, fog = 0 }
    ClimateManager = { FLOAT_DESATURATION = 0, FLOAT_GLOBAL_LIGHT_INTENSITY = 1, FLOAT_FOG_INTENSITY = 5, COLOR_GLOBAL_LIGHT = 0 }
    ClimateColorInfo = { new = function() return { setExterior = function() end, setInterior = function() end } end }
    SandboxVars = nil
    local ms = 0
    getTimestampMs = function() ms = ms + 1000; return ms end
    local tick
    Events = { OnTick = { Add = function(f) tick = f end }, EveryOneMinute = { Add = function() end } }
    getDebug = function() return false end
    getGameTime = function() return { getTimeOfDay = function() return world.tod end } end
    getClimateManager = function()
        return {
            getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end,
            getFogIntensity = function() return world.fog end,
            getClimateFloat = function(_, id) floats[id] = floats[id] or channel("f" .. id); return floats[id] end,
            getClimateColor = function() return color end,
        }
    end
    NOM_World = nil
    package.loaded["NOM_World"] = nil
    dofile("mod/42/media/lua/client/NOM_Atmosphere.lua")
    return tick, calls, world
end

local function count(calls, entry)
    local n = 0
    for _, c in ipairs(calls) do if c == entry then n = n + 1 end end
    return n
end

return {
    atmosphere_idle_day_touches_nothing = function()
        local tick, calls = setup(12)
        for _ = 1, 50 do tick() end
        assert(#calls == 0, "chamou o clima de dia sem efeito: " .. table.concat(calls, ","))
    end,
    atmosphere_disables_once_after_night = function()
        local tick, calls, world = setup(23)
        for _ = 1, 40 do tick() end
        assert(count(calls, "f0:on") == 1, "liga uma vez só")
        world.tod = 12
        for _ = 1, 40 do tick() end
        assert(count(calls, "f0:off") == 1, "desliga uma vez só")
        assert(count(calls, "tint:off") == 1)
        assert(count(calls, "f5:on") == 0, "sem névoa, canal de névoa nunca liga")
    end,
}
