-- Névoa clímax (sprint 0047): base + bolsões. Defaults por cor = playtest Johan (0047g).
-- Puro (sem API do jogo). Branca: sandbox (altura + aggression). Vermelha: tabela fixa.
-- O cliente empurra params pro mod3 (NOM_FogQualitySync); fallback sem mod3 usa vinheta.
NOM_FogClimaxRules = {}
local R = NOM_FogClimaxRules

R.PARAM_HEIGHT = 2
R.PARAM_POCKET_HEIGHT = 3
R.PARAM_HAZE = 7

R.BASE_HEIGHT_MIN = 0.2
R.BASE_HEIGHT_MAX = 1.2
R.BASE_HEIGHT_DEFAULT = 1.0   -- branca: setParam(2, 1)
R.BASE_HAZE_DEFAULT = 0.8     -- branca: setParam(7, 0.8) — fixo
R.POCKET_HEIGHT = 1.2         -- branca
R.POCKET_AGGRESSION_DEFAULT = 1

-- Vermelha (playtest Johan): altura 1, bolsão 1,1, véu 1, cov 1, boost 1 (res 3 no cliente)
R.RED = {
    baseHeight = 1.0,
    baseHaze = 1.0,
    pocketHeight = 1.1,
    pocketCoverage = 1.0,
    pocketBoost = 1.0,
    pocketScale = 50,
    pocketSpeedMul = 1.0,
    pocketAggression = 1,
    fallbackBaseVignette = 0.28,
    fallbackPocketVignette = 0.84,
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
end

-- baseHeight em andares; pocketAggression 0..2 (0 = sem bolsões). Look da **branca**.
function R.look(baseHeight, pocketAggression)
    local h = clamp(tonumber(baseHeight) or R.BASE_HEIGHT_DEFAULT, R.BASE_HEIGHT_MIN, R.BASE_HEIGHT_MAX)
    local a = clamp(tonumber(pocketAggression) or R.POCKET_AGGRESSION_DEFAULT, 0, 2)
    local haze = R.BASE_HAZE_DEFAULT
    local coverage, boost, scale, speed
    if a <= 0 then
        coverage, boost, scale, speed = 0, 0, 50, 1
    else
        -- default (a=1): cov 0,10 / boost 1,1
        coverage = 0.05 + 0.05 * a
        boost = 0.75 + 0.35 * a
        scale = 55 - 5 * a
        speed = 0.85 + 0.25 * a
    end
    local baseVig = 0.28 + 0.1 * (h - R.BASE_HEIGHT_DEFAULT)
    local pocketVig = a <= 0 and baseVig or (0.72 + 0.12 * a)
    return {
        color = "white",
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

function R.lookRed()
    local L = copy(R.RED)
    L.color = "red"
    return L
end

-- color: "white" | "red" | "black" (preta usa look branco até haver playtest próprio).
function R.fromConfig(color)
    require "NOM_Config"
    if color == "red" then return R.lookRed() end
    return R.look(NOM_Config.get("FogBaseHeight"), NOM_Config.get("FogPocketAggression"))
end

return NOM_FogClimaxRules
