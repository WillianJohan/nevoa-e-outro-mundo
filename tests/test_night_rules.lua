require "NOM_NightRules"

local function cfg(o)
    local c = { fasterOn = true, sensesOn = true, speedMult = 1.5, senseMult = 1.5, sight = 2, hearing = 2 }
    for k, v in pairs(o or {}) do c[k] = v end
    return c
end

return {
    -- calmaria depois da névoa: o zumbi comum fica um degrau pior em tudo (sprint 0033)
    night_rules_calm_dulls_common = function()
        local R = NOM_NightRules
        local c = cfg()
        local w = R.wanted(false, nil, 2, c, true)
        assert(w.speed == 3 and w.sight == 3 and w.hearing == 3 and w.key == "c3,3,3")
        w = R.wanted(true, nil, 2, c, true)
        assert(w.speed == 3 and w.key == "c3,3,3", "calmaria vence a noite no comum")
        assert(R.wanted(false, nil, 3, c, true).speed == 3, "já arrastado fica arrastado")
        assert(R.wanted(true, "eco", 2, c, true).key == "eco", "Eco não sente a calmaria")
        assert(R.wanted(false, nil, 2, c, false).key == "day", "sem calmaria, dia normal")
        assert(R.wanted(false, nil, 2, c).key == "day", "calm nil = sem calmaria")
    end,
    night_rules_dull_clamps = function()
        assert(NOM_NightRules.dull(1, 1) == 2 and NOM_NightRules.dull(2, 1) == 3)
        assert(NOM_NightRules.dull(3, 1) == 3 and NOM_NightRules.dull(2, 5) == 3)
    end,
    -- calmaria parte da base do sandbox (1..3), não dos degraus da noite
    night_rules_calm_uses_sandbox_senses = function()
        local w = NOM_NightRules.wanted(false, nil, 1, cfg({ sight = 1, hearing = 3 }), true)
        assert(w.speed == 2 and w.sight == 2 and w.hearing == 3 and w.key == "c2,2,3")
        w = NOM_NightRules.wanted(false, nil, 2, cfg({ sight = 4, hearing = 5 }), true)
        assert(w.sight == 3 and w.hearing == 3, "sorteio por zumbi: base normal, um degrau abaixo")
    end,
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
        local w = NOM_NightRules.wanted(false, nil, 2, cfg())
        assert(w.key == "day" and w.speed == 2 and w.sight == nil and w.hearing == nil)
    end,
    night_rules_wanted_night_default = function()
        local w = NOM_NightRules.wanted(true, nil, 2, cfg())
        assert(w.speed == 1 and w.sight == 1 and w.hearing == 1 and w.key ~= "day")
    end,
    night_rules_wanted_eco_slow_and_unboosted = function()
        local w = NOM_NightRules.wanted(true, "eco", 1, cfg({ speedMult = 3 }))
        assert(w.speed == NOM_NightRules.ECO_SPEED and w.speed == 3)
        assert(w.sight == nil and w.hearing == nil and w.key ~= "day")
        -- Eco de dia (antes de sumir) não é tocado
        assert(NOM_NightRules.wanted(false, "eco", 2, cfg()).key == "day")
    end,
    night_rules_wanted_toggles_off_is_day = function()
        local w = NOM_NightRules.wanted(true, nil, 2, cfg({ fasterOn = false, sensesOn = false, speedMult = 3, senseMult = 3 }))
        assert(w.key == "day" and w.speed == 2 and w.sight == nil)
        -- multiplicador 1.0 também não muda nada
        assert(NOM_NightRules.wanted(true, nil, 2, cfg({ speedMult = 1, senseMult = 1 })).key == "day")
    end,
    night_rules_wanted_only_senses = function()
        local w = NOM_NightRules.wanted(true, nil, 2, cfg({ fasterOn = false, hearing = 3 }))
        assert(w.speed == 2 and w.sight == 1 and w.hearing == 2)
        local s = NOM_NightRules.wanted(true, nil, 2, cfg({ sensesOn = false }))
        assert(s.speed == 1 and s.sight == nil and s.hearing == nil)
        assert(w.key ~= s.key)
    end,
    -- Corredor: sprinter mesmo com NightFaster desligado; sentidos da noite
    night_rules_wanted_corredor = function()
        local R = NOM_NightRules
        local w = R.wanted(true, "corredor", 3, cfg({ fasterOn = false, sensesOn = false }))
        assert(w.speed == 1 and w.sight == nil and w.hearing == nil and w.key ~= "day")
        local n = R.wanted(true, "corredor", 2, cfg())
        assert(n.speed == 1 and n.sight == 1 and n.hearing == 1)
        -- mesmos stats de um zumbi comum da noite, chave diferente: o mod sabe que é variante
        assert(n.key ~= R.wanted(true, nil, 2, cfg()).key)
    end,
    -- Carpideira (sprint 0011): corredora como o Corredor. Calma ela está parada
    -- (useless, NOM_Carpideira), então a velocidade só aparece depois do grito.
    night_rules_wanted_carpideira_sprints = function()
        local R = NOM_NightRules
        local w = R.wanted(false, "carpideira", 3, cfg())
        assert(w.speed == R.CORREDOR_SPEED and w.key ~= "day", "de dia na névoa não correu")
        local n = R.wanted(true, "carpideira", 3, cfg({ fasterOn = false }))
        assert(n.speed == R.CORREDOR_SPEED and n.key ~= R.wanted(true, "corredor", 3, cfg({ fasterOn = false })).key)
    end,
    -- Estalador: cego (pior visão) e ouvido apurado, com ou sem os sentidos da noite
    night_rules_wanted_estalador = function()
        local R = NOM_NightRules
        local w = R.wanted(true, "estalador", 2, cfg())
        assert(w.speed == 1 and w.sight == 3 and w.hearing == 1, "estalador: " .. tostring(w.sight))
        local off = R.wanted(true, "estalador", 2, cfg({ fasterOn = false, sensesOn = false }))
        assert(off.speed == 2 and off.sight == 3 and off.hearing == 1 and off.key ~= "day")
        assert(off.key ~= R.wanted(true, "corredor", 2, cfg()).key)
    end,
    night_rules_countdown = function()
        local m, due = 0, false
        for _ = 1, 59 do
            m, due = NOM_NightRules.countdown(m, 60)
            assert(not due)
        end
        m, due = NOM_NightRules.countdown(m, 60)
        assert(due and m == 0)
    end,
    -- o jogo multiplica o raio do som pela audição do zumbi (getSoundAttract ×
    -- getHearingMultiplier: 3.0 / 1.0 / 0.45); o mod divide pra o alcance ser o configurado
    night_rules_sound_radius = function()
        local R = NOM_NightRules
        assert(R.HEARING_MULT[1] == 3.0 and R.HEARING_MULT[2] == 1.0 and R.HEARING_MULT[3] == 0.45)
        assert(R.soundRadius(30, cfg()) == 10, "apurada à noite: 30 / 3")
        assert(R.soundRadius(30, cfg({ sensesOn = false })) == 30, "sentidos desligados: raio do jogo")
        assert(R.soundRadius(30, cfg({ senseMult = 1.0 })) == 30, "sem degrau: raio do jogo")
        assert(R.soundRadius(30, cfg({ hearing = 3 })) == 30, "ruim → normal: ×1")
        assert(R.soundRadius(25, cfg()) == 8)
        assert(R.soundRadius(1, cfg()) == 1, "nunca zero")
    end,
    -- 20 = teto do raio de visão do zumbi (PZMath.clamp em updateVisionRadius)
    night_rules_torch_radius = function()
        assert(NOM_NightRules.torchRadius(1.5) == 30)
        assert(NOM_NightRules.torchRadius(1.0) == 20)
    end,
    -- variante da névoa de dia: só o perfil dela, sem bônus da noite
    night_rules_wanted_variant_by_day = function()
        local c = NOM_NightRules.wanted(false, "corredor", 3, cfg())
        assert(c.speed == 1 and c.sight == nil and c.key ~= "day")
        local e = NOM_NightRules.wanted(false, "estalador", 2, cfg())
        assert(e.speed == 2 and e.sight == 3 and e.hearing == 1 and e.key ~= "day")
        assert(e.key ~= NOM_NightRules.wanted(true, "estalador", 2, cfg()).key, "dia e noite com a mesma chave")
    end,
}
