-- Regras puras da tempestade da névoa preta e da vermelha (sprint 0045): sem API do jogo,
-- testável com ./run-tests.sh. Quem usa: server/NOM_Storm.lua (relâmpago e trovão) e
-- server/NOM_ClimateLook.lua (chuva). A branca não tem tempestade.
require "NOM_Math"

NOM_StormRules = {}

local R = NOM_StormRules

-- Intervalo entre relâmpagos, em ms reais.
R.THUNDER_MIN_MS = 8000
R.THUNDER_MAX_MS = 30000
-- Distância do relâmpago ao jogador, em tiles: o trovão chega dist/300 s depois do clarão
-- (ThunderStorm.enqueueThunderEvent, pz-api-notes §34), então 40..900 dá de quase junto a 3 s.
R.DIST_MIN = 40
R.DIST_MAX = 900
-- Clarão na preta: os Tições perto dos jogadores congelam esse tempo.
R.FLASH_MS = 1000
-- Chuva em RAIN_CHANCE % das névoas pretas e vermelhas, na intensidade RAIN_INTENSITY (0..1).
R.RAIN_CHANCE = 30
R.RAIN_INTENSITY = 0.55

function R.nextThunder(r)
    r = math.max(0, math.min(r, 0.999999))
    return math.floor(R.THUNDER_MIN_MS + (R.THUNDER_MAX_MS - R.THUNDER_MIN_MS) * r)
end

-- Tile do relâmpago em volta de (px, py); rAngle e rDist em 0..1.
function R.thunderPoint(px, py, rAngle, rDist)
    local a = rAngle * 2 * math.pi
    local d = R.DIST_MIN + (R.DIST_MAX - R.DIST_MIN) * math.max(0, math.min(rDist, 1))
    return math.floor(px + math.cos(a) * d + 0.5), math.floor(py + math.sin(a) * d + 0.5)
end

-- O período (contador de névoas do NOM_FogEvent) decide: a mesma névoa chove do começo ao fim.
function R.rains(period)
    period = tonumber(period)
    if period == nil then return false end
    return NOM_Math.mod(math.floor(period) * 7919 + 104729, 100) < R.RAIN_CHANCE
end

return NOM_StormRules
