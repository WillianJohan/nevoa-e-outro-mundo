require "NOM_AtmosphereRules"

local R = NOM_AtmosphereRules

return {
    atmosphere_rules_approach = function()
        assert(R.approach(0, 1, 500, 1000) == 0.5)
        assert(R.approach(0.9, 1, 500, 1000) == 1, "passou do alvo")
        assert(R.approach(0.2, 0, 500, 1000) == 0, "passou do alvo descendo")
        assert(R.approach(0.5, 0.5, 500, 1000) == 0.5)
    end,
    atmosphere_rules_vignette = function()
        local off = R.vignette(0)
        assert(off.blur == 0 and off.desat == 0 and off.darkness == 0, "intensidade 0 ainda escurece")
        local one, two = R.vignette(1), R.vignette(2)
        assert(two.darkness > one.darkness and one.darkness > 0)
        for _, v in ipairs({ one, two, R.vignette(50) }) do
            for _, k in ipairs({ "blur", "desat", "darkness" }) do
                assert(v[k] >= 0 and v[k] <= 1, k .. " fora de 0..1")
            end
            assert(v.radius > 0 and v.gradient > 0)
        end
    end,
}
