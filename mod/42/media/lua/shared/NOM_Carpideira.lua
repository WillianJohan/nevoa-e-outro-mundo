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
require "NOM_NightStats"
require "NOM_FogState"

NOM_Carpideira = {
    SOB = "NOM_CarpideiraSob",       -- media/scripts/NOM_sounds.txt
    SCREAM = "NOM_CarpideiraScream",
    SCAN_TICKS = 10,
    -- Soluça só quem está a até SOB_RANGE tiles de um jogador local (o som some a 12):
    -- a célula carregada pode ter dezenas de Carpideiras, e cada uma seria um loop.
    SOB_RANGE = 15,
    -- [persistentOutfitID] = true: já gritou nesta névoa (o servidor avisa; solo: direto).
    screamed = {},
    -- [zumbi] = true: este processo a deixou useless (só esses são soltos).
    still = {},
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
    if C.screamed[z:getPersistentOutfitID()] then
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

-- Por frame, no dono, na névoa (NOM_VariantAI). Parada: useless (o idle não
-- perambula, RespondToSound volta cedo, spottedNew 191–208 zera o alvo) e o alvo de
-- agora largado uma vez. Ligado uma vez por objeto; o pacote leva o useless às
-- outras cópias e a quem herdar a posse.
function C.hold(z, md)
    if C.still[z] then
        if md.NOM_furia ~= nil and md.NOM_furia == NOM_FogState.period then C.letGo(z) end
        return
    end
    if C.furious(z, md) then
        -- já gritou, mas a posse veio pra cá com o useless no pacote do dono antigo
        -- (NetworkZombieAI.set/parse): solta, como o Estalador herdado (NOM_VariantAI).
        -- Custo: uma chamada a mais por frame na furiosa.
        if z:isUseless() and not C.gameUseless(z) then z:setUseless(false) end
        return
    end
    z:setUseless(true)
    z:setTarget(nil)
    C.still[z] = true
end

-- Desliga o useless sem perguntar de quem é: se o tutorial ou o menu de debug ligou
-- o useless numa Carpideira que este processo parou, ele cai junto (não dá pra
-- distinguir, como no Estalador).
function C.letGo(z)
    C.still[z] = nil
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
    if C.still[z] then C.letGo(z) end
    stopSob(z)
    lastReport[z] = nil
end

-- O servidor decidiu o grito (p = quem a acordou, nil se este processo não o tem).
-- Grito local no emitter dela (cada processo que a tem carregada toca o seu: no MP
-- o servidor manda o comando a todos), soluço para; no dono, solta e força o spot no
-- jogador: spotted(p, true) → spottedNew com chance 1 000 000 (1114–1120), alvo e
-- última posição vista (1909–1950). Só vale sem useless (191–208): solta antes.
-- fn(z) a cada grito que este processo toca (efeitos de tela, sprint 0013). Em pcall:
-- um erro de quem ouve não pode parar o grito (no solo quem chama é o servidor).
local screamListeners = {}
function C.onScream(fn)
    screamListeners[#screamListeners + 1] = fn
end

function C.scream(z, p)
    z:getModData().NOM_furia = NOM_FogState.period
    stopSob(z)
    z:playSoundLocal(C.SCREAM)
    for _, fn in ipairs(screamListeners) do
        local ok, err = pcall(fn, z)
        if not ok and getDebug() then print("[NOM] grito: erro de quem ouve: " .. tostring(err)) end
    end
    if z:isRemoteZombie() then return end
    C.letGo(z)
    if p then z:spotted(p, true) end
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

local function sob(z)
    local id = sobs[z]
    if id and z:getEmitter():isPlaying(id) then return end
    sobs[z] = z:playSoundLocal(C.SOB)
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
                sob(z)
            end
        end
    end
    for z in pairs(sobs) do
        if not found[z] then stopSob(z) end
    end
end

-- report(z, jogador, why): um jogador local acordou a Carpideira z (why = "near" | "light").
function C.install(report)
    local ticks = 0
    Events.OnTick.Add(function()
        ticks = ticks + 1
        if ticks < C.SCAN_TICKS then return end
        ticks = 0
        scan(report)
    end)
    NOM_FogState.onChange(function(on)
        if not on then
            C.screamed, lastReport = {}, {}
        end
    end)
end

return NOM_Carpideira
