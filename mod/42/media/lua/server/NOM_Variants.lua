-- Variantes da névoa, lado do servidor (ADR-005/ADR-006): decide os gritos do
-- Corredor e da Carpideira. O alvo do zumbi e a visão do jogador só existem em quem
-- simula e vê, então quem avisa é o NOM_VariantAI (Corredor pegou um jogador de alvo)
-- e o NOM_Carpideira (jogador perto ou lanterna nela): no solo, aqui mesmo; no MP,
-- o cliente ("corredorSaw", "carpideiraWoke"). O servidor não confia no aviso:
-- confere a variante pelo próprio sorteio (período de névoa), a névoa, a distância
-- e o cooldown. O barulho que acorda a Carpideira o servidor ouve sozinho.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_VariantRules"
require "NOM_ColorIdentityRules"
require "NOM_VariantAI"
require "NOM_CarpideiraRules"
require "NOM_Carpideira"
require "NOM_Fog"
require "NOM_Night"

local MODULE = "NevoaEOutroMundo"
-- Sprint 0048: banco de gritos (timbre novo); o gameplay (horda + cooldown) não muda.
local SCREAM_SOUNDS = { "NOM_CorredorScream", "NOM_CorredorScream2", "NOM_CorredorScream3" }
local ECO_OUTFIT = "NOM_Eco"
local CR = NOM_CarpideiraRules

