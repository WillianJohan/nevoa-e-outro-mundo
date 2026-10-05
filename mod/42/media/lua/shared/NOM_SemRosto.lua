-- Sem-rosto onde os jogadores veem: no solo, o próprio processo (server/NOM_Fog.lua
-- instala); no MP, cada cliente (client/NOM_FogClient.lua instala). Ver e luz são
-- do cliente (LightingJNI), então é aqui que se descobre que um jogador olhou pro
-- Sem-rosto e pra onde ele pode ir sem ser visto. Quem decide é o servidor
-- (NOM_Fog.seen), e quem move é o dono do zumbi (ADR-007).
require "NOM_Config"
require "NOM_VariantRules"
require "NOM_SemRostoRules"
require "NOM_FogState"

NOM_SemRosto = { SCAN_TICKS = 10 }

local R = NOM_SemRostoRules
local ECO_OUTFIT = "NOM_Eco" -- media/clothing/clothing.xml

-- [zumbi] = último relato em ms reais (não piscar: o servidor também confere).
local lastReport = {}
-- Sem-rosto locais achados na última varredura (pro rádio).
local known = {}

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
end

-- period: período de névoa (nil = desconhecido, nunca é Sem-rosto). Ecos nunca
-- são: no solo pela marca do server/NOM_Eco.lua, no cliente de MP pelo outfit.
function NOM_SemRosto.isSemRosto(z, period)
    if not period or z:isDead() then return false end
    if (z:hasModData() and z:getModData().NOM_eco) or z:getOutfitName() == ECO_OUTFIT then return false end
    return NOM_VariantRules.semRosto(z:getPersistentOutfitID(), period, NOM_VariantRules.semRostoConfig(NOM_Config.get))
end

-- IsoGameCharacter.teleportTo(III): setX/Y/Z + setLastX/Y + ensureOnTile, sem
-- rede. Vale onde o zumbi é simulado; no MP o pacote do dono leva a posição nova
-- (NetworkZombiePacker.applyZombie aceita a do dono).
function NOM_SemRosto.move(z, x, y, zz)
    z:teleportTo(x, y, zz)
end

-- Visto ou iluminado: o square do zumbi com isCanSee(pn), que já junta linha de
-- visão, cone e luz (LightingJNI bit 2). É o teste do próprio jogo pra "o
-- jogador vê este zumbi" (IsoZombie.checkZombieEntersPlayerBuilding 26–44).
local function seenBy(p, z)
    if dist(p:getX(), p:getY(), z:getX(), z:getY()) > R.REPORT_RANGE then return false end
    local sq = z:getCurrentSquare()
    return sq ~= nil and sq:isCanSee(p:getPlayerNum())
end

-- Primeiro tile atrás do jogador, mais perto que o zumbi, livre e fora da linha
-- de visão dele (isCouldSee: sem depender de luz). nil se não houver.
local function destination(p, z)
    local px, py = p:getX(), p:getY()
    local pz = math.floor(p:getZ())
    local r = R.nextRadius(dist(px, py, z:getX(), z:getY()))
    local cell, pn = getCell(), p:getPlayerNum()
    -- getDirection em radianos: shared/Fishing/FishingRod.lua:286
    for _, s in ipairs(R.spots(px, py, p:getForwardDirection():getDirection(), r)) do
        local sq = cell:getGridSquare(s.x, s.y, pz)
        if sq and sq:isFree(false) and not sq:isCouldSee(pn) then return s.x, s.y, pz end
    end
    return nil
end

local function localPlayers()
    local out = {}
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then out[#out + 1] = p end
    end
    return out
end

local function scan(report)
    if not NOM_FogState.on or not NOM_Config.get("SemRostoEnabled") then
        known = {}
        return
    end
    local found, now, players = {}, getTimestampMs(), localPlayers()
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if NOM_SemRosto.isSemRosto(z, NOM_FogState.period) then
            found[#found + 1] = z
            if R.ready(lastReport[z], now) then
                for _, p in ipairs(players) do
                    if seenBy(p, z) then
                        local x, y, zz = destination(p, z)
                        if x then
                            lastReport[z] = now
                            report(z, x, y, zz, p)
                            if getDebug() then
                                print("[NOM] semrosto visto x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY())
                                    .. " para x=" .. x .. " y=" .. y)
                            end
                        end
                        break
                    end
                end
            end
        end
    end
    known = found
end

-- Distância do Sem-rosto mais perto do jogador (nil se nenhum), da última varredura.
function NOM_SemRosto.nearest(p)
    if not NOM_FogState.on then return nil end
    local best
    for _, z in ipairs(known) do
        if not z:isDead() and z:getZ() == p:getZ() then
            local d = dist(p:getX(), p:getY(), z:getX(), z:getY())
            if not best or d < best then best = d end
        end
    end
    return best
end

-- report(z, x, y, z, jogador): um jogador local viu o Sem-rosto e (x, y, z) é
-- onde ele pode reaparecer.
function NOM_SemRosto.install(report)
    local ticks = 0
    Events.OnTick.Add(function()
        ticks = ticks + 1
        if ticks < NOM_SemRosto.SCAN_TICKS then return end
        ticks = 0
        scan(report)
    end)
    NOM_FogState.onChange(function(on)
        if not on then
            known, lastReport = {}, {}
        end
    end)
end

return NOM_SemRosto
