-- Regras puras da tempestade da névoa preta e da vermelha (sprint 0045; tint da preta
-- na 0053): sem API do jogo, testável com ./run-tests.sh. Quem usa: server/NOM_Storm.lua
-- (relâmpago e trovão), server/NOM_ClimateLook.lua (chuva) e client/NOM_StormFx.lua
-- (cor do clarão na preta). A branca não tem tempestade.
require "NOM_FogEventRules"

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
R.RAIN_SALT = 104395301 -- sorteio da chuva por período, separado do da preta
-- Sprint 0053: cor do clarão vanilla (ThunderStorm.PlayerLightningInfo.lightningColor).
-- Branco = vanilla / vermelha; vermelho sangue só na preta. O som do trovão não tinge.
R.LIGHTNING_WHITE = { r = 1, g = 1, b = 1 }
R.LIGHTNING_BLACK = { r = 1, g = 0.12, b = 0.06 }
-- Pulso de tela (fallback sem mod3): ms do pico ao zero do overlay vermelho.
R.STORM_FLASH_MS = 450

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

-- O período (contador de névoas do NOM_FogEvent) e a semente do mundo decidem, como o sorteio da
-- preta (NOM_FogEventRules.blackFog): a mesma névoa chove do começo ao fim, e cada save chove em
-- névoas diferentes.
function R.rains(period, seed)
    period = tonumber(period)
    if period == nil then return false end
    return NOM_FogEventRules.frac(seed, math.floor(period), R.RAIN_SALT) * 100 < R.RAIN_CHANCE
end

-- RGB do clarão: só a névoa preta pinta de vermelho (vermelha e branca ficam brancas).
function R.lightningTint(black)
    if black then return R.LIGHTNING_BLACK.r, R.LIGHTNING_BLACK.g, R.LIGHTNING_BLACK.b end
    return R.LIGHTNING_WHITE.r, R.LIGHTNING_WHITE.g, R.LIGHTNING_WHITE.b
end

-- Alfa do overlay de tela (fallback): pico em 0, some em STORM_FLASH_MS.
function R.stormFlash(now, at)
    if at == nil or now < at then return 0 end
    local t = (now - at) / R.STORM_FLASH_MS
    if t >= 1 then return 0 end
    local k = 1 - t
    return k * k
end

return NOM_StormRules
