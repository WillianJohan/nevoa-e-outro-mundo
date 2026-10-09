if isClient() then return end

-- Tempestade da névoa preta e da vermelha (sprint 0045): com a névoa aberta, de THUNDER_MIN_MS a
-- THUNDER_MAX_MS um relâmpago longe de um jogador sorteado, com clarão e trovão e sem raio
-- caindo: ThunderStorm.triggerThunderEvent(x, y, false, true, true); no servidor o jogo
-- transmite pros clientes, no solo enfileira direto (pz-api-notes §34; vanilla em
-- server/ClientCommands.lua:657-664). Na preta o clarão congela os Tições perto dos jogadores
-- (NOM_TicaoLight.flash) e o cliente pinta o clarão de vermelho (0053, NOM_StormFx).
-- A chuva é do server/NOM_ClimateLook.lua. A branca fica como está.
require "NOM_World"
require "NOM_Players"
require "NOM_StormRules"

-- rainForced: o debug força chuva nas névoas pretas e vermelhas (NOM.rain), só em memória.
NOM_Storm = { rainForced = false }

local S = NOM_Storm
local R = NOM_StormRules
local MODULE = "NevoaEOutroMundo"
local nextAt = nil

local function debugLog(msg)
    if getDebug() then print("[NOM] tempestade " .. msg) end
end

local function rnd() return ZombRand(1000) / 1000 end

-- Avisa o cliente do clarão vermelho (overlay sem mod3). No dedicado, comando de rede; no
-- solo, chama NOM_StormFx.flash direto se o cliente já carregou.
local function tellFlash()
    if isServer() then
        sendServerCommand(MODULE, "thunderFlash", {})
    elseif NOM_StormFx then
        NOM_StormFx.flash()
    end
end

local function strike(player, now)
    local x, y = R.thunderPoint(player:getX(), player:getY(), rnd(), rnd())
    getClimateManager():getThunderStorm():triggerThunderEvent(x, y, false, true, true)
    if NOM_World.black then
        if NOM_TicaoLight then NOM_TicaoLight.flash(now) end
        tellFlash()
    end
    debugLog("relâmpago em " .. x .. "," .. y)
    return x, y
end

local function alive()
    local out = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then out[#out + 1] = p end
    end
    return out
end

function S.tick()
    if not (NOM_World.fog and (NOM_World.red or NOM_World.black)) then
        nextAt = nil
        return
    end
    local now = getTimestampMs()
    if nextAt == nil then nextAt = now + R.nextThunder(rnd()) end
    if now < nextAt then return end
    nextAt = now + R.nextThunder(rnd())
    local ps = alive()
    if #ps > 0 then strike(ps[ZombRand(#ps) + 1], now) end
end

-- Pro debug: relâmpago já perto do jogador, em qualquer tempo.
function S.force(player) return strike(player, getTimestampMs()) end

Events.OnTick.Add(S.tick)

return NOM_Storm
