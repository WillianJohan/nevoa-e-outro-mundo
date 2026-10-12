-- Regras puras do Tição (sprint 0038).
require "NOM_TicaoRules"

local R = NOM_TicaoRules

return {
    -- metade arrastado, metade arrastado rápido; o mesmo zumbi no mesmo período dá sempre o
    -- mesmo, o chapéu caído não muda; nunca corredor
    ticao_rules_speed_half_and_half = function()
        local n = { [2] = 0, [3] = 0 }
        for index = 1, 10 do
            for seed = 1, 100 do
                local id = index * 65536 + seed
                local s = R.speed(id, 4)
                assert(s == 2 or s == 3, "velocidade " .. tostring(s))
                assert(R.speed(id, 4) == s and R.speed(id + 32768, 4) == s, "não determinístico")
                n[s] = n[s] + 1
            end
        end
        assert(n[2] > 400 and n[3] > 400, n[2] .. "/" .. n[3])
    end,
    -- outro período, outro sorteio (não é o mesmo zumbi sempre rápido)
    ticao_rules_speed_changes_with_period = function()
        local diff = 0
        for seed = 1, 200 do
            if R.speed(65536 + seed, 1) ~= R.speed(65536 + seed, 2) then diff = diff + 1 end
        end
        assert(diff > 60 and diff < 140, "períodos correlacionados: " .. diff)
    end,
    -- caça mais forte que a da noite (padrão 90 min, 25 tiles) e visão curta menor que a da névoa
    ticao_rules_hunt_and_vision = function()
        require "NOM_Config"
        SandboxVars = nil
        assert(R.huntMinutes() < NOM_Config.DEFAULTS.HuntIntervalMinutes and R.huntReach() > NOM_Config.DEFAULTS.HuntRadius)
        assert(R.VISION_TILES < NOM_Config.DEFAULTS.FogZombieVision)
    end,
    -- Pesadelo: mais arrastado rápido que o Padrão; nunca corredor
    ticao_rules_pesadelo_more_fast = function()
        require "NOM_Config"
        SandboxVars = { NevoaEOutroMundo = { BlackFogPressure = 2 } }
        local n2 = 0
        for seed = 1, 400 do
            if R.speed(65536 + seed, 4) == R.FAST_SHAMBLER then n2 = n2 + 1 end
        end
        SandboxVars = { NevoaEOutroMundo = { BlackFogPressure = 3 } }
        local n3 = 0
        for seed = 1, 400 do
            if R.speed(65536 + seed, 4) == R.FAST_SHAMBLER then n3 = n3 + 1 end
        end
        assert(n3 > n2 + 40, "Pesadelo não acelerou: " .. n2 .. " -> " .. n3)
        SandboxVars = nil
    end,
}
