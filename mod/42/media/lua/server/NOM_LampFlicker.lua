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
require "NOM_BlackPressureRules"
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

-- Poste da rede de fora: fogo e lampião têm a cor reescrita pelo jogo (IsoFire.update) e a luz de
-- dentro de prédio pelo IsoLightSource.update (§34). Acesa e com raio de luz fixa.
local function lamp(s)
    return s:isHydroPowered() and s:getLocalToBuilding() == nil and s:getRadius() >= NOM_LightRules.FIXED_MIN
end

-- Volta pela lista da célula em fatias (a lista cobre todos os jogadores e tem centenas de luzes):
-- cache = os postes perto da última volta completa.
local cache, scanList, scanAt, scanNext, scanPos, nextScan = {}, nil, 0, {}, {}, 0

local function positions()
    local pos = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then pos[#pos + 1] = { p:getX(), p:getY() } end
    end
    return pos
end

local function scan(now)
    if scanList == nil then
        if now < nextScan then return end
        nextScan = now + R.LAMP_SCAN_MS
        scanList, scanAt, scanNext, scanPos = getCell():getLamppostPositions(), 0, {}, positions()
    end
    local size = scanList:size()
    local stop = math.min(size, scanAt + R.LAMP_BATCH)
    for i = scanAt, stop - 1 do
        local s = scanList:get(i)
        if s ~= nil and s:isActive() then
            local x, y = s:getX(), s:getY()
            if nearAny(x, y, scanPos) and lamp(s) then scanNext[#scanNext + 1] = { s = s, x = x, y = y, z = s:getZ() } end
        end
    end
    scanAt = stop
    if scanAt >= size then cache, scanList = scanNext, nil end
end

-- Um poste do cache, a partir de um sorteado, ainda aceso e fora de pisca.
local function pick(now)
    local n = #cache
    if n == 0 then return nil end
    local first = ZombRand(n)
    for i = 0, n - 1 do
        local c = cache[NOM_Math.mod(first + i, n) + 1]
        if c.s:isActive() and not L.isOff(c.x, c.y, c.z, now) then return c.x, c.y, c.z end
    end
    return nil
end

-- Na preta, o perfil de pressão aperta postes (ilhas instáveis); na vermelha ficam os defaults.
local function lampOpts()
    if NOM_World.black then return NOM_BlackPressureRules.current() end
    return nil
end

local function start(x, y, z, now)
    local opts = lampOpts()
    local segs = R.lamp(rnd, opts)
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

function L.tick()
    if not (NOM_World.fog and (NOM_World.red or NOM_World.black)) then
        if nextCheck ~= nil then
            nextCheck = nil
            L.off = {}
            cache, scanList, nextScan = {}, nil, 0
        end
        return
    end
    local now = getTimestampMs()
    scan(now)
    local opts = lampOpts()
    local checkMs = (opts and opts.lampCheckMs) or R.LAMP_CHECK_MS
    local chance = (opts and opts.lampChance) or R.LAMP_CHANCE
    if nextCheck == nil then nextCheck = now + checkMs end
    if now < nextCheck then return end
    nextCheck = now + checkMs
    if ZombRand(100) >= chance or busy(now) >= R.LAMP_MAX then return end
    local x, y, z = pick(now)
    if x then start(x, y, z, now) end
end

-- Pro debug: pisca já o poste mais perto do jogador (a lista inteira de uma vez; sem sorteio nem
-- teto, em qualquer névoa).
function L.force(player)
    local now = getTimestampMs()
    local px, py = player:getX(), player:getY()
    local list = getCell():getLamppostPositions()
    local best, bx, by, bz = R.LAMP_NEAR * R.LAMP_NEAR
    for i = 0, list:size() - 1 do
        local s = list:get(i)
        if s ~= nil and s:isActive() then
            local x, y = s:getX(), s:getY()
            local d = (x - px) * (x - px) + (y - py) * (y - py)
            if d <= best and lamp(s) and not L.isOff(x, y, s:getZ(), now) then
                best, bx, by, bz = d, x, y, s:getZ()
            end
        end
    end
    if not bx then return nil end
    start(bx, by, bz, now)
    return bx, by, bz
end

Events.OnTick.Add(L.tick)

return NOM_LampFlicker
