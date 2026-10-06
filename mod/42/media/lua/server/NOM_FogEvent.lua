-- Evento de névoa, lado do servidor (sprint 0009, ADR-009). A névoa não vem do
-- clima: a agenda é por dia (sprint 0033, shared/NOM_FogEventRules: o dia sorteia se tem
-- névoa e a que horas, pode ter uma segunda depois da folga, e o terceiro dia sem névoa
-- tem com certeza). Na hora sorteada vem o presságio (sprint 0034): a cor é decidida e a
-- tela de quem vê ganha estática por 3 s reais. Depois a sirene toca em todo jogador (cada
-- um sorteia as posições dela em volta de si) e começa a fuga: a névoa visual sobe na hora
-- (NOM_World.rising) e, 30 s reais depois, a névoa de jogo começa e dura o que o tipo
-- manda (branca ou vermelha, em horas de jogo). Depois do fim vem a calmaria
-- (NOM_World.calm). O estado mora no ModData global (data.fog: night = período, inNight,
-- next, endAt, red, seed, bornAt, day, lastEnd, calmUntil...) e sobrevive a
-- salvar/carregar; o presságio e a contagem da fuga só existem em memória: recarregar no
-- meio deles volta ao presságio (o next segue no passado), com a mesma cor (red já salvo), e
-- a sirene recomeça os 30 s.
-- A flag vai pro NOM_World (setFog), e dele pros consumidores (NOM_Fog avisa os
-- clientes com o período). O canal de névoa do clima é do NOM_ClimateLook.
if isClient() then return end

require "NOM_World"
require "NOM_FogState"
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
local omenLeft -- ms reais do presságio até a sirene (sprint 0034); nil = sem presságio
-- Névoa vermelha (sprint 0010): a sirene decide e salva em data.fog.red (sprint 0019:
-- a chance muda com os dias, então re-sortear na recarga podia trocar a cor);
-- forcedRed pra próxima sirene, só em memória (recarregar antes da sirene perde o forçado:
-- só debug): nil = sorteio, true = vermelha (NOM_Debug.redFog(true), NOM_FogEvent.force),
-- false = branca forçada (só NOM_FogEvent.force; NOM_Debug.redFog(false) volta ao sorteio).
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

-- A subida da fuga no mundo (o clima do servidor) e, no solo, em quem vê. No dedicado o
-- cliente liga a dele pelos comandos siren/sirenStop/fog (client/NOM_FogClient.lua).
local function rise(on, red)
    NOM_World.setRising(on, red)
    if not isServer() then NOM_FogState.setRising(on, red) end
end

function NOM_FogEvent.period()
    return state().night or 0
end

-- { next, endAt, sirenMs, sirenRed, presageMs } pro status do debug e pra quem entra na
-- contagem. O presságio conta como sirene pendente (sirenMs até a névoa), pros toggles.
function NOM_FogEvent.status()
    local s = state()
    local pending = countdown or (omenLeft and omenLeft + R.GRACE_MS)
    return { next = s.next, endAt = s.endAt, sirenMs = pending, sirenRed = pending and s.red == true,
        presageMs = omenLeft }
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

-- A cor do período que vem, no data.fog.red: se já estava salva (presságio, recarga), vale
-- ela. Devolve a chance usada, "-" se não houve sorteio (pro log).
local function decideColor(s)
    if s.red ~= nil and forcedRed == nil then return "-" end
    local red, c = decideRed()
    s.red = red
    return hours(c)
end

-- Presságio (sprint 0034): decide a cor, avisa quem vê (estática na tela) e conta
-- PRESAGE_MS reais até a sirene (OnTick). Recusa se o evento já está aberto, a sirene já
-- tocou ou o presságio já corre.
local function presage()
    local s = state()
    if s.inNight or countdown or omenLeft then return false end
    local chance = decideColor(s)
    omenLeft, lastMs = R.PRESAGE_MS, getTimestampMs()
    if isServer() then
        sendServerCommand(MODULE, "presage", { red = s.red })
    else
        NOM_FogState.setOmen(s.red)
    end
    debugLog("presagio vermelha=" .. tostring(s.red) .. " dias=" .. hours(R.days(s, now())) .. " chance=" .. chance)
    return true
end

-- Toca a sirene, sobe a névoa visual e começa a fuga. skip: a névoa começa no próximo
-- tick (debug). Recusa se o evento já está aberto ou a sirene já tocou. Chamada direta
-- (debug) durante o presságio pula o resto dele.
function NOM_FogEvent.siren(skip)
    local s = state()
    if s.inNight or countdown then return false end
    omenLeft = nil
    countdown, lastMs = skip and 0 or R.GRACE_MS, getTimestampMs()
    local chance = decideColor(s)
    rise(true, s.red)
    if isServer() then
        sendServerCommand(MODULE, "siren", { red = s.red })
    else
        NOM_Siren.play(s.red)
        NOM_SirenFreeze.start(countdown)
    end
    -- inteiro: "contagem=30000"; dias e chance da vermelha com 2 casas
    debugLog("sirene contagem=" .. math.floor(countdown) .. " vermelha=" .. tostring(s.red) ..
        " dias=" .. hours(R.days(s, now())) .. " chance=" .. chance)
    return true
