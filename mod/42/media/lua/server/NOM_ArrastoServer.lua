-- Servidor do Arrasto (sprint 0059 spike). Quem simula aplica (ADR-005).
-- No solo este processo é o dono; no dedicado o debug marca a cópia do servidor
-- (spike: playtest solo primeiro).
if isClient() then return end

require "NOM_World"
require "NOM_ArrastoRules"
require "NOM_Arrasto"

NOM_ArrastoServer = {}

local function fogColor()
    if not NOM_World or not NOM_World.fog then return nil end
    if NOM_World.black then return "black" end
    if NOM_World.red then return "red" end
    return "white"
end

-- Força o Arrasto no zumbi (debug). Cor da névoa precisa ser vermelha/preta
-- (ou skipColor=true pra testar fora da névoa).
function NOM_ArrastoServer.force(z, skipColor)
    if z == nil then return nil, "sem zumbi" end
    local color = fogColor()
    if not skipColor and not NOM_ArrastoRules.enabled(color) then
        return nil, "só na névoa vermelha ou preta (agora=" .. tostring(color) .. ")"
    end
    if not NOM_Arrasto.apply(z) then return nil, "zumbi morto" end
    return true
end

return NOM_ArrastoServer
