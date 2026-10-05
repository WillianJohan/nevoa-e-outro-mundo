-- Variantes noturnas, lado do servidor (ADR-005/ADR-006): decide o grito do
-- Corredor. O alvo do zumbi só existe em quem o simula, então quem vê o
-- Corredor pegar um jogador é o NOM_VariantAI (solo: aqui mesmo; MP: o cliente
-- dono, que manda "corredorSaw"). O servidor não confia no aviso: confere a
-- variante pelo próprio sorteio, a noite e o cooldown.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_VariantRules"
require "NOM_VariantAI"
require "NOM_NightCount"
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
    return NOM_VariantRules.variant(z:getPersistentOutfitID(), NOM_NightCount.current(), cfg) == "corredor"
end

-- Som: no dedicado sendPlaySound manda aos clientes perto (FishingNet.lua:86;
-- só age com GameServer.server); no solo toca no emitter do zumbi. Atração é
-- outra coisa: addSound pelo NOM_Night.call, com o alcance compensado pela
-- audição da noite.
local function scream(z)
    if not NOM_World.night or not isCorredor(z) then return end
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

-- args vem do cliente: só número, e -1 (sem ID de rede) nunca casa.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "corredorSaw" then return end
    local id = args and args.id
    if type(id) ~= "number" or id == -1 then return end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then
            scream(z)
            return
        end
    end
end)
