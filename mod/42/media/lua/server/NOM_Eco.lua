-- Eco: à noite, corpo perto de jogador solta uma alma fraca, uma vez na vida.
-- Só no servidor (no solo o servidor roda no mesmo processo).
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_EcoRules"

local OUTFIT = "NOM_Eco" -- media/clothing/clothing.xml
local HEALTH = 0.3       -- vanilla "normal" nasce com 1.5 ± 0.3 (createZombieOutsideWorld)
local FEMALE_CHANCE = 50

local function debugLog(msg)
    if getDebug() then print("[NOM] eco " .. msg) end
end

-- Chaves de outfit (NOM_EcoRules.outfitKey) dos Ecos já spawnados. Ficam no
-- ModData global porque o modData do zumbi não é salvo: é por elas que um Eco
-- que volta de chunk descarregado é reconhecido.
local function outfitKeys()
    local data = ModData.getOrCreate("NevoaEOutroMundo")
    data.ecoOutfitKeys = data.ecoOutfitKeys or {}
    return data.ecoOutfitKeys
end

local function markEco(z)
    z:getModData().NOM_eco = true
    z:setHealth(HEALTH)
end

local function isEco(z)
    return z:getModData().NOM_eco == true
end

-- Padrão de server/XpSystem/XpUpdate.lua:294-297.
local function players()
    local out = {}
    if isServer() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    else
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p then out[#out + 1] = p end
        end
    end
    return out
end

local function spawnFrom(body)
    local sq = body:getSquare()
    local list = addZombiesInOutfit(sq:getX(), sq:getY(), sq:getZ(), 1, OUTFIT, FEMALE_CHANCE)
    if not list or list:size() == 0 then
        return false
    end
    local z = list:get(0)
    -- OnZombieCreate já disparou antes do outfit ser vestido: marca aqui.
    markEco(z)
    local key = NOM_EcoRules.outfitKey(z:getPersistentOutfitID())
    if key then
        outfitKeys()[key] = true
    else
        debugLog("outfit " .. OUTFIT .. " não carregou (persistentOutfitID 0)")
    end
    body:getModData().NOM_ecoReleased = true
    return true
end

local function ecosNear(cell, px, py, radius)
    local list = cell:getZombieList()
    local r2, n = radius * radius, 0
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if isEco(z) and not z:isDead() then
            local dx, dy = z:getX() - px, z:getY() - py
            if dx * dx + dy * dy <= r2 then n = n + 1 end
        end
    end
    return n
end

-- ponytail: só o andar do jogador; corpos em outro andar ficam de fora.
local function bodiesAround(cell, px, py, pz, radius)
    local cands = {}
    local cx, cy = math.floor(px), math.floor(py)
    for x = cx - radius, cx + radius do
        for y = cy - radius, cy + radius do
            local sq = cell:getGridSquare(x, y, pz)
            if sq then
                local list = sq:getDeadBodys()
                for i = 0, list:size() - 1 do
                    local b = list:get(i)
                    local animal = b:isAnimal()
                    local md = not animal and b:getModData() or {}
                    local dx, dy = x - cx, y - cy
                    cands[#cands + 1] = {
                        body = b, dist2 = dx * dx + dy * dy, animal = animal,
                        released = md.NOM_ecoReleased == true, eco = md.NOM_eco == true,
                    }
                end
            end
        end
    end
    return cands
end

local function scan()
    if not NOM_World.night or not NOM_Config.get("EcoEnabled") then return end
    local cell = getCell()
    local radius = NOM_Config.get("EcoRadius")
    local cap = NOM_Config.get("EcoMaxPerPlayer")
    local spawned = 0
    for _, p in ipairs(players()) do
        if not p:isDead() then
            local px, py, pz = p:getX(), p:getY(), math.floor(p:getZ())
            local quota = NOM_EcoRules.quota(cap, ecosNear(cell, px, py, radius))
            for _, c in ipairs(NOM_EcoRules.pick(bodiesAround(cell, px, py, pz, radius), radius, quota)) do
                if spawnFrom(c.body) then spawned = spawned + 1 end
            end
        end
    end
    if spawned > 0 then debugLog("spawn=" .. spawned) end
end

Events.EveryTenMinutes.Add(scan)
