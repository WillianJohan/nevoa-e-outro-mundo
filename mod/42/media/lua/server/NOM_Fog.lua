-- Névoa, lado do servidor: conta os períodos de névoa e avisa quem vê (no solo,
-- o próprio processo; no dedicado, os clientes). Cada período tem um número,
-- base do sorteio do Sem-rosto (ADR-006), contado como as noites: pelo estado
-- salvo no ModData global, não pela borda.
if isClient() then return end

require "NOM_World"
require "NOM_EcoRules"
require "NOM_FogState"

local MODULE = "NevoaEOutroMundo"

local function debugLog(msg)
    if getDebug() then print("[NOM] nevoa " .. msg) end
end

NOM_Fog = {}

local function state()
    local data = ModData.getOrCreate(MODULE)
    data.fog = data.fog or {}
    return data.fog
end

-- nil antes do primeiro OnClimateTick (estado do clima desconhecido).
function NOM_Fog.period()
    if NOM_World.tod == nil then return nil end
    return NOM_EcoRules.syncNight(state(), NOM_World.fog)
end

NOM_World.onChange(function(flag, on)
    if flag ~= "fog" then return end
    local period = NOM_Fog.period()
    if isServer() then
        sendServerCommand(MODULE, "fog", { on = on, period = period })
    else
        NOM_FogState.set(on, period)
    end
    debugLog("fog=" .. tostring(on) .. " periodo=" .. tostring(period))
end)

-- Cliente que entra no meio da névoa não viu a borda: pergunta.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "fogState" then return end
    sendServerCommand(player, MODULE, "fog", { on = NOM_World.fog, period = NOM_Fog.period() })
end)

return NOM_Fog
