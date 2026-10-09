-- shared/NOM_FogClimaxRules.lua: base + bolsões (sprint 0047; defaults playtest Johan).
require "NOM_FogClimaxRules"
local R = NOM_FogClimaxRules

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-4)
end

return {
    fog_climax_defaults_match_johan_playtest = function()
        local L = R.look()
        -- setParam(2,1) (7,0.8) (3,1.2) (14,0.1) (15,1.1)
        assert(near(L.baseHeight, 1.0), "altura: " .. L.baseHeight)
        assert(near(L.baseHaze, 0.8), "véu: " .. L.baseHaze)
        assert(near(L.pocketHeight, 1.2), "bolsão H: " .. L.pocketHeight)
        assert(near(L.pocketCoverage, 0.1), "cobertura: " .. L.pocketCoverage)
        assert(near(L.pocketBoost, 1.1), "boost: " .. L.pocketBoost)
        assert(L.pocketScale > 30 and L.pocketScale < 90, "escala " .. L.pocketScale)
        assert(L.pocketSpeedMul > 0.5)
    end,

    fog_climax_haze_fixed_not_from_height = function()
        assert(near(R.look(0.35, 1).baseHaze, R.BASE_HAZE_DEFAULT))
        assert(near(R.look(1.2, 1).baseHaze, R.BASE_HAZE_DEFAULT))
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
        local D = R.look(1.0, 1)
        local P = R.look(1.0, 2)
        assert(P.pocketCoverage >= D.pocketCoverage)
        assert(P.pocketBoost >= D.pocketBoost)
    end,

    fog_climax_leve_rarer = function()
        local D = R.look(1.0, 1)
        local L = R.look(0.35, 0.5)
        assert(L.pocketCoverage <= D.pocketCoverage)
        assert(L.baseHeight <= D.baseHeight)
        assert(near(L.baseHaze, D.baseHaze))
    end,

    fog_climax_fallback_vignette_weaker_on_base = function()
        local L = R.look(1.0, 1)
        assert(L.fallbackBaseVignette < L.fallbackPocketVignette)
        assert(L.fallbackBaseVignette > 0)
        local off = R.look(1.0, 0)
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
        assert(near(L.baseHaze, R.BASE_HAZE_DEFAULT))
        assert(L.color == "white")
        SandboxVars = { NevoaEOutroMundo = { FogBaseHeight = 0.35, FogPocketAggression = 0 } }
        package.loaded.NOM_Config = nil
        local Z = R.fromConfig()
        assert(near(Z.baseHeight, 0.35))
        assert(Z.pocketCoverage == 0)
    end,

    -- playtest Johan vermelha: 2=1, 3=1.1, 7=1, 14=1, 15=1 (fixo; não usa sandbox)
    fog_climax_red_look_fixed = function()
        local L = R.lookRed()
        assert(L.color == "red")
        assert(near(L.baseHeight, 1.0))
        assert(near(L.baseHaze, 1.0))
        assert(near(L.pocketHeight, 1.1))
        assert(near(L.pocketCoverage, 1.0))
        assert(near(L.pocketBoost, 1.0))
        SandboxVars = { NevoaEOutroMundo = { FogBaseHeight = 0.35, FogPocketAggression = 0 } }
        package.loaded.NOM_Config = nil
        local Z = R.fromConfig("red")
        assert(near(Z.baseHeight, 1.0) and near(Z.pocketCoverage, 1.0), "vermelha não ignora sandbox")
    end,

    -- playtest Johan preta: 2=1.2, 3=1.1, 7=1, 14=1, 15=1.2
    fog_climax_black_look_fixed = function()
        local L = R.lookBlack()
        assert(L.color == "black")
        assert(near(L.baseHeight, 1.2))
        assert(near(L.baseHaze, 1.0))
        assert(near(L.pocketHeight, 1.1))
        assert(near(L.pocketCoverage, 1.0))
        assert(near(L.pocketBoost, 1.2))
        SandboxVars = { NevoaEOutroMundo = { FogBaseHeight = 0.35, FogPocketAggression = 0 } }
        package.loaded.NOM_Config = nil
        local Z = R.fromConfig("black")
        assert(Z.color == "black")
        assert(near(Z.baseHeight, 1.2) and near(Z.pocketBoost, 1.2), "preta não ignora sandbox")
    end,
}
