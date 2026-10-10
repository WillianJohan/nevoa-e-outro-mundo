-- Carpideira (sprint 0011) onde ela é simulada, vista e ouvida: no solo, o próprio
-- processo (server/NOM_Variants.lua instala); no MP, cada cliente
-- (client/NOM_VariantsClient.lua instala).
-- * Quem simula (o dono, ADR-005) a deixa parada enquanto calma: useless, a mesma
--   alavanca do Estalador (sprint 0004). Chamado pelo NOM_VariantAI a cada frame.
-- * Quem a tem carregada toca o soluço local (sem rede) e avisa quando um jogador
--   local a acorda: perto (CarpideiraTriggerRadius) ou com a lanterna acesa e ela
--   vista a até ALERT_RANGE. O barulho o servidor ouve sozinho (OnWorldSound).
-- * Quem decide o grito é o servidor (server/NOM_Variants.lua); aqui ficam os
--   efeitos dele (NOM_Carpideira.scream).
require "NOM_Config"
require "NOM_CarpideiraRules"
require "NOM_VariantRules"
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_Math"

NOM_Carpideira = {
    SOB = "NOM_CarpideiraSob",       -- media/scripts/NOM_sounds.txt
    SCREAM = "NOM_CarpideiraScream", -- legado / default
    SCREAMS = { "NOM_CarpideiraScream", "NOM_CarpideiraScream2", "NOM_CarpideiraScream3" },
    SCAN_TICKS = 10,
    -- Soluça só quem está a até SOB_RANGE tiles de um jogador local (o som some a 12):
    -- a célula carregada pode ter dezenas de Carpideiras, e cada uma seria um loop.
    SOB_RANGE = 15,
    -- [persistentOutfitID] = true: já gritou nesta névoa (o servidor avisa; solo: direto).
    screamed = {},
    -- [zumbi] = true: este processo a deixou useless (só esses são soltos).
    still = {},
    -- Sprint 0052: [zumbi] = { at = ms fim do timeout, gx, gy, gz } enquanto anda chorando.
    walking = {},
    -- [zumbi] = ms reais da próxima caminhada (dono).
    nextWalk = {},
    -- Debug: força a próxima caminhada no hold seguinte (NOM.carpWalk).
    forceWalk = false,
    -- 0064 K3: [zumbi] = { p, at, started } enquanto espera getup 2c / timeout B.
    pendingGetup = {},
}

local C = NOM_Carpideira
local R = NOM_CarpideiraRules

-- Tabelas chaveadas pelo objeto do zumbi: limitadas às Carpideiras carregadas e
-- esvaziadas no reaproveitamento/morte (forget), quando o som para (sobs) ou no fim
-- da névoa (lastReport).
local sobs = {}       -- [zumbi] = id do soluço tocando
local lastReport = {} -- [zumbi] = ms reais do último aviso

-- Furiosa = já gritou nesta névoa. A marca do objeto (NOM_furia = número do período,
-- então vale só nesta névoa) é cache; a verdade é o ID (o objeto novo que volta do
-- virtual tem modData vazio). NOM_NightStats.forget apaga a marca na morte.
function C.furious(z, md)
    local period = NOM_FogState.period
    if md.NOM_furia ~= nil and md.NOM_furia == period then return true end
    if C.screamed[NOM_VariantRules.baseId(z:getPersistentOutfitID())] then
        md.NOM_furia = period
        return true
    end
    return false
end

-- Useless do próprio jogo (outfit de debug com "Useless", updateInternal 47–58): o mod
-- nunca desliga. string.find com plain: client/OptionScreens/LoadGameScreen.lua:601.
function C.gameUseless(z)
    local outfit = z:getOutfitName()
    return outfit ~= nil and string.find(outfit, "Useless", 1, true) ~= nil
end

-- Para quem já anda: PathFindState não olha useless (sirene, pz-api-notes §21).
local function halt(z)
    z:getPathFindBehavior2():cancel()
    z:setPath2(nil)
    z:setVariable("bPathfind", false)
    z:setVariable("bMoving", false)
end

local function scheduleWalk(z, now)
    local u = R.rng(NOM_VariantRules.baseId(z:getPersistentOutfitID()) + NOM_Math.mod(now, 100000))()
    C.nextWalk[z] = now + R.walkGapMs(u)
