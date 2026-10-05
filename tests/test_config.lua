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
    config_night_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("NightFaster") == true)
        assert(NOM_Config.get("NightSharperSenses") == true)
        assert(NOM_Config.get("NightHunt") == true)
        assert(NOM_Config.get("NightSpeedMult") == 1.5)
        assert(NOM_Config.get("NightSenseMult") == 1.5)
        assert(NOM_Config.get("HuntIntervalMinutes") == 60)
        assert(NOM_Config.get("HuntRadius") == 30)
    end,
    config_variant_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("EstaladorEnabled") == true)
        assert(NOM_Config.get("CorredorEnabled") == true)
        assert(NOM_Config.get("EstaladorChance") == 5)
        assert(NOM_Config.get("CorredorChance") == 10)
        assert(NOM_Config.get("CorredorScreamRadius") == 40)
    end,
    config_fog_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("SemRostoEnabled") == true)
        assert(NOM_Config.get("SemRostoChance") == 5)
        assert(NOM_Config.get("FogAmbience") == true)
        assert(NOM_Config.get("FogOverlays") == true)
        assert(NOM_Config.get("FogVignette") == true)
        assert(NOM_Config.get("FogVignetteIntensity") == 1.0)
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
        assert(n >= 24, "esperava as opções da névoa, achou " .. n)
    end,
    -- varredura é (2r+1)² squares por jogador: 60 é o teto de custo aceito
    config_eco_radius_max_is_60 = function()
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        local block = txt:match("option NevoaEOutroMundo%.EcoRadius = {(.-)}")
        assert(block and block:match("max = (%d+)") == "60", "max do EcoRadius")
    end,
    -- todo som tocado pelo Lua está declarado e aponta pra arquivo que existe no mod
    config_sound_scripts_point_to_files = function()
        local f = assert(io.open("mod/42/media/scripts/NOM_sounds.txt"))
        local txt = f:read("*a")
        f:close()
        local declared, n = {}, 0
        for name, body in txt:gmatch("sound%s+([%w_]+)%s*(%b{})") do
            declared[name] = true
            local file = body:match("file%s*=%s*([^,%s]+)")
            assert(file, "som sem arquivo: " .. name)
            local h = io.open("mod/42/" .. file, "rb")
            assert(h, "arquivo do som não existe: " .. file)
            assert(#h:read("*a") > 1000, "arquivo vazio: " .. file)
            h:close()
            n = n + 1
        end
        assert(n >= 2, "sons declarados: " .. n)
        for _, name in ipairs({ "NOM_EstaladorClick", "NOM_CorredorScream" }) do
            assert(declared[name], "som usado no Lua sem declaração: " .. name)
        end
    end,
}
