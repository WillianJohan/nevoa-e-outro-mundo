-- Número da noite atual, salvo no ModData global. Usado pelo Eco (de que noite é
-- cada Eco) e pelas variantes (sorteio por noite, ADR-006), e mandado aos
-- clientes junto da flag "night". Só no servidor.
if isClient() then return end

require "NOM_World"
require "NOM_EcoRules"

NOM_NightCount = {}

-- Fica em data.eco (onde nasceu na sprint 0002) pra não zerar saves existentes.
local function state()
    local data = ModData.getOrCreate("NevoaEOutroMundo")
    data.eco = data.eco or {}
    return data.eco
end

-- nil antes do primeiro OnClimateTick (hora ainda desconhecida). Conta pelo
-- estado salvo, não pela borda (NOM_EcoRules.syncNight): chamar várias vezes, ou
-- de vários arquivos em qualquer ordem, não conta a mesma noite duas vezes.
function NOM_NightCount.current()
    if NOM_World.tod == nil then return nil end
    return NOM_EcoRules.syncNight(state(), NOM_World.night)
end

return NOM_NightCount
