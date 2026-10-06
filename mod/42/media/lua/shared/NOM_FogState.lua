-- Estado da névoa do lado de quem vê e ouve (cliente; no solo, o mesmo processo).
-- Quem decide é o servidor (server/NOM_Fog.lua): no solo ele chama set direto,
-- no MP o client/NOM_FogClient.lua segue o comando "fog". Os sistemas locais
-- (som, vinheta, overlays, Sem-rosto) leem daqui.
-- rising/risingRed (sprint 0034): a névoa visual subindo na fuga, antes da névoa de jogo.
-- Quem liga: no solo o server/NOM_FogEvent.lua, no MP o NOM_FogClient (siren, sirenStop,
-- fog). Só o visual e o som de ambiente leem visible(); a regra de jogo segue on.
-- omenAt/omenRed/sirenAt (sprint 0034): marcas de getTimestampMs da estática na tela
-- (shared/NOM_ScreenFxRules.staticLevel): o presságio, 3 s antes da sirene, e a sirene (a
-- subida que liga). A subida que desliga (névoa aberta, cancelada) e o fim limpam.
NOM_FogState = { on = false, period = nil, red = false, rising = false, risingRed = false,
    omenAt = nil, omenRed = false, sirenAt = nil }

local listeners = {}

local function clearMarks()
    NOM_FogState.omenAt, NOM_FogState.omenRed, NOM_FogState.sirenAt = nil, false, nil
end

-- fn(on) só na borda.
function NOM_FogState.onChange(fn)
    listeners[#listeners + 1] = fn
end

-- period: número do período de névoa (sorteio do Sem-rosto, ADR-006). nil
-- enquanto o cliente não souber. red: névoa vermelha (sprint 0010), só com névoa.
function NOM_FogState.set(on, period, red)
    local was = NOM_FogState.on
    NOM_FogState.on = on
    NOM_FogState.period = period
    NOM_FogState.red = on == true and red == true
    if was == on then return end
    if not on then clearMarks() end
    for _, fn in ipairs(listeners) do fn(on) end
end

-- Não é borda de névoa: quem ouve onChange (regra de jogo) não fica sabendo.
-- getTimestampMs: CONFIRMED server/ISObjectClickHandler.lua:352.
function NOM_FogState.setRising(on, red)
    local was = NOM_FogState.rising
    NOM_FogState.rising = on == true
    NOM_FogState.risingRed = NOM_FogState.rising and red == true
    if NOM_FogState.rising and not was then NOM_FogState.sirenAt = getTimestampMs() end
    if not NOM_FogState.rising then clearMarks() end
end

-- O presságio: a cor é a que a sirene vai tocar.
function NOM_FogState.setOmen(red)
    NOM_FogState.omenAt, NOM_FogState.omenRed, NOM_FogState.sirenAt = getTimestampMs(), red == true, nil
end

-- A cor mudou no meio (debug, NOM_FogEvent.setRed): o presságio e a subida que já correm
-- trocam de cor, sem recomeçar e sem ligar o que não corre.
function NOM_FogState.recolor(red)
    if NOM_FogState.omenAt then NOM_FogState.omenRed = red == true end
    if NOM_FogState.rising then NOM_FogState.risingRed = red == true end
end

function NOM_FogState.visible()
    return NOM_FogState.on == true or NOM_FogState.rising
end

function NOM_FogState.visibleRed()
    return (NOM_FogState.on == true and NOM_FogState.red) or (NOM_FogState.rising and NOM_FogState.risingRed)
end

return NOM_FogState
