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

-- Janela de cegueira, em updates do zumbi, não em tempo real (~1 s a 60 FPS). Fecha sozinha e abre
-- de novo no update seguinte se o jogador ainda estiver agachado à vista: useless
-- também é surdo (RespondToSound volta cedo, bytecode 8–15), e a janela curta é o
-- que deixa o Estalador ouvir entre uma e outra.
NOM_VariantAI.BLIND_FRAMES = 60

-- Zumbis que ESTE mod deixou useless: { [zumbi] = { p = jogador, n = updates } }.
-- Só esses são desligados; useless de outro (tutorial, debug, outro mod) fica.
local blinded = {}

-- Agachado e sem correr: o Estalador não tem como saber que o jogador está ali.
local function silent(p)
    return p:isSneaking() and not p:isRunning() and not p:isSprinting()
end

local function release(z)
    blinded[z] = nil
    z:setUseless(false)
end

-- Por que useless e não só setTarget(nil): o spot dá bonusSpotTime = 720
-- (spottedNew 1909–1917), e o updateInternal refaz o spot forçado depois do
-- OnZombieUpdate e antes da máquina de estados (956–991), com setTarget e
-- pathToCharacter. Zumbi useless leva setTarget(null) e spottedLast = null no
-- spottedNew (191–208): o laço do spot forçado morre ali. A caminhada até a
-- última posição vista (WalkTowardState) continua, mas sem alvo não há ataque.
local function estalador(z, md, blind)
    if blind then
        blind.n = blind.n + 1
        if blind.n < NOM_VariantAI.BLIND_FRAMES and silent(blind.p) then return end
        release(z)
        return -- o spot volta no próximo frame; se ainda for silencioso, fecha de novo
    end
    -- useless viaja no pacote do zumbi (NetworkZombieAI.set → getBooleanVariables
    -- 86–89; parse 204–252): se a posse trocou no meio da janela, este dono herdou
    -- o useless sem a entrada em blinded. Desliga, salvo o useless do próprio jogo
    -- (outfit de debug com "Useless", updateInternal 47–58). O do menu de debug e
    -- do tutorial não dá pra distinguir: num Estalador à noite, também cai.
    -- Custo: uma chamada Java por Estalador local por frame.
    if z:isUseless() then
        local outfit = z:getOutfitName()
        -- string.find com plain: client/OptionScreens/LoadGameScreen.lua:601
        if not (outfit and string.find(outfit, "Useless", 1, true)) then z:setUseless(false) end
        return
    end
    if md.NOM_alert then return end
    local t = z:getTarget()
    if t ~= nil and instanceof(t, "IsoPlayer") and silent(t) then
        z:setTarget(nil)
        z:setUseless(true)
        blinded[z] = { p = t, n = 0 }
    end
end

local function corredor(z, md, report)
    local t = z:getTarget()
    local player = t ~= nil and instanceof(t, "IsoPlayer")
    if player and not md.NOM_hunting then report(z) end
    md.NOM_hunting = player or nil
end

-- OnZombieUpdate roda por zumbi a cada frame: o zumbi comum sai na primeira
-- linha, com duas consultas de tabela Lua e nenhuma chamada Java.
local function onUpdate(z, report)
    local kind, blind = NOM_NightStats.variants[z], blinded[z]
    if kind == nil and blind == nil then return end
    local md = z:getModData()
    if kind ~= nil and md.NOM_variant ~= kind then -- objeto reaproveitado
        NOM_NightStats.variants[z] = nil
        kind = nil
    end
    local on = NOM_NightStats.night and not z:isRemoteZombie()
    if kind == "estalador" and on then
        estalador(z, md, blind)
    elseif blind then
        release(z) -- amanheceu, deixou de ser Estalador ou virou remoto
    elseif kind == "corredor" and on then
        corredor(z, md, report)
    end
end

-- Golpe é barulho: o Estalador acertado passa a seguir quem bateu.
-- ponytail: alerta até o zumbi ir pro virtual ou amanhecer; esfriar com o tempo se pedirem.
local function onHit(z)
    if blinded[z] then release(z) end
    if NOM_NightStats.variants[z] ~= "estalador" then return end
    z:getModData().NOM_alert = true
end

-- Objeto reaproveitado pra outro zumbi (resetForReuse → OnZombieCreate) não
-- herda a cegueira. Morto também sai da tabela.
local function forget(z)
    if blinded[z] then release(z) end
end

-- Estalo de aviso, tocado em toda cópia local (remota também): cada jogador
-- ouve o que está perto dele, sem rede. playSoundLocal = getEmitter():playSoundImpl
-- (nome, nil), sem pacote; emitter:playSound no cliente de MP manda PacketType.PlaySound
-- (FMODSoundEmitter.playSound 0–104) e cada cliente faria os outros ouvirem de novo.
local function clicks()
    if not NOM_NightStats.night then return end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        -- tabela Lua antes de qualquer chamada no zumbi: o comum não custa nada
        if NOM_NightStats.variants[z] == "estalador" and z:getModData().NOM_variant == "estalador"
            and not z:isDead() and ZombRand(CLICK_ODDS) == 0 then
            z:playSoundLocal(NOM_VariantAI.CLICK_SOUND)
        end
    end
end

-- report(z): Corredor dono passou a ter um jogador como alvo.
function NOM_VariantAI.install(report)
    Events.OnZombieUpdate.Add(function(z) onUpdate(z, report) end)
    Events.OnHitZombie.Add(onHit)
    Events.OnZombieCreate.Add(forget)
    Events.OnZombieDead.Add(forget)
    Events.EveryOneMinute.Add(clicks)
end

return NOM_VariantAI
