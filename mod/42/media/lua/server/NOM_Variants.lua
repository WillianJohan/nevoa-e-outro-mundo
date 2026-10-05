-- Variantes da névoa, lado do servidor (ADR-005/ADR-006): decide o grito do
-- Corredor. O alvo do zumbi só existe em quem o simula, então quem vê o
-- Corredor pegar um jogador é o NOM_VariantAI (solo: aqui mesmo; MP: o cliente
-- dono, que manda "corredorSaw"). O servidor não confia no aviso: confere a
-- variante pelo próprio sorteio (período de névoa), a névoa e o cooldown.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_VariantRules"
require "NOM_VariantAI"
require "NOM_Fog"
require "NOM_Night"

local MODULE = "NevoaEOutroMundo"
local SCREAM_SOUND = "NOM_CorredorScream" -- media/scripts/NOM_sounds.txt
local ECO_OUTFIT = "NOM_Eco"

local function debugLog(msg)
    if getDebug() then print("[NOM] variantes " .. msg) end
end

local function isCorredor(z)
    if z:isDead() then return false end
    if z:getModData().NOM_eco or z:getOutfitName() == ECO_OUTFIT then return false end
    local cfg = NOM_VariantRules.config(NOM_Config.get)
    return NOM_VariantRules.variant(z:getPersistentOutfitID(), NOM_Fog.period(), cfg, NOM_World.red) == "corredor"
end

-- Som: no dedicado sendPlaySound manda aos clientes perto (FishingNet.lua:86;
-- só age com GameServer.server); no solo toca no emitter do zumbi. Atração é
-- outra coisa: addSound pelo NOM_Night.call, com o alcance compensado pela
-- audição da noite (só à noite). O Corredor só existe na névoa, de dia ou de noite.
local function scream(z)
    if not NOM_World.fog or not isCorredor(z) then return end
    local md = z:getModData()
    local now = getGameTime():getWorldAgeHours()
    if not NOM_VariantRules.screamReady(md.NOM_screamAt, now) then return end
    md.NOM_screamAt = now
    if isServer() then
        sendPlaySound(SCREAM_SOUND, false, z)
    else
        z:getEmitter():playSound(SCREAM_SOUND)
    end
    local radius = NOM_Config.get("CorredorScreamRadius")
    NOM_Night.call(z, radius)
    debugLog("grito x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY()) .. " raio=" .. radius)
end

-- Solo: este processo simula os zumbis (no dedicado é o cliente dono).
if not isServer() then NOM_VariantAI.install(scream) end

-- O aviso vem do cliente, que pode mentir. Além da variante, da névoa e do
-- cooldown (scream), só vale de quem está perto do zumbi, e cada jogador manda
-- no máximo um aviso a cada RATE_MS de relógio real (contando os inválidos).
local SENDER_RANGE = 25
local RATE_MS = 2000
-- ponytail: chave é o objeto do jogador; quem desconecta fica na tabela até o
-- servidor reiniciar (um número por jogador). Limpar no desconectar se crescer.
local lastSaw = {}

local function rateOk(player)
    local now = getTimestampMs()
    local last = lastSaw[player]
    if last and now - last < RATE_MS then return false end
    lastSaw[player] = now
    return true
end

-- args: só número, e -1 (sem ID de rede) nunca casa.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "corredorSaw" then return end
    if not rateOk(player) then return end
    local id = args and args.id
    if type(id) ~= "number" or id == -1 then return end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then
            if player:DistTo(z:getX(), z:getY()) <= SENDER_RANGE then scream(z) end
            return
        end
    end
end)
