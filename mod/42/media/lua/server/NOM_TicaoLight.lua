-- A luz congela o Tição (sprint 0038), lado do servidor: quem está na luz é decisão daqui
-- (ADR-002/005). Na preta, a cada tick confere uma fatia dos zumbis (NOM_LightRules.batch: todos a
-- cada SWEEP_MS) contra as luzes dos jogadores; aceso = congelado até HOLD_MS depois de sair da
-- luz. A cada SWEEP_MS a lista vai pro dono: no solo direto (NOM_TicaoFreeze.apply), no dedicado
-- pelo comando "ticaoFrozen" com os onlineIDs.
--
-- Luzes (javap de projectzomboid.jar, pz-api-notes §30): IsoPlayer.getActiveLightItem() (o
-- vanilla sincroniza o liga/desliga: client/ISUI/ISInventoryPaneContextMenu.lua:2883, já usado no
-- server/NOM_Night.lua), InventoryItem.isTorchCone()Z, getLightDistance()I, getTorchDot()F,
-- IsoGameCharacter.getForwardDirectionX()/Y()F, getVehicle(), BaseVehicle.getHeadlightsOn()Z
-- (server/Vehicles/Vehicles.lua:565). Luz fixa (cômodo aceso, poste) fica pra 0039.
--
-- A lanterna pisca (tarefa 5): a cada FLICKER_CHECK_MS, cada lanterna acesa sorteia; a que
-- apaga não congela ninguém nesse tempo e os Tições que ela segurava soltam na hora. O apagar é
-- local no dono da lanterna (NOM_TicaoFreeze.flicker), sem sync: no solo direto, no dedicado
-- pelo comando "torchFlicker" só pra ele.
if isClient() then return end

require "NOM_World"
require "NOM_Players"
require "NOM_LightRules"
require "NOM_TicaoFreeze"
require "NOM_Math"

local MODULE = "NevoaEOutroMundo"
local R = NOM_LightRules

NOM_TicaoLight = { untilMs = {}, by = {}, flickerUntil = {} }
local T = NOM_TicaoLight
local lights, cursor, lastMs, nextGather, nextSend, nextFlicker = {}, 0, nil, 0, 0, nil
local sentEmpty = true

local function debugLog(msg)
    if getDebug() then print("[NOM] ticao luz " .. msg) end
end

-- Luzes acesas agora, com o jogador dono. Lanterna em flicker não conta.
local function gather(now)
    local out = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() and not ((T.flickerUntil[p] or 0) > now) then
            local v = p:getVehicle()
            local l
            if v ~= nil then
                if v:getHeadlightsOn() then
                    l = R.headlight()
                    l.x, l.y, l.z = v:getX(), v:getY(), math.floor(v:getZ())
                end
            else
                local item = p:getActiveLightItem()
                if item ~= nil then
                    l = R.fromItem(item:isTorchCone(), item:getLightDistance(), item:getTorchDot())
                    if l then
                        l.x, l.y, l.z = p:getX(), p:getY(), math.floor(p:getZ())
                        l.fx, l.fy = p:getForwardDirectionX(), p:getForwardDirectionY()
                    end
                end
            end
            if l then
                l.owner = p
                out[#out + 1] = l
            end
        end
    end
    return out
end

-- Fatia do rodízio: 2 chamadas (x, y) por zumbi longe de toda luz; perto, + andar e morto.
local function check(z, now)
    local zx, zy = z:getX(), z:getY()
    local zz
    for _, l in ipairs(lights) do
        local dx, dy = zx - l.x, zy - l.y
        local reach = l.range + R.BODY
        if dx * dx + dy * dy <= reach * reach then
            zz = zz or z:getZ()
            if R.lit(l, zx, zy, zz) and not z:isDead() then
                T.untilMs[z] = now + R.HOLD_MS
                T.by[z] = l.owner
                return
            end
        end
    end
end

local function frozenList(now)
    local zs, gone = {}, {}
    for z, u in pairs(T.untilMs) do
        if u > now then zs[#zs + 1] = z else gone[#gone + 1] = z end
    end
    for _, z in ipairs(gone) do
        T.untilMs[z] = nil
        T.by[z] = nil
    end
    return zs
end

local function send(zs)
    if not isServer() then
        NOM_TicaoFreeze.apply(zs)
        return
    end
    if #zs == 0 and sentEmpty then return end
    local ids = {}
    for _, z in ipairs(zs) do
        local id = z:getOnlineID()
        if id ~= -1 then ids[#ids + 1] = id end
    end
    sendServerCommand(MODULE, "ticaoFrozen", { ids = ids })
    sentEmpty = #zs == 0
end

local function flickerOne(p, ms, now)
    T.flickerUntil[p] = now + ms
    for z, owner in pairs(T.by) do
        if owner == p then T.untilMs[z] = 0 end
    end
    if isServer() then
        sendServerCommand(p, MODULE, "torchFlicker", { ms = ms })
    else
        NOM_TicaoFreeze.flicker(p, ms)
    end
    debugLog("lanterna piscou por " .. ms .. " ms")
end

local function flickers(now)
    if nextFlicker == nil then nextFlicker = now + R.FLICKER_CHECK_MS end
    if now < nextFlicker then return end
    nextFlicker = now + R.FLICKER_CHECK_MS
    for _, l in ipairs(lights) do
        if l.fx ~= nil then -- só lanterna na mão (farol e lampião não piscam)
            local ms = R.flicker(ZombRand(100), ZombRand(1000) / 1000)
            if ms then flickerOne(l.owner, ms, now) end
        end
    end
end

-- Fim da preta: a lista vazia vai uma vez (o dono solta), e tudo zera.
local function stop()
    T.untilMs, T.by, T.flickerUntil = {}, {}, {}
    lights, lastMs, nextFlicker = {}, nil, nil
    send({})
end

local wasBlack = false

function T.tick()
    if not NOM_World.black then
        if wasBlack then
            wasBlack = false
            stop()
        end
        return
    end
    wasBlack = true
    local now = getTimestampMs()
    local dt = lastMs and math.min(now - lastMs, R.SWEEP_MS) or R.SWEEP_MS
    lastMs = now
    if now >= nextGather then
        flickers(now) -- antes da leitura: a lanterna que apaga já sai da lista nova
        lights = gather(now)
        nextGather = now + R.SWEEP_MS
    end
    if #lights > 0 then
        local list = getCell():getZombieList()
        local size = list:size()
        local n = R.batch(size, dt)
        for k = 0, n - 1 do check(list:get(NOM_Math.mod(cursor + k, size)), now) end
        cursor = size > 0 and NOM_Math.mod(cursor + n, size) or 0
    end
    if now >= nextSend then
        nextSend = now + R.SWEEP_MS
        send(frozenList(now))
    end
end

-- Pro debug: congelados agora (no servidor).
function T.count()
    local n, now = 0, getTimestampMs()
    for _, u in pairs(T.untilMs) do if u > now then n = n + 1 end end
    return n
end

local function forget(z)
    T.untilMs[z] = nil
    T.by[z] = nil
end

Events.OnTick.Add(T.tick)
Events.OnZombieDead.Add(forget)
if not isServer() then NOM_TicaoFreeze.install() end

return NOM_TicaoLight
