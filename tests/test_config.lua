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
    config_eco_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("EcoEnabled") == true)
        assert(NOM_Config.get("EcoMaxPerPlayer") == 30)
        assert(NOM_Config.get("EcoRadius") == 40)
    end,
    -- toda opção do sandbox tem default no Lua e rótulo + tooltip nas duas línguas
    config_every_option_has_default_and_translations = function()
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        local langs = {}
        for _, lang in ipairs({ "PTBR", "EN" }) do
            local j = assert(io.open("mod/42/media/lua/shared/Translate/" .. lang .. "/Sandbox.json"))
            langs[lang] = j:read("*a")
            j:close()
        end
        local n = 0
        for name in txt:gmatch("option NevoaEOutroMundo%.(%w+)") do
            n = n + 1
            assert(NOM_Config.DEFAULTS[name] ~= nil, "sem default: " .. name)
            for lang, json in pairs(langs) do
                local key = '"Sandbox_NevoaEOutroMundo.' .. name
                assert(json:find(key .. '"', 1, true), lang .. " sem rótulo: " .. name)
                assert(json:find(key .. '_tooltip"', 1, true), lang .. " sem tooltip: " .. name)
            end
        end
        assert(n >= 6, "esperava as opções do Eco, achou " .. n)
    end,
    -- varredura é (2r+1)² squares por jogador: 60 é o teto de custo aceito
    config_eco_radius_max_is_60 = function()
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        local block = txt:match("option NevoaEOutroMundo%.EcoRadius = {(.-)}")
        assert(block and block:match("max = (%d+)") == "60", "max do EcoRadius")
    end,
}
