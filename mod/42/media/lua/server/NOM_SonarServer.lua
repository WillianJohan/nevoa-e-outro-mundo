-- Sonar do Estalador (sprint 0037, spec §6), lado do servidor (ADR-002/005): decide o estalo,
-- anda o anel e decide quem ele achou, igual pra todos.
-- * Estalo: com a névoa aberta (NOM_World.fog), cada Estalador vivo (o sorteio pelo
--   persistentOutfitID, como o grito do Corredor no server/NOM_Variants.lua) estala a cada
--   R.gap(ZombRand(GAP_ROLL)) ms (5 a 30 s), sorteado de novo a cada estalo, se há jogador a
--   até SEND_RANGE no andar dele. O relógio (S.clock) é o tempo real do OnTick que para na
--   pausa (isGamePaused): não depende do tamanho do dia. A lista de zumbis é lida a cada
--   SCAN_MS (acha Estalador novo, tira quem saiu); a agenda é conferida a cada SAMPLE_MS.
-- * Anel: anda no OnTick em tempo real (getTimestampMs, parado com isGamePaused), RANGE tiles
--   em DURATION_MS. Quem ele cruza no mesmo andar é conferido: em pé (isSneaking falso) ou
--   andando (posição amostrada a cada SAMPLE_MS) é achado; agachado e parado, passa.
--   isSneaking chega ao servidor no pacote do jogador (NetworkPlayerVariables
--   .getBooleanVariables 5–12 / setBooleanVariables 2–8, NetworkPlayerAI.parse(PlayerPacket)
--   221–224); a posição também (Prediction.position).
-- * Quem aplica: no solo este processo (NOM_Sonar.ring e NOM_Sonar.found direto); no
--   dedicado "sonar" { x, y, z, id } vai só a quem está a até SEND_RANGE, e "sonarFound"
--   { id, pl } a todos (o dono do Estalador pode ser qualquer cliente), e o dono aplica
--   (shared/NOM_Sonar.lua).
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
-- next[z] = { at = S.clock do próximo estalo, pid = persistentOutfitID, seen = passada }.
NOM_SonarServer = { rings = {}, emitted = 0, found = 0, passed = 0, sheltered = 0, dropped = 0, clock = 0, next = {} }
local S = NOM_SonarServer
-- samples[p] = { x0, y0 = amostra anterior, x1, y1 = a última, lx, ly = posição do último tick
-- lido (o anel não é pulado entre ticks) }. ponytail: chave é o objeto do jogador; quem sai
-- fica até reiniciar (um por jogador), como o NOM_Variants.
local samples = {}
local lastMs, sampledAt, scannedAt
local pending, scans = 0, 0 -- ms ainda não somados ao relógio; passadas na lista
local scratch = {} -- mexer na tabela no meio do pairs não é seguro no Kahlua (NOM_VariantAI)

local function debugLog(msg)
    if getDebug() then print("[NOM] sonar " .. msg) end
end

