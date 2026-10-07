-- Perambular na névoa (sprint 0036, spec §5), lado do servidor (ADR-002/005): decide
-- quando sai uma onda e a semente dela. A cada NOM_WanderRules.gap minutos de jogo com a
-- névoa aberta (NOM_World.fog, que só abre depois da fuga da sirene) e a opção FogWander
-- ligada. Quem simula escolhe os zumbis e manda andar (shared/NOM_Wander.lua): no solo é
-- este processo; no dedicado vai "wander" { seed } a todos os clientes
-- (client/NOM_VariantsClient.lua).
-- ZombRand(n): server/ClientCommands.lua:120. EveryOneMinute: já usado (pz-api-notes §7).
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_WanderRules"
require "NOM_Wander"

local MODULE = "NevoaEOutroMundo"

NOM_WanderServer = { left = nil, waves = 0 }
local S = NOM_WanderServer

local function roll() return ZombRand(10000) / 10000 end

-- Uma onda agora. why: "tempo" ou "debug" (log do -debug).
function S.wave(why)
    local seed = ZombRand(1000000) + 1
    S.waves = S.waves + 1
    if isServer() then
        sendServerCommand(MODULE, "wander", { seed = seed })
    else
        NOM_Wander.wave(seed)
    end
    if getDebug() then print("[NOM] perambular onda por=" .. tostring(why) .. " semente=" .. seed) end
    return seed
end

function S.minute()
    if not NOM_World.fog or not NOM_Config.get("FogWander") then
        S.left = nil
        return
    end
    if S.left == nil then S.left = NOM_WanderRules.gap(roll()) end
    S.left = S.left - 1
    if S.left > 0 then return end
    S.left = NOM_WanderRules.gap(roll())
    S.wave("tempo")
end

Events.EveryOneMinute.Add(S.minute)

return NOM_WanderServer
