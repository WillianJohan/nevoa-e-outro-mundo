-- Almas esqueléticas (sprint 0055, ADR-002/005): o servidor mantém população
-- viva 4–20 enquanto a névoa estiver aberta (branca/vermelha/preta); quem
-- simula aplica look/seek (shared/NOM_Alma.lua). Rua + TTL em tempo real.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_AlmaRules"
require "NOM_Alma"
require "NOM_Players"

local MODULE = "NevoaEOutroMundo"
local R = NOM_AlmaRules

NOM_AlmaServer = { nextAt = nil, waves = 0, alive = {}, pendingBorn = {} }
local S = NOM_AlmaServer

local function debugLog(msg)
    if getDebug() then print("[NOM] alma " .. msg) end
end

local function roll()
    return ZombRand(10000) / 10000
end

local function enabled()
    return NOM_Config.get("AlmaEnabled") ~= false and R.active(NOM_World)
end

-- Avisa clientes perto: FX negro + som (spawn/despawn/group).
local function fx(kind, x, y, z)
    local args = { kind = kind, x = x, y = y, z = z }
    if isServer() then
        sendServerCommand(MODULE, "almaFx", args)
    else
        -- solo: o cliente é o mesmo processo; o handler do client também roda se
        -- carregado. Dispara direto se NOM_AlmaClient existir.
        if NOM_AlmaClient and NOM_AlmaClient.fx then NOM_AlmaClient.fx(args) end
    end
end

local function outsideOk(x, y, zz)
    local sq = getCell():getGridSquare(x, y, zz)
    if not sq or not sq:isFree(false) then return false end
    if not R.streetOk(sq:isOutside()) then return false end
    local props = sq:getProperties()
    if props and props:has(IsoFlagType.water) then return false end
    return true
end

