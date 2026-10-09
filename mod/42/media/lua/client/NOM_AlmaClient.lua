-- Cliente: FX negro + sons das almas (sprint 0050) e remoção no MP.
-- Não decide spawn/TTL: só aplica o que o servidor mandou (ADR-002).
if isServer() then return end

require "NOM_AlmaRules"
require "NOM_Alma"
require "NOM_ScreenFx"

NOM_AlmaClient = { parts = {}, pendingBorn = {} }
NOM_Alma.install() -- dono no MP aplica seek/som
local C = NOM_AlmaClient
local R = NOM_AlmaRules
local TEX = "media/textures/NOM/NOM_Cinza.png"
local LIFE_MS = 900
local MAX_PARTS = 48
local BORN_RETRY_TICKS = 90 -- ~1,5 s a 60 fps se o zumbi ainda não replicou

local function debugLog(msg)
    if getDebug() then print("[NOM] almaFx " .. msg) end
end

-- Rajada de partículas pretas no chão (overlay de tela, como lascas/cinza).
local function burst(x, y, z, n)
    local now = getTimestampMs()
    for i = 1, n do
        if #C.parts >= MAX_PARTS then table.remove(C.parts, 1) end
        C.parts[#C.parts + 1] = {
            x = x + (ZombRand(100) - 50) / 100,
            y = y + (ZombRand(100) - 50) / 100,
            z = z,
            born = now,
            life = LIFE_MS + ZombRand(400),
            size = 6 + ZombRand(10),
            rise = 0.15 + ZombRand(20) / 100,
        }
    end
end

local function playAt(name, x, y, z)
    local sq = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if sq then
        local ok, err = pcall(function()
            getSoundManager():PlayWorldSound(name, sq, 0, 25, 1.0, false)
        end)
        if ok then return end
        debugLog("PlayWorldSound: " .. tostring(err))
    end
    local p = getSpecificPlayer(0)
    if p then pcall(function() p:getEmitter():playSound(name) end) end
end

function C.fx(args)
    if type(args) ~= "table" then return end
    local kind, x, y, z = args.kind, args.x, args.y, args.z
    if type(x) ~= "number" or type(y) ~= "number" then return end
    z = z or 0
    if kind == "spawn" then
        playAt(R.SOUND.spawn, x, y, z)
        burst(x, y, z, 8)
    elseif kind == "despawn" then
        playAt(R.SOUND.despawn, x, y, z)
        burst(x, y, z, 10)
    elseif kind == "group" then
        playAt(R.SOUND.group, x, y, z)
        burst(x, y, z, 4)
    end
end

local function draw(el, now)
    if #C.parts == 0 then return end
    local tex = getTexture(TEX)
    if not tex then return end
    local zoom = 1
    if getCore then
        local ok, z = pcall(function() return getCore():getZoom(0) end)
        if ok and z then zoom = math.max(z, 0.25) end
    end
    for i = #C.parts, 1, -1 do
        local p = C.parts[i]
        local age = now - p.born
        if age >= p.life then
            table.remove(C.parts, i)
        else
            local t = age / p.life
            local wx, wy, wz = p.x, p.y, p.z + p.rise * t
            local sx = isoToScreenX(0, wx, wy, wz)
            local sy = isoToScreenY(0, wx, wy, wz)
            local a = (1 - t) * 0.85
            local s = math.max(1, p.size * (0.7 + 0.5 * (1 - t)) / zoom)
            el:drawTextureScaled(tex, sx - s / 2, sy - s / 2, s, s, a, 0.05, 0.05, 0.06)
        end
    end
end

NOM_ScreenFx.extra[#NOM_ScreenFx.extra + 1] = draw
Events.OnMainMenuEnter.Add(function() C.parts = {}; C.pendingBorn = {} end)

-- Marca local: modData do servidor não chega (ADR-006 / Eco). Devolve true se achou.
local function tryMarkBorn(id, crawler)
    local cell = getCell()
    if not cell then return false end
    local list = cell:getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then
            NOM_Alma.markRemote(z, crawler == true)
            return true
        end
    end
    return false
end

local function onServerCommand(module, command, args)
    if module ~= "NevoaEOutroMundo" then return end
    if command == "almaFx" then
        C.fx(args)
    elseif command == "almaBorn" and type(args) == "table" and type(args.id) == "number" and args.id ~= -1 then
        if not tryMarkBorn(args.id, args.crawler == true) then
            C.pendingBorn[#C.pendingBorn + 1] = {
                id = args.id, crawler = args.crawler == true, left = BORN_RETRY_TICKS,
            }
        end
    elseif command == "almaGone" and type(args) == "table" and type(args.ids) == "table" then
        local gone = {}
        for _, id in ipairs(args.ids) do gone[id] = true end
        gone[-1] = nil
        -- tira da fila de retry se o servidor já removeu
        if #C.pendingBorn > 0 then
            local keep = {}
            for i = 1, #C.pendingBorn do
                if not gone[C.pendingBorn[i].id] then keep[#keep + 1] = C.pendingBorn[i] end
            end
            C.pendingBorn = keep
        end
        local list = getCell():getZombieList()
        for i = list:size() - 1, 0, -1 do
            local z = list:get(i)
            if gone[z:getOnlineID()] then
                z:removeFromWorld()
                z:removeFromSquare()
            end
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnTick.Add(function()
    if #C.pendingBorn == 0 then return end
    local left = {}
    for i = 1, #C.pendingBorn do
        local e = C.pendingBorn[i]
        if tryMarkBorn(e.id, e.crawler) then
            -- ok
        elseif e.left > 1 then
            e.left = e.left - 1
            left[#left + 1] = e
        else
            debugLog("almaBorn timeout id=" .. tostring(e.id))
        end
    end
    C.pendingBorn = left
end)

return NOM_AlmaClient
