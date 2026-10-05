-- Evento de névoa, lado do servidor (sprint 0009, ADR-009). A névoa não vem do
-- clima: numa hora sorteada a sirene toca em todo jogador e, 30 s reais depois,
-- a névoa começa e dura de FogMinHours a FogMaxHours de jogo. O estado mora no
-- ModData global (data.fog: night = período, inNight, next, endAt) e sobrevive a
-- salvar/carregar; a contagem da sirene só existe em memória: recarregar no meio
-- dela toca a sirene de novo e recomeça os 30 s (o next segue no passado).
-- A flag vai pro NOM_World (setFog), e dele pros consumidores (NOM_Fog avisa os
-- clientes com o período). O canal de névoa do clima é do NOM_ClimateLook.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_FogEventRules"
require "NOM_Siren"

local MODULE = "NevoaEOutroMundo"
local R = NOM_FogEventRules

NOM_FogEvent = {}

local countdown, lastMs -- ms reais até a névoa; nil = sem sirene tocando

local function debugLog(msg)
    if getDebug() then print("[NOM] nevoa " .. msg) end
end

local function state()
    local data = ModData.getOrCreate(MODULE)
    data.fog = data.fog or {}
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

-- { next, endAt, sirenMs } pro status do debug.
function NOM_FogEvent.status()
    local s = state()
    return { next = s.next, endAt = s.endAt, sirenMs = countdown }
end

-- Toca a sirene e começa a contagem. skip: a névoa começa no próximo tick (debug).
-- Recusa se o evento já está aberto ou a sirene já tocou.
function NOM_FogEvent.siren(skip)
    if state().inNight or countdown then return false end
    countdown, lastMs = skip and 0 or R.SIREN_MS, getTimestampMs()
    if isServer() then
        sendServerCommand(MODULE, "siren", {})
    else
        NOM_Siren.play()
    end
    debugLog("sirene contagem=" .. countdown)
    return true
end

-- Fecha o evento agora (ou cancela a sirene) e agenda o próximo.
function NOM_FogEvent.stop()
    local was = countdown ~= nil
    countdown = nil
    if not state().inNight then return was end
    R.stop(state(), now(), cfg(), rand)
    NOM_World.setFog(false)
    debugLog("evento fim proxima=" .. hours(state().next))
    return true
end

local function begin()
    countdown = nil
    if not R.start(state(), now(), cfg(), rand) then return end
    debugLog("evento inicio periodo=" .. state().night .. " fim=" .. hours(state().endAt))
    NOM_World.setFog(true)
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
    NOM_World.setFog(s.inNight == true)
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
