-- Arrasto (sprint 0059): marca o IsoZombie como rastejante do spike.
-- Chamado no processo que simula (ADR-005). APIs: setCrawler (almas 0050),
-- doZombieSpeed (NightStats/almas). setCrawler: EXISTS via uso em NOM_Alma.lua.
require "NOM_ArrastoRules"

NOM_Arrasto = {}

-- Aplica o protótipo no zumbi: crawler + velocidade lenta + ModData.
-- Devolve true se marcou.
function NOM_Arrasto.apply(z)
    if z == nil or z:isDead() then return false end
    local R = NOM_ArrastoRules
    local md = z:getModData()
    R.mark(md)
    if z.setCrawler then z:setCrawler(true) end
    if z.doZombieSpeed then z:doZombieSpeed(R.speedDeg()) end
    return true
end

function NOM_Arrasto.clear(z)
    if z == nil then return end
    NOM_ArrastoRules.clear(z:getModData())
end

function NOM_Arrasto.is(z)
    if z == nil then return false end
    return NOM_ArrastoRules.isArrasto(z:getModData())
end

return NOM_Arrasto
