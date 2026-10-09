-- Noite agressiva, lado do servidor (ADR-005: o servidor decide, quem simula
-- aplica). Decide a noite, chama os zumbis até os jogadores (caça) e transforma
-- lanterna ligada ao ar livre em farol. Stats do zumbi: NOM_NightStats.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_NightRules"
require "NOM_TicaoRules"
require "NOM_NightStats"
require "NOM_Players"
require "NOM_NightCount"

local MODULE = "NevoaEOutroMundo"
-- Farol da lanterna a cada N minutos de jogo: chamado todo minuto vira enxame.
local TORCH_EVERY_MINUTES = 5

local function debugLog(msg)
    if getDebug() then print("[NOM] noite " .. msg) end
end

-- Solo: este processo simula os zumbis. Dedicado: o cliente dono simula
-- (NetworkZombieManager.updateAuth) e aplica em client/NOM_NightClient.lua.
if not isServer() then NOM_NightStats.install() end

NOM_World.onChange(function(flag, on)
    -- Calmaria depois da névoa (NOM_FogEvent → NOM_World.setCalm): mesmo caminho da noite.
    if flag == "calm" then
        if isServer() then
            sendServerCommand(MODULE, "calm", { on = on })
        else
            NOM_NightStats.setCalm(on)
        end
        debugLog("calm=" .. tostring(on))
        return
    end
    if flag ~= "night" then return end
    -- O número da noite vai junto (status do debug). As variantes usam o período de
    -- névoa, que vai pelo comando "fog" (server/NOM_Fog.lua, ADR-006).
    local night = NOM_NightCount.current()
    if isServer() then
        sendServerCommand(MODULE, "night", { on = on, night = night })
    else
        NOM_NightStats.setNight(on, night)
    end
    debugLog("night=" .. tostring(on))
end)

-- Cliente que entra no meio da noite não viu a borda: pergunta.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "nightState" then return end
    sendServerCommand(player, MODULE, "night", { on = NOM_World.night, night = NOM_NightCount.current() })
    sendServerCommand(player, MODULE, "calm", { on = NOM_World.calm })
end)

local function alive()
    local out = {}
    for _, p in ipairs(NOM_Players.all()) do
        if not p:isDead() then out[#out + 1] = p end
    end
    return out
end

-- addSound no servidor vai pro popman e pros clientes (WorldSoundManager.addSound
-- → GameServer.sendWorldSound): o zumbi reage onde é simulado. O jogo multiplica
-- o raio pela audição do zumbi (getSoundAttract), que a noite aguça: reach é o
-- alcance efetivo e o raio passado é dividido de volta (NOM_NightRules.soundRadius).
-- O volume fica no alcance: getSoundAttract devolve volume × queda e o zumbi
-- segue o som mais forte; volume baixo perderia pra barulho vanilla.
NOM_Night = {}

-- src: jogador (caça, lanterna) ou zumbi (gritos do Corredor e da Carpideira, server/NOM_Variants.lua,
-- que pode vir de dia na névoa: aí ninguém tem o degrau da noite e o raio é o do jogo).
-- hearing: degrau de audição de quem deve ouvir (a caça da preta: o Tição, NOM_TicaoRules.HEARING);
-- nil = o do sandbox com o bônus da noite.
function NOM_Night.call(src, reach, hearing)
    local radius
    if hearing then
        radius = math.max(1, math.floor(reach / NOM_NightRules.HEARING_MULT[hearing] + 0.5))
    else
        radius = NOM_NightRules.soundRadius(reach, {
            sensesOn = NOM_World.night and NOM_Config.get("NightSharperSenses"),
            senseMult = NOM_Config.get("NightSenseMult"),
            hearing = getSandboxOptions():getOptionByName("ZombieLore.Hearing"):getValue(),
        })
    end
    -- calling: o addSound dispara o OnWorldSound na hora (WorldSound.init 129–155); o
    -- barulho que acorda a Carpideira (server/NOM_Variants.lua) ignora os chamados do mod.
    NOM_Night.calling = true
    addSound(src, math.floor(src:getX()), math.floor(src:getY()), math.floor(src:getZ()), radius, reach)
    NOM_Night.calling = false
end

-- O vanilla sincroniza o liga/desliga da luz (syncItemActivated, client/ISUI/
-- ISInventoryPaneContextMenu.lua:2883), então o servidor vê a lanterna acesa.
local function torchOutside(p)
    local sq = p:getCurrentSquare()
    return sq ~= nil and sq:isOutside() and p:getActiveLightItem() ~= nil
end

local huntMinutes, torchMinutes, lastLit, ticaoMinutes = 0, 0, 0, 0

local function hunt(ps)
    if not NOM_Config.get("NightHunt") then
        huntMinutes = 0
        return
    end
    local due
    huntMinutes, due = NOM_NightRules.countdown(huntMinutes, NOM_Config.get("HuntIntervalMinutes"))
    if not due or #ps == 0 then return end
    local radius = NOM_Config.get("HuntRadius")
    for _, p in ipairs(ps) do NOM_Night.call(p, radius) end
    debugLog("caca jogadores=" .. #ps .. " raio=" .. radius)
end

-- ponytail: o zumbi não tem alcance de visão ajustável por zumbi além dos
-- degraus (e o raio é preso em 20); a lanterna vira um chamado sonoro.
local function torches(ps)
    if not NOM_Config.get("NightSharperSenses") then
        torchMinutes = 0
        return
    end
    local due
    torchMinutes, due = NOM_NightRules.countdown(torchMinutes, TORCH_EVERY_MINUTES)
    if not due then return end
    local radius, lit = NOM_NightRules.torchRadius(NOM_Config.get("NightSenseMult")), 0
    for _, p in ipairs(ps) do
        if torchOutside(p) then
            NOM_Night.call(p, radius)
            lit = lit + 1
        end
    end
    if lit ~= lastLit then
        debugLog("lanterna jogadores=" .. lit .. " raio=" .. radius)
        lastLit = lit
    end
end

-- Caça do Tição (sprint 0038): na preta, de dia ou de noite, mais forte que a da noite.
-- Intervalo e alcance: NOM_BlackPressureRules via NOM_TicaoRules (sprint 0051).
local function ticaoHunt()
    if not NOM_World.black then
        ticaoMinutes = 0
        return
    end
    local due
    local minutes = NOM_TicaoRules.huntMinutes()
    local reach = NOM_TicaoRules.huntReach()
    ticaoMinutes, due = NOM_NightRules.countdown(ticaoMinutes, minutes)
    if not due then return end
    local ps = alive()
    for _, p in ipairs(ps) do NOM_Night.call(p, reach, NOM_TicaoRules.HEARING) end
    debugLog("caca do ticao jogadores=" .. #ps .. " alcance=" .. reach)
end

local function everyMinute()
    ticaoHunt()
    if not NOM_World.night then
        huntMinutes, torchMinutes = 0, 0
        return
    end
    local ps = alive()
    hunt(ps)
    torches(ps)
end

Events.EveryOneMinute.Add(everyMinute)

return NOM_Night
