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

-- Estado salvo no ModData global: { night, inNight, ids }. ids guarda o
-- persistentOutfitID exato (com a semente) de cada Eco e a noite em que nasceu:
-- o modData do zumbi não é salvo, e é por esse ID que um Eco que volta de chunk
-- descarregado é reconhecido.
local function store()
    local data = ModData.getOrCreate("NevoaEOutroMundo")
    data.eco = data.eco or {}
    data.eco.ids = data.eco.ids or {}
    return data.eco
end

-- Número da noite atual (nil antes do primeiro OnClimateTick). Abre noite nova
-- e poda IDs velhos quando a noite começa.
local function currentNight()
    if NOM_World.tod == nil then return nil end
    local s = store()
    local before = s.night
    local night = NOM_EcoRules.syncNight(s, NOM_World.night)
    if night ~= before then NOM_EcoRules.prune(s.ids, night) end
    return night
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

local function spawnFrom(body, night)
    local sq = body:getSquare()
    local list = addZombiesInOutfit(sq:getX(), sq:getY(), sq:getZ(), 1, OUTFIT, FEMALE_CHANCE)
    if not list or list:size() == 0 then
        return false
    end
    local z = list:get(0)
    -- OnZombieCreate já disparou antes do outfit ser vestido: marca aqui.
    markEco(z)
    local id = z:getPersistentOutfitID()
    if id ~= 0 then
        store().ids[id] = night
    else
        debugLog("outfit " .. OUTFIT .. " não carregou (persistentOutfitID 0)")
    end
    body:getModData().NOM_ecoReleased = true
    return true
end

-- Mesma ordem do jogo ao trocar zumbi por corpo (bytecode IsoDeadBody.<init>
-- 1177-1181). No MP o servidor não avisa os clientes (o /removezombies do admin
-- usa NetworkZombiePacker.deleteZombie, que não é exposto): manda os onlineIDs
-- e client/NOM_EcoClient.lua apaga o fantasma. -1 = sem ID de rede, não viaja.
local function removeEcos(list)
    local ids, saved = {}, store().ids
    for _, z in ipairs(list) do
        saved[z:getPersistentOutfitID()] = nil
        local online = z:getOnlineID()
        if online ~= -1 then ids[#ids + 1] = online end
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
        if not b:isAnimal() and b:hasModData() and b:getModData().NOM_eco then
            sq:removeCorpse(b, false)
            removed = removed + 1
        end
    end
    if removed > 0 then debugLog("cadaveres=" .. removed) end
    return removed
end

local function near(a, b, r2)
    local dx, dy = a.x - b.x, a.y - b.y
    return a.z == b.z and dx * dx + dy * dy <= r2
end

-- Uma passada na lista de zumbis conta os Ecos perto de cada jogador.
local function countEcosNear(cell, ps, radius)
    local counts, r2 = {}, radius * radius
    for i = 1, #ps do counts[i] = 0 end
    local list = cell:getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if isEco(z) and not z:isDead() then
            local pos = { x = math.floor(z:getX()), y = math.floor(z:getY()), z = math.floor(z:getZ()) }
            for j, p in ipairs(ps) do
                if near(pos, p, r2) then counts[j] = counts[j] + 1 end
            end
        end
    end
    return counts
end

-- Corpos ainda sem Eco no raio de qualquer jogador. Cada square é lido uma vez
-- por varredura, mesmo com jogadores juntos. Corpo já liberado é pulado antes
-- de alocar qualquer coisa; cadáver de Eco que escapou da remoção é varrido.
-- ponytail: só o andar do jogador; corpo em outro andar fica de fora.
local function bodiesAround(cell, ps, radius)
    local cands, visited = {}, {}
    for _, p in ipairs(ps) do
        for x = p.x - radius, p.x + radius do
            for y = p.y - radius, p.y + radius do
                local key = (x * 100000 + y) * 100 + p.z + 50
                if not visited[key] then
                    visited[key] = true
                    local sq = cell:getGridSquare(x, y, p.z)
                    if sq then
                        local list, sweep = sq:getDeadBodys(), false
                        for i = 0, list:size() - 1 do
                            local b = list:get(i)
                            if not b:isAnimal() then
                                local md = b:hasModData() and b:getModData() or nil
                                if md and md.NOM_eco then
                                    sweep = true
                                elseif not (md and md.NOM_ecoReleased) then
                                    cands[#cands + 1] = { body = b, x = x, y = y, z = p.z }
                                end
                            end
                        end
                        if sweep then removeEcoCorpses(sq) end
                    end
                end
            end
        end
    end
    return cands
end

local function scan()
    local night = currentNight()
    if not night or not NOM_World.night or not NOM_Config.get("EcoEnabled") then return end
    local cell = getCell()
    local radius = NOM_Config.get("EcoRadius")
    local cap = NOM_Config.get("EcoMaxPerPlayer")
    local ps = {}
    for _, p in ipairs(players()) do
        if not p:isDead() then
            ps[#ps + 1] = { x = math.floor(p:getX()), y = math.floor(p:getY()), z = math.floor(p:getZ()) }
        end
    end
    if #ps == 0 then return end
    local counts = countEcosNear(cell, ps, radius)
    local cands = bodiesAround(cell, ps, radius)
    local r2, spawned = radius * radius, 0
    for i, p in ipairs(ps) do
        local quota = NOM_EcoRules.quota(cap, counts[i])
        for _, c in ipairs(NOM_EcoRules.pick(cands, p.x, p.y, p.z, radius, quota)) do
            if spawnFrom(c.body, night) then
                c.released = true
                spawned = spawned + 1
                -- o Eco novo conta no teto de todo jogador perto dele
                for j, q in ipairs(ps) do
                    if near(c, q, r2) then counts[j] = counts[j] + 1 end
                end
            end
        end
    end
    if spawned > 0 then debugLog("spawn=" .. spawned) end
end

-- Eco que volta de chunk descarregado: o modData dele não foi salvo, só o
-- persistentOutfitID. ID exato conhecido → veste pelo próprio ID (o jogo faria
-- isso depois, preguiçoso) e confirma pelo nome; se não bater, a lista de mods
-- mudou o índice do outfit e o ID sai.
local toCheck = {}
local function onZombieCreate(z)
    local id = z:getPersistentOutfitID()
    if id == 0 then return end
    local ids = store().ids
    if ids[id] == nil then return end
    z:dressInPersistentOutfitID(id)
    if z:getOutfitName() ~= OUTFIT then
        ids[id] = nil
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
    store().ids[z:getPersistentOutfitID()] = nil
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
    -- OnClimateTick) → espera. Regra do GDD: Eco de outra noite, ou de dia, sai.
    if #toCheck > 0 then
        local night = currentNight()
        if night then
            local gone, ids = {}, store().ids
            for _, z in ipairs(toCheck) do
                if isEco(z) and not z:isDead()
                    and not NOM_EcoRules.keepReloaded(ids[z:getPersistentOutfitID()], night, NOM_World.night) then
                    gone[#gone + 1] = z
                end
            end
            toCheck = {}
            removeEcos(gone)
        end
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
    if flag ~= "night" then return end
    currentNight()
    if not on then
        removeEcos(loadedEcos())
    end
end)

Events.EveryTenMinutes.Add(scan)
Events.OnZombieCreate.Add(onZombieCreate)
Events.OnZombieDead.Add(onZombieDead)
Events.OnTick.Add(onTick)
