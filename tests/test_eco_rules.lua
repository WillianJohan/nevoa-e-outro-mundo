require "NOM_EcoRules"

local function cand(dist2, extra)
    local c = { dist2 = dist2, animal = false, released = false, eco = false }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

return {
    -- bit 31 = sexo, bits 16-30 = índice do outfit, bits 0-15 = semente (bytecode PersistentOutfits)
    rules_key_ignores_seed = function()
        assert(NOM_EcoRules.outfitKey(7 * 65536 + 1) == NOM_EcoRules.outfitKey(7 * 65536 + 499))
    end,
    rules_key_separates_index_and_sex = function()
        local male = 7 * 65536 + 123
        local female = 7 * 65536 + 5 - 2147483648 -- int com sinal, bit 31 ligado
        assert(NOM_EcoRules.outfitKey(male) ~= NOM_EcoRules.outfitKey(female))
        assert(NOM_EcoRules.outfitKey(male) ~= NOM_EcoRules.outfitKey(8 * 65536 + 123))
    end,
    -- 0 = "outfit não existe" (pickOutfit devolve 0): nunca vira chave
    rules_key_zero_is_nil = function()
        assert(NOM_EcoRules.outfitKey(0) == nil)
        assert(NOM_EcoRules.outfitKey(nil) == nil)
    end,

    rules_pick_nearest_first_up_to_quota = function()
        local cands = {}
        for i = 60, 1, -1 do cands[#cands + 1] = cand(i) end
        local got = NOM_EcoRules.pick(cands, 40, 30)
        assert(#got == 30, "pegou " .. #got)
        for i = 1, 30 do assert(got[i].dist2 == i, "ordem errada em " .. i) end
    end,
    rules_pick_filters_animal_released_and_eco_corpse = function()
        local got = NOM_EcoRules.pick({
            cand(1, { animal = true }),
            cand(2, { released = true }),
            cand(3, { eco = true }),
            cand(4),
        }, 40, 30)
        assert(#got == 1 and got[1].dist2 == 4)
    end,
    -- raio é círculo: o canto do quadrado varrido fica de fora
    rules_pick_respects_radius_circle = function()
        local got = NOM_EcoRules.pick({ cand(40 * 40), cand(40 * 40 * 2) }, 40, 30)
        assert(#got == 1 and got[1].dist2 == 1600)
    end,
    rules_pick_zero_quota_is_empty = function()
        assert(#NOM_EcoRules.pick({ cand(1) }, 40, 0) == 0)
    end,
    rules_quota_never_negative = function()
        assert(NOM_EcoRules.quota(30, 45) == 0)
        assert(NOM_EcoRules.quota(30, 12) == 18)
    end,
}
