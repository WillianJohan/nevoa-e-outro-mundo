-- Regras puras da brasa permanente (sprint 0067).
require "NOM_BrasaRules"

local R = NOM_BrasaRules

return {
    brasa_period_in_range = function()
        for seed = 0, 200 do
            local p = R.periodMs(seed, false)
            assert(p >= R.PERIOD_MIN_MS and p <= R.PERIOD_MAX_MS, "period " .. p)
        end
        assert(R.periodMs(1, true) == R.HUNT_PERIOD_MS)
    end,

    brasa_phases_desync = function()
        local a = R.phase0(1)
        local b = R.phase0(2)
        assert(a ~= b, "fases iguais")
        assert(a >= 0 and a < 1 and b >= 0 and b < 1)
    end,

    brasa_pulse_breathes = function()
        local period = 3000
        local lo, hi = 2, 0
        for t = 0, period, 50 do
            local p = R.pulse(t, period, 0, false)
            if p < lo then lo = p end
            if p > hi then hi = p end
        end
        assert(lo <= R.INTENSITY_MIN + 0.02, "piso " .. lo)
        assert(hi >= R.INTENSITY_MAX - 0.02, "teto " .. hi)
    end,

    brasa_pulse_holds_in_light = function()
        local p = R.pulse(0, 3000, 0.25, true)
        assert(p >= R.LIGHT_HOLD_MIN and p <= R.LIGHT_HOLD_MAX, "luz " .. p)
        local a = R.pulse(1500, 3000, 0.25, true)
        assert(math.abs(a - p) < 1e-6, "não deve respirar na luz")
    end,

    -- Canal próprio 0..1 pro TintColour.r; shader faz 0.30 + 0.70*channel.
    brasa_pulse_channel_maps_intensity = function()
        assert(math.abs(R.pulseChannel(R.INTENSITY_FLOOR) - 0) < 1e-6)
        assert(math.abs(R.pulseChannel(1.0) - 1) < 1e-6)
        local mid = R.pulseChannel(0.55)
        local inten = R.INTENSITY_FLOOR + R.INTENSITY_SPAN * mid
        assert(math.abs(inten - 0.55) < 1e-5, "remap " .. inten)
        local light = R.pulseChannel(0.30)
        assert(light <= 0.01, "luz no canal: " .. light)
        local lightHi = R.pulseChannel(0.45)
        assert(lightHi > 0.2 and lightHi < 0.25, "luz teto canal: " .. lightHi)
    end,

    brasa_no_alpha_pulse_api = function()
        assert(R.alpha == nil, "Alpha do personagem não é canal de pulso")
        assert(R.ALPHA_LO == nil and R.ALPHA_HI == nil)
    end,

    brasa_core_only_at_peak = function()
        assert(R.coreOn(0.84) == false)
        assert(R.coreOn(0.85) == true)
        assert(R.coreOn(1.0) == true)
    end,

    brasa_items_named = function()
        assert(R.ITEM == "Base.NOM_BrasaCasca")
        assert(R.ITEM_STATIC == "Base.NOM_BrasaCascaStatic")
    end,
}
