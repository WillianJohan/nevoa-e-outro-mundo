-- Almas esqueléticas (sprint 0050): quem simula aplica look, seek e som de evento.
-- O servidor agenda leva/TTL (server/NOM_AlmaServer.lua); aqui o dono do zumbi
-- (isLocal, ADR-005) manda pathToLocationF pro jogador vivo mais perto e mantém
-- o esqueleto negro. Sem API de rede: o pacote do dono leva a posição.
require "NOM_AlmaRules"
require "NOM_VariantWardrobe"

NOM_Alma = {}
local R = NOM_AlmaRules

local function debugLog(msg)
    if getDebug() then print("[NOM] alma " .. msg) end
end

function NOM_Alma.is(z)
    if not z or z:isDead() then return false end
    local md = z:getModData()
    return md and md.NOM_alma == true
end

-- Look mínimo: esqueleto vanilla (setSkeleton) + vida baixa. Crawler veio no spawn.
-- Evidência: pz-api-notes (setSkeleton queimado; addZombiesInOutfit longa com crawler).
-- Lote 2: variantes A1–A5 (bíblia §9). A2–A4 tentam ItemVisual; falha → fica A1.
function NOM_Alma.dress(z, crawler)
    local md = z:getModData()
    md.NOM_alma = true
    md.NOM_almaCrawler = crawler == true
    z:setHealth(R.HEALTH)
    local ok, err = pcall(function() z:setSkeleton(true) end)
    if not ok then debugLog("setSkeleton falhou: " .. tostring(err)) end
    if crawler then
        local ok2, err2 = pcall(function()
            if z.setCrawler then z:setCrawler(true) end
            if z.setCanWalk then z:setCanWalk(false) end
        end)
        if not ok2 then debugLog("crawler: " .. tostring(err2)) end
    end
    local id = z.getPersistentOutfitID and z:getPersistentOutfitID() or 0
    local variant = NOM_VariantWardrobe.pick("alma", id)
    if variant then
        md.NOM_almaVar = variant.id
        md.NOM_almaTrail = variant.trail == true or nil
        if variant.pieces and #variant.pieces > 0 and z.getItemVisuals and ItemVisual then
            local ok3, err3 = pcall(function()
                local list = z:getItemVisuals()
                for _, piece in ipairs(variant.pieces) do
                    local iv = ItemVisual.new()
                    iv:setItemType(piece.type)
                    NOM_VariantWardrobe.treat(iv, piece, variant)
                    list:add(iv)
                end
                if z.resetModelNextFrame then z:resetModelNextFrame() end
            end)
            if not ok3 then debugLog("alma wardrobe: " .. tostring(err3)) end
        end
    end
end

-- Jogadores vivos neste processo (mesmo padrão do NOM_Wander / NOM_SirenFreeze).
local function nearestPlayer(z)
    local best, bestD2
    local zx, zy, zz = z:getX(), z:getY(), math.floor(z:getZ())
    local function consider(p)
        if not p or p:isDead() then return end
        if math.floor(p:getZ()) ~= zz then return end
        local dx, dy = p:getX() - zx, p:getY() - zy
        local d2 = dx * dx + dy * dy
        if bestD2 == nil or d2 < bestD2 then
            best, bestD2 = p, d2
        end
    end
    for i = 0, getNumActivePlayers() - 1 do
        consider(getSpecificPlayer(i))
    end
    if isClient() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do consider(list:get(i)) end
    end
    return best
end

-- Seek lento: path pro tile do jogador. Shambler/crawler do jogo limitam a velocidade.
function NOM_Alma.seek(z)
    if not z:isLocal() or z:isDead() or z:isUseless() then return false end
    local p = nearestPlayer(z)
    if not p then return false end
    z:pathToLocationF(p:getX(), p:getY(), p:getZ())
    return true
end

-- Som de evento (crawl/shamble): no emitter do zumbi, sem chamar horda.
function NOM_Alma.eventSound(z)
    if z:isDead() then return end
    local name = R.loopSound(z:getModData().NOM_almaCrawler == true)
    local ok, err = pcall(function() z:getEmitter():playSound(name) end)
    if not ok then debugLog("som: " .. tostring(err)) end
end

-- Tick do dono (ADR-005): seek e som. No solo o mesmo processo; no MP, cada cliente
-- nos zumbis locais. O servidor só agenda spawn/TTL (NOM_AlmaServer).
local installed
function NOM_Alma.install()
    if installed then return end
    installed = true
    Events.OnTick.Add(function()
        if isGamePaused and isGamePaused() then return end
        local now = getTimestampMs()
        local list = getCell() and getCell():getZombieList()
        if not list then return end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if NOM_Alma.is(z) and z:isLocal() then
                local md = z:getModData()
                if (md.NOM_almaSeekAt or 0) <= now then
                    NOM_Alma.seek(z)
                    md.NOM_almaSeekAt = now + R.SEEK_MS
                end
                if (md.NOM_almaSoundAt or 0) <= now then
                    NOM_Alma.eventSound(z)
                    md.NOM_almaSoundAt = now + R.SOUND_EVENT_MS
                end
            end
        end
    end)
end

-- Marca no cliente de MP (modData do servidor não chega): onlineID → crawler.
function NOM_Alma.markRemote(z, crawler)
    if not z or z:isDead() then return end
    NOM_Alma.dress(z, crawler == true)
end

return NOM_Alma
