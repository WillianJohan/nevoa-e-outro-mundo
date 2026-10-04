require "NOM_NightRules"

local function cfg(o)
    local c = { fasterOn = true, sensesOn = true, speedMult = 1.5, senseMult = 1.5, sight = 2, hearing = 2 }
    for k, v in pairs(o or {}) do c[k] = v end
    return c
end

return {
    -- degraus do jogo: 1.0 não muda, 1.5 sobe um, 2.5 sobe dois
    night_rules_steps = function()
        local R = NOM_NightRules
        assert(R.steps(1.0) == 0 and R.steps(1.49) == 0)
        assert(R.steps(1.5) == 1 and R.steps(2.49) == 1)
        assert(R.steps(2.5) == 2 and R.steps(3.0) == 2)
        assert(R.steps(0.5) == 0 and R.steps(nil) == 0)
    end,
    -- 1 é o melhor degrau (corredor, águia, apurado)
    night_rules_sharpen_clamps = function()
        assert(NOM_NightRules.sharpen(3, 1) == 2)
        assert(NOM_NightRules.sharpen(2, 2) == 1)
        assert(NOM_NightRules.sharpen(1, 1) == 1)
    end,
    -- sandbox 4/5 são sorteios no jogo: a base vira normal
    night_rules_base_sense_random_is_normal = function()
        assert(NOM_NightRules.baseSense(1) == 1 and NOM_NightRules.baseSense(3) == 3)
        assert(NOM_NightRules.baseSense(4) == 2 and NOM_NightRules.baseSense(5) == 2)
    end,
    -- velocidade fixa no sandbox vale pra todos; aleatória (4) usa a do zumbi
    night_rules_day_tier = function()
        assert(NOM_NightRules.dayTier(2, 1) == 2)
        assert(NOM_NightRules.dayTier(4, 3) == 3)
    end,
    night_rules_wanted_day = function()
        local w = NOM_NightRules.wanted(false, false, 2, cfg())
        assert(w.key == "day" and w.speed == 2 and w.sight == nil and w.hearing == nil)
    end,
    night_rules_wanted_night_default = function()
        local w = NOM_NightRules.wanted(true, false, 2, cfg())
        assert(w.speed == 1 and w.sight == 1 and w.hearing == 1 and w.key ~= "day")
    end,
    night_rules_wanted_eco_slow_and_unboosted = function()
        local w = NOM_NightRules.wanted(true, true, 1, cfg({ speedMult = 3 }))
        assert(w.speed == NOM_NightRules.ECO_SPEED and w.speed == 3)
        assert(w.sight == nil and w.hearing == nil and w.key ~= "day")
        -- Eco de dia (antes de sumir) não é tocado
        assert(NOM_NightRules.wanted(false, true, 2, cfg()).key == "day")
    end,
    night_rules_wanted_toggles_off_is_day = function()
        local w = NOM_NightRules.wanted(true, false, 2, cfg({ fasterOn = false, sensesOn = false, speedMult = 3, senseMult = 3 }))
        assert(w.key == "day" and w.speed == 2 and w.sight == nil)
        -- multiplicador 1.0 também não muda nada
        assert(NOM_NightRules.wanted(true, false, 2, cfg({ speedMult = 1, senseMult = 1 })).key == "day")
    end,
    night_rules_wanted_only_senses = function()
        local w = NOM_NightRules.wanted(true, false, 2, cfg({ fasterOn = false, hearing = 3 }))
        assert(w.speed == 2 and w.sight == 1 and w.hearing == 2)
        local s = NOM_NightRules.wanted(true, false, 2, cfg({ sensesOn = false }))
        assert(s.speed == 1 and s.sight == nil and s.hearing == nil)
        assert(w.key ~= s.key)
    end,
    night_rules_hunt_tick = function()
        local m, due = 0, false
        for _ = 1, 59 do
            m, due = NOM_NightRules.huntTick(m, 60)
            assert(not due)
        end
        m, due = NOM_NightRules.huntTick(m, 60)
        assert(due and m == 0)
    end,
    -- 20 = teto do raio de visão do zumbi (PZMath.clamp em updateVisionRadius)
    night_rules_torch_radius = function()
        assert(NOM_NightRules.torchRadius(1.5) == 30)
        assert(NOM_NightRules.torchRadius(1.0) == 20)
    end,
}
