require "NOM_Rules"
require "NOM_Config"

-- Flags night/fog derivadas do clima vanilla.
NOM_World = { night = false, fog = false }

-- fogIntensity: névoa vanilla limpa, sem a camada do mod (quem chama sabe ler).
function NOM_World.update(fogIntensity)
    local season = getClimateManager():getSeason()
    NOM_World.tod = getGameTime():getTimeOfDay()
    NOM_World.dawn = season:getDawn()
    NOM_World.dusk = season:getDusk()
    NOM_World.fogIntensity = fogIntensity
    NOM_World.night = NOM_Rules.isNight(NOM_World.tod, NOM_World.dawn, NOM_World.dusk)
    NOM_World.fog = NOM_Rules.isFog(fogIntensity, NOM_Config.get("FogThreshold"), NOM_World.fog)
    return NOM_World
end

return NOM_World
