-- Eco: à noite, corpo perto de jogador solta uma alma fraca, uma vez na vida.
-- Só no servidor (no solo o servidor roda no mesmo processo).
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_EcoRules"

local OUTFIT = "NOM_Eco" -- media/clothing/clothing.xml
local HEALTH = 0.3       -- vanilla "normal" nasce com 1.5 ± 0.3 (createZombieOutsideWorld)
local FEMALE_CHANCE = 50
-- Ticks procurando o cadáver depois do OnZombieDead: o corpo nasce no fim da
-- animação de morte, não no evento. Depois disso, a varredura periódica limpa.
local CORPSE_TICKS = 600

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

-- Mesma ordem do jogo ao trocar zumbi por corpo (bytecode IsoDeadBody.<init>
-- 1177-1181). No MP o servidor não avisa os clientes (o /removezombies do admin
-- usa NetworkZombiePacker.deleteZombie, que não é exposto): manda os onlineIDs
-- e client/NOM_EcoClient.lua apaga o fantasma.
local function removeEcos(list)
    local ids = {}
    for _, z in ipairs(list) do
        ids[#ids + 1] = z:getOnlineID()
        z:removeFromWorld()
        z:removeFromSquare()
    end
    if isServer() and #ids > 0 then
        sendServerCommand("NevoaEOutroMundo", "ecoGone", { ids = ids })
    end
    if #list > 0 then debugLog("removidos=" .. #list) end
end

local function loadedEcos()
    local out, list = {}, getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if isEco(z) and not z:isDead() then out[#out + 1] = z end
    end
    return out
end

-- Corpo de Eco carrega o modData do Eco (o construtor do IsoDeadBody copia).
-- removeCorpse(body, false) no servidor avisa os clientes (RemoveCorpseFromMap).
local function removeEcoCorpses(sq)
    local list, removed = sq:getDeadBodys(), 0
    for i = list:size() - 1, 0, -1 do
        local b = list:get(i)
        if not b:isAnimal() and b:getModData().NOM_eco then
            sq:removeCorpse(b, false)
            removed = removed + 1
        end
    end
    if removed > 0 then debugLog("cadaveres=" .. removed) end
    return removed
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
            local cands = bodiesAround(cell, px, py, pz, radius)
            for _, c in ipairs(cands) do
                -- rede de segurança: cadáver de Eco que escapou da remoção
                if c.eco then removeEcoCorpses(c.body:getSquare()) end
            end
            for _, c in ipairs(NOM_EcoRules.pick(cands, radius, quota)) do
                if spawnFrom(c.body) then spawned = spawned + 1 end
            end
        end
    end
    if spawned > 0 then debugLog("spawn=" .. spawned) end
end

-- Eco que volta de chunk descarregado: o modData dele não foi salvo, só o
-- persistentOutfitID. Chave conhecida → veste pelo próprio ID (o jogo faria isso
-- depois, preguiçoso) e confirma pelo nome; chave velha (lista de mods mudou) sai.
local toCheck = {}
local function onZombieCreate(z)
    local id = z:getPersistentOutfitID()
    local key = NOM_EcoRules.outfitKey(id)
    if not key then return end
    local keys = outfitKeys()
    if not keys[key] then return end
    z:dressInPersistentOutfitID(id)
    if z:getOutfitName() ~= OUTFIT then
        keys[key] = nil
        return
    end
    markEco(z)
    toCheck[#toCheck + 1] = z
end

local dying = {}
local function onZombieDead(z)
    if not isEco(z) then return end
    -- DoZombieInventory já rodou antes do evento (bytecode IsoZombie.onKilled)
    z:getInventory():removeAllItems()
    dying[#dying + 1] = { x = math.floor(z:getX()), y = math.floor(z:getY()), z = math.floor(z:getZ()), ticks = CORPSE_TICKS }
end

-- O corpo pode cair no square vizinho durante a animação de morte.
local function sweepAround(cell, d)
    local removed = 0
    for x = d.x - 1, d.x + 1 do
        for y = d.y - 1, d.y + 1 do
            local sq = cell:getGridSquare(x, y, d.z)
            if sq then removed = removed + removeEcoCorpses(sq) end
        end
    end
    return removed
end

local function onTick()
    -- Não dá pra remover dentro do OnZombieCreate: o jogo põe o zumbi na lista
    -- da célula depois do evento. Hora ainda desconhecida (antes do primeiro
    -- OnClimateTick) → espera.
    if #toCheck > 0 and NOM_World.tod ~= nil then
        local gone = {}
        if not NOM_World.night then
            for _, z in ipairs(toCheck) do
                if isEco(z) and not z:isDead() then gone[#gone + 1] = z end
            end
        end
        toCheck = {}
        removeEcos(gone)
    end
    if #dying == 0 then return end
    local cell = getCell()
    for i = #dying, 1, -1 do
        local d = dying[i]
        d.ticks = d.ticks - 1
        if sweepAround(cell, d) > 0 or d.ticks <= 0 then
            table.remove(dying, i)
        end
    end
end

NOM_World.onChange(function(flag, on)
    if flag == "night" and not on then
        removeEcos(loadedEcos())
    end
end)

Events.EveryTenMinutes.Add(scan)
Events.OnZombieCreate.Add(onZombieCreate)
Events.OnZombieDead.Add(onZombieDead)
Events.OnTick.Add(onTick)
