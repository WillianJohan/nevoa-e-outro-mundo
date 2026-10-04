NOM_Config = {}

NOM_Config.DEFAULTS = {
    DarkEnabled = true,
    DarkIntensity = 1.0,
    FogThreshold = 0.5,
    EcoEnabled = true,
    EcoMaxPerPlayer = 30,
    EcoRadius = 40,
    NightFaster = true,
    NightSharperSenses = true,
    NightHunt = true,
    NightSpeedMult = 1.5,
    NightSenseMult = 1.5,
    HuntIntervalMinutes = 60,
    HuntRadius = 30,
}

function NOM_Config.get(key)
    local vars = SandboxVars and SandboxVars.NevoaEOutroMundo
    if vars and vars[key] ~= nil then
        return vars[key]
    end
    return NOM_Config.DEFAULTS[key]
end

return NOM_Config
