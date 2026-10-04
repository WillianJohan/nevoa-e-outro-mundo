require "NOM_Config"

return {
    config_missing_sandboxvars_uses_default = function()
        SandboxVars = nil
        assert(NOM_Config.get("FogThreshold") == 0.5)
        assert(NOM_Config.get("DarkEnabled") == true)
    end,
    config_missing_page_uses_default = function()
        SandboxVars = {}
        assert(NOM_Config.get("DarkIntensity") == 1.0)
    end,
    config_reads_sandbox_value = function()
        SandboxVars = { NevoaEOutroMundo = { FogThreshold = 0.8 } }
        assert(NOM_Config.get("FogThreshold") == 0.8)
    end,
    config_false_is_not_missing = function()
        SandboxVars = { NevoaEOutroMundo = { DarkEnabled = false } }
        assert(NOM_Config.get("DarkEnabled") == false)
    end,
}
