-- Regras puras da brasa permanente na névoa preta (sprint 0067, direção
-- look-brasa-nevoa-preta): pulso lento por zumbi, Alpha na faixa que mantém a
-- crosta Dissolve sólida, e "prende a respiração" na luz. Sem API do jogo.
require "NOM_Math"

NOM_BrasaRules = {
    PERIOD_MIN_MS = 2400,
    PERIOD_MAX_MS = 3200,
    HUNT_PERIOD_MS = 1600,
    INTENSITY_MIN = 0.55,
    INTENSITY_MAX = 1.0,
    CORE_GATE = 0.85,
    LIGHT_HOLD_MIN = 0.30,
    LIGHT_HOLD_MAX = 0.45,
    -- Alpha do personagem: crosta NOM_Dissolve fica sólida acima de 0,85;
    -- pulso mora em 0,92–1,0 pra não abrir buraco na crosta.
    ALPHA_LO = 0.92,
    ALPHA_HI = 1.0,
    ITEM = "Base.NOM_BrasaCasca",
    ITEM_STATIC = "Base.NOM_BrasaCascaStatic",
}

local R = NOM_BrasaRules

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- Período e fase estáveis por semente (onlineID / outfit).
function R.periodMs(seed, hunting)
    if hunting then return R.HUNT_PERIOD_MS end
    seed = math.floor(tonumber(seed) or 0)
    local span = R.PERIOD_MAX_MS - R.PERIOD_MIN_MS
    local u = NOM_Math.mod(seed * 1103515245 + 12345, 10000) / 10000
    return R.PERIOD_MIN_MS + math.floor(u * span + 0.5)
end

function R.phase0(seed)
    seed = math.floor(tonumber(seed) or 0)
    return NOM_Math.mod(seed * 2654435761, 10000) / 10000
end

-- Intensidade 0,55–1,0 (seno suave). lightHold=true → prende em 0,30–0,45.
function R.pulse(nowMs, periodMs, phase0, lightHold)
    periodMs = math.max(1, tonumber(periodMs) or R.PERIOD_MIN_MS)
    phase0 = tonumber(phase0) or 0
    local t = (tonumber(nowMs) or 0) / periodMs + phase0
    local u = 0.5 + 0.5 * math.sin(t * 2 * math.pi)
    local lo, hi = R.INTENSITY_MIN, R.INTENSITY_MAX
    if lightHold then
        lo, hi = R.LIGHT_HOLD_MIN, R.LIGHT_HOLD_MAX
        -- fase congelada: usa só phase0 pra não "respirar" na luz
        u = 0.5 + 0.5 * math.sin(phase0 * 2 * math.pi)
    end
    return lo + (hi - lo) * clamp(u, 0, 1)
end

-- Mapeia pulso → Alpha do personagem (faixa ALPHA_LO..ALPHA_HI).
function R.alpha(pulse)
    pulse = clamp(tonumber(pulse) or R.INTENSITY_MIN, R.INTENSITY_MIN, R.INTENSITY_MAX)
    local k = (pulse - R.INTENSITY_MIN) / (R.INTENSITY_MAX - R.INTENSITY_MIN)
    return R.ALPHA_LO + (R.ALPHA_HI - R.ALPHA_LO) * k
end

function R.coreOn(pulse)
    return (tonumber(pulse) or 0) >= R.CORE_GATE
end

return NOM_BrasaRules
