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
-- cfg = NOM_VariantRules.config(...) (opcional: quem varre a lista passa
-- um só pra todos).
-- O sorteio (uma chamada Java, o ID) vem primeiro: a varredura passa por todo
-- zumbi carregado a cada SCAN_TICKS na névoa, e o comum para aí.
function NOM_SemRosto.isSemRosto(z, period, cfg)
    if not period then return false end
    cfg = cfg or NOM_VariantRules.config(NOM_Config.get)
    if not NOM_VariantRules.semRosto(z:getPersistentOutfitID(), period, cfg) then return false end
    if z:isDead() then return false end
    return not ((z:hasModData() and z:getModData().NOM_eco) or z:getOutfitName() == ECO_OUTFIT)
end

-- Chão onde o Sem-rosto pode reaparecer: square existe, livre e não é água.
-- Também é a conferência do servidor (server/NOM_Fog.lua).
-- isFree(false): client/ISUI/ISWorldObjectContextMenu.lua:2199;
-- água: server/Fishing/BuildingObjects/FishingNet.lua:31.
function NOM_SemRosto.floorOk(sq)
    return sq ~= nil and sq:isFree(false) and not sq:getProperties():has(IsoFlagType.water)
end

-- IsoGameCharacter.teleportTo(III) põe o zumbi no canto do tile (setX(int)) e
-- faz setLastX/Y + ensureOnTile, sem rede. Depois, centro do tile (setX/setY e
-- setLastX/setLastY, públicos em IsoMovingObject). Vale onde o zumbi é simulado;
-- no MP o pacote do dono leva a posição nova (NetworkZombiePacker.applyZombie
-- aceita a do dono).
function NOM_SemRosto.move(z, x, y, zz)
    z:teleportTo(x, y, zz)
    z:setX(x + 0.5)
    z:setY(y + 0.5)
    z:setLastX(x + 0.5)
    z:setLastY(y + 0.5)
end

local function localPlayers()
    local out = {}
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then out[#out + 1] = p end
    end
    return out
end

-- Nenhum jogador local tem linha de visão pro tile (isCouldSee: sem depender de
-- luz). Tela dividida conta todos; o dono do MP confere os dele antes de mover.
function NOM_SemRosto.hidden(sq, players)
    for _, p in ipairs(players or localPlayers()) do
        if sq:isCouldSee(p:getPlayerNum()) then return false end
    end
    return true
end

-- Visto ou iluminado: o square do zumbi com isCanSee(pn), que já junta linha de
-- visão, cone e luz (LightingJNI bit 2). É o teste do próprio jogo pra "o
-- jogador vê este zumbi" (IsoZombie.checkZombieEntersPlayerBuilding 26–44).
-- Mesmo andar (math.floor: jogador na escada tem z quebrado).
local function seenBy(p, z)
    if math.floor(p:getZ()) ~= math.floor(z:getZ()) then return false end
    if dist(p:getX(), p:getY(), z:getX(), z:getY()) > R.REPORT_RANGE then return false end
    local sq = z:getCurrentSquare()
    return sq ~= nil and sq:isCanSee(p:getPlayerNum())
end

-- Primeiro tile atrás do jogador, mais perto que o zumbi, chão livre e fora da
-- linha de visão de todos os jogadores locais. nil se não houver.
local function destination(p, z, players)
    local px, py = p:getX(), p:getY()
    local pz = math.floor(p:getZ())
    local r = R.nextRadius(dist(px, py, z:getX(), z:getY()))
    local cell = getCell()
    -- getDirection em radianos: shared/Fishing/FishingRod.lua:286
    for _, s in ipairs(R.spots(px, py, p:getForwardDirection():getDirection(), r)) do
        local sq = cell:getGridSquare(s.x, s.y, pz)
        if NOM_SemRosto.floorOk(sq) and NOM_SemRosto.hidden(sq, players) then return s.x, s.y, pz end
    end
    return nil
end

local function scan(report)
    if not NOM_FogState.on or not NOM_Config.get("SemRostoEnabled") then
        known = {}
        return
    end
    local found, now, players = {}, getTimestampMs(), localPlayers()
    local cfg = NOM_VariantRules.config(NOM_Config.get)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if NOM_SemRosto.isSemRosto(z, NOM_FogState.period, cfg) then
            found[#found + 1] = z
            if R.ready(lastReport[z], now) then
                for _, p in ipairs(players) do
                    if seenBy(p, z) then
                        -- colado: não some, ataca (R.ATTACK_DIST)
                        if R.vanishes(dist(p:getX(), p:getY(), z:getX(), z:getY())) then
                            local x, y, zz = destination(p, z, players)
                            if x then
                                lastReport[z] = now
                                report(z, x, y, zz, p)
                                if getDebug() then
                                    print("[NOM] semrosto visto x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY())
                                        .. " para x=" .. x .. " y=" .. y)
                                end
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
        if not z:isDead() and math.floor(z:getZ()) == math.floor(p:getZ()) then
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
