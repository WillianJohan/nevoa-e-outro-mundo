-- Estado da névoa do lado de quem vê e ouve (cliente; no solo, o mesmo processo).
-- Quem decide é o servidor (server/NOM_Fog.lua): no solo ele chama set direto,
-- no MP o client/NOM_FogClient.lua segue o comando "fog". Os sistemas locais
-- (som, vinheta, overlays, Sem-rosto) leem daqui.
NOM_FogState = { on = false, period = nil, red = false }

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

return NOM_FogState
