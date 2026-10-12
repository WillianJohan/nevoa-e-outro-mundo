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
-- black/risingBlack/omenBlack: a névoa preta (sprint 0038), como as do vermelho; nunca junto dele.
NOM_FogState = { on = false, period = nil, red = false, black = false, rising = false, risingRed = false,
    risingBlack = false, omenAt = nil, omenRed = false, omenBlack = false, sirenAt = nil }

local listeners = {}
local colorListeners = {}

local function clearMarks()
    NOM_FogState.omenAt, NOM_FogState.omenRed, NOM_FogState.sirenAt = nil, false, nil
    NOM_FogState.omenBlack = false
end

-- fn(on) só na borda on/off (regra de jogo / overlays).
function NOM_FogState.onChange(fn)
    listeners[#listeners + 1] = fn
end

-- fn(color) quando a cor ativa muda (branca/vermelha/preta) — clímax fog sync (0047g).
function NOM_FogState.onColorChange(fn)
    colorListeners[#colorListeners + 1] = fn
end

local function notifyColor(prev)
    local now = NOM_FogState.color()
    if now == prev then return end
    for _, fn in ipairs(colorListeners) do fn(now) end
end

-- period: número do período de névoa (sorteio do Sem-rosto, ADR-006). nil
-- enquanto o cliente não souber. red: névoa vermelha (sprint 0010), só com névoa.
function NOM_FogState.set(on, period, red, black)
    local was = NOM_FogState.on
    local prevColor = NOM_FogState.color()
    NOM_FogState.on = on
    NOM_FogState.period = period
    NOM_FogState.black = on == true and black == true
    NOM_FogState.red = on == true and red == true and not NOM_FogState.black
    if was ~= on then
        if not on then clearMarks() end
        for _, fn in ipairs(listeners) do fn(on) end
    end
    notifyColor(prevColor)
end

-- Não é borda de névoa: quem ouve onChange (regra de jogo) não fica sabendo.
-- getTimestampMs: CONFIRMED server/ISObjectClickHandler.lua:352.
function NOM_FogState.setRising(on, red, black)
    local was = NOM_FogState.rising
    local prevColor = NOM_FogState.color()
    NOM_FogState.rising = on == true
    NOM_FogState.risingBlack = NOM_FogState.rising and black == true
    NOM_FogState.risingRed = NOM_FogState.rising and red == true and not NOM_FogState.risingBlack
    if NOM_FogState.rising and not was then NOM_FogState.sirenAt = getTimestampMs() end
    if not NOM_FogState.rising then clearMarks() end
    notifyColor(prevColor)
end

-- O presságio: a cor é a que a sirene vai tocar.
function NOM_FogState.setOmen(red, black)
    local prevColor = NOM_FogState.color()
    NOM_FogState.omenAt, NOM_FogState.omenRed, NOM_FogState.sirenAt = getTimestampMs(), red == true, nil
    NOM_FogState.omenBlack = black == true
    if NOM_FogState.omenBlack then NOM_FogState.omenRed = false end
    notifyColor(prevColor)
end

-- A cor mudou no meio (debug, NOM_FogEvent.setRed): o presságio e a subida que já correm
-- trocam de cor, sem recomeçar e sem ligar o que não corre.
function NOM_FogState.recolor(red, black)
    local prevColor = NOM_FogState.color()
    local b = black == true
    local r = red == true and not b
    if NOM_FogState.omenAt then NOM_FogState.omenRed, NOM_FogState.omenBlack = r, b end
    if NOM_FogState.rising then NOM_FogState.risingRed, NOM_FogState.risingBlack = r, b end
    notifyColor(prevColor)
end

function NOM_FogState.visible()
    return NOM_FogState.on == true or NOM_FogState.rising
end

function NOM_FogState.visibleRed()
    return (NOM_FogState.on == true and NOM_FogState.red) or (NOM_FogState.rising and NOM_FogState.risingRed)
end

function NOM_FogState.visibleBlack()
    return (NOM_FogState.on == true and NOM_FogState.black) or (NOM_FogState.rising and NOM_FogState.risingBlack)
end

-- Cor da névoa aberta (ou da que sobe, ou do presságio): "black", "red" ou "white".
function NOM_FogState.color()
    local s = NOM_FogState
    if s.on then return s.black and "black" or (s.red and "red" or "white") end
    if s.rising then return s.risingBlack and "black" or (s.risingRed and "red" or "white") end
    return s.omenBlack and "black" or (s.omenRed and "red" or "white")
end

return NOM_FogState
