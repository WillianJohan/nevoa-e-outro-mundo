-- Cliente de MP: o dono do zumbi roda a IA (ADR-005), então é aqui que o
-- Estalador fica cego, estala e o Corredor é visto pegando um jogador de alvo.
-- Quem decide o grito é o servidor (server/NOM_Variants.lua): o cliente só avisa.
if not isClient() then return end

require "NOM_VariantAI"

NOM_VariantAI.install(function(z)
    local id = z:getOnlineID()
    if id == -1 then return end -- sem ID de rede: o servidor não acharia
    sendClientCommand("NevoaEOutroMundo", "corredorSaw", { id = id })
end)
