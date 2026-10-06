-- Comportamento das variantes onde o zumbi é simulado (ADR-005): Estalador cego,
-- Corredor que avisa, Carpideira parada (NOM_Carpideira). No solo, o
-- próprio processo (server/NOM_Variants.lua instala); no MP, o cliente
-- (client/NOM_VariantsClient.lua instala). A variante vem do NOM_NightStats
-- (modData.NOM_variant, só em memória, ADR-006). Variante só age na névoa (decisão
-- do Johan, 05/10), de dia ou de noite: tudo aqui olha o NOM_FogState. O grito do Corredor é decisão
-- do servidor: aqui só se avisa, pelo report passado no install.
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_Carpideira"
require "NOM_SirenFreeze"
require "NOM_VariantRules"
require "NOM_Config"

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
-- Só esses são desligados; useless de outro (tutorial, debug, outro mod) fica. Exposta só pra
-- leitura: o rodízio do NOM_SirenFreeze não solta o Estalador cego.
NOM_VariantAI.blinded = {}
local blinded = NOM_VariantAI.blinded

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
    -- do tutorial não dá pra distinguir: num Estalador na névoa, também cai.
    -- Custo: uma chamada Java por Estalador local por frame.
    if z:isUseless() then
        if not NOM_Carpideira.gameUseless(z) then z:setUseless(false) end
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
-- linha, com três consultas de tabela Lua e nenhuma chamada Java.
local function onUpdate(z, report)
    local kind, blind, still = NOM_NightStats.variants[z], blinded[z], NOM_Carpideira.still[z]
    if kind == nil and blind == nil and still == nil then return end
    local md = z:getModData()
    if kind ~= nil and md.NOM_variant ~= kind then -- objeto reaproveitado
        NOM_NightStats.variants[z] = nil
        kind = nil
    end
    local on = NOM_FogState.on and z:isLocal() -- dono (pz-api-notes §24)
    if kind == "estalador" and on then
        estalador(z, md, blind)
    elseif blind then
        release(z) -- névoa baixou, deixou de ser Estalador ou virou remoto
    elseif kind == "corredor" and on then
        corredor(z, md, report)
    end
    -- Carpideira (sprint 0011): parada enquanto calma; solta quando a névoa baixa,
    -- deixa de ser Carpideira ou vira remota (aí o pacote do dono manda).
    if kind == "carpideira" and on then
        NOM_Carpideira.hold(z, md)
    elseif still then
        NOM_Carpideira.letGo(z)
    end
end

-- Golpe é barulho: o Estalador acertado passa a seguir quem bateu.
-- ponytail: alerta até o zumbi ir pro virtual ou a névoa baixar; esfriar com o tempo se pedirem.
local function onHit(z)
    if blinded[z] then release(z) end
    if NOM_NightStats.variants[z] ~= "estalador" then return end
    z:getModData().NOM_alert = true
end

-- Useless herdado (review da 0011): o useless viaja no pacote do zumbi
-- (NetworkZombieAI.set → getBooleanVariables 86–89; parse 204–252) e o
-- resetForReuse não o limpa. Se o dono que parou a Carpideira (ou cegou o Estalador)
-- perde a posse, a névoa acaba ou o objeto é reaproveitado, o novo dono fica com um
-- zumbi useless que nada aqui marcou, e o onUpdate sai cedo (kind, blind e still nil).
-- Solta o useless de zumbi local que este processo não ligou, mas só de quem o mod
-- pode ter deixado useless: Carpideira ou Estalador no período de névoa atual ou no
-- anterior (o sorteio é determinístico, ADR-006), normal ou vermelha (a cor de um
-- período passado não é guardada: as duas contam). Fica: o do próprio jogo (outfit
-- "Useless"), o do tutorial (client/Tutorial/Steps.lua:847, 1107; e nada no modo
-- tutorial, getCore():getGameMode() == "Tutorial", shared/TimedActions/
-- ISGrabCorpseAction.lua:140) e o de outro mod num zumbi que nunca foi variante. O
-- useless do menu de debug numa ex-variante cai na passada seguinte.
-- Chamado pela passada do NOM_NightStats e no OnZombieCreate.
local HELD = { carpideira = true, estalador = true }

local function heldByMod(id)
    local period = NOM_FogState.period
    if not period then return false end
    local cfg = NOM_VariantRules.config(NOM_Config.get)
    for n = period - 1, period do
        if HELD[NOM_VariantRules.variant(id, n, cfg) or ""] or HELD[NOM_VariantRules.variant(id, n, cfg, true) or ""] then
            return true
        end
    end
    return false
end

local function unstick(z)
    if blinded[z] or NOM_Carpideira.still[z] or NOM_SirenFreeze.frozen[z] or not z:isLocal() or not z:isUseless() then return end
    if getCore():getGameMode() == "Tutorial" or NOM_Carpideira.gameUseless(z) then return end
    if heldByMod(z:getPersistentOutfitID()) then z:setUseless(false) end
end

-- Objeto reaproveitado pra outro zumbi (resetForReuse → OnZombieCreate) não
-- herda a cegueira nem a parada. Morto também sai da tabela.
local function forget(z)
    if blinded[z] then release(z) end
    NOM_Carpideira.forget(z)
end

local function created(z)
    forget(z)
    unstick(z)
end

-- Estalo de aviso, tocado em toda cópia local (remota também): cada jogador
-- ouve o que está perto dele, sem rede. playSoundLocal = getEmitter():playSoundImpl
-- (nome, nil), sem pacote; emitter:playSound no cliente de MP manda PacketType.PlaySound
-- (FMODSoundEmitter.playSound 0–104) e cada cliente faria os outros ouvirem de novo.
local function clicks()
    if not NOM_FogState.on then return end
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
    Events.OnZombieCreate.Add(created)
    NOM_NightStats.unstick = unstick
    Events.OnZombieDead.Add(forget)
    Events.EveryOneMinute.Add(clicks)
end

return NOM_VariantAI
