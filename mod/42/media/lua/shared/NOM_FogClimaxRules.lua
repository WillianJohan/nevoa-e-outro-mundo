-- Névoa clímax (sprint 0047): base baixa tipo gelo seco + bolsões viajantes raros/brutais.
-- Puro (sem API do jogo). Sandbox manda os 2 eixos; o cliente empurra params pro mod3
-- (NOM_FogQualitySync) e o fallback sem mod3 usa a vinheta (NOM_ScreenFxRules).
NOM_FogClimaxRules = {}
local R = NOM_FogClimaxRules

R.PARAM_HEIGHT = 2
R.PARAM_POCKET_HEIGHT = 3
R.PARAM_HAZE = 7

R.BASE_HEIGHT_MIN = 0.2
R.BASE_HEIGHT_MAX = 1.2
R.BASE_HEIGHT_DEFAULT = 0.68   -- 0047f: envelope baixo; miolo vem do floor orgânico + fall 3,2
R.POCKET_HEIGHT = 1.2
R.POCKET_AGGRESSION_DEFAULT = 1
-- 0047f: HAZE shader 0,32 × baseHaze ~0,52 ≈ 0,17 no chão (0047e 0,19 + floor flat = sopa)
R.BASE_HAZE_DEFAULT = 0.52

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- baseHeight em andares; pocketAggression 0..2 (0 = sem bolsões).
function R.look(baseHeight, pocketAggression)
    local h = clamp(tonumber(baseHeight) or R.BASE_HEIGHT_DEFAULT, R.BASE_HEIGHT_MIN, R.BASE_HEIGHT_MAX)
    local a = clamp(tonumber(pocketAggression) or R.POCKET_AGGRESSION_DEFAULT, 0, 2)
    local haze = clamp(0.46 + 0.14 * ((h - R.BASE_HEIGHT_MIN) / (R.BASE_HEIGHT_MAX - R.BASE_HEIGHT_MIN)), 0.45, 0.60)
    local coverage, boost, scale, speed
    if a <= 0 then
        coverage, boost, scale, speed = 0, 0, 50, 1
    else
        -- default (a=1): ~8% cobertura, boost forte; a=2 sobe um pouco (ainda raro)
        coverage = 0.05 + 0.05 * a
        boost = 0.85 + 0.35 * a
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
