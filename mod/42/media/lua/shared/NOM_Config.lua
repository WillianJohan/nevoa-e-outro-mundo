NOM_Config = {}

NOM_Config.DEFAULTS = {
    DarkEnabled = true,
    DarkIntensity = 1.0,
    FogEventEveryDays = 3,
    FogMinHours = 2,
    FogMaxHours = 6,
    RedFogEnabled = true,
    RedFogChance = 10,
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
    EstaladorEnabled = true,
    CorredorEnabled = true,
    EstaladorChance = 5,
    CorredorChance = 2,
    CorredorScreamRadius = 40,
    SemRostoEnabled = true,
    SemRostoChance = 5,
    CarpideiraEnabled = true,
    CarpideiraChance = 3,
    CarpideiraTriggerRadius = 4,
    CarpideiraScreamRadius = 60,
    FogAmbience = true,
    FogOverlays = true,
    FogVignette = true,
    FogVignetteIntensity = 1.0,
}

function NOM_Config.get(key)
    local vars = SandboxVars and SandboxVars.NevoaEOutroMundo
    if vars and vars[key] ~= nil then
        return vars[key]
    end
    return NOM_Config.DEFAULTS[key]
end

return NOM_Config
