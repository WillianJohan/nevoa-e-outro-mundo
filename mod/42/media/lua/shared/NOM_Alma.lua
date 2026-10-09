-- Almas esqueléticas (sprint 0050): quem simula aplica look, seek e som de evento.
-- O servidor agenda leva/TTL (server/NOM_AlmaServer.lua); aqui o dono do zumbi
-- (isLocal, ADR-005) manda pathToLocationF pro jogador vivo mais perto e mantém
-- o esqueleto negro. Sem API de rede: o pacote do dono leva a posição.
require "NOM_AlmaRules"

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

return NOM_Alma