local function track(z, diesAt)
    S.alive[#S.alive + 1] = { z = z, diesAt = diesAt }
end

-- MP: modData não viaja. Se onlineID ainda é -1 no spawn, reenvia no tick.
local function announceBorn(z, crawler)
    if not isServer() then return end
    local online = z:getOnlineID()
    if online ~= -1 then
        sendServerCommand(MODULE, "almaBorn", { id = online, crawler = crawler == true })
        return
    end
    S.pendingBorn[#S.pendingBorn + 1] = { z = z, crawler = crawler == true }
end

local function flushPendingBorn()
    if not isServer() or #S.pendingBorn == 0 then return end
    local left = {}
    for i = 1, #S.pendingBorn do
        local e = S.pendingBorn[i]
        local z = e.z
        if z and not z:isDead() then
            local online = z:getOnlineID()
            if online ~= -1 then
                sendServerCommand(MODULE, "almaBorn", { id = online, crawler = e.crawler })
            else
                left[#left + 1] = e
            end
        end
    end
    S.pendingBorn = left
end

-- quiet: leva em massa — só FX de group no wave(); despawn individual fica.
local function spawnOne(px, py, pz, now, quiet)
    local pos = R.pickSpawn(px, py, pz, roll, outsideOk, 16)
    if not pos then return nil end
    local crawler = R.isCrawler(roll())
    local ttl = R.ttl(roll())
    -- versão longa: crawler + health (pz-api-notes § spawn)
    local list = addZombiesInOutfit(pos.x, pos.y, pos.z, 1, nil, R.FEMALE_CHANCE,
        crawler, false, false, false, false, false, R.HEALTH)
    if not list or list:size() == 0 then return nil end
    local z = list:get(0)
    NOM_Alma.dress(z, crawler)
    local md = z:getModData()
    md.NOM_almaUntil = now + ttl
    md.NOM_almaSeekAt = now
    md.NOM_almaSoundAt = now + math.floor(roll() * R.SOUND_EVENT_MS)
    -- shambler mancando (speedType 3); crawler já veio no spawn
    local ok, err = pcall(function() z:doZombieSpeed(3) end)
    if not ok then debugLog("speed: " .. tostring(err)) end
    track(z, now + ttl)
    if not quiet then
        fx("spawn", pos.x, pos.y, pos.z)
    end
    announceBorn(z, crawler)
    return z
end

-- Repõe população perto dos jogadores. why: "tempo" ou "debug".
function S.wave(why)
    if not enabled() and why ~= "debug" then return 0 end
    if why == "debug" and not R.active(NOM_World) then
        return 0, "almas precisam de névoa aberta"
    end
    if why == "debug" and NOM_Config.get("AlmaEnabled") == false then
        return 0, "almas desligadas na opção AlmaEnabled"
    end
    local alive = #S.alive
    local n = R.refillCount(alive, roll())
    if why == "debug" then
        -- debug: se já está no intervalo, ainda permite um top-up curto até o teto
        if n == 0 then
            n = math.min(8, R.POP_MAX - alive)
        else
            n = math.min(n, 8)
        end
        if n <= 0 then return 0, "população no teto (" .. R.POP_MAX .. ")" end
    elseif n <= 0 then
        return 0
    end
    -- nunca passar do máximo (defesa em profundidade)
    if alive + n > R.POP_MAX then n = R.POP_MAX - alive end
    if n <= 0 then return 0 end

    local spawned = 0
    local now = getTimestampMs()
    local ps = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then
            ps[#ps + 1] = { x = p:getX(), y = p:getY(), z = p:getZ() }
        end
    end
    if #ps == 0 then return 0, "sem jogador" end
    -- grupo: um FX/som de leva (sem spawn por indivíduo — evita saturar áudio/FPS)
    local groupFx = false
    for i = 1, n do
        local p = ps[1 + ((i - 1) % #ps)]
        if spawnOne(p.x, p.y, p.z, now, true) then
            spawned = spawned + 1
            if not groupFx then
                fx("group", math.floor(p.x), math.floor(p.y), math.floor(p.z))
                groupFx = true
            end
        end
    end
    S.waves = S.waves + 1
    S.nextAt = now + R.REFILL_MS
    debugLog("repor por=" .. tostring(why) .. " pedida=" .. n .. " spawn=" .. spawned
        .. " vivas=" .. #S.alive .. " proxima_ms=" .. R.REFILL_MS)
    return spawned
end

local function removeAlma(z, why)
    if not z then return end
    local x, y, zz = math.floor(z:getX()), math.floor(z:getY()), math.floor(z:getZ())
    fx("despawn", x, y, zz)
    local online = z:getOnlineID()
    z:removeFromWorld()
    z:removeFromSquare()
    if isServer() and online ~= -1 then
        sendServerCommand(MODULE, "almaGone", { ids = { online } })
    end
    debugLog("despawn por=" .. tostring(why) .. " x=" .. x .. " y=" .. y)
end

local function prune(now)
    for i = #S.alive, 1, -1 do
        local e = S.alive[i]
        local z = e.z
        if not z or z:isDead() then
            table.remove(S.alive, i)
        elseif now >= e.diesAt then
            removeAlma(z, "ttl")
            table.remove(S.alive, i)
        else
            local sq = z:getCurrentSquare()
            if sq and not R.streetOk(sq:isOutside()) then
                removeAlma(z, "interior")
                table.remove(S.alive, i)
            end
            -- seek/som: shared/NOM_Alma.install (dono do zumbi, ADR-005)
        end
    end
end

function S.clear(why)
    for i = #S.alive, 1, -1 do
        removeAlma(S.alive[i].z, why or "fim")
        table.remove(S.alive, i)
    end
    S.nextAt = nil
end

function S.tick()
    if isGamePaused and isGamePaused() then return end
    local now = getTimestampMs()
    flushPendingBorn()
    if not enabled() then
        if #S.alive > 0 then S.clear("fora") end
        S.nextAt = nil
        S.pendingBorn = {}
        return
    end
    prune(now)
    -- no intervalo: só espera TTL/interior derrubarem; abaixo do mínimo: repor
    if #S.alive >= R.POP_MIN then
        return
    end
    if S.nextAt == nil then
        S.nextAt = now
    end
    if now >= S.nextAt then
        S.wave("tempo")
    end
end

NOM_World.onChange(function(flag, on)
    if flag == "fog" or flag == "red" or flag == "black" then
        if not R.active(NOM_World) and #S.alive > 0 then
            S.clear("fim")
        end
    end
end)

Events.OnTick.Add(S.tick)
NOM_Alma.install() -- solo: o mesmo processo simula; no dedicado o cliente também instala

return NOM_AlmaServer