end

-- Locais + (no MP) online: o destino não deve aproximar ninguém conhecido
-- (mesmo espírito do NOM_Wander.players).
local function playersNear()
    local out = {}
    local function add(p)
        if p and not p:isDead() then
            out[#out + 1] = { x = p:getX(), y = p:getY(), z = p:getZ() }
        end
    end
    for i = 0, getNumActivePlayers() - 1 do add(getSpecificPlayer(i)) end
    if isClient() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do add(list:get(i)) end
    end
    return out
end

local function endWalk(z, now)
    C.walking[z] = nil
    halt(z)
    scheduleWalk(z, now or getTimestampMs())
end

-- Por frame, no dono, na névoa (NOM_VariantAI). Calma: useless parado, ou caminhada
-- curta chorando (sprint 0052): solta useless, pathToLocationF sem setTarget, reaplica
-- useless ao chegar/timeout. Ligado uma vez por objeto; o pacote leva o useless.
-- Orçamento: calma parada sai cedo (como na 0011) sem getPersistentOutfitID a cada frame.
function C.hold(z, md)
    -- K3 no meio do getup: não reaplica useless (senão cancela o levantar).
    if C.pendingGetup[z] then return end
    local now = getTimestampMs()
    local walk = C.walking[z]
    if walk then
        if C.furious(z, md) then
            endWalk(z, now)
            C.still[z], C.nextWalk[z] = nil, nil
            if z:isUseless() and not C.gameUseless(z) then z:setUseless(false) end
            return
        end
        z:setTarget(nil)
        local gx, gy = walk.gx + 0.5, walk.gy + 0.5
        local dx, dy = z:getX() - gx, z:getY() - gy
        -- Chegou ou timeout. Não usar isMoving(): com pathfind o jogo pode ter
        -- bPathfind ligado e isMoving falso (review 0052) — abortaria no 1º frame.
        if now >= walk.at or (dx * dx + dy * dy) <= 0.36 then
            endWalk(z, now)
        else
            C.still[z] = nil
            return
        end
    end
    if C.still[z] then
        if md.NOM_furia ~= nil and md.NOM_furia == NOM_FogState.period then
            C.letGo(z)
            return
        end
        local due = C.nextWalk[z]
        if due == nil then scheduleWalk(z, now); due = C.nextWalk[z] end
        if not C.forceWalk and now < due then return end
    elseif C.furious(z, md) then
        C.nextWalk[z] = nil
        -- já gritou, mas a posse veio pra cá com o useless no pacote do dono antigo
        if z:isUseless() and not C.gameUseless(z) then z:setUseless(false) end
        return
    end
    if C.forceWalk or (C.nextWalk[z] ~= nil and now >= C.nextWalk[z]) or C.still[z] then
        -- Chão: o mesmo critério do Sem-rosto / Wander (isFree + sem água), sem
        -- puxar o módulo inteiro (pz-api-notes §3.4 / §27).
        local dest = R.pickWalk(z:getX(), z:getY(), z:getZ(), playersNear(),
            R.rng(NOM_VariantRules.baseId(z:getPersistentOutfitID()) + now),
            function(x, y, zz)
                local sq = getCell():getGridSquare(x, y, zz)
                return sq ~= nil and sq:isFree(false) and not sq:getProperties():has(IsoFlagType.water)
            end)
        if dest then
            C.forceWalk = false
            if C.still[z] then
                C.still[z] = nil
                if not C.gameUseless(z) then z:setUseless(false) end
            end
            z:setTarget(nil)
            z:pathToLocationF(dest.x + 0.5, dest.y + 0.5, dest.z)
            C.walking[z] = { at = now + R.WALK_TIMEOUT_MS, gx = dest.x, gy = dest.y, gz = dest.z }
            return
        end
        -- pickWalk falhou: mantém forceWalk pra tentar de novo no próximo frame
        scheduleWalk(z, now)
        if C.still[z] and not C.forceWalk then return end
        if C.still[z] then return end
    end
    if C.still[z] then return end
    z:setUseless(true)
    z:setTarget(nil)
    C.still[z] = true
    if C.nextWalk[z] == nil then scheduleWalk(z, now) end
end

-- Desliga o useless sem perguntar de quem é: se o tutorial ou o menu de debug ligou
-- o useless numa Carpideira que este processo parou, ele cai junto (não dá pra
-- distinguir, como no Estalador).
function C.letGo(z)
    if C.walking[z] then endWalk(z) end
    C.still[z] = nil
    C.nextWalk[z] = nil
    z:setUseless(false)
end

local function stopSob(z)
    local id = sobs[z]
    if not id then return end
    z:getEmitter():stopSoundLocal(id)
    sobs[z] = nil
end

-- Objeto reaproveitado pra outro zumbi (OnZombieCreate) ou morto: sai de tudo
-- (NOM_VariantAI chama nos dois eventos).
function C.forget(z)
    if C.still[z] or C.walking[z] then C.letGo(z) end
    C.pendingGetup[z] = nil
    stopSob(z)
    lastReport[z] = nil
    C.nextWalk[z] = nil
end

-- O servidor decidiu o grito (p = quem a acordou, nil se este processo não o tem).
-- Grito local no emitter dela (cada processo que a tem carregada toca o seu: no MP
-- o servidor manda o comando a todos), soluço para; no dono, solta e força o spot no
-- jogador: spotted(p, true) → spottedNew com chance 1 000 000 (1114–1120), alvo e
-- última posição vista (1909–1950). Só vale sem useless (191–208): solta antes.
-- fn(z) a cada grito que este processo toca (efeitos de tela, sprint 0013). Em pcall:
-- um erro de quem ouve não pode parar o grito (no solo quem chama é o servidor).
-- K3 Rastejante: caminho 2c (getup) antes do som; timeout → fallback B (grita deitada).
local screamListeners = {}
function C.onScream(fn)
    screamListeners[#screamListeners + 1] = fn
end

local function beginGetup(z)
    if z.setFallOnFront then z:setFallOnFront(true) end
    if z.setOnFloor then z:setOnFloor(true) end
    if z.setKnockedDown then z:setKnockedDown(true) end
    if z.setCanWalk then z:setCanWalk(true) end
    if z.setCrawler then z:setCrawler(false) end
end

local function finishScream(z, p)
    z:playSoundLocal(C.SCREAMS[ZombRand(#C.SCREAMS) + 1])
    for _, fn in ipairs(screamListeners) do
        local ok, err = pcall(fn, z)
        if not ok and getDebug() then print("[NOM] grito: erro de quem ouve: " .. tostring(err)) end
    end
    if not z:isLocal() then return end
    C.letGo(z)
    if p then z:spotted(p, true) end
end

local function tickPendingGetup()
    local now = getTimestampMs()
    for z, e in pairs(C.pendingGetup) do
        if z:isDead() then
            C.pendingGetup[z] = nil
        else
            local st = z.getCurrentStateName and z:getCurrentStateName() or nil
            local crawl = z.isCrawling and z:isCrawling()
            local ready, why = R.getupDone(st, crawl, now - e.started, R.GETUP_TIMEOUT_MS)
            if ready then
                C.pendingGetup[z] = nil
                if getDebug() then
                    print("[NOM] carpideira getup=" .. tostring(why) .. " state=" .. tostring(st))
                end
                finishScream(z, e.p)
            end
        end
    end
end

function C.scream(z, p)
    local md = z:getModData()
    md.NOM_furia = NOM_FogState.period
    stopSob(z)
    -- K3 ainda rastejando: dono inicia 2c; todos esperam getup/timeout pra tocar o grito.
    local crawling = z.isCrawling and z:isCrawling()
    if md.NOM_screamerCrawler and crawling then
        if z:isLocal() then
            C.letGo(z)
            beginGetup(z)
        end
        local now = getTimestampMs()
        C.pendingGetup[z] = { p = p, started = now, at = now + R.GETUP_TIMEOUT_MS }
        return
    end
    finishScream(z, p)
end

local function localPlayers()
    local out = {}
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then out[#out + 1] = p end
    end
    return out
end

-- Por que este jogador, a d tiles, acorda a Carpideira z: "near", "light" ou nil.
-- Lanterna: acesa (getActiveLightItem, pz-api-notes §2.4) e o square dela com
-- isCanSee(pn) (linha de visão + cone + luz, o "jogador vê" do jogo, §3.4): ela está
-- na frente dele e iluminada. Aproximação de "apontada pra ela": luz de outra fonte
-- com a lanterna acesa na mão também conta.
local function why(p, z, d, radius)
    if math.floor(p:getZ()) ~= math.floor(z:getZ()) then return nil end
    if d <= radius then return "near" end
    if d > R.ALERT_RANGE or p:getActiveLightItem() == nil then return nil end
    local sq = z:getCurrentSquare()
    if sq ~= nil and sq:isCanSee(p:getPlayerNum()) then return "light" end
    return nil
end

-- volume: 0..1 pela distância (R.sobVolume); setVolume no emitter do personagem
-- (mesmo caminho do FogSound / Devices, local).
local function sob(z, volume)
    local id = sobs[z]
    local e = z:getEmitter()
    if id and e:isPlaying(id) then
        e:setVolume(id, volume)
        return
    end
    sobs[z] = z:playSoundLocal(C.SOB)
    e:setVolume(sobs[z], volume)
end

local function stopAll()
    for z in pairs(sobs) do stopSob(z) end
end

-- A cada SCAN_TICKS: soluço das calmas carregadas, aviso de quem as acorda e fim do
-- soluço de quem saiu (morreu, gritou, foi pro virtual: removeFromWorld não para os
-- sons do emitter). A tabela Lua vem antes de qualquer chamada: o zumbi que não é
-- Carpideira não custa nada.
local function scan(report)
    if not NOM_FogState.on or not NOM_Config.get("CarpideiraEnabled") then
        stopAll()
        return
    end
    local found, now, players = {}, getTimestampMs(), localPlayers()
    local radius = NOM_Config.get("CarpideiraTriggerRadius")
    -- Um aviso por varredura: o servidor aceita um por segundo por jogador, e vários
    -- de uma vez atrasariam os outros; quem ficou de fora vai na varredura seguinte.
    local reported = false
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        local md = NOM_NightStats.variants[z] == "carpideira" and not z:isDead() and z:getModData()
        if md and not C.furious(z, md) then
            local zx, zy = z:getX(), z:getY()
            local last, nearest = lastReport[z], nil
            local ready = not reported and (last == nil or now - last >= R.REPORT_GAP_MS)
            for _, p in ipairs(players) do
                local dx, dy = p:getX() - zx, p:getY() - zy
                local d = math.sqrt(dx * dx + dy * dy)
                if nearest == nil or d < nearest then nearest = d end
                local w = ready and why(p, z, d, radius)
                if w then
                    ready, reported = false, true
                    lastReport[z] = now
                    report(z, p, w)
                    if getDebug() then
                        print("[NOM] carpideira acordada por=" .. w .. " x=" .. math.floor(zx) .. " y=" .. math.floor(zy))
                    end
                end
            end
            -- no solo o aviso decide o grito na hora (NOM_Carpideira.scream): sem soluço
            if nearest ~= nil and nearest <= C.SOB_RANGE and md.NOM_furia ~= NOM_FogState.period then
                found[z] = true
                sob(z, R.sobVolume(nearest))
            end
        end
    end
    for z in pairs(sobs) do
        if not found[z] then stopSob(z) end
    end
end

-- Distância até a Carpideira calma mais perto que está soluçando (nil se nenhuma).
-- Usado pela vinheta ZB-free (client/NOM_ScreenFx.lua, sprint 0052).
function C.nearestSob(p)
    if not p or not NOM_FogState.on or not NOM_Config.get("CarpideiraEnabled") then return nil end
    local best = nil
    local px, py = p:getX(), p:getY()
    for z, id in pairs(sobs) do
        if id and z:getEmitter():isPlaying(id) and not z:isDead() then
            local dx, dy = px - z:getX(), py - z:getY()
            local d = math.sqrt(dx * dx + dy * dy)
            if best == nil or d < best then best = d end
        end
    end
    return best
end

-- report(z, jogador, why): um jogador local acordou a Carpideira z (why = "near" | "light").
function C.install(report)
    local ticks = 0
    Events.OnTick.Add(function()
        tickPendingGetup()
        ticks = ticks + 1
        if ticks < C.SCAN_TICKS then return end
        ticks = 0
        scan(report)
    end)
    NOM_FogState.onChange(function(on)
        if not on then
            C.screamed, lastReport = {}, {}
            C.pendingGetup = {}
        end
    end)
end

return NOM_Carpideira
