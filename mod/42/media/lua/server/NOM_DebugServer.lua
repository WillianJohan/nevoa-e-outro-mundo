-- Comandos de debug, lado do servidor (no solo, o mesmo processo). Só com o jogo
-- em -debug: força a noite (NOM_World.forced), começa e termina um evento de névoa
-- (NOM_FogEvent), força a névoa vermelha, força a variante de um zumbi
-- (NOM_VariantRules.forced), spawna um Eco, muda a hora, spawna zumbis comuns e
-- puxa um zumbi até o jogador, solta uma onda de perambular, imprime o estado do mod. Quem chama
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
require "NOM_SemRosto"

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

-- Evento de verdade: sirene (a névoa sobe e os bichos soltam 30 s reais depois, ou já com
-- skip), ou fim.
-- toggle (NOM.fog sem argumento): névoa aberta ou sirene contando termina; senão, sirene.
-- Quem decide é o servidor: o cliente não sabe da contagem.
function ops.fog(_, a)
    if a.toggle then a.value = not (NOM_World.fog or NOM_FogEvent.status().sirenMs ~= nil) end
    if a.value then return "nevoa sirene=" .. tostring(NOM_FogEvent.siren(a.skip)) end
    return "nevoa fim=" .. tostring(NOM_FogEvent.stop())
end

-- NOM.setFog / NOM.setRedFog (sprint 0033): névoa branca ou vermelha de verdade, qualquer
-- que seja o estado (fecha o que estiver aberto ou contando); skip abre sem a espera.
function ops.setFog(_, a)
    local color = a.red and "vermelha" or "branca"
    return "nevoa forcada " .. color .. "=" .. tostring(NOM_FogEvent.force(a.red, a.skip))
end

-- Por persistentOutfitID: todo processo sorteia igual (ADR-006), então o servidor
-- (grito do Corredor, sumiço do Sem-rosto) e os clientes (quem simula e quem vê)
-- recebem o mesmo forçado.
-- Névoa vermelha (sprint 0010): aberta vira na hora; senão, sirene vermelha e evento.
-- toggle: vermelha aberta ou sirene vermelha contando desfaz; senão força.
function ops.redFog(_, a)
    if a.toggle then a.value = not (NOM_World.red == true or NOM_FogEvent.status().sirenRed == true) end
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

-- Hora do relógio (sprint 0020), sempre pra frente: hora menor que a de agora vira a
-- mesma hora do dia seguinte (h + 24). O GameTime.update seguinte (938–972) tira 24, chama
-- advanceOneDay e, no servidor, marca o sync do relógio. Voltar no tempo dessincroniza a
-- data dos clientes do dedicado (SyncClockPacket) e volta o getWorldAgeHours, que os
-- timers da névoa usam. No solo é o relógio local; no MP o do servidor.
function ops.time(_, a)
    local gt = getGameTime()
    local h = a.hour
    if h < gt:getTimeOfDay() then h = h + 24 end
    gt:setTimeOfDay(h)
    return "hora=" .. fmt(a.hour)
end

local function knownOutfit(name)
    return getAllOutfits(false):contains(name) or getAllOutfits(true):contains(name)
end

-- Zumbis em 3×3 em volta do tile pedido (o cliente mira na frente do jogador), no máximo
-- a SPAWN_REACH tiles e um andar de quem pede. addZombiesInOutfitArea sorteia cada um com
-- Rand.Next(x1, x2), fim exclusivo (bytecode 0–54): x-1..x+1. outfit nil: o jogo sorteia
-- (ISSpawnHordeUI.lua:73, 276); nome que não existe é recusado (getAllOutfits, :71-72).
function ops.spawn(player, a)
    local dx, dy = a.x - player:getX(), a.y - player:getY()
    local reach = NOM_DebugRules.SPAWN_REACH
    if not (dx * dx + dy * dy <= reach * reach and math.abs(a.z - player:getZ()) <= 1) then return "spawn longe" end
    if a.outfit and not knownOutfit(a.outfit) then return "spawn outfit desconhecido=" .. a.outfit end
    local fx, fy, fz = math.floor(a.x), math.floor(a.y), math.floor(a.z)
    local list = addZombiesInOutfitArea(fx - 1, fy - 1, fx + 2, fy + 2, fz, a.n, a.outfit, nil)
    return "spawn n=" .. a.n .. " criados=" .. (list and list:size() or 0) .. " outfit=" .. (a.outfit or "-")
end

-- Zumbi vivo mais perto de quem pede, no mesmo andar (a mesma conta do NOM_Debug.nearest).
local function nearestTo(player)
    local best, bestD
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if not z:isDead() and math.floor(z:getZ()) == math.floor(player:getZ()) then
            local dx, dy = z:getX() - player:getX(), z:getY() - player:getY()
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then best, bestD = z, d end
        end
    end
    return best
end

local function byOnlineId(id)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then return z end
    end
end

-- NOM.getZombie (sprint 0033): puxa um zumbi pro tile de quem pede. Só o dono simula o
-- zumbi (ADR-005): no dedicado o servidor não move a cópia dele, avisa todos
-- (debugMove) e o cliente dono move (client/NOM_Debug.lua, mesmo sem -debug). No solo este
-- processo é o dono: move direto. Sem ID de rede (-1, como no solo) vale o mais perto de
-- quem pede; no dedicado, -1 é recusado.
-- Não reaproveita o semRostoMove: o cliente dele só move se nenhum jogador vê o destino
-- e reserva o tile do Sem-rosto; o jogador está parado no destino, então nunca moveria.
function ops.pull(player, a)
    local dx, dy = a.x + 0.5 - player:getX(), a.y + 0.5 - player:getY()
    local reach = NOM_DebugRules.PULL_REACH
    if not (dx * dx + dy * dy <= reach * reach and a.z == math.floor(player:getZ())) then return "pull longe" end
    if isServer() then
        if a.id == -1 then return "zumbi sem ID de rede" end -- nenhum cliente acharia
        sendServerCommand(MODULE, "debugMove", { id = a.id, x = a.x, y = a.y, z = a.z })
        return "zumbi puxado x=" .. a.x .. " y=" .. a.y
    end
    local z
    if a.id == -1 then z = nearestTo(player) else z = byOnlineId(a.id) end
    if not z then return "zumbi não achado" end
    NOM_SemRosto.move(z, a.x, a.y, a.z)
    return "zumbi puxado x=" .. a.x .. " y=" .. a.y
end

-- Uma onda de perambular agora (sprint 0036; NOM_WanderServer, lido na hora: carrega depois
-- deste arquivo). Só com a névoa aberta, como a de verdade.
function ops.wander()
    if not NOM_World.fog then return "perambular precisa de névoa aberta" end
    if not NOM_WanderServer then return "perambular não carregou" end
    return "perambular onda semente=" .. NOM_WanderServer.wave("debug")
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
