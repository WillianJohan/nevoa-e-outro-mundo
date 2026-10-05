-- Comandos de debug, lado do servidor (no solo, o mesmo processo). Só com o jogo
-- em -debug: força a noite (NOM_World.forced), começa e termina um evento de névoa
-- (NOM_FogEvent), força a névoa vermelha, força a variante de um zumbi
-- (NOM_VariantRules.forced), spawna um Eco, muda a hora, spawna zumbis comuns e
-- imprime o estado do mod. Quem chama
-- é o client/NOM_Debug.lua pelo console Lua; roteiro em docs/teste-in-game.md.
-- A noite forçada vive em memória até o servidor reiniciar, MAS ela e o evento de
-- névoa avançam os contadores salvos de noites e de névoas (NOM_NightCount e
-- NOM_FogEvent, ModData global): o número da névoa muda o sorteio das variantes e o da
-- noite, a noite dos Ecos daquele save pra sempre. Use um save descartável.
if isClient() then return end

require "NOM_World"
require "NOM_VariantRules"
require "NOM_DebugRules"
require "NOM_NightCount"
require "NOM_Fog"
require "NOM_FogEvent"
require "NOM_Eco"

local MODULE = "NevoaEOutroMundo"

-- Fora do -debug nada acontece. No dedicado, além do -debug do servidor, quem
-- pede precisa da permissão de debug do jogo (server/ClientCommands.lua:1280);
-- no solo o -debug basta.
local function allowed(player)
    if not getDebug() or player == nil then return false end
    if not isServer() then return true end
    if player:getRole():hasCapability(Capability.UseDebugContextMenu) then return true end
    print("[NOM] debug negado: sem permissão de debug")
    return false
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function fmt(v)
    if type(v) ~= "number" then return tostring(v) end
    return string.format("%.2f", v)
end

local ops = {}

-- Vale na próxima leitura do clima (OnClimateTick, um por minuto de jogo).
function ops.night(_, a)
    NOM_World.forced.night = a.value
    return "noite forcada=" .. tostring(a.value)
end

-- Evento de verdade: sirene (e a névoa 30 s reais depois, ou já com skip), ou fim.
-- toggle (NOM.fog sem argumento): névoa aberta ou sirene contando termina; senão, sirene.
-- Quem decide é o servidor: o cliente não sabe da contagem.
function ops.fog(_, a)
    if a.toggle then a.value = not (NOM_World.fog or NOM_FogEvent.status().sirenMs ~= nil) end
    if a.value then return "nevoa sirene=" .. tostring(NOM_FogEvent.siren(a.skip)) end
    return "nevoa fim=" .. tostring(NOM_FogEvent.stop())
end

-- Por persistentOutfitID: todo processo sorteia igual (ADR-006), então o servidor
-- (grito do Corredor, sumiço do Sem-rosto) e os clientes (quem simula e quem vê)
-- recebem o mesmo forçado.
-- Névoa vermelha (sprint 0010): aberta vira na hora; senão, sirene vermelha e evento.
function ops.redFog(_, a)
    return "nevoa vermelha=" .. tostring(NOM_FogEvent.setRed(a.value))
end

function ops.variant(_, a)
    local id = NOM_VariantRules.baseId(a.id) -- sem o bit do chapéu caído (o sorteio tira)
    NOM_VariantRules.forced[id] = a.kind
    if isServer() then sendServerCommand(MODULE, "debugVariant", { id = id, kind = a.kind }) end
    return "variante id=" .. id .. " forcada=" .. tostring(a.kind)
end

function ops.spawnEco(player)
    local ok = NOM_Eco.spawnAt(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
    return "eco spawn=" .. tostring(ok)
end

-- Hora do relógio (sprint 0020): no solo é o relógio local; no MP o do servidor, que
-- os clientes seguem (GameTime.syncClock). O mod lê no próximo OnClimateTick.
function ops.time(_, a)
    getGameTime():setTimeOfDay(a.hour)
    return "hora=" .. fmt(a.hour)
end

-- Zumbis no tile pedido (o cliente mira na frente do jogador), no máximo a
-- SPAWN_REACH tiles de quem pede. outfit nil: o jogo sorteia (ISSpawnHordeUI.lua:73, 276).
function ops.spawn(player, a)
    local dx, dy = a.x - player:getX(), a.y - player:getY()
    local reach = NOM_DebugRules.SPAWN_REACH
    if not (dx * dx + dy * dy <= reach * reach) then return "spawn longe" end
    local list = addZombiesInOutfit(math.floor(a.x), math.floor(a.y), math.floor(a.z), a.n, a.outfit, 50)
    return "spawn n=" .. a.n .. " criados=" .. (list and list:size() or 0) .. " outfit=" .. (a.outfit or "-")
end

function ops.status()
    local w, f, ev = NOM_World, NOM_World.forced, NOM_FogEvent.status()
    return NOM_DebugRules.line("[NOM] debug servidor", {
        hora = fmt(w.tod),
        noite = w.night,
        nevoa = w.fog,
        noiteN = tostring(NOM_NightCount.current()),
        nevoaN = tostring(NOM_Fog.period()),
        vermelha = w.red,
        proxima = ev.next and fmt(ev.next) or "-", -- horas de mundo (getWorldAgeHours)
        fim = ev.endAt and fmt(ev.endAt) or "-",
        sirene = ev.sirenMs and math.floor(ev.sirenMs) or "-", -- ms reais até a névoa
        forcarNoite = tostring(f.night),
        forcados = count(NOM_VariantRules.forced),
        ecos = NOM_Eco.loaded(),
    })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "debug" then return end
    if not allowed(player) then return end
    local a = NOM_DebugRules.parse(args)
    if not a then return end
    local msg = ops[a.op](player, a)
    if a.op ~= "status" then msg = "[NOM] debug " .. msg end
    print(msg)
    if isServer() then sendServerCommand(player, MODULE, "debugReply", { msg = msg }) end
end)

-- Cliente que entra depois (pergunta nightState ao entrar, client/NOM_NightClient.lua)
-- não viu os debugVariant: recebe a tabela inteira. Só se houver algo forçado (e
-- portanto só em -debug, que é quando ela enche).
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "nightState" or not isServer() then return end
    local any = false
    for _ in pairs(NOM_VariantRules.forced) do any = true break end -- next() não existe no Kahlua
    if not any then return end
    local list = {}
    for id, kind in pairs(NOM_VariantRules.forced) do list[#list + 1] = { id = id, kind = kind } end
    sendServerCommand(player, MODULE, "debugForced", { list = list })
end)
