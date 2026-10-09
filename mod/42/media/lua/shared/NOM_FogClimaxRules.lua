-- Névoa clímax (sprint 0047): base + bolsões viajantes. Defaults = playtest Johan (branca, 0047g).
-- Puro (sem API do jogo). Sandbox manda os 2 eixos; o cliente empurra params pro mod3
-- (NOM_FogQualitySync) e o fallback sem mod3 usa a vinheta (NOM_ScreenFxRules).
NOM_FogClimaxRules = {}
local R = NOM_FogClimaxRules

R.PARAM_HEIGHT = 2
R.PARAM_POCKET_HEIGHT = 3
R.PARAM_HAZE = 7

R.BASE_HEIGHT_MIN = 0.2
R.BASE_HEIGHT_MAX = 1.2
R.BASE_HEIGHT_DEFAULT = 1.0   -- playtest Johan (branca): setParam(2, 1)
R.BASE_HAZE_DEFAULT = 0.8     -- setParam(7, 0.8) — fixo, não deriva da altura
R.POCKET_HEIGHT = 1.2
R.POCKET_AGGRESSION_DEFAULT = 1

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- baseHeight em andares; pocketAggression 0..2 (0 = sem bolsões).
function R.look(baseHeight, pocketAggression)
    local h = clamp(tonumber(baseHeight) or R.BASE_HEIGHT_DEFAULT, R.BASE_HEIGHT_MIN, R.BASE_HEIGHT_MAX)
    local a = clamp(tonumber(pocketAggression) or R.POCKET_AGGRESSION_DEFAULT, 0, 2)
    -- véu fixo no default do Johan; não sobe/desce com a altura do sandbox
    local haze = R.BASE_HAZE_DEFAULT
    local coverage, boost, scale, speed
    if a <= 0 then
        coverage, boost, scale, speed = 0, 0, 50, 1
    else
        -- default (a=1): cov 0,10 / boost 1,1 (setParam 14/15 do playtest)
        coverage = 0.05 + 0.05 * a
        boost = 0.75 + 0.35 * a
        scale = 55 - 5 * a
        speed = 0.85 + 0.25 * a
    end
    local baseVig = 0.28 + 0.1 * (h - R.BASE_HEIGHT_DEFAULT)
    local pocketVig = a <= 0 and baseVig or (0.72 + 0.12 * a)
    return {
        baseHeight = h,
        baseHaze = haze,
        pocketHeight = R.POCKET_HEIGHT,
        pocketCoverage = coverage,
        pocketScale = scale,
        pocketBoost = boost,
        pocketSpeedMul = speed,
        pocketAggression = a,
        fallbackBaseVignette = clamp(baseVig, 0.15, 0.5),
        fallbackPocketVignette = clamp(pocketVig, 0.15, 0.95),
    }
end

function R.fromConfig()
    require "NOM_Config"
    return R.look(NOM_Config.get("FogBaseHeight"), NOM_Config.get("FogPocketAggression"))
end

return NOM_FogClimaxRules
