-- Qualidade e resolução da névoa do mod Java opcional (mod3, sprints 0026 e 0030): manda as opções
-- do jogador (Opções > Mods, NOM_ScreenFxOptions.fogQuality e flowResolution) pro mod3 com
-- NOMRender_setParam(6, q) e NOMRender_setParam(9, s). Névoa preta (sprint 0039):
-- NOMRender_setParam(12, 1|0). Clímax fog (sprint 0047): altura da base (2), altura do bolsão (3),
-- véu (7), cobertura (14) e boost (15) a partir do sandbox (NOM_FogClimaxRules).
-- O global vem do mod3 (RenderContext.setParam, @LuaMethod registrado pelo ZombieBuddy);
-- sem o mod3, nada. A opção pode mudar no "Aplicar" a qualquer hora: confere a cada minuto
-- de jogo e só manda o que mudou (trocar a resolução recria a grade da névoa). A preta vai
-- também na borda da névoa (NOM_FogState.onChange), sem esperar o minuto.
if isServer() then return end

require "NOM_ScreenFxOptions"
require "NOM_FogState"
require "NOM_FogClimaxRules"

NOM_FogQualitySync = {
    PARAM = 6, PARAM_RES = 9, PARAM_BLACK = 12,
    PARAM_HEIGHT = NOM_FogClimaxRules.PARAM_HEIGHT,
    PARAM_POCKET_HEIGHT = NOM_FogClimaxRules.PARAM_POCKET_HEIGHT,
    PARAM_HAZE = NOM_FogClimaxRules.PARAM_HAZE,
    PARAM_POCKET_COV = 14,
    PARAM_POCKET_BOOST = 15,
}

local S = NOM_FogQualitySync
local lastQuality, lastRes, lastBlack
local lastHeight, lastPocketH, lastHaze, lastCov, lastBoost

local function pushOne(idx, value, last)
    if value == last then return last, false end
    NOMRender_setParam(idx, value)
    return value, true
end

function S.push()
    if NOMRender_setParam == nil then return false end
    local sent = false
    local q = NOM_ScreenFxOptions.fogQuality()
    if q ~= lastQuality then
        NOMRender_setParam(S.PARAM, q)
        lastQuality = q
        sent = true
    end
    local r = NOM_ScreenFxOptions.flowResolution()
    if r ~= lastRes then
        NOMRender_setParam(S.PARAM_RES, r)
        lastRes = r
        sent = true
    end
    local b = NOM_FogState.black == true and 1 or 0
    if b ~= lastBlack then
        NOMRender_setParam(S.PARAM_BLACK, b)
        lastBlack = b
        sent = true
    end
    local L = NOM_FogClimaxRules.fromConfig()
    local v, ch
    lastHeight, ch = pushOne(S.PARAM_HEIGHT, L.baseHeight, lastHeight)
    if ch then sent = true end
    lastPocketH, ch = pushOne(S.PARAM_POCKET_HEIGHT, L.pocketHeight, lastPocketH)
    if ch then sent = true end
    lastHaze, ch = pushOne(S.PARAM_HAZE, L.baseHaze, lastHaze)
    if ch then sent = true end
    lastCov, ch = pushOne(S.PARAM_POCKET_COV, L.pocketCoverage, lastCov)
    if ch then sent = true end
    lastBoost, ch = pushOne(S.PARAM_POCKET_BOOST, L.pocketBoost, lastBoost)
    if ch then sent = true end
    return sent
end

Events.OnGameStart.Add(function()
    lastQuality, lastRes, lastBlack = nil, nil, nil
    lastHeight, lastPocketH, lastHaze, lastCov, lastBoost = nil, nil, nil, nil, nil
    S.push()
end)
Events.EveryOneMinute.Add(S.push)
NOM_FogState.onChange(function() S.push() end)

return NOM_FogQualitySync
