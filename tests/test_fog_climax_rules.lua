-- shared/NOM_FogClimaxRules.lua: base baixa + bolsões (sprint 0047).
require "NOM_FogClimaxRules"
local R = NOM_FogClimaxRules

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-4)
end

return {
    fog_climax_defaults_are_low_base_rare_pockets = function()
        local L = R.look()
        -- 0047e: altura 0,68; baseHaze ~0,50 → HAZE×scale ≈ 0,19
        assert(L.baseHeight < 0.75 and L.baseHeight > 0.5, "base fora do alvo 0047e: " .. L.baseHeight)
        assert(L.baseHaze < 0.58 and L.baseHaze > 0.40, "véu fora do alvo 0047e: " .. L.baseHaze)
        assert(near(L.baseHaze, R.BASE_HAZE_DEFAULT, 0.05))
        assert(L.pocketHeight > L.baseHeight + 0.4, "bolsão sem contraste de altura")
        assert(L.pocketCoverage > 0.03 and L.pocketCoverage < 0.18, "cobertura " .. L.pocketCoverage)
        assert(L.pocketScale > 30 and L.pocketScale < 90, "escala " .. L.pocketScale)
        assert(L.pocketSpeedMul > 0.5)
    end,

    fog_climax_aggression_zero_disables_pockets = function()
        local L = R.look(nil, 0)
        assert(L.pocketCoverage == 0)
        assert(L.pocketBoost == 0)
    end,

    fog_climax_base_height_clamped = function()
        assert(near(R.look(0.1, 1).baseHeight, R.BASE_HEIGHT_MIN))
        assert(near(R.look(9, 1).baseHeight, R.BASE_HEIGHT_MAX))
        assert(near(R.look(0.45, 1).baseHeight, 0.45))
    end,

    fog_climax_pesadelo_more_brutal_than_default = function()
        local D = R.look(0.45, 1)
        local P = R.look(0.55, 2)
        assert(P.pocketCoverage >= D.pocketCoverage)
        assert(P.pocketBoost >= D.pocketBoost)
        assert(P.baseHeight >= D.baseHeight)
    end,

    fog_climax_leve_rarer_and_lower = function()
        local D = R.look(0.45, 1)
        local L = R.look(0.35, 0.5)
        assert(L.pocketCoverage <= D.pocketCoverage)
        assert(L.baseHeight <= D.baseHeight)
        assert(L.baseHaze <= D.baseHaze + 1e-6)
    end,

    fog_climax_fallback_vignette_weaker_on_base = function()
        local L = R.look(0.45, 1)
        assert(L.fallbackBaseVignette < L.fallbackPocketVignette)
        assert(L.fallbackBaseVignette > 0)
        local off = R.look(0.45, 0)
        assert(near(off.fallbackPocketVignette, off.fallbackBaseVignette))
    end,

    fog_climax_params_indices = function()
        assert(R.PARAM_HEIGHT == 2)
        assert(R.PARAM_POCKET_HEIGHT == 3)
        assert(R.PARAM_HAZE == 7)
    end,

    fog_climax_from_config = function()
        SandboxVars = nil
        package.loaded.NOM_Config = nil
        local L = R.fromConfig()
        assert(near(L.baseHeight, R.BASE_HEIGHT_DEFAULT))
        assert(near(L.pocketAggression, R.POCKET_AGGRESSION_DEFAULT))
        SandboxVars = { NevoaEOutroMundo = { FogBaseHeight = 0.35, FogPocketAggression = 0 } }
        package.loaded.NOM_Config = nil
        local Z = R.fromConfig()
        assert(near(Z.baseHeight, 0.35))
        assert(Z.pocketCoverage == 0)
    end,
}
