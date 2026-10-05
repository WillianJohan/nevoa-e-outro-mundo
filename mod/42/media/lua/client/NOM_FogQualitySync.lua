-- Qualidade da névoa do mod Java opcional (mod3, sprint 0026): manda a opção do jogador
-- (Opções > Mods, NOM_ScreenFxOptions.fogQuality) pro shader com NOMRender_setParam(6, q).
-- O global vem do mod3 (RenderContext.setParam, @LuaMethod registrado pelo ZombieBuddy);
-- sem o mod3, nada. A opção pode mudar no "Aplicar" a qualquer hora: confere a cada minuto
-- de jogo e só manda quando muda.
if isServer() then return end

require "NOM_ScreenFxOptions"

NOM_FogQualitySync = { PARAM = 6 }

local S = NOM_FogQualitySync
local last

function S.push()
    if NOMRender_setParam == nil then return false end
    local q = NOM_ScreenFxOptions.fogQuality()
    if q == last then return false end
    NOMRender_setParam(S.PARAM, q)
    last = q
    return true
end

Events.OnGameStart.Add(function()
    last = nil
    S.push()
end)
Events.EveryOneMinute.Add(S.push)

return NOM_FogQualitySync
