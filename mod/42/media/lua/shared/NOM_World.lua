require "NOM_Rules"

-- Flags night/fog do mundo. A noite vem do relógio (NOM_World.update, no
-- OnClimateTick do servidor); a névoa é um evento do mod (server/NOM_FogEvent.lua,
-- ADR-009), ligada por NOM_World.setFog.
-- red: a névoa aberta é vermelha (sprint 0010); sempre false sem névoa.
NOM_World = { night = false, fog = false, red = false }

-- Noite forçada pelo NOM_Debug (só em -debug, server/NOM_DebugServer.lua):
-- night = true/false; nil = do relógio. Só em memória. A névoa forçada é um
-- evento de verdade (NOM_FogEvent).
NOM_World.forced = {}

local listeners = {}

-- fn(flag, value) é chamada só na borda: flag "night", "fog" ou "red". A borda
-- "red" só sai com a névoa já aberta (debug): na borda "fog" o red já é o novo.
function NOM_World.onChange(fn)
    listeners[#listeners + 1] = fn
end

local function notify(flag, was)
    if NOM_World[flag] == was then return end
    for _, fn in ipairs(listeners) do
        fn(flag, NOM_World[flag])
    end
end

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

function NOM_World.setFog(on, red)
    local was, wasRed = NOM_World.fog, NOM_World.red
    NOM_World.fog = on == true
    NOM_World.red = NOM_World.fog and red == true
    notify("fog", was)
    if NOM_World.fog == was then notify("red", wasRed) end
end

return NOM_World
