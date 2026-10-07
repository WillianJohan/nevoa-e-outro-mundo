if isClient() then return end

-- Poste que pisca (sprint 0045): na névoa preta e na vermelha, de tempos em tempos um poste de fora
-- perto de um jogador gagueja (NOM_FlickerRules.lamp). O servidor sorteia e manda a posição e o
-- padrão ("lampFlicker", pra todos); quem desenha toca na cor da luz (client/NOM_LampFlickerFx.lua).
-- No solo, direto. Na preta, o poste piscando não congela o Tição (NOM_TicaoLight.lampFlicker).
-- Só luz com getLocalToBuilding() == nil: a de dentro de prédio tem a cor reescrita pelo
-- IsoLightSource.update() (pz-api-notes §34). A lista de postes do dedicado é o UNKNOWN da §31.
require "NOM_World"
require "NOM_Players"
require "NOM_FlickerRules"
require "NOM_LightRules"
require "NOM_Math"

NOM_LampFlicker = { off = {} } -- off[chave] = até quando (ms) o poste está no padrão

local L = NOM_LampFlicker
local R = NOM_FlickerRules
local MODULE = "NevoaEOutroMundo"
local nextCheck = nil

local function debugLog(msg)
    if getDebug() then print("[NOM] poste " .. msg) end
end

local function rnd() return ZombRand(1000) / 1000 end

function L.isOff(x, y, z, now) return (L.off[R.lampKey(x, y, z)] or 0) > now end

local function busy(now)
    local n, gone = 0, {}
    for k, u in pairs(L.off) do
        if u > now then n = n + 1 else gone[#gone + 1] = k end
    end
    for _, k in ipairs(gone) do L.off[k] = nil end
    return n
end

local function nearAny(x, y, pos)
    local r2 = R.LAMP_NEAR * R.LAMP_NEAR
    for _, p in ipairs(pos) do
        local dx, dy = x - p[1], y - p[2]
        if dx * dx + dy * dy <= r2 then return true end
    end
    return false
end

-- Um poste que pode piscar perto de alguma das posições, andando LAMP_TRIES pela lista.
local function pick(pos, now)
    local list = getCell():getLamppostPositions()
    local size = list:size()
    if size == 0 or #pos == 0 then return nil end
    local start = ZombRand(size)
    for i = 0, math.min(R.LAMP_TRIES, size) - 1 do
        local s = list:get(NOM_Math.mod(start + i, size))
        if s ~= nil and s:isActive() and s:getLocalToBuilding() == nil
            and s:getRadius() >= NOM_LightRules.FIXED_MIN then
            local x, y, z = s:getX(), s:getY(), s:getZ()
            if nearAny(x, y, pos) and not L.isOff(x, y, z, now) then return x, y, z end
        end
    end
    return nil
end

local function start(x, y, z, now)
    local segs = R.lamp(rnd)
    local untilMs = now + R.total(segs)
    L.off[R.lampKey(x, y, z)] = untilMs
    if NOM_TicaoLight then NOM_TicaoLight.lampFlicker(R.lampKey(x, y, z), untilMs) end
    if isServer() then
        sendServerCommand(MODULE, "lampFlicker", { x = x, y = y, z = z, segs = segs })
    elseif NOM_LampFlickerFx then
        NOM_LampFlickerFx.play(x, y, z, segs)
    end
    debugLog("piscou em " .. x .. "," .. y .. "," .. z .. " (" .. #segs .. " trechos)")
end

local function positions()
    local pos = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then pos[#pos + 1] = { p:getX(), p:getY() } end
    end
    return pos
end

function L.tick()
    if not (NOM_World.fog and (NOM_World.red or NOM_World.black)) then
        if nextCheck ~= nil then
            nextCheck = nil
            L.off = {}
        end
        return
    end
    local now = getTimestampMs()
    if nextCheck == nil then nextCheck = now + R.LAMP_CHECK_MS end
    if now < nextCheck then return end
    nextCheck = now + R.LAMP_CHECK_MS
    if ZombRand(100) >= R.LAMP_CHANCE or busy(now) >= R.LAMP_MAX then return end
    local x, y, z = pick(positions(), now)
    if x then start(x, y, z, now) end
end

-- Pro debug: pisca já um poste perto do jogador (sem sorteio nem teto, em qualquer névoa).
function L.force(player)
    local now = getTimestampMs()
    local x, y, z = pick({ { player:getX(), player:getY() } }, now)
    if not x then return nil end
    start(x, y, z, now)
    return x, y, z
end

Events.OnTick.Add(L.tick)

return NOM_LampFlicker
