require "NOM_VariantRules"

local R = NOM_VariantRules

local function cfg(o)
    local c = { estaladorOn = true, corredorOn = true, estaladorChance = 5, corredorChance = 10 }
    for k, v in pairs(o or {}) do c[k] = v end
    return c
end

-- persistentOutfitID como o jogo monta (PersistentOutfits.pickOutfitMale):
-- bit 31 = feminino (int com sinal: negativo), índice << 16, semente 1..500
local function outfitID(index, seed, female)
    local id = index * 65536 + seed
    if female then id = id - 2147483648 end
    return id
end

local function realIDs()
    local out = {}
    for index = 1, 20 do
        for seed = 1, 500 do
            out[#out + 1] = outfitID(index, seed, false)
            out[#out + 1] = outfitID(index, seed, true)
        end
    end
    return out
end

local function count(ids, night, c)
    local n = { estalador = 0, corredor = 0 }
    for _, id in ipairs(ids) do
        local v = R.variant(id, night, c)
        if v then n[v] = n[v] + 1 end
    end
    return n
end

return {
    -- servidor e clientes calculam sozinhos: mesma entrada, mesma resposta
    variant_rules_deterministic = function()
        for _, id in ipairs({ outfitID(3, 17, false), outfitID(250, 499, true), 1 }) do
            for night = 1, 5 do
                assert(R.variant(id, night, cfg()) == R.variant(id, night, cfg()))
            end
        end
    end,
    -- antes da 1ª leitura do clima (ou do nightState no cliente) não há noite: sem variante
    variant_rules_needs_night_number = function()
        local c = cfg({ estaladorChance = 100 })
        assert(R.variant(outfitID(3, 17), nil, c) == nil)
        assert(R.variant(0, 3, c) == nil, "ID 0 (sem outfit) virou variante")
        assert(R.variant(nil, 3, c) == nil)
        assert(R.variant(outfitID(3, 17, true), 3, c) == "estalador", "ID feminino (negativo) falhou")
    end,
    variant_rules_chance_bounds_and_toggles = function()
        local ids = realIDs()
        local none = count(ids, 4, cfg({ estaladorChance = 0, corredorChance = 0 }))
        assert(none.estalador == 0 and none.corredor == 0)
        local all = count(ids, 4, cfg({ estaladorChance = 100 }))
        assert(all.estalador == #ids)
        local off = count(ids, 4, cfg({ estaladorOn = false, corredorChance = 100 }))
        assert(off.estalador == 0 and off.corredor == #ids, "toggle desligado ainda sorteou")
        local both = count(ids, 4, cfg({ estaladorChance = 70, corredorChance = 70 }))
        assert(both.estalador + both.corredor == #ids, "soma > 100 deixou zumbi comum")
    end,
    -- a taxa bate com o sandbox nos IDs que o jogo gera de fato
    variant_rules_rate_matches_chance = function()
        local ids = realIDs()
        for night = 1, 3 do
            local n = count(ids, night, cfg())
            local e, c = n.estalador / #ids * 100, n.corredor / #ids * 100
            assert(math.abs(e - 5) < 1.5, "Estalador " .. e .. "%")
            assert(math.abs(c - 10) < 1.5, "Corredor " .. c .. "%")
        end
    end,
    -- padrão do pedido do Johan (05/10): ~15% de cada, ~30% da noite (Estalador e
    -- Corredor no mesmo sorteio, faixas contíguas), Sem-rosto ~15% da névoa
    variant_rules_default_chances = function()
        require "NOM_Config"
        SandboxVars = nil
        local ids = realIDs()
        local c = R.config(NOM_Config.get)
        local s = R.semRostoConfig(NOM_Config.get)
        for night = 1, 3 do
            local n = count(ids, night, c)
            local e, k = n.estalador / #ids * 100, n.corredor / #ids * 100
            assert(math.abs(e - 15) < 1.5 and math.abs(k - 15) < 1.5, string.format("E %.1f%% C %.1f%%", e, k))
            assert(math.abs(e + k - 30) < 2, "total " .. (e + k))
            local sr = 0
            for _, id in ipairs(ids) do if R.semRosto(id, night, s) then sr = sr + 1 end end
            assert(math.abs(sr / #ids * 100 - 15) < 1.5, "Sem-rosto " .. sr / #ids * 100)
        end
    end,
    -- "uma vez por noite": a noite seguinte é outro sorteio
    variant_rules_rerolls_each_night = function()
        local ids, kept, total = realIDs(), 0, 0
        for _, id in ipairs(ids) do
            if R.variant(id, 7, cfg()) == "estalador" then
                total = total + 1
                if R.variant(id, 8, cfg()) == "estalador" then kept = kept + 1 end
            end
        end
        assert(total > 0 and kept / total < 0.5, "Estaladores repetidos de uma noite pra outra: " .. kept .. "/" .. total)
    end,
    -- noites independentes: P(variante em N e em N+1) ≈ p², não mais
    variant_rules_nights_independent = function()
        local ids = realIDs()
        for _, night in ipairs({ 1, 7, 30 }) do
            local first, both = 0, 0
            for _, id in ipairs(ids) do
                if R.variant(id, night, cfg()) then
                    first = first + 1
                    if R.variant(id, night + 1, cfg()) then both = both + 1 end
                end
            end
            local p, joint = first / #ids, both / #ids
            assert(math.abs(joint - p * p) < 0.006, string.format("noite %d: P(as duas)=%.4f, p²=%.4f", night, joint, p * p))
        end
    end,
    variant_rules_config_reads_sandbox = function()
        local vals = { EstaladorEnabled = false, CorredorEnabled = true, EstaladorChance = 7, CorredorChance = 9 }
        local c = R.config(function(k) return vals[k] end)
        assert(c.estaladorOn == false and c.corredorOn == true and c.estaladorChance == 7 and c.corredorChance == 9)
    end,
    variant_rules_scream_cooldown = function()
        assert(R.screamReady(nil, 10))
        assert(not R.screamReady(10, 10 + R.SCREAM_COOLDOWN_HOURS - 0.01))
        assert(R.screamReady(10, 10 + R.SCREAM_COOLDOWN_HOURS))
    end,
    -- Sem-rosto: sorteio por período de névoa, mesma conta determinística
    semrosto_rules_deterministic_and_needs_period = function()
        local c = { semRostoOn = true, semRostoChance = 100 }
        assert(R.semRosto(outfitID(3, 17), 2, c) == true)
        assert(R.semRosto(outfitID(3, 17, true), 2, c) == true, "ID feminino (negativo) falhou")
        assert(R.semRosto(outfitID(3, 17), nil, c) == false, "sem período virou Sem-rosto")
        assert(R.semRosto(0, 2, c) == false, "ID 0 virou Sem-rosto")
        assert(R.semRosto(outfitID(3, 17), 2, { semRostoOn = false, semRostoChance = 100 }) == false)
        assert(R.semRosto(outfitID(3, 17), 2, { semRostoOn = true, semRostoChance = 0 }) == false)
    end,
    semrosto_rules_rate_matches_chance = function()
        local ids = realIDs()
        for period = 1, 3 do
            local n = 0
            for _, id in ipairs(ids) do
                if R.semRosto(id, period, { semRostoOn = true, semRostoChance = 5 }) then n = n + 1 end
            end
            assert(math.abs(n / #ids * 100 - 5) < 1.5, "Sem-rosto " .. (n / #ids * 100) .. "%")
        end
    end,
    -- noite e névoa juntas: ser Estalador não muda a chance de ser Sem-rosto,
    -- mesmo quando o número da noite e o da névoa são iguais
    semrosto_rules_independent_of_night_variant = function()
        local ids = realIDs()
        local c = { semRostoOn = true, semRostoChance = 20 }
        for _, n in ipairs({ 1, 4 }) do
            local est, both, sem = 0, 0, 0
            for _, id in ipairs(ids) do
                local e = R.variant(id, n, cfg({ estaladorChance = 20, corredorChance = 0 })) == "estalador"
                local s = R.semRosto(id, n, c)
                if e then est = est + 1 end
                if s then sem = sem + 1 end
                if e and s then both = both + 1 end
            end
            local pe, ps = est / #ids, sem / #ids
            assert(math.abs(both / #ids - pe * ps) < 0.01, string.format("n=%d: P(as duas)=%.4f, pe*ps=%.4f", n, both / #ids, pe * ps))
        end
    end,
    semrosto_rules_config_reads_sandbox = function()
        local vals = { SemRostoEnabled = false, SemRostoChance = 12 }
        local c = R.semRostoConfig(function(k) return vals[k] end)
        assert(c.semRostoOn == false and c.semRostoChance == 12)
    end,
    -- forçado pelo NOM_Debug: vale contra chance e toggle, mas não sem noite/período
    variant_rules_forced_wins = function()
        local off = { estaladorOn = false, corredorOn = false, estaladorChance = 0, corredorChance = 0 }
        local soff = { semRostoOn = false, semRostoChance = 0 }
        R.forced[123] = "corredor"
        assert(R.variant(123, 1, off) == "corredor")
        assert(R.variant(123, nil, off) == nil, "noite desconhecida")
        R.forced[123] = "semrosto"
        assert(R.variant(123, 1, off) == nil)
        assert(R.semRosto(123, 1, soff) == true)
        assert(R.semRosto(123, nil, soff) == false, "período desconhecido")
        R.forced[123] = nil
        assert(R.semRosto(123, 1, soff) == false)
    end,
}
