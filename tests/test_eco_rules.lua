require "NOM_EcoRules"

-- corpo candidato: posição do square e se já soltou Eco
local function cand(x, y, extra)
    local c = { x = x, y = y, z = 0, released = false }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

return {
    rules_pick_nearest_first_up_to_quota = function()
        local cands = {}
        for i = 60, 1, -1 do cands[#cands + 1] = cand(i, 0) end
        local got = NOM_EcoRules.pick(cands, 0, 0, 0, 100, 30)
        assert(#got == 30, "pegou " .. #got)
        for i = 1, 30 do assert(got[i].x == i, "ordem errada em " .. i) end
    end,
    rules_pick_skips_released = function()
        local got = NOM_EcoRules.pick({ cand(1, 0, { released = true }), cand(2, 0) }, 0, 0, 0, 40, 30)
        assert(#got == 1 and got[1].x == 2)
    end,
    -- raio é círculo: o canto do quadrado varrido fica de fora
    rules_pick_respects_radius_circle = function()
        local got = NOM_EcoRules.pick({ cand(40, 0), cand(40, 40) }, 0, 0, 0, 40, 30)
        assert(#got == 1 and got[1].x == 40 and got[1].y == 0)
    end,
    -- só o andar do jogador
    rules_pick_same_floor_only = function()
        local got = NOM_EcoRules.pick({ cand(1, 0, { z = 1 }), cand(2, 0) }, 0, 0, 0, 40, 30)
        assert(#got == 1 and got[1].x == 2)
    end,
    rules_pick_zero_quota_is_empty = function()
        assert(#NOM_EcoRules.pick({ cand(1, 0) }, 0, 0, 0, 40, 0) == 0)
    end,
    rules_quota_never_negative = function()
        assert(NOM_EcoRules.quota(30, 45) == 0)
        assert(NOM_EcoRules.quota(30, 12) == 18)
    end,

    -- noite atual: conta noites pelo estado salvo, não pela borda (servidor que
    -- reinicia no meio da noite não pode abrir uma noite nova)
    rules_night_counts_once_per_night = function()
        local s = {}
        assert(NOM_EcoRules.syncNight(s, true) == 1)
        assert(NOM_EcoRules.syncNight(s, true) == 1, "mesma noite contou duas vezes")
        NOM_EcoRules.syncNight(s, false)
        assert(NOM_EcoRules.syncNight(s, true) == 2)
    end,
    -- Ecos de noites com mais de KEEP_NIGHTS noites saem da lista
    rules_prune_old_nights = function()
        local ids = { [10] = 1, [11] = 5, [12] = 9 }
        NOM_EcoRules.prune(ids, 9)
        assert(ids[10] == nil, "noite velha ficou")
        assert(ids[11] == 5 and ids[12] == 9)
    end,
    -- Eco recarregado: fica só se for da noite atual e ainda for noite
    rules_reloaded_eco_keeps_only_same_night = function()
        assert(NOM_EcoRules.keepReloaded(3, 3, true) == true)
        assert(NOM_EcoRules.keepReloaded(2, 3, true) == false)
        assert(NOM_EcoRules.keepReloaded(3, 3, false) == false)
    end,
}
