-- Evento de névoa, lado do servidor (sprint 0009, ADR-009). A névoa não vem do
-- clima: a agenda é por dia (sprint 0033, shared/NOM_FogEventRules: o dia sorteia se tem
-- névoa e a que horas, pode ter uma segunda depois da folga, e o terceiro dia sem névoa
-- tem com certeza). Na hora sorteada a sirene toca em todo jogador (com a direção de onde
-- ela "vem", pro congelamento) e, 45 s reais depois, a névoa começa e dura o que o tipo
-- manda (branca ou vermelha, em horas de jogo). Depois do fim vem a calmaria
-- (NOM_World.calm). O estado mora no ModData global (data.fog: night = período, inNight,
-- next, endAt, red, seed, bornAt, day, lastEnd, calmUntil...) e sobrevive a
-- salvar/carregar; a contagem da sirene só existe em memória: recarregar no meio dela toca
-- a sirene de novo (a mesma cor, red já salvo) e recomeça os 45 s (o next segue no passado).
-- A flag vai pro NOM_World (setFog), e dele pros consumidores (NOM_Fog avisa os
-- clientes com o período). O canal de névoa do clima é do NOM_ClimateLook.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_FogEventRules"
require "NOM_Siren"
require "NOM_SirenFreeze"
require "NOM_VariantRules"

local MODULE = "NevoaEOutroMundo"
local R = NOM_FogEventRules

NOM_FogEvent = {}

-- Solo: este processo simula os zumbis e congela direto. Dedicado: quem congela é o
-- cliente dono (client/NOM_FogClient.lua); o servidor não simula zumbi.
if not isServer() then NOM_SirenFreeze.install() end

local countdown, lastMs -- ms reais até a névoa; nil = sem sirene tocando
-- Névoa vermelha (sprint 0010): a sirene decide e salva em data.fog.red (sprint 0019:
-- a chance muda com os dias, então re-sortear na recarga podia trocar a cor);
-- forcedRed = NOM_Debug.redFog(true) pra próxima sirene (nil = sorteio), só em memória
-- (recarregar antes da sirene perde o forçado: só debug).
local forcedRed

local function debugLog(msg)
    if getDebug() then print("[NOM] nevoa " .. msg) end
end

-- seed: semente do mundo pro sorteio da névoa vermelha (ADR-010), sorteada no
-- primeiro uso (save novo ou anterior a ela) e salva. ZombRand(n) no Lua é
-- LuaManager$GlobalObject.ZombRand(D)D → RandLua.Next(long) → Next(int, Random),
-- inteiro em [0, n) (bytecode 0–35); n = SEED_RANGE cabe em int.
-- horas de mundo (shared/Definitions/animal/ButcheringUtil.lua:594)
local function now() return getGameTime():getWorldAgeHours() end

-- bornAt: hora de mundo em que a curva de tensão começa (sprint 0019), gravada uma vez
-- como a semente (NOM_FogEventRules.born): save novo agora, save veterano no ponto neutro
-- da curva (30 dias atrás), que não muda nada pra quem já jogava.
local function state()
    local data = ModData.getOrCreate(MODULE)
    data.fog = data.fog or {}
    if data.fog.seed == nil then data.fog.seed = ZombRand(NOM_VariantRules.SEED_RANGE) end
    R.born(data.fog, now())
    return data.fog
end

-- ZombRand(n): inteiro em [0, n) (uso no mod: client/NOM_FogSound.lua)
local function rand() return ZombRand(10000) / 10000 end
local function cfg() return R.config(NOM_Config.get) end

local function hours(v) return v and string.format("%.2f", v) or "-" end

function NOM_FogEvent.period()
    return state().night or 0
end

-- { next, endAt, sirenMs, sirenRed, sirenDir } pro status do debug e pra quem entra na contagem.
function NOM_FogEvent.status()
    local s = state()
    return { next = s.next, endAt = s.endAt, sirenMs = countdown, sirenRed = countdown and s.red == true,
        sirenDir = countdown and s.sirenDir or nil }
end

-- O vermelho é do período que a sirene anuncia (o próximo): sorteio puro do número e da
-- semente (NOM_VariantRules.redFog), com a chance do sandbox no dia de agora (zero na
-- carência: NOM_FogEventRules.redChance). Devolve a cor e a chance usada (pro log).
local function decideRed()
    local s = state()
    local vc = NOM_VariantRules.config(NOM_Config.get)
    vc.redFogChance = R.redChance(vc.redFogChance or 0, cfg(), R.days(s, now()))
    if forcedRed ~= nil then return forcedRed, vc.redFogChance end
    return NOM_VariantRules.redFog((s.night or 0) + 1, vc, s.seed), vc.redFogChance
end

-- Toca a sirene e começa a contagem. skip: a névoa começa no próximo tick (debug).
-- Recusa se o evento já está aberto ou a sirene já tocou.
-- A cor fica no data.fog.red: se já estava salva (recarga durante a sirene), vale ela.
function NOM_FogEvent.siren(skip)
    local s = state()
    if s.inNight or countdown then return false end
    countdown, lastMs = skip and 0 or R.SIREN_MS, getTimestampMs()
    local chance = "-" -- cor salva reaproveitada (recarga): não houve sorteio
    if s.red == nil or forcedRed ~= nil then
        local red, c = decideRed()
        s.red, chance = red, hours(c)
    end
    -- a direção é do período que a sirene anuncia (o próximo): pura da semente e do número,
    -- igual em toda máquina (a recarga durante a contagem repete a mesma)
    local dir = R.sirenDir(s.seed, (s.night or 0) + 1)
    s.sirenDir = dir
    if isServer() then
        sendServerCommand(MODULE, "siren", { red = s.red, dir = dir })
    else
        NOM_Siren.play(s.red)
        NOM_SirenFreeze.start(dir, countdown)
    end
    -- inteiro: "contagem=45000"; dias e chance da vermelha com 2 casas
    debugLog("sirene contagem=" .. math.floor(countdown) .. " vermelha=" .. tostring(s.red) ..
        " dias=" .. hours(R.days(s, now())) .. " chance=" .. chance .. " dir=" .. hours(dir))
    return true
end

-- Fecha o evento agora (ou cancela a sirene). Sirene cancelada tira a pendente do dia
-- (R.cancel): o next ficou no passado e o minuto seguinte tocaria de novo; o dedicado
-- avisa os clientes pra largarem o congelamento. Evento aberto: R.stop (calmaria, folga).
function NOM_FogEvent.stop()
    local was = countdown ~= nil
    countdown = nil
    forcedRed = nil
    if not state().inNight then
        if was then
            R.cancel(state())
            if isServer() then
                sendServerCommand(MODULE, "sirenStop", {})
            else
                NOM_SirenFreeze.stop()
            end
        end
        return was
    end
    R.stop(state(), now(), cfg())
    NOM_World.setFog(false)
    NOM_World.setCalm(R.calm(state(), now()))
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
        s.red = on == true
        return true
    end
    if on then return NOM_FogEvent.siren(false) end
    return true
end

local function begin()
    countdown = nil
    forcedRed = nil
    if not isServer() then NOM_SirenFreeze.stop() end -- a sirene acabou: os zumbis soltam antes da névoa
    if not R.start(state(), now(), cfg(), rand, state().red) then return end
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
    NOM_World.setCalm(R.calm(s, now()))
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
