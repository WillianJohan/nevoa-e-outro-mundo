-- Gritos ambiente da névoa (sprint 0048, produto §3.1.1): só neste cliente, sem rede e
-- sem horda. Agenda pela regra pura (NOM_AmbientScreamRules); toca num emitter do pool
-- longe do jogador (getFreeEmitter + playSoundImpl, pz-api-notes §22 / NOM_Siren).
-- Desliga com FogAmbience. Preta: silêncio.
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_AmbientScreamRules"

NOM_AmbientScream = {
    UPDATE_TICKS = 20,
}
local S = NOM_AmbientScream
local A = NOM_AmbientScreamRules

local nextAt -- timestamp do próximo grito (nil = ainda não agendou)
local ticks = 0

-- Cor jogável: inclui rising/omen (fuga ~30 s). `.black`/`.red` sozinhos
-- tratam risingBlack como branca e ligam gritos na subida da preta.
local function color()
    return NOM_FogState.color()
end

local function schedule(now, c)
    local gap = A.gap(c, ZombRand(A.GAP[c].max - A.GAP[c].min + 1))
    nextAt = now + gap
end

-- Toca um grito agora (debug ou agenda). Devolve a mensagem de log ou nil.
function S.play(p)
    if not p or p:isDead() then return nil end
    local c = color()
    if not A.enabled(NOM_Config.get("FogAmbience"), c) then return "ambiente off" end
    local name = A.pick(ZombRand(#A.SOUNDS))
    local dist = A.distance(c, ZombRand(A.DIST[c].max - A.DIST[c].min + 1))
    local bearing = A.bearing(ZombRand(360))
    local x, y = A.spot(p:getX(), p:getY(), dist, bearing)
    local z = p:getZ()
    getWorld():getFreeEmitter(x, y, z):playSoundImpl(name, false, nil)
    if getDebug() then
        print("[NOM] ambient scream " .. name .. " dist=" .. dist .. " cor=" .. c)
    end
    return name .. " dist=" .. math.floor(dist)
end

local function onTick()
    ticks = ticks + 1
    if ticks < S.UPDATE_TICKS then return end
    ticks = 0
    local now = getTimestampMs()
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then
        nextAt = nil
        return
    end
    if not NOM_FogState.visible() then
        nextAt = nil
        return
    end
    local c = color()
    if not A.enabled(NOM_Config.get("FogAmbience"), c) then
        nextAt = nil
        return
    end
    if nextAt == nil then
        schedule(now, c)
        return
    end
    if now < nextAt then return end
    S.play(p)
    schedule(now, c)
end

Events.OnTick.Add(onTick)

return NOM_AmbientScream
