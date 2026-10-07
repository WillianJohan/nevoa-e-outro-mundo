-- Sonar do Estalador (sprint 0037, spec §6), lado do servidor (ADR-002/005): decide o estalo,
-- anda o anel e decide quem ele achou, igual pra todos.
-- * Estalo: no EveryOneMinute, com a névoa aberta (NOM_World.fog), cada Estalador vivo (o
--   sorteio pelo persistentOutfitID, como o grito do Corredor no server/NOM_Variants.lua)
--   estala com chance 1/CLICK_ODDS se há jogador a até SEND_RANGE no andar dele.
-- * Anel: anda no OnTick em tempo real (getTimestampMs, parado com isGamePaused), RANGE tiles
--   em DURATION_MS. Quem ele cruza no mesmo andar é conferido: em pé (isSneaking falso) ou
--   andando (posição amostrada a cada SAMPLE_MS) é achado; agachado e parado, passa.
--   isSneaking chega ao servidor no pacote do jogador (NetworkPlayerVariables
--   .getBooleanVariables 5–12 / setBooleanVariables 2–8, NetworkPlayerAI.parse(PlayerPacket)
--   221–224); a posição também (Prediction.position).
-- * Quem aplica: no solo este processo (NOM_Sonar.ring e NOM_Sonar.found direto); no
--   dedicado "sonar" { x, y, z, id } e "sonarFound" { id, pl } vão a todos os clientes e o
--   dono do Estalador aplica (shared/NOM_Sonar.lua).
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_VariantRules"
require "NOM_Fog"
require "NOM_SonarRules"
require "NOM_Sonar"
require "NOM_Players"

local MODULE = "NevoaEOutroMundo"
local ECO_OUTFIT = "NOM_Eco"
local MAX_STEP_MS = 250 -- um engasgo não pula o anel inteiro
local R = NOM_SonarRules

-- rings: { x, y, z, age, r = raio do tick anterior (nil antes do primeiro), zombie, id }.
NOM_SonarServer = { rings = {}, emitted = 0, found = 0, passed = 0 }
local S = NOM_SonarServer
-- samples[p] = { x0, y0 = amostra anterior, x1, y1 = a última }. ponytail: chave é o objeto
-- do jogador; quem sai fica até reiniciar (um por jogador), como o NOM_Variants.
local samples = {}
local lastMs, sampledAt

local function debugLog(msg)
    if getDebug() then print("[NOM] sonar " .. msg) end
end

