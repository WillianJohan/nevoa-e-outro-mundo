-- Pressão da névoa preta (sprint 0051): Leve / Padrão / Pesadelo. Sem API do jogo;
-- testável com ./run-tests.sh. Quem aplica é LightRules, TicaoLight, Night, LampFlicker.
-- A preta continua só Tição: estes números apertam luz/caça, não inventam horda.
require "NOM_Config"

NOM_BlackPressureRules = {}

local R = NOM_BlackPressureRules

R.LEVE = 1
R.PADRAO = 2
R.PESADELO = 3

-- Perfis (decisão na ausência do Johan; fáceis de mudar no playtest).
-- huntOnFlickerReach = 0 desliga a caça no piscar (Leve).
local PROFILES = {
    [1] = {
        flickerCheckMs = 12000, flickerChance = 20, flickerMinMs = 700, flickerMaxMs = 1400,
        holdMs = 500,
        huntMinutes = 25, huntReach = 35, huntOnFlickerReach = 0,
        fastBias = 0.5,
        lampCheckMs = 2500, lampChance = 25,
        lampDarkChance = 0.3, lampDarkMinMs = 400, lampDarkMaxMs = 1200,
    },
    [2] = {
        flickerCheckMs = 7000, flickerChance = 40, flickerMinMs = 900, flickerMaxMs = 2000,
        holdMs = 280,
        huntMinutes = 12, huntReach = 40, huntOnFlickerReach = 25,
        fastBias = 0.5,
        lampCheckMs = 1500, lampChance = 40,
        lampDarkChance = 0.5, lampDarkMinMs = 800, lampDarkMaxMs = 2000,
    },
    [3] = {
        flickerCheckMs = 4000, flickerChance = 55, flickerMinMs = 1200, flickerMaxMs = 2500,
        holdMs = 150,
        huntMinutes = 8, huntReach = 50, huntOnFlickerReach = 35,
        fastBias = 0.75,
        lampCheckMs = 1000, lampChance = 55,
        lampDarkChance = 0.7, lampDarkMinMs = 1200, lampDarkMaxMs = 3000,
    },
}

function R.level(raw)
    raw = tonumber(raw)
    if raw == nil then return R.PADRAO end
    if raw < R.LEVE then return R.LEVE end
    if raw > R.PESADELO then return R.PESADELO end
    return math.floor(raw)
end

function R.profile(level)
    return PROFILES[R.level(level)]
end

function R.current()
    return R.profile(NOM_Config.get("BlackFogPressure"))
end

return NOM_BlackPressureRules
