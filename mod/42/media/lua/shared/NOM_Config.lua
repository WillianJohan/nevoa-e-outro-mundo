NOM_Config = {}

NOM_Config.DEFAULTS = {
    DarkEnabled = true,
    DarkIntensity = 1.0,
    FogThreshold = 0.5,
}

function NOM_Config.get(key)
    local vars = SandboxVars and SandboxVars.NevoaEOutroMundo
    if vars and vars[key] ~= nil then
        return vars[key]
    end
    return NOM_Config.DEFAULTS[key]
end

return NOM_Config