-- Jogadores vivos com a posição deste tick e a do último tick lido: { p, x, y, z, px, py }.
local function read()
    local out = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then
            local s = samples[p]
            out[#out + 1] = { p = p, x = p:getX(), y = p:getY(), z = p:getZ(), px = s and s.lx, py = s and s.ly }
        end
    end
    return out
end

local function remember(players)
    for _, e in ipairs(players) do
        local s = samples[e.p]
        if s ~= nil then s.lx, s.ly = e.x, e.y end
    end
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

-- Interior de o (jogador ou zumbi), pra casa proteger (NOM_SonarRules.sheltered):
-- sq:isOutside() lê a flag "exterior" do square (IsoGridSquare.isOutside 0–10; o vanilla
-- compara o isOutside de dois squares em shared/RadioCom/ISRadioInteractions.lua:185) e
-- sq:getBuilding() é o prédio da sala, ou nil (IsoGridSquare.getBuilding 0–15; comparado com
-- ~= em client/ISUI/ISWorldObjectContextMenu.lua:1679). Sem square: nil (não sabe).
local function where(o)
    local sq = o:getCurrentSquare()
    if sq == nil then return nil, nil end
    if sq:isOutside() then return false, nil end
    return true, sq:getBuilding()
end

-- Lotado (MAX_RINGS): sai o anel vivo mais longe de todo jogador, se ele já não alcança
-- ninguém (além de REACH) e está mais longe que o novo; senão o novo não nasce. Anel anunciado
-- é sempre simulado até o fim. Devolve se o novo cabe.
local function room(x, y, zz, players)
    if #S.rings < R.MAX_RINGS then return true end
    players = players or read()
    local worst, worstD = nil, R.REACH * R.REACH
    for i, ring in ipairs(S.rings) do
        local d = R.nearest2(ring.x, ring.y, ring.z, players)
        if d > worstD then worst, worstD = i, d end
    end
    if worst == nil or R.nearest2(x, y, zz, players) >= worstD then return false end
    table.remove(S.rings, worst)
    return true
end

-- Um anel agora em (x, y, z). z: o Estalador (nil: anel de debug, só visual). why: log.
-- players: o read() deste tick (nil: lê). Devolve false se lotado (nada é anunciado).
function S.emit(z, x, y, zz, why, players)
    if not room(x, y, zz, players) then
        S.dropped = S.dropped + 1
        debugLog("lotado, estalo descartado por=" .. tostring(why) .. " x=" .. math.floor(x) .. " y=" .. math.floor(y))
        return false
    end
    local id = z and z:getOnlineID() or -1
    local ring = { x = x, y = y, z = zz, age = 0, zombie = z, id = id, hit = {} }
    if z then
        ring.pid = z:getPersistentOutfitID() -- conferido antes de aplicar (objeto reaproveitado)
        ring.inside, ring.building = where(z) -- onde o Estalador estalou
    end
    S.rings[#S.rings + 1] = ring
    S.emitted = S.emitted + 1
    if isServer() then
        -- só a quem está perto: sendServerCommand(jogador, módulo, comando, args)
        -- (server/ClientCommands.lua:477, pz-api-notes §7)
        local args = { x = x, y = y, z = zz, id = id }
        for _, e in ipairs(players or read()) do
            if R.hears(x, y, e.x, e.y) then sendServerCommand(e.p, MODULE, "sonar", args) end
        end
    else
        NOM_Sonar.ring(x, y, zz)
    end
    debugLog("estalo por=" .. tostring(why) .. " x=" .. math.floor(x) .. " y=" .. math.floor(y) .. " z=" .. zz ..
        " estalador=" .. tostring(z ~= nil))
    return true
end

-- O anel cruzou o jogador e (do read): confere e decide, uma vez por anel e jogador.
local function check(ring, e)
    if ring.zombie == nil or ring.hit[e.p] then return end
    ring.hit[e.p] = true
    local dist = math.floor(math.sqrt((e.x - ring.x) ^ 2 + (e.y - ring.y) ^ 2) * 10 + 0.5) / 10
    local pIn, pBld = where(e.p)
    if R.sheltered(pIn, pBld, ring.inside, ring.building) then
        S.sheltered = S.sheltered + 1
        debugLog("passou pela casa dist=" .. dist .. " jogador_dentro=" .. tostring(pIn) ..
            " estalador_dentro=" .. tostring(ring.inside))
        return
    end
    local sneaking = e.p:isSneaking()
    local s = samples[e.p]
    local moving = s ~= nil and R.moving(s.x0, s.y0, e.x, e.y)
    if not R.exposed(sneaking, moving) then
        S.passed = S.passed + 1
        debugLog("passou agachado e parado dist=" .. dist)
        return
    end
    -- o objeto do zumbi vai pro pool e volta como outro (resetForReuse): o anel deixa de achar
    if ring.zombie:getPersistentOutfitID() ~= ring.pid then
        ring.zombie = nil
        debugLog("estalador reaproveitado no meio do anel, achado descartado")
        return
    end
    S.found = S.found + 1
    if isServer() then
        sendServerCommand(MODULE, "sonarFound", { id = ring.id, pl = e.p:getOnlineID(), pid = ring.pid })
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

local function isEco(z)
    return z:getModData().NOM_eco == true or z:getOutfitName() == ECO_OUTFIT
end

local function estaladorCfg()
    return NOM_VariantRules.config(NOM_Config.get), NOM_Fog.period(), NOM_World.red, NOM_World.black
end

local function schedule(e) e.at = S.clock + R.gap(ZombRand(R.GAP_ROLL)) end

-- Passada na lista: Estalador vivo novo entra na agenda com o primeiro intervalo sorteado
-- (cada um o seu: não estalam juntos); quem saiu da lista, morreu ou virou Eco sai.
-- Custo: 2 chamadas por zumbi (get, getPersistentOutfitID) e 3 por Estalador.
local function scan()
    scans = scans + 1
    local cfg, period, red, black = estaladorCfg()
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        local pid = z:getPersistentOutfitID()
        if NOM_VariantRules.variant(pid, period, cfg, red, black) == "estalador" and not z:isDead() and not isEco(z) then
            local e = S.next[z]
            if e == nil or e.pid ~= pid then -- novo, ou objeto reaproveitado pra outro zumbi
                e = { pid = pid }
                schedule(e)
                S.next[z] = e
            end
            e.seen = scans
        end
    end
    local n = 0
    for z, e in pairs(S.next) do
        if e.seen ~= scans then
            n = n + 1
            scratch[n] = z
        end
    end
    for i = 1, n do
        S.next[scratch[i]] = nil
        scratch[i] = nil
    end
end

-- Quem venceu o intervalo estala (se ainda há jogador perto) e sorteia o próximo.
local function clicks(players)
    local n = 0
    for z, e in pairs(S.next) do
        if S.clock >= e.at then
            n = n + 1
            scratch[n] = z
        end
    end
    for i = 1, n do
        local z = scratch[i]
        scratch[i] = nil
        schedule(S.next[z])
        if not z:isDead() then
            local x, y, zz = z:getX(), z:getY(), math.floor(z:getZ())
            if R.near(x, y, zz, players) then S.emit(z, x, y, zz, "tempo", players) end
        end
    end
end

-- O relógio soma o tempo real dos ticks (no máximo MAX_STEP_MS cada); com o jogo pausado o
-- que se acumulou desde a última conferência é jogado fora. Sem anel, a pausa é conferida só
-- na amostra (a cada SAMPLE_MS): até 250 ms de pausa podem entrar no relógio.
function S.tick()
    local n = #S.rings
    if n == 0 and not NOM_World.fog then
        if lastMs ~= nil then
            lastMs, sampledAt, scannedAt, pending = nil, nil, nil, 0
            S.next = {}
        end
        return
    end
    local now = getTimestampMs()
    local dt = lastMs and math.max(0, math.min(now - lastMs, MAX_STEP_MS)) or 0
    lastMs = now
    pending = pending + dt
    local due = NOM_World.fog and (sampledAt == nil or now - sampledAt >= R.SAMPLE_MS)
    if n == 0 and not due then return end
    if isGamePaused() then
        pending = 0
        return
    end
    S.clock = S.clock + pending
    pending = 0
    local players = read()
    if due then
        sampledAt = now
        sample(players)
        if #players > 0 then
            if scannedAt == nil or S.clock - scannedAt >= R.SCAN_MS then
                scannedAt = S.clock
                scan()
            end
            clicks(players)
        end
    end
    if #S.rings > 0 then advance(players, dt) end
    remember(players)
end

-- NOM.sonar() (debug): o estalo do Estalador vivo mais perto de p (mesmo andar, até
-- DEBUG_REACH); sem Estalador (ou sem névoa), um anel na posição de p, só visual.
function S.force(p)
    local px, py, pz = p:getX(), p:getY(), math.floor(p:getZ())
    local best, bestD
    if NOM_World.fog then
        local cfg, period, red, black = estaladorCfg()
        local reach = R.DEBUG_REACH * R.DEBUG_REACH
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if NOM_VariantRules.variant(z:getPersistentOutfitID(), period, cfg, red, black) == "estalador"
                and not z:isDead() and math.floor(z:getZ()) == pz and not isEco(z) then
                local dx, dy = z:getX() - px, z:getY() - py
                local d = dx * dx + dy * dy
                if d <= reach and (bestD == nil or d < bestD) then best, bestD = z, d end
            end
        end
    end
    if best then
        if S.next[best] then schedule(S.next[best]) end -- não estala de novo logo depois
        if not S.emit(best, best:getX(), best:getY(), pz, "debug") then return "sonar lotado (" .. R.MAX_RINGS .. " anéis)" end
        return "sonar estalador x=" .. math.floor(best:getX()) .. " y=" .. math.floor(best:getY()) ..
            " dist=" .. math.floor(math.sqrt(bestD) + 0.5)
    end
    if not S.emit(nil, px, py, pz, "debug") then return "sonar lotado (" .. R.MAX_RINGS .. " anéis)" end
    return "sonar anel no jogador (sem Estalador a até " .. R.DEBUG_REACH .. " tiles)"
end

Events.OnTick.Add(S.tick)

return NOM_SonarServer
