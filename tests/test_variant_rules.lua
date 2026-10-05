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
}