-- Jogadores vivos com a posição deste tick: { p, x, y, z }.
local function read()
    local out = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then out[#out + 1] = { p = p, x = p:getX(), y = p:getY(), z = p:getZ() } end
    end
    return out
end

local function sample(players)
    for _, e in ipairs(players) do
        local s = samples[e.p]
        if s == nil then
            samples[e.p] = { x0 = e.x, y0 = e.y, x1 = e.x, y1 = e.y }
        else
            s.x0, s.y0, s.x1, s.y1 = s.x1, s.y1, e.x, e.y
        end
    end
end

-- Um anel agora em (x, y, z). z: o Estalador (nil: anel de debug, só visual). why: log.
function S.emit(z, x, y, zz, why)
    if #S.rings >= R.MAX_RINGS then table.remove(S.rings, 1) end
    local id = z and z:getOnlineID() or -1
    S.rings[#S.rings + 1] = { x = x, y = y, z = zz, age = 0, zombie = z, id = id }
    S.emitted = S.emitted + 1
    if isServer() then
        sendServerCommand(MODULE, "sonar", { x = x, y = y, z = zz, id = id })
    else
        NOM_Sonar.ring(x, y, zz)
    end
    debugLog("estalo por=" .. tostring(why) .. " x=" .. math.floor(x) .. " y=" .. math.floor(y) .. " z=" .. zz ..
        " estalador=" .. tostring(z ~= nil))
end

-- O anel cruzou o jogador e (do read): confere e decide.
local function check(ring, e)
    local sneaking = e.p:isSneaking()
    local s = samples[e.p]
    local moving = s ~= nil and R.moving(s.x0, s.y0, e.x, e.y)
    local dist = math.floor(math.sqrt((e.x - ring.x) ^ 2 + (e.y - ring.y) ^ 2) * 10 + 0.5) / 10
    if not R.exposed(sneaking, moving) then
        S.passed = S.passed + 1
        debugLog("passou agachado e parado dist=" .. dist)
        return
    end
    S.found = S.found + 1
    if isServer() then
        sendServerCommand(MODULE, "sonarFound", { id = ring.id, pl = e.p:getOnlineID() })
    else
        NOM_Sonar.found(ring.zombie, e.p)
    end
    debugLog("achou jogador dist=" .. dist .. " agachado=" .. tostring(sneaking) .. " andando=" .. tostring(moving))
end

local function advance(players, dt)
    local i = 1
    while i <= #S.rings do
        local ring = S.rings[i]
        ring.age = ring.age + dt
        local r1 = R.radius(ring.age)
        -- sem Estalador (debug) ou sem ID de rede no dedicado, ninguém tem o que aplicar
        if ring.zombie ~= nil and (ring.id ~= -1 or not isServer()) then
            for _, k in ipairs(R.sweep(ring, ring.r, r1, players)) do check(ring, players[k]) end
        end
        ring.r = r1
        if R.done(ring.age) then table.remove(S.rings, i) else i = i + 1 end
    end
end

function S.tick()
    local n = #S.rings
    if n == 0 and not NOM_World.fog then
        lastMs, sampledAt = nil, nil
        return
    end
    local now = getTimestampMs()
    local dt = lastMs and math.max(0, math.min(now - lastMs, MAX_STEP_MS)) or 0
    lastMs = now
    local due = NOM_World.fog and (sampledAt == nil or now - sampledAt >= R.SAMPLE_MS)
    if n == 0 and not due then return end
    if isGamePaused() then return end
    local players = read()
    if due then
        sampledAt = now
        sample(players)
    end
    if n > 0 then advance(players, dt) end
end

local function isEco(z)
    return z:getModData().NOM_eco == true or z:getOutfitName() == ECO_OUTFIT
end

local function estaladorCfg()
    return NOM_VariantRules.config(NOM_Config.get), NOM_Fog.period(), NOM_World.red
end

-- Custo: 2 chamadas por zumbi (get, getPersistentOutfitID); o resto só no Estalador sorteado.
function S.minute()
    if not NOM_World.fog then return end
    local players = read()
    if #players == 0 then return end
    local cfg, period, red = estaladorCfg()
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if NOM_VariantRules.variant(z:getPersistentOutfitID(), period, cfg, red) == "estalador"
            and R.clicks(ZombRand(R.CLICK_ODDS)) and not z:isDead() then
            local x, y, zz = z:getX(), z:getY(), math.floor(z:getZ())
            if R.near(x, y, zz, players) and not isEco(z) then S.emit(z, x, y, zz, "tempo") end
        end
    end
end

-- NOM.sonar() (debug): o estalo do Estalador vivo mais perto de p (mesmo andar, até
-- DEBUG_REACH); sem Estalador (ou sem névoa), um anel na posição de p, só visual.
function S.force(p)
    local px, py, pz = p:getX(), p:getY(), math.floor(p:getZ())
    local best, bestD
    if NOM_World.fog then
        local cfg, period, red = estaladorCfg()
        local reach = R.DEBUG_REACH * R.DEBUG_REACH
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if NOM_VariantRules.variant(z:getPersistentOutfitID(), period, cfg, red) == "estalador"
                and not z:isDead() and math.floor(z:getZ()) == pz and not isEco(z) then
                local dx, dy = z:getX() - px, z:getY() - py
                local d = dx * dx + dy * dy
                if d <= reach and (bestD == nil or d < bestD) then best, bestD = z, d end
            end
        end
    end
    if best then
        S.emit(best, best:getX(), best:getY(), pz, "debug")
        return "sonar estalador x=" .. math.floor(best:getX()) .. " y=" .. math.floor(best:getY()) ..
            " dist=" .. math.floor(math.sqrt(bestD) + 0.5)
    end
    S.emit(nil, px, py, pz, "debug")
    return "sonar anel no jogador (sem Estalador a até " .. R.DEBUG_REACH .. " tiles)"
end

Events.EveryOneMinute.Add(S.minute)
Events.OnTick.Add(S.tick)

return NOM_SonarServer
