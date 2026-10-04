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
    mix_night_only_has_no_fog_channel = function()
        local look = NOM_Rules.mix(1, 0, 1)
        assert(look.fog.weight == 0)
        assert(look.desaturation.weight > 0)
        assert(look.tint.weight > 0)
    end,
    mix_intensity_scales_weight = function()
        local half = NOM_Rules.mix(1, 0, 0.5)
        local full = NOM_Rules.mix(1, 0, 1)
        assert(near(half.desaturation.weight * 2, full.desaturation.weight))
    end,
    mix_overlap_takes_strongest_not_sum = function()
        local both = NOM_Rules.mix(1, 1, 1)
        local fog = NOM_Rules.mix(0, 1, 1)
        assert(near(both.desaturation.weight, fog.desaturation.weight))
        -- cor da sobreposição fica entre azul (noite) e sépia (névoa)
        local n, f = NOM_Rules.LOOKS.night.tint.value, NOM_Rules.LOOKS.fog.tint.value
        for i = 1, 3 do
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