end

-- Fecha o evento agora (ou cancela o presságio ou a sirene). Sirene cancelada tira a pendente do dia
-- (R.cancel): o next ficou no passado e o minuto seguinte tocaria de novo; o dedicado
-- avisa os clientes pra largarem o congelamento. Evento aberto: R.stop (calmaria, folga).
function NOM_FogEvent.stop()
    local was = countdown ~= nil or omenLeft ~= nil
    countdown, omenLeft = nil, nil
    forcedRed = nil
    if not state().inNight then
        if was then
            R.cancel(state())
            rise(false)
            if isServer() then
                sendServerCommand(MODULE, "sirenStop", {})
            else
                NOM_Siren.stop()
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
-- e os clientes recebem pelo NOM_Fog (borda "red"). Presságio ou contagem correndo: a névoa
-- que vem segue o pedido (a sirene que já tocou fica) e a cor do presságio e da subida muda
-- em quem vê (no dedicado, pelo comando sirenColor, que não toca a sirene de novo). Nada
-- aberto: true começa um evento vermelho pelo presságio, como o force; false só desfaz o pedido.
function NOM_FogEvent.setRed(on)
    local s = state()
    if s.inNight then
        s.red = on == true
        NOM_World.setFog(true, s.red)
        debugLog("vermelha=" .. tostring(s.red) .. " periodo=" .. tostring(s.night))
        return true
    end
    forcedRed = on and true or nil
    if countdown or omenLeft then
        s.red = on == true
        if countdown then NOM_World.setRising(true, s.red) end
        if isServer() then
            sendServerCommand(MODULE, "sirenColor", { red = s.red })
        else
            NOM_FogState.recolor(s.red)
        end
        return true
    end
    if on then return presage() end
    return true
end

-- Debug (NOM.setFog / NOM.setRedFog): névoa na cor pedida, sempre (red false = branca, não
-- sorteio). Evento aberto, presságio ou sirene contando fecham antes (stop), então vale pra
-- quem estiver aberto; depois vem o presságio e a sirene (skip: sem presságio, a névoa abre
-- no próximo tick). Sem a calmaria que o stop acabou de ligar: é uma névoa nova.
function NOM_FogEvent.force(red, skip)
    if state().inNight or countdown or omenLeft then NOM_FogEvent.stop() end
    state().calmUntil = nil
    NOM_World.setCalm(false)
    forcedRed = red == true
    if skip then return NOM_FogEvent.siren(true) end
    return presage()
end

local function begin()
    countdown = nil
    forcedRed = nil
    if not isServer() then NOM_SirenFreeze.stop() end -- a fuga acabou: os zumbis soltam antes da névoa
    if not R.start(state(), now(), cfg(), rand, state().red) then
        rise(false)
        return
    end
    NOM_World.setCalm(false) -- R.start zerou a calmaria; o clima só relê no minuto seguinte
    debugLog("evento inicio periodo=" .. state().night .. " fim=" .. hours(state().endAt) .. " vermelha=" .. tostring(state().red))
    NOM_World.setFog(true, state().red)
    rise(false) -- depois do setFog: no solo quem vê já está com on e não pisca
end

-- Uma vez por minuto de jogo. Também acerta a flag na primeira leitura depois
-- de carregar (save no meio do evento volta com névoa).
Events.OnClimateTick.Add(function()
    local s = state()
    local before = s.next
    local action = R.update(s, now(), cfg(), rand)
    if action == "siren" then presage() end
    if action == "end" then debugLog("evento fim proxima=" .. hours(s.next)) end
    if s.next ~= before and action ~= "end" then debugLog("proxima=" .. hours(s.next)) end
    NOM_World.setFog(s.inNight == true, s.red == true)
    NOM_World.setCalm(R.calm(s, now()))
end)

-- Contagem em tempo real: getTimestampMs (CONFIRMED server/ISObjectClickHandler.lua:352),
-- parada com o jogo pausado (isGamePaused = GameTime.isGamePaused: velocidade 0 no
-- solo, servidor vazio com PauseEmpty no dedicado). Primeiro o presságio, depois a fuga.
Events.OnTick.Add(function()
    if omenLeft then
        local t = getTimestampMs()
        omenLeft = R.countdown(omenLeft, t - lastMs, isGamePaused())
        lastMs = t
        if omenLeft <= 0 then NOM_FogEvent.siren(false) end
        return
    end
    if not countdown then return end
    local t = getTimestampMs()
    countdown = R.countdown(countdown, t - lastMs, isGamePaused())
    lastMs = t
    if not isServer() then NOM_SirenFreeze.extend(countdown) end
    if countdown <= 0 then begin() end
end)

return NOM_FogEvent
