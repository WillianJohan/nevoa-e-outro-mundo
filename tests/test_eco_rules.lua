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
    -- hora de mundo em que a noite abriu: o Eco só vem de quem morreu antes dela
    rules_sync_night_records_start = function()
        local s = {}
        NOM_EcoRules.syncNight(s, true, 100.5)
        assert(s.start == 100.5)
        NOM_EcoRules.syncNight(s, true, 101)
        assert(s.start == 100.5, "início andou no meio da noite")
        NOM_EcoRules.syncNight(s, false, 110)
        NOM_EcoRules.syncNight(s, true, 124.5)
        assert(s.start == 124.5)
    end,
    -- save de antes da sprint 0008 aberto de noite: sem início guardado, vale a carga
    rules_sync_night_migrates_open_night = function()
        local s = { night = 4, inNight = true }
        assert(NOM_EcoRules.syncNight(s, true, 130) == 4)
        assert(s.start == 130)
    end,
    rules_died_before_night = function()
        assert(NOM_EcoRules.diedBeforeNight(99, 100) == true)
        assert(NOM_EcoRules.diedBeforeNight(100.2, 100) == false)
        assert(NOM_EcoRules.diedBeforeNight(-1, 100) == true, "sem hora de morte = antigo")
        assert(NOM_EcoRules.diedBeforeNight(150, nil) == true, "início desconhecido não bloqueia")
    end,
    -- ids = { [id] = { [noite] = true } }: noites velhas saem, conjunto vazio sai
    rules_prune_old_nights = function()
        local ids = { [10] = { [1] = true }, [11] = { [1] = true, [5] = true }, [12] = { [9] = true } }
        NOM_EcoRules.prune(ids, 9)
        assert(ids[10] == nil, "conjunto vazio ficou")
        assert(ids[11][1] == nil and ids[11][5] == true, "noite velha ficou no gêmeo")
        assert(ids[12][9] == true)
    end,
    -- Eco recarregado: fica só se o ID tem a noite atual e ainda é noite
    rules_reloaded_eco_keeps_only_same_night = function()
        assert(NOM_EcoRules.keepReloaded({ [3] = true }, 3, true) == true)
        assert(NOM_EcoRules.keepReloaded({ [2] = true }, 3, true) == false)
        assert(NOM_EcoRules.keepReloaded({ [2] = true, [3] = true }, 3, true) == true)
        assert(NOM_EcoRules.keepReloaded({ [3] = true }, 3, false) == false)
        assert(NOM_EcoRules.keepReloaded(nil, 3, true) == false)
    end,
}
