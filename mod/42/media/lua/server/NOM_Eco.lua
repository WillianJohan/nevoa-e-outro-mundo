-- Eco: à noite, corpo perto de jogador solta uma alma fraca, uma vez na vida.
-- Só no servidor (no solo o servidor roda no mesmo processo).
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_EcoRules"
require "NOM_Players"
require "NOM_NightCount"

local OUTFIT = "NOM_Eco" -- media/clothing/clothing.xml
local HEALTH = 0.3       -- vanilla "normal" nasce com 1.5 ± 0.3 (createZombieOutsideWorld)
local FEMALE_CHANCE = 50
-- Ticks procurando o cadáver depois do OnZombieDead: o corpo nasce no fim da
-- animação de morte, não no evento. Depois disso, a varredura periódica limpa.
local CORPSE_TICKS = 600

local function debugLog(msg)
    if getDebug() then print("[NOM] eco " .. msg) end
end

-- Estado salvo no ModData global: { night, inNight, ids } (night/inNight são do
-- NOM_NightCount). ids guarda o
-- persistentOutfitID exato (com a semente) de cada Eco e as noites em que um Eco
-- com esse ID nasceu (NOM_EcoRules.prune explica os gêmeos):
-- o modData do zumbi não é salvo, e é por esse ID que um Eco que volta de chunk
-- descarregado é reconhecido.
local function store()
    local data = ModData.getOrCreate("NevoaEOutroMundo")
    data.eco = data.eco or {}
    data.eco.ids = data.eco.ids or {}
    return data.eco
end

-- Número da noite atual (nil antes do primeiro OnClimateTick), do contador
-- compartilhado. Poda os IDs velhos uma vez por noite nova (e uma vez por boot).
local prunedFor
local function currentNight()
    local night = NOM_NightCount.current()
    if night and night ~= prunedFor then
        NOM_EcoRules.prune(store().ids, night)
        prunedFor = night
    end
    return night
end

local function markEco(z)
    z:getModData().NOM_eco = true
    z:setHealth(HEALTH)
end

local function isEco(z)
    return z:getModData().NOM_eco == true
end

NOM_Eco = {}

-- Um Eco em (x, y, zz), contado na noite night. Devolve o zumbi ou nil.
local function spawn(x, y, zz, night)
    local list = addZombiesInOutfit(x, y, zz, 1, OUTFIT, FEMALE_CHANCE)
    if not list or list:size() == 0 then
        return nil
    end
    local z = list:get(0)
    -- OnZombieCreate já disparou antes do outfit ser vestido: marca aqui.
    markEco(z)
    local id = z:getPersistentOutfitID()
    if id ~= 0 then
        local ids = store().ids
        ids[id] = ids[id] or {}
        ids[id][night] = true
    else
        debugLog("outfit " .. OUTFIT .. " não carregou (persistentOutfitID 0)")
    end
    return z
end

local function spawnFrom(body, night)
    -- corpo da lista compartilhada da varredura pode ter sido removido entre ticks
    local sq = body:getSquare()
    if not sq then return false end
    if not spawn(sq:getX(), sq:getY(), sq:getZ(), night) then return false end
    body:getModData().NOM_ecoReleased = true
    return true
end

-- Mesma ordem do jogo ao trocar zumbi por corpo (bytecode IsoDeadBody.<init>
-- 1177-1181). No MP o servidor não avisa os clientes (o /removezombies do admin
-- usa NetworkZombiePacker.deleteZombie, que não é exposto): manda os onlineIDs
-- e client/NOM_EcoClient.lua apaga o fantasma. -1 = sem ID de rede, não viaja.
local function removeEcos(list)
    -- O ID fica na lista: um gêmeo descarregado pode ter o mesmo (só a poda tira).
    local ids = {}
    for _, z in ipairs(list) do
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

-- Debug (server/NOM_DebugServer.lua): Eco sem corpo, só à noite (de dia não
-- haveria amanhecer pra levá-lo).
function NOM_Eco.spawnAt(x, y, zz)
    local night = currentNight()
    if not night or not NOM_World.night then return false end
    return spawn(x, y, zz, night) ~= nil
end

function NOM_Eco.loaded()
    return #loadedEcos()
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

-- Ecos vivos perto do jogador p (uma passada na lista de zumbis). Conta também os
-- que a varredura acabou de spawnar pra outro jogador: o Eco novo entra no teto de
-- todo jogador perto dele.
local function countEcosNear(cell, p, radius)
    local n, r2 = 0, radius * radius
    local list = cell:getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if isEco(z) and not z:isDead() then
            local pos = { x = math.floor(z:getX()), y = math.floor(z:getY()), z = math.floor(z:getZ()) }
            if near(pos, p, r2) then n = n + 1 end
        end
    end
    return n
end

-- Junta em cands os corpos ainda sem Eco no raio do jogador p. visited vale pela
-- varredura inteira: square já lido pra outro jogador não é lido de novo, e o
-- corpo dele já está em cands. Corpo já liberado é pulado antes de alocar
-- qualquer coisa; cadáver de Eco que escapou da remoção é varrido.
-- ponytail: só o andar do jogador; corpo em outro andar fica de fora.
local function bodiesAround(cell, p, radius, visited, cands)
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

-- Varredura em andamento: { ps, i, visited, cands, night, radius, cap, spawned }.
-- Um jogador por tick (o pico é o raio de um jogador, (2R+1)² squares, não N×).
local scanning

local function startScan()
    scanning = nil
    local night = currentNight()
    if not night or not NOM_World.night or not NOM_Config.get("EcoEnabled") then return end
    local ps = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then
            ps[#ps + 1] = { x = math.floor(p:getX()), y = math.floor(p:getY()), z = math.floor(p:getZ()) }
        end
    end
    if #ps == 0 then return end
    scanning = { ps = ps, i = 1, visited = {}, cands = {}, night = night, spawned = 0,
        radius = NOM_Config.get("EcoRadius"), cap = NOM_Config.get("EcoMaxPerPlayer") }
end

local function scanStep()
    local s = scanning
    if not NOM_World.night or currentNight() ~= s.night then -- amanheceu no meio
        scanning = nil
        return
    end
    local cell, p = getCell(), s.ps[s.i]
    local quota = NOM_EcoRules.quota(s.cap, countEcosNear(cell, p, s.radius))
    bodiesAround(cell, p, s.radius, s.visited, s.cands)
    for _, c in ipairs(NOM_EcoRules.pick(s.cands, p.x, p.y, p.z, s.radius, quota)) do
        if spawnFrom(c.body, s.night) then
            c.released = true
            s.spawned = s.spawned + 1
        end
    end
    s.i = s.i + 1
    if s.i > #s.ps then
        if s.spawned > 0 then debugLog("spawn=" .. s.spawned) end
        scanning = nil
    end
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
    if scanning then scanStep() end
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

Events.EveryTenMinutes.Add(startScan)
Events.OnZombieCreate.Add(onZombieCreate)
Events.OnZombieDead.Add(onZombieDead)
Events.OnTick.Add(onTick)
