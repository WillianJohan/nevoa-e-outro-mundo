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

    brasa_alpha_keeps_dissolve_solid = function()
        local a0 = R.alpha(R.INTENSITY_MIN)
        local a1 = R.alpha(R.INTENSITY_MAX)
        assert(a0 >= R.ALPHA_LO - 1e-6 and a1 <= R.ALPHA_HI + 1e-6)
        assert(a0 >= 0.92, "crosta dissolve precisa Alpha >= 0.92: " .. a0)
        assert(a1 >= a0)
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
