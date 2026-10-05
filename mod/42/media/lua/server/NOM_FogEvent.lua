-- Evento de névoa, lado do servidor (sprint 0009, ADR-009). A névoa não vem do
-- clima: numa hora sorteada a sirene toca em todo jogador e, 30 s reais depois,
-- a névoa começa e dura de FogMinHours a FogMaxHours de jogo. O estado mora no
-- ModData global (data.fog: night = período, inNight, next, endAt, red) e sobrevive a
-- salvar/carregar; a contagem da sirene só existe em memória: recarregar no meio
-- dela toca a sirene de novo e recomeça os 30 s (o next segue no passado).
-- A flag vai pro NOM_World (setFog), e dele pros consumidores (NOM_Fog avisa os
-- clientes com o período). O canal de névoa do clima é do NOM_ClimateLook.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_FogEventRules"
require "NOM_Siren"
require "NOM_VariantRules"

local MODULE = "NevoaEOutroMundo"
local R = NOM_FogEventRules

NOM_FogEvent = {}

local countdown, lastMs -- ms reais até a névoa; nil = sem sirene tocando
-- Névoa vermelha (sprint 0010): pendingRed = o que a sirene tocando decidiu;
-- forcedRed = NOM_Debug.redFog(true) pra próxima sirene (nil = sorteio). Os dois só
-- em memória: recarregar durante a sirene re-sorteia (mesmo resultado do sorteio) e
-- perde o forçado do debug (aceito: só debug).
local pendingRed, forcedRed

local function debugLog(msg)
    if getDebug() then print("[NOM] nevoa " .. msg) end
end

-- seed: semente do mundo pro sorteio da névoa vermelha (ADR-010), sorteada no
-- primeiro uso (save novo ou anterior a ela) e salva. ZombRand(n) no Lua é
-- LuaManager$GlobalObject.ZombRand(D)D → RandLua.Next(long) → Next(int, Random),
-- inteiro em [0, n) (bytecode 0–35); n = SEED_RANGE cabe em int.
local function state()
    local data = ModData.getOrCreate(MODULE)
    data.fog = data.fog or {}
    if data.fog.seed == nil then data.fog.seed = ZombRand(NOM_VariantRules.SEED_RANGE) end
    return data.fog
end

-- ZombRand(n): inteiro em [0, n) (uso no mod: client/NOM_FogSound.lua)
local function rand() return ZombRand(10000) / 10000 end
-- horas de mundo (shared/Definitions/animal/ButcheringUtil.lua:594)
local function now() return getGameTime():getWorldAgeHours() end
local function cfg() return R.config(NOM_Config.get) end

local function hours(v) return v and string.format("%.2f", v) or "-" end

function NOM_FogEvent.period()
    return state().night or 0
end

-- { next, endAt, sirenMs, sirenRed } pro status do debug e pra quem entra na contagem.
function NOM_FogEvent.status()
    local s = state()
    return { next = s.next, endAt = s.endAt, sirenMs = countdown, sirenRed = countdown and pendingRed }
end

-- O vermelho é do período que a sirene anuncia (o próximo): sorteio puro do número,
-- o mesmo em qualquer processo e depois de recarregar (NOM_VariantRules.redFog).
local function decideRed()
    if forcedRed ~= nil then return forcedRed end
    local s = state()
    return NOM_VariantRules.redFog((s.night or 0) + 1, NOM_VariantRules.config(NOM_Config.get), s.seed)
end

-- Toca a sirene e começa a contagem. skip: a névoa começa no próximo tick (debug).
-- Recusa se o evento já está aberto ou a sirene já tocou.
function NOM_FogEvent.siren(skip)
    if state().inNight or countdown then return false end
    countdown, lastMs = skip and 0 or R.SIREN_MS, getTimestampMs()
    pendingRed = decideRed()
    if isServer() then
        sendServerCommand(MODULE, "siren", { red = pendingRed })
    else
        NOM_Siren.play(pendingRed)
    end
    debugLog("sirene contagem=" .. math.floor(countdown) .. " vermelha=" .. tostring(pendingRed)) -- inteiro: "contagem=30000"
    return true
end

-- Fecha o evento agora (ou cancela a sirene) e agenda o próximo. Sirene
-- cancelada também reagenda: o next da agenda ficou no passado e o minuto
-- seguinte tocaria de novo.
function NOM_FogEvent.stop()
    local was = countdown ~= nil
    countdown = nil
    forcedRed = nil
    if not state().inNight then
        if was then R.stop(state(), now(), cfg(), rand) end
        return was
    end
    R.stop(state(), now(), cfg(), rand)
    NOM_World.setFog(false)
    debugLog("evento fim proxima=" .. hours(state().next))
    return true
end

-- Debug (NOM_Debug.redFog). Evento aberto: vira (ou deixa de ser) vermelho na hora
-- e os clientes recebem pelo NOM_Fog (borda "red"). Contagem correndo: a névoa
-- que vem segue o pedido (a sirene que já tocou fica). Nada aberto: true toca a
-- sirene vermelha e começa um evento; false só desfaz o pedido.
function NOM_FogEvent.setRed(on)
    local s = state()
    if s.inNight then
        s.red = on == true
        NOM_World.setFog(true, s.red)
        debugLog("vermelha=" .. tostring(s.red) .. " periodo=" .. tostring(s.night))
        return true
    end
    forcedRed = on and true or nil
    if countdown then
        pendingRed = on == true
        return true
    end
    if on then return NOM_FogEvent.siren(false) end
    return true
end

local function begin()
    countdown = nil
    forcedRed = nil
    if not R.start(state(), now(), cfg(), rand, pendingRed) then return end
    debugLog("evento inicio periodo=" .. state().night .. " fim=" .. hours(state().endAt) .. " vermelha=" .. tostring(state().red))
    NOM_World.setFog(true, state().red)
end

-- Uma vez por minuto de jogo. Também acerta a flag na primeira leitura depois
-- de carregar (save no meio do evento volta com névoa).
Events.OnClimateTick.Add(function()
    local s = state()
    local before = s.next
    local action = R.update(s, now(), cfg(), rand)
    if action == "siren" then NOM_FogEvent.siren(false) end
    if action == "end" then debugLog("evento fim proxima=" .. hours(s.next)) end
    if s.next ~= before and action ~= "end" then debugLog("proxima=" .. hours(s.next)) end
    NOM_World.setFog(s.inNight == true, s.red == true)
end)

-- Contagem em tempo real: getTimestampMs (CONFIRMED server/ISObjectClickHandler.lua:352),
-- parada com o jogo pausado (isGamePaused = GameTime.isGamePaused: velocidade 0 no
-- solo, servidor vazio com PauseEmpty no dedicado).
Events.OnTick.Add(function()
    if not countdown then return end
    local t = getTimestampMs()
    countdown = R.countdown(countdown, t - lastMs, isGamePaused())
    lastMs = t
    if countdown <= 0 then begin() end
end)

return NOM_FogEvent
