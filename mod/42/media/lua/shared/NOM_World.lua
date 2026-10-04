require "NOM_Rules"
require "NOM_Config"

-- Flags night/fog derivadas do clima vanilla.
NOM_World = { night = false, fog = false }

local listeners = {}

-- fn(flag, value) é chamada só na borda: flag "night" ou "fog".
function NOM_World.onChange(fn)
    listeners[#listeners + 1] = fn
end

local function notify(flag, was)
    if NOM_World[flag] == was then return end
    for _, fn in ipairs(listeners) do
        fn(flag, NOM_World[flag])
    end
end

-- fogIntensity: névoa vanilla limpa, sem a camada do mod (quem chama sabe ler).
function NOM_World.update(fogIntensity)
    local season = getClimateManager():getSeason()
    local wasNight, wasFog = NOM_World.night, NOM_World.fog
    NOM_World.tod = getGameTime():getTimeOfDay()
    NOM_World.dawn = season:getDawn()
    NOM_World.dusk = season:getDusk()
    NOM_World.fogIntensity = fogIntensity
    NOM_World.night = NOM_Rules.isNight(NOM_World.tod, NOM_World.dawn, NOM_World.dusk)
    NOM_World.fog = NOM_Rules.isFog(fogIntensity, NOM_Config.get("FogThreshold"), NOM_World.fog)
    notify("night", wasNight)
    notify("fog", wasFog)
    return NOM_World
end

return NOM_World
