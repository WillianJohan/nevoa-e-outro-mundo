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
-- Guarda também a hora de mundo em que a noite abriu (getWorldAgeHours:
-- shared/Definitions/animal/ButcheringUtil.lua:594), pra regra do Eco.
function NOM_NightCount.current()
    if NOM_World.tod == nil then return nil end
    return NOM_EcoRules.syncNight(state(), NOM_World.night, getGameTime():getWorldAgeHours())
end

-- Hora de mundo em que a noite atual abriu (nil antes de conhecida). O Eco só
-- vem de quem morreu antes dela (NOM_EcoRules.diedBeforeNight).
function NOM_NightCount.start()
    if NOM_NightCount.current() == nil then return nil end
    return state().start
end

-- Save com a noite aberta carregado de dia: a primeira leitura do clima fecha a
-- noite salva, senão a noite seguinte herdaria o número (e o sorteio) da velha.
-- Roda depois do OnClimateTick do NOM_ClimateLook (ordem alfabética de carga); se
-- vier antes, tenta de novo no próximo.
local synced = false
Events.OnClimateTick.Add(function()
    if synced or NOM_World.tod == nil then return end
    NOM_NightCount.current()
    synced = true
end)

return NOM_NightCount
