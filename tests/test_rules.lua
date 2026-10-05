require "NOM_Rules"

local function near(a, b) return math.abs(a - b) < 1e-6 end

return {
    night_after_dusk = function()
        assert(NOM_Rules.isNight(22, 6, 21) == true)
    end,
    night_before_dawn = function()
        assert(NOM_Rules.isNight(3, 6, 21) == true)
    end,
    day_midday = function()
        assert(NOM_Rules.isNight(12, 6, 21) == false)
    end,
    night_starts_exactly_at_dusk = function()
        assert(NOM_Rules.isNight(21, 6, 21) == true)
    end,
    day_starts_exactly_at_dawn = function()
        assert(NOM_Rules.isNight(6, 6, 21) == false)
    end,

    fog_turns_on_at_threshold = function()
        assert(NOM_Rules.isFog(0.5, 0.5, false) == true)
        assert(NOM_Rules.isFog(0.49, 0.5, false) == false)
    end,
    fog_hysteresis_keeps_on_slightly_below = function()
        assert(NOM_Rules.isFog(0.47, 0.5, true) == true)
    end,
    fog_hysteresis_turns_off_below_band = function()
        assert(NOM_Rules.isFog(0.44, 0.5, true) == false)
    end,

    -- rampa anda um passo por minuto de jogo (um OnClimateTick)
    ramp_goes_up = function()
        assert(near(NOM_Rules.ramp(0, true, 20), 1 / 20))
    end,
    ramp_goes_down = function()
        assert(near(NOM_Rules.ramp(1, false, 20), 1 - 1 / 20))
    end,
    ramp_full_after_duration_ticks = function()
        local v = 0
        for _ = 1, 19 do v = NOM_Rules.ramp(v, true, 20) end
        assert(v < 1, "chegou cedo")
        v = NOM_Rules.ramp(v, true, 20)
        assert(near(v, 1), "não chegou em 20 minutos")
    end,
    ramp_caps_at_bounds = function()
        assert(NOM_Rules.ramp(0.99, true, 20) == 1)
        assert(NOM_Rules.ramp(0.01, false, 20) == 0)
    end,

    mix_zero_when_both_off = function()
        local look = NOM_Rules.mix(0, 0, 1)
        for _, ch in ipairs(NOM_Rules.CHANNELS) do
            assert(look[ch].weight == 0, ch)
        end
    end,
    -- à noite só os canais que o render usa no escuro: a dessaturação vai a zero
    -- com a noite (PlayerRenderSettings 594–606: × (1 − darkness))
    mix_night_only_has_no_fog_channel = function()
        local look = NOM_Rules.mix(1, 0, 1)
        assert(look.fog.weight == 0)
        assert(look.desaturation.weight == 0)
        assert(look.ambient.weight > 0)
        assert(look.tint.weight > 0)
    end,
    mix_intensity_scales_weight = function()
        local half = NOM_Rules.mix(1, 0, 0.5)
        local full = NOM_Rules.mix(1, 0, 1)
        assert(near(half.tint.weight * 2, full.tint.weight))
    end,
    -- luz do céu = 2 × mod × ambient (GameTime.getSkyLightLevel 10–77), mod = 1 − alfa ×
    -- (1 − cor) (PlayerRenderSettings 662–725). Noite vanilla de verdade: o
    -- server/Climate/ClimateMain.lua:14-22 troca as cores no OnClimateManagerInit;
    -- sem lua cinza 0.25, lua cheia 0.33, alfa 0.8 nas duas (mod 0.40 e 0.464)
    rules_sky_mod_matches_render = function()
        local r, g, b = NOM_Rules.skyMod(unpack(NOM_Rules.VANILLA_NIGHTS.noMoon))
        assert(near(r, 1 - 0.8 * 0.75) and near(g, r) and near(b, r), "sem lua " .. r)
        assert(near(NOM_Rules.skyMod(unpack(NOM_Rules.VANILLA_NIGHTS.moon)), 1 - 0.8 * 0.67), "lua cheia")
        assert(near(NOM_Rules.skyMod(1, 1, 1, 0.9), 1), "cor branca não escurece")
    end,
    -- "a noite parece clara igual dia": contra a noite vanilla REAL, com e sem lua,
    -- a luz do céu cai ≥ 35% em todo canal com DarkIntensity 1 e ≥ 60% com 2; o
    -- azul cai menos que o vermelho (frio), mas também cai os 35%
    rules_night_darker_and_colder_than_vanilla = function()
        local function night(van, intensity)
            local t = NOM_Rules.mix(1, 0, intensity).tint
            local c = {}
            for i = 1, 4 do c[i] = NOM_Rules.blend(van[i], t.value[i], t.weight) end
            local base = NOM_Rules.skyMod(unpack(van))
            local r, g, b = NOM_Rules.skyMod(unpack(c))
            return 1 - r / base, 1 - g / base, 1 - b / base
        end
        for name, van in pairs(NOM_Rules.VANILLA_NIGHTS) do
            local r, g, b = night(van, 1)
            local f = string.format("%s DI1: r %.0f%% g %.0f%% b %.0f%%", name, r * 100, g * 100, b * 100)
            assert(r >= 0.35 and g >= 0.35 and b >= 0.35, "pouco escuro: " .. f)
            assert(r <= 0.55, "escuro demais pra jogar: " .. f)
            assert(r > b + 0.03, "não ficou mais fria: " .. f)
            local r2, g2, b2 = night(van, 2)
            assert(r2 >= 0.6 and g2 >= 0.6 and b2 >= 0.6,
                string.format("%s DI2: r %.0f%% g %.0f%% b %.0f%%", name, r2 * 100, g2 * 100, b2 * 100))
        end
    end,
    -- névoa: o updateValues (1645–1770) puxa a luz global pra uma de três cores pela
    -- intensidade da névoa, e o ClimateMain.lua:24-34 põe alfa 0.8 nas três. Contra
    -- qualquer uma, a névoa do mod não pode clarear: ≥ 25% em todo canal com
    -- DarkIntensity 1 (≥ 25% também com 2), puxando pro sépia (azul cai mais)
    rules_fog_darker_than_vanilla_on_every_path = function()
        local function drop(van, look)
            local t = look.tint
            local c = {}
            for i = 1, 4 do c[i] = NOM_Rules.blend(van[i], t.value[i], t.weight) end
            local br, bg, bb = NOM_Rules.skyMod(unpack(van))
            local r, g, b = NOM_Rules.skyMod(unpack(c))
            return 1 - r / br, 1 - g / bg, 1 - b / bb
        end
        for name, van in pairs(NOM_Rules.VANILLA_FOGS) do
            for _, I in ipairs({ 1, 2 }) do
                local r, g, b = drop(van, NOM_Rules.mix(0, 1, I))
                local f = string.format("%s DI%d: r %.0f%% g %.0f%% b %.0f%%", name, I, r * 100, g * 100, b * 100)
                assert(r >= 0.25 and g >= 0.25 and b >= 0.25, "névoa pouco escura ou mais clara: " .. f)
                if I == 1 then assert(b > r, "não puxou pro sépia: " .. f) end
            end
        end
    end,
    -- noite + névoa juntas: a mistura das duas cores ainda passa nos dois testes
    rules_night_and_fog_together_still_dark = function()
        local look = NOM_Rules.mix(1, 1, 1)
        local t = look.tint
        local function drop(van)
            local c = {}
            for i = 1, 4 do c[i] = NOM_Rules.blend(van[i], t.value[i], t.weight) end
            local base = { NOM_Rules.skyMod(unpack(van)) }
            local m = { NOM_Rules.skyMod(unpack(c)) }
            local worst = 1
            for i = 1, 3 do worst = math.min(worst, 1 - m[i] / base[i]) end
            return worst
        end
        for name, van in pairs(NOM_Rules.VANILLA_NIGHTS) do
            assert(drop(van) >= 0.35, name .. " noite+névoa: " .. drop(van))
        end
        for name, van in pairs(NOM_Rules.VANILLA_FOGS) do
            assert(drop(van) >= 0.25, name .. " noite+névoa: " .. drop(van))
        end
    end,
    mix_overlap_takes_strongest_not_sum = function()
        local both = NOM_Rules.mix(1, 1, 1)
        local fog = NOM_Rules.mix(0, 1, 1)
        assert(near(both.desaturation.weight, fog.desaturation.weight))
        -- cor da sobreposição fica entre azul (noite) e sépia (névoa)
        local n, f = NOM_Rules.LOOKS.night.tint.value, NOM_Rules.LOOKS.fog.tint.value
        for i = 1, 4 do
            local lo, hi = math.min(n[i], f[i]), math.max(n[i], f[i])
            assert(both.tint.value[i] >= lo and both.tint.value[i] <= hi)
        end
    end,
    mix_weight_never_exceeds_one = function()
        local look = NOM_Rules.mix(1, 1, 2)
        for _, ch in ipairs(NOM_Rules.CHANNELS) do
            assert(look[ch].weight <= 1, ch)
        end
    end,

    fog_exits_at_minimum_threshold = function()
        -- C2: limite 0.05 com histerese 0.05 nunca saía (0 >= 0)
        assert(NOM_Rules.isFog(0, 0.05, true) == false)
    end,
    blend_moves_from_vanilla_toward_target = function()
        assert(near(NOM_Rules.blend(0.2, 1, 0.25), 0.4))
        assert(NOM_Rules.blend(0.7, 0, 0) == 0.7)
        assert(NOM_Rules.blend(0.7, 0, 1) == 0)
    end,
    mix_tint_is_continuous_across_overlap = function()
        -- I2: cor não pode pular de azul pra sépia quando um passa o outro
        local a = NOM_Rules.mix(1, 0.74, 1).tint.value
        local b = NOM_Rules.mix(1, 0.76, 1).tint.value
        for i = 1, 3 do
            assert(math.abs(a[i] - b[i]) < 0.02, "pulo no canal " .. i)
        end
    end,
}

