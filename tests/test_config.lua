require "NOM_Config"

return {
    config_missing_sandboxvars_uses_default = function()
        SandboxVars = nil
        assert(NOM_Config.get("FogDailyChance") == 65)
        assert(NOM_Config.get("DarkEnabled") == true)
    end,
    config_missing_page_uses_default = function()
        SandboxVars = {}
        assert(NOM_Config.get("DarkIntensity") == 1.0)
    end,
    config_reads_sandbox_value = function()
        SandboxVars = { NevoaEOutroMundo = { FogDailyChance = 40 } }
        assert(NOM_Config.get("FogDailyChance") == 40)
    end,
    config_false_is_not_missing = function()
        SandboxVars = { NevoaEOutroMundo = { DarkEnabled = false } }
        assert(NOM_Config.get("DarkEnabled") == false)
    end,
    config_eco_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("EcoEnabled") == true)
        assert(NOM_Config.get("EcoMaxPerPlayer") == 20)
        assert(NOM_Config.get("EcoRadius") == 30)
    end,
    config_night_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("NightFaster") == true)
        assert(NOM_Config.get("NightSharperSenses") == true)
        assert(NOM_Config.get("NightHunt") == true)
        assert(NOM_Config.get("NightSpeedMult") == 1.5)
        assert(NOM_Config.get("NightSenseMult") == 1.5)
        assert(NOM_Config.get("HuntIntervalMinutes") == 90)
        assert(NOM_Config.get("HuntRadius") == 25)
    end,
    config_variant_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("EstaladorEnabled") == true)
        assert(NOM_Config.get("CorredorEnabled") == true)
        assert(NOM_Config.get("EstaladorChance") == 5)
        assert(NOM_Config.get("CorredorChance") == 3)
        assert(NOM_Config.get("CorredorScreamRadius") == 40)
    end,
    -- Carpideira (sprint 0011): chance 3 (decisão do Johan, 05/10), raios 4 e 50 (PO, sprint 0019)
    config_carpideira_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("CarpideiraEnabled") == true)
        assert(NOM_Config.get("CarpideiraChance") == 3)
        assert(NOM_Config.get("CarpideiraTriggerRadius") == 4)
        assert(NOM_Config.get("CarpideiraScreamRadius") == 50)
    end,
    -- névoa é evento (sprint 0009); balanceamento do PO (sprint 0019): base 2 dias, 3 a 6 horas; FogThreshold saiu
    config_red_fog_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("RedFogEnabled") == true)
        assert(NOM_Config.get("RedFogChance") == 20)
    end,
    config_fog_event_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.DEFAULTS.FogEventEveryDays == nil, "FogEventEveryDays ainda no Lua")
        assert(NOM_Config.get("FogDailyChance") == 65)
        assert(NOM_Config.get("FogMaxDailyChance") == 85)
        assert(NOM_Config.get("FogEscalationDays") == 60)
        assert(NOM_Config.get("FogSecondChance") == 15)
        assert(NOM_Config.get("FogMinGapHours") == 6)
        assert(NOM_Config.get("FogMaxDaysWithout") == 2)
        assert(NOM_Config.get("FogMinHours") == 3)
        assert(NOM_Config.get("FogMaxHours") == 5)
        assert(NOM_Config.get("RedFogMinHours") == 4)
        assert(NOM_Config.get("RedFogMaxHours") == 6)
        assert(NOM_Config.get("FogCalmHours") == 2)
        assert(NOM_Config.DEFAULTS.FogThreshold == nil, "FogThreshold ainda no Lua")
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        assert(not txt:find("FogThreshold", 1, true), "FogThreshold ainda no menu")
        assert(not txt:find("FogEventEveryDays", 1, true), "FogEventEveryDays ainda no menu")
    end,
    config_fog_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("SemRostoEnabled") == true)
        assert(NOM_Config.get("SemRostoChance") == 3)
        assert(NOM_Config.get("FogAmbience") == true)
        assert(NOM_Config.get("FogOverlays") == true)
        assert(NOM_Config.get("FogVignette") == true)
        assert(NOM_Config.get("FogVignetteIntensity") == 1.0)
    end,
    -- toda opção do sandbox tem default no Lua (as traduções: test_translations.lua)
    config_every_option_has_default = function()
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        local n = 0
        for name in txt:gmatch("option NevoaEOutroMundo%.(%w+)") do
            n = n + 1
            assert(NOM_Config.DEFAULTS[name] ~= nil, "sem default: " .. name)
        end
        assert(n >= 24, "esperava as opções da névoa, achou " .. n)
    end,
    -- o default do Lua (sem sandbox) e o do menu (sandbox-options.txt) são o mesmo número
    config_sandbox_defaults_match_lua = function()
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        local n = 0
        for name, body in txt:gmatch("option NevoaEOutroMundo%.(%w+)%s*=%s*(%b{})") do
            local v = body:match("default%s*=%s*([%d%.]+)")
            if v then
                n = n + 1
                assert(NOM_Config.DEFAULTS[name] == tonumber(v),
                    name .. ": Lua " .. tostring(NOM_Config.DEFAULTS[name]) .. ", menu " .. v)
            end
        end
        assert(n >= 10, "achou só " .. n .. " opções numéricas")
    end,
    -- curva de tensão (sprint 0019): escalada ligada, carência 7 dias (faixa 0–60)
    config_new_options_defaults = function()
        SandboxVars = nil
        assert(NOM_Config.get("FogEscalation") == true)
        assert(NOM_Config.get("RedFogGraceDays") == 7)
        local f = assert(io.open("mod/42/media/sandbox-options.txt"))
        local txt = f:read("*a")
        f:close()
        local esc = txt:match("option NevoaEOutroMundo%.FogEscalation = {(.-)}")
        assert(esc and esc:find("type = boolean", 1, true), "FogEscalation fora do menu")
        local grace = txt:match("option NevoaEOutroMundo%.RedFogGraceDays = {(.-)}")
        assert(grace and grace:match("min = (%d+)") == "0" and grace:match("max = (%d+)") == "60", "faixa da carência")
    end,
    -- sprint 0033: o tooltip da chance de vermelha avisa da carência (sem curva até o dobro)
    config_red_chance_tooltip_mentions_curve = function()
        for lang, words in pairs({ PTBR = { "carência" }, EN = { "grace" } }) do
            local f = assert(io.open("mod/42/media/lua/shared/Translate/" .. lang .. "/Sandbox.json"))
            local txt = f:read("*a")
            f:close()
            local tip = txt:match('"Sandbox_NevoaEOutroMundo%.RedFogChance_tooltip"%s*:%s*"([^"]*)"')
            for _, w in ipairs(words) do
                assert(tip and tip:find(w, 1, true), lang .. ": tooltip da chance sem '" .. w .. "'")
            end
        end
    end,
    -- tooltip do Eco (PO, sprint 0019): a mordida do Eco infecta como a de qualquer zumbi
    config_eco_tooltip_says_bite_infects = function()
        for lang, word in pairs({ PTBR = "mordida do Eco infecta", EN = "bite infects" }) do
            local f = assert(io.open("mod/42/media/lua/shared/Translate/" .. lang .. "/Sandbox.json"))
            local txt = f:read("*a")
            f:close()
            local tip = txt:match('"Sandbox_NevoaEOutroMundo%.EcoEnabled_tooltip"%s*:%s*"([^"]*)"')
            assert(tip and tip:find(word, 1, true), lang .. ": tooltip do Eco sem a mordida")
        end
    end,
    -- drone e rádio tocam em loop; o metal é um golpe só
    config_fog_sounds_loop = function()
        local f = assert(io.open("mod/42/media/scripts/NOM_sounds.txt"))
        local txt = f:read("*a")
        f:close()
        local function body(name) return txt:match("sound%s+" .. name .. "%s*(%b{})") end
        assert(body("NOM_FogDrone"):find("loop = true", 1, true), "drone sem loop")
        assert(body("NOM_RadioStatic"):find("loop = true", 1, true), "rádio sem loop")
        assert(not body("NOM_FogMetal"):find("loop", 1, true), "metal em loop")
        -- sirenes posicionais (sprint 0034): uma vez por evento, ouvidas de 40 a 200 tiles. O
        -- rolloff do FMOD atenua de distanceMin a distanceMax e não zera depois (pz-api-notes §23)
        for _, name in ipairs({ "NOM_Siren", "NOM_SirenRed", "NOM_SirenFar", "NOM_SirenRedFar" }) do
            local b = assert(body(name), "sirene sem declaração: " .. name)
            assert(not b:find("loop", 1, true), name .. " em loop (toca uma vez por evento)")
            assert(tonumber(b:match("distanceMin = (%d+)")) == 20, name .. ": distanceMin")
            assert(tonumber(b:match("distanceMax = (%d+)")) == 220, name .. ": distanceMax")
        end
        -- Carpideira: soluço em loop e baixo (perto); grito uma vez e de longe
        local sob, scream = body("NOM_CarpideiraSob"), body("NOM_CarpideiraScream")
        assert(sob and sob:find("loop = true", 1, true), "soluço sem loop")
        assert(tonumber(sob:match("distanceMax = (%d+)")) <= 15, "soluço alto demais")
        assert(not scream:find("loop", 1, true), "grito em loop")
        assert(tonumber(scream:match("distanceMax = (%d+)")) >= 100, "grito perto demais")
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
        assert(n >= 5, "sons declarados: " .. n)
        for _, name in ipairs({ "NOM_EstaladorClick", "NOM_CorredorScream", "NOM_FogDrone", "NOM_FogMetal", "NOM_RadioStatic", "NOM_Siren", "NOM_SirenRed",
        "NOM_SirenFar", "NOM_SirenRedFar", "NOM_CarpideiraSob", "NOM_CarpideiraScream" }) do
            assert(declared[name], "som usado no Lua sem declaração: " .. name)
        end
    end,
}
