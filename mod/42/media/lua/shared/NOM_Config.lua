NOM_Config = {}

NOM_Config.DEFAULTS = {
    DarkEnabled = true,
    DarkIntensity = 1.0,
    FogDailyChance = 65,
    FogEscalation = true,
    FogMaxDailyChance = 85,
    FogEscalationDays = 60,
    FogSecondChance = 15,
    FogMinGapHours = 6,
    FogMaxDaysWithout = 2,
    FogMinHours = 3,
    FogMaxHours = 5,
    RedFogEnabled = true,
    RedFogChance = 20,
    RedFogGraceDays = 7,
    RedFogMinHours = 4,
    RedFogMaxHours = 6,
    BlackFogEnabled = true,
    BlackFogChance = 5,
    BlackFogGraceDays = 14,
    BlackFogMinHours = 2,
    BlackFogMaxHours = 3,
    FogCalmHours = 2,
    FogBaseHeight = 1.0,
    FogPocketAggression = 1.0,
    FogZombieVision = 4,
    FogWander = true,
    EcoEnabled = true,
    EcoMaxPerPlayer = 20,
    EcoRadius = 30,
    NightFaster = true,
    NightSharperSenses = true,
    NightHunt = true,
    NightSpeedMult = 1.5,
    NightSenseMult = 1.5,
    HuntIntervalMinutes = 90,
    HuntRadius = 25,
    EstaladorEnabled = true,
    CorredorEnabled = true,
    EstaladorChance = 5,
    CorredorChance = 3,
    CorredorScreamRadius = 40,
    SemRostoEnabled = true,
    SemRostoChance = 3,
    CarpideiraEnabled = true,
    CarpideiraChance = 3,
    CarpideiraTriggerRadius = 4,
    CarpideiraScreamRadius = 50,
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
