require "NOM_Rules"
require "NOM_Config"

-- Flags derivadas do clima, que o jogo já sincroniza entre servidor e clientes.
NOM_World = { night = false, fog = false }

function NOM_World.update()
    local clim = getClimateManager()
    local season = clim:getSeason()
    NOM_World.tod = getGameTime():getTimeOfDay()
    NOM_World.dawn = season:getDawn()
    NOM_World.dusk = season:getDusk()
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
