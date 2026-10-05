-- Comandos de console pro teste in-game (docs/teste-in-game.md), só com o jogo em
-- -debug. Uso no console Lua do debug:
--   NOM_Debug.night(true|false|nil)   noite forçada; nil devolve pro relógio
--   NOM_Debug.fog(0.8|nil)            intensidade de névoa forçada (0..1); nil devolve pro clima
--   NOM_Debug.spawnEco()              um Eco nos pés do jogador (só à noite)
--   NOM_Debug.variant("estalador")    zumbi mais perto vira Estalador ("corredor", "semrosto"; nil desfaz; só vale na névoa)
--   NOM_Debug.status()                estado do mod, local e do servidor
-- Tudo vai pro servidor (server/NOM_DebugServer.lua), que confere e decide. No solo
-- o sendClientCommand vira OnClientCommand no mesmo processo (SinglePlayerClient).
-- A forma com jogador: a de 3 argumentos chega no solo sem jogador (playerIndex -1).
if isServer() or not getDebug() then return end

require "NOM_VariantRules"
require "NOM_DebugRules"
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_SemRosto"

local MODULE = "NevoaEOutroMundo"

NOM_Debug = {}

local function send(args)
    local p = getSpecificPlayer(0)
    if not p then return end
    sendClientCommand(p, MODULE, "debug", args)
end

function NOM_Debug.night(on) send({ op = "night", value = on }) end
function NOM_Debug.fog(v) send({ op = "fog", value = v }) end
function NOM_Debug.spawnEco() send({ op = "spawnEco" }) end

-- Zumbi vivo mais perto do jogador 0, no mesmo andar.
local function nearest(p)
    local best, bestD
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if not z:isDead() and math.floor(z:getZ()) == math.floor(p:getZ()) then
            local dx, dy = z:getX() - p:getX(), z:getY() - p:getY()
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then best, bestD = z, d end
        end
    end
    return best
end

function NOM_Debug.variant(kind)
    local p = getSpecificPlayer(0)
    local z = p and nearest(p)
    if not z then
        print("[NOM] debug nenhum zumbi perto")
        return
    end
    local id = z:getPersistentOutfitID()
    print("[NOM] debug variante x=" .. math.floor(z:getX()) .. " y=" .. math.floor(z:getY()) .. " id=" .. id)
    send({ op = "variant", id = id, kind = kind })
end

-- Linha local (quem simula e quem vê) e pedido da linha do servidor.
function NOM_Debug.status()
    local kinds = { estalador = 0, corredor = 0 }
    for _, k in pairs(NOM_NightStats.variants) do
        if kinds[k] then kinds[k] = kinds[k] + 1 end
    end
    local p = getSpecificPlayer(0)
    local near = p and NOM_SemRosto.nearest(p)
    print(NOM_DebugRules.line("[NOM] debug local", {
        noite = NOM_NightStats.night,
        noiteN = tostring(NOM_NightStats.nightNumber),
        nevoa = NOM_FogState.on,
        nevoaN = tostring(NOM_FogState.period),
        estaladores = kinds.estalador,
        corredores = kinds.corredor,
        semRostoPerto = near and math.floor(near) or "nenhum",
    }))
    send({ op = "status" })
end

-- MP: resposta do servidor no console do cliente e variante forçada pra todos.
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE then return end
    if command == "debugReply" then
        print(args.msg)
    elseif command == "debugVariant" and type(args.id) == "number" then
        NOM_VariantRules.forced[args.id] = args.kind
    elseif command == "debugForced" and type(args.list) == "table" then -- entrou depois
        for _, f in pairs(args.list) do
            if type(f.id) == "number" then NOM_VariantRules.forced[f.id] = f.kind end
        end
    end
end)