local function corredorScream()
    return SCREAM_SOUNDS[ZombRand(#SCREAM_SOUNDS) + 1]
end

local function debugLog(msg)
    if getDebug() then print("[NOM] variantes " .. msg) end
end

local function isKind(z, kind)
    if z:isDead() then return false end
    if z:getModData().NOM_eco or z:getOutfitName() == ECO_OUTFIT then return false end
    if z:getModData().NOM_alma then return false end -- almas (sprint 0050): além das variantes
    local cfg = NOM_VariantRules.config(NOM_Config.get)
    return NOM_VariantRules.variant(z:getPersistentOutfitID(), NOM_Fog.period(), cfg, NOM_World.red, NOM_World.black) == kind
end

-- Som: no dedicado sendPlaySound manda aos clientes perto (FishingNet.lua:86;
-- só age com GameServer.server); no solo toca no emitter do zumbi. Atração é
-- outra coisa: addSound pelo NOM_Night.call, com o alcance compensado pela
-- audição da noite (só à noite). O Corredor só existe na névoa, de dia ou de noite.
local function scream(z)
    if not NOM_World.fog or not isKind(z, "corredor") then return end
    local md = z:getModData()
    local now = getGameTime():getWorldAgeHours()
    local mood = NOM_ColorIdentityRules.mood(NOM_World.red, NOM_World.black)
    if not NOM_VariantRules.screamReady(md.NOM_screamAt, now, mood) then return end
    md.NOM_screamAt = now
    local sound = corredorScream()
    if isServer() then
        sendPlaySound(sound, false, z)
    else
        z:getEmitter():playSound(sound)
    end
    local radius = NOM_Config.get("CorredorScreamRadius")
    NOM_Night.call(z, radius)
    debugLog("grito x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY()) .. " raio=" .. radius)
end

-- Carpideira (sprint 0011) ----------------------------------------------------

-- Quem já gritou nesta névoa, no ModData global (salvo com o mundo): recarregar no
-- meio não deixa gritar de novo. Chave = persistentOutfitID (a identidade da
-- variante, ADR-006; o mesmo ID que volta do virtual).
local function screamedNow()
    return CR.screamed(ModData.getOrCreate(MODULE), NOM_Fog.period())
end

-- p acordou a Carpideira z (why: "near", "light" ou "noise"). Um grito por névoa
-- por PID + gap global entre qualquer grito (playtest 2026-10-10: evita clusters).
-- Marca, chama a horda (CarpideiraScreamRadius) e espalha. O grito toca local em
-- cada cliente que a tem carregada; o dono solta e caça p.
local function carpideira(z, p, why)
    if not NOM_World.fog or not isKind(z, "carpideira") then return false end
    local data = ModData.getOrCreate(MODULE)
    local state = CR.screamState(data, NOM_Fog.period())
    local pid = NOM_VariantRules.baseId(z:getPersistentOutfitID())
    if state.pids[pid] then return false end
    local now = getTimestampMs()
    if not CR.globalScreamReady(state, now) then
        debugLog("carpideira gap x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY())
            .. " nextAt=" .. tostring(state.nextAt))
        return false
    end
    state.pids[pid] = true
    local gap = CR.scheduleNextScream(state, now, ZombRand(10001) / 10000)
    local radius = NOM_Config.get("CarpideiraScreamRadius")
    NOM_Night.call(z, radius)
    if isServer() then
        sendServerCommand(MODULE, "carpideiraScream", { pid = pid, id = z:getOnlineID(), pl = p:getOnlineID() })
    else
        NOM_Carpideira.screamed[pid] = true
        NOM_Carpideira.scream(z, p)
    end
    debugLog("carpideira grito por=" .. why .. " x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY())
        .. " raio=" .. radius .. " gapMs=" .. gap)
    return true
end

-- Aviso de quem vê (cliente ou o próprio processo): confere com a posição que o
-- servidor conhece, com folga, e a lanterna acesa (sincronizada, pz-api-notes §2.4).
local function woke(player, z, why)
    if math.floor(player:getZ()) ~= math.floor(z:getZ()) then return end
    local dist = player:DistTo(z:getX(), z:getY())
    if not CR.woke(why, dist, NOM_Config.get("CarpideiraTriggerRadius"), player:getActiveLightItem() ~= nil) then return end
    carpideira(z, player, why)
end

-- Solo: este processo simula os zumbis e vê (no dedicado é o cliente).
-- NOM_Carpideira.screamed é memória: recarregar o save no meio da névoa a esvazia, e
-- a que gritou voltaria parada e soluçando. Refeita do ModData ao carregar
-- (OnInitGlobalModData, server/Vehicles/ProfessionVehicles.lua:343-350) e na borda da
-- névoa (o primeiro minuto depois de carregar, NOM_FogEvent). No dedicado quem entra
-- recebe carpideiraList (abaixo).
local function syncScreamed()
    local out = {}
    for pid in pairs(screamedNow()) do out[pid] = true end
    NOM_Carpideira.screamed = out
end

if not isServer() then
    NOM_VariantAI.install(scream)
    NOM_Carpideira.install(function(z, p, why) woke(p, z, why) end)
    Events.OnInitGlobalModData.Add(syncScreamed)
    NOM_World.onChange(function(flag, on)
        if flag == "fog" and on then syncScreamed() end
    end)
end

-- Barulho alto perto acorda: Events.OnWorldSound(x, y, z, raio, volume, fonte) sai de
-- todo addSound (WorldSoundManager$WorldSound.init 129–155), inclusive o de cliente
-- de MP, que o servidor refaz com o jogador de fonte (WorldSoundPacket.processServer
-- 90–139). Só barulho de jogador (é quem ela caça); os chamados do próprio mod
-- (caça, lanterna, gritos) ficam de fora. Uma volta na lista por barulho alto, com 1
-- chamada (o ID) no zumbi que não é Carpideira.
Events.OnWorldSound.Add(function(x, y, zz, radius, volume, source)
    if NOM_Night.calling or not NOM_World.fog or radius < CR.LOUD_RADIUS then return end
    if source == nil or not instanceof(source, "IsoPlayer") or not NOM_Config.get("CarpideiraEnabled") then return end
    if NOM_World.black then return end -- na preta todo zumbi é Tição: Carpideira nenhuma
    local cfg, period, red = NOM_VariantRules.config(NOM_Config.get), NOM_Fog.period(), NOM_World.red
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if NOM_VariantRules.variant(z:getPersistentOutfitID(), period, cfg, red) == "carpideira"
            and math.floor(z:getZ()) == zz then
            local dx, dy = z:getX() - x, z:getY() - y
            if CR.loud(math.sqrt(dx * dx + dy * dy), radius) then carpideira(z, source, "noise") end
        end
    end
end)

-- Avisos de cliente --------------------------------------------------------------

-- Cada jogador manda no máximo um aviso de cada tipo a cada rate ms de relógio real
-- (contando os inválidos): procurar o zumbi custa uma volta na lista.
-- ponytail: chave é o objeto do jogador; quem desconecta fica na tabela até o
-- servidor reiniciar (um número por jogador). Limpar no desconectar se crescer.
local function limiter(rate)
    local last = {}
    return function(player)
        local now = getTimestampMs()
        local t = last[player]
        if t and now - t < rate then return false end
        last[player] = now
        return true
    end
end

local SENDER_RANGE = 25 -- corredorSaw: só de quem está perto do Corredor
local sawOk = limiter(2000)
local wokeOk = limiter(CR.RATE_MS)

-- args.id: só número, e -1 (sem ID de rede) nunca casa.
local function byOnlineID(id)
    if type(id) ~= "number" or id == -1 then return nil end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then return z end
    end
    return nil
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE then return end
    if command == "corredorSaw" then
        if not sawOk(player) then return end
        local z = byOnlineID(args and args.id)
        if z and player:DistTo(z:getX(), z:getY()) <= SENDER_RANGE then scream(z) end
    elseif command == "carpideiraWoke" then
        if not wokeOk(player) or type(args) ~= "table" then return end
        local z = byOnlineID(args.id)
        if z then woke(player, z, args.why) end
    elseif command == "fogState" and NOM_World.fog then
        -- quem entra no meio da névoa (client/NOM_FogClient.lua pergunta) fica sabendo
        -- quem já gritou: não toca o soluço nela e o dono não a deixa parada de novo
        local list = {}
        for pid in pairs(screamedNow()) do list[#list + 1] = pid end
        if #list > 0 then sendServerCommand(player, MODULE, "carpideiraList", { pids = list }) end
    end
end)
