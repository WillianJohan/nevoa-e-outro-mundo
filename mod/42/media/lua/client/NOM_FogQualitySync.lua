-- Qualidade e resolução da névoa do mod Java opcional (mod3, sprints 0026 e 0030): manda as opções
-- do jogador (Opções > Mods, NOM_ScreenFxOptions.fogQuality e flowResolution) pro mod3 com
-- NOMRender_setParam(6, q) e NOMRender_setParam(9, s).
-- O global vem do mod3 (RenderContext.setParam, @LuaMethod registrado pelo ZombieBuddy);
-- sem o mod3, nada. A opção pode mudar no "Aplicar" a qualquer hora: confere a cada minuto
-- de jogo e só manda o que mudou (trocar a resolução recria a grade da névoa).
if isServer() then return end

require "NOM_ScreenFxOptions"

NOM_FogQualitySync = { PARAM = 6, PARAM_RES = 9 }

local S = NOM_FogQualitySync
local lastQuality, lastRes

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
    return sent
end

Events.OnGameStart.Add(function()
    lastQuality = nil
    lastRes = nil
    S.push()
end)
Events.EveryOneMinute.Add(S.push)

return NOM_FogQualitySync
