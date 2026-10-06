-- Estado da névoa do lado de quem vê e ouve (cliente; no solo, o mesmo processo).
-- Quem decide é o servidor (server/NOM_Fog.lua): no solo ele chama set direto,
-- no MP o client/NOM_FogClient.lua segue o comando "fog". Os sistemas locais
-- (som, vinheta, overlays, Sem-rosto) leem daqui.
-- rising/risingRed (sprint 0034): a névoa visual subindo na fuga, antes da névoa de jogo.
-- Quem liga: no solo o server/NOM_FogEvent.lua, no MP o NOM_FogClient (siren, sirenStop,
-- fog). Só o visual e o som de ambiente leem visible(); a regra de jogo segue on.
NOM_FogState = { on = false, period = nil, red = false, rising = false, risingRed = false }

local listeners = {}

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
    for _, fn in ipairs(listeners) do fn(on) end
end

-- Não é borda de névoa: quem ouve onChange (regra de jogo) não fica sabendo.
function NOM_FogState.setRising(on, red)
    NOM_FogState.rising = on == true
    NOM_FogState.risingRed = NOM_FogState.rising and red == true
end

function NOM_FogState.visible()
    return NOM_FogState.on == true or NOM_FogState.rising
end

function NOM_FogState.visibleRed()
    return (NOM_FogState.on == true and NOM_FogState.red) or (NOM_FogState.rising and NOM_FogState.risingRed)
end

return NOM_FogState
