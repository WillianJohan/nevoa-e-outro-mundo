-- Comportamento das variantes onde o zumbi é simulado (ADR-005): no solo, o
-- próprio processo (server/NOM_Variants.lua instala); no MP, o cliente
-- (client/NOM_VariantsClient.lua instala). A variante vem do NOM_NightStats
-- (modData.NOM_variant, só em memória, ADR-006). O grito do Corredor é decisão
-- do servidor: aqui só se avisa, pelo report passado no install.
require "NOM_NightStats"

NOM_VariantAI = {}

NOM_VariantAI.CLICK_SOUND = "NOM_EstaladorClick" -- media/scripts/NOM_sounds.txt
-- Estalo a cada minuto de jogo com chance 1/CLICK_ODDS: espalha os estalos
-- (todos no mesmo minuto viraria metrônomo).
local CLICK_ODDS = 2

-- Agachado e sem correr: o Estalador não tem como saber que o jogador está ali.
local function silent(p)
    return p:isSneaking() and not p:isRunning() and not p:isSprinting()
end

-- OnZombieUpdate dispara antes da máquina de estados do zumbi (bytecode
-- IsoZombie.updateInternal: evento em 696, IsoGameCharacter.update em 1029), e
-- o spot só faz setTarget (IsoPlayer.TestZombieSpotPlayer → spottedNew). Tirar
-- o alvo aqui é o que o próprio jogo faz pra zumbi "useless" ou na fumaça
-- (spottedNew 191–235). Som não passa por alvo: o Estalador continua indo até ele.
local function onUpdate(z, report)
    if not NOM_NightStats.night or z:isRemoteZombie() or not z:hasModData() then return end
    local md = z:getModData()
    local v = md.NOM_variant
    if v == nil then return end
    local t = z:getTarget()
    local player = t ~= nil and instanceof(t, "IsoPlayer")
    if v == "estalador" then
        if player and not md.NOM_alert and silent(t) then z:setTarget(nil) end
    elseif v == "corredor" then
        if player and not md.NOM_hunting then report(z) end
        md.NOM_hunting = player or nil
    end
end

-- Golpe é barulho: o Estalador acertado passa a seguir quem bateu.
-- ponytail: alerta até o zumbi ir pro virtual ou amanhecer; esfriar com o tempo se pedirem.
local function onHit(z)
    if not z:hasModData() then return end
    local md = z:getModData()
    if md.NOM_variant == "estalador" then md.NOM_alert = true end
end

-- Estalo de aviso, tocado em toda cópia local (remota também): cada jogador
-- ouve o que está perto dele, sem rede.
local function clicks()
    if not NOM_NightStats.night then return end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:hasModData() and z:getModData().NOM_variant == "estalador" and not z:isDead()
            and ZombRand(CLICK_ODDS) == 0 then
            z:getEmitter():playSound(NOM_VariantAI.CLICK_SOUND)
        end
    end
end

-- report(z): Corredor dono passou a ter um jogador como alvo.
function NOM_VariantAI.install(report)
    Events.OnZombieUpdate.Add(function(z) onUpdate(z, report) end)
    Events.OnHitZombie.Add(onHit)
    Events.EveryOneMinute.Add(clicks)
end

return NOM_VariantAI
