-- Comandos de debug, lado do servidor (no solo, o mesmo processo). Só com o jogo
-- em -debug: força noite e névoa (NOM_World.forced), força a variante de um zumbi
-- (NOM_VariantRules.forced), spawna um Eco e imprime o estado do mod. Quem chama
-- é o client/NOM_Debug.lua pelo console Lua; roteiro em docs/teste-in-game.md.
-- Nada daqui é salvo: o forçado vive em memória até o servidor reiniciar.
if isClient() then return end

require "NOM_World"
require "NOM_VariantRules"
require "NOM_DebugRules"
require "NOM_NightCount"
require "NOM_Fog"
require "NOM_Eco"

local MODULE = "NevoaEOutroMundo"

-- Fora do -debug nada acontece. No dedicado, além do -debug do servidor, quem
-- pede precisa da permissão de debug do jogo (server/ClientCommands.lua:1280);
-- no solo o -debug basta.
local function allowed(player)
    if not getDebug() or player == nil then return false end
    if not isServer() then return true end
    return player:getRole():hasCapability(Capability.UseDebugContextMenu)
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

function ops.fog(_, a)
    NOM_World.forced.fog = a.value
    return "nevoa forcada=" .. tostring(a.value)
end

-- Por persistentOutfitID: todo processo sorteia igual (ADR-006), então o servidor
-- (grito do Corredor, sumiço do Sem-rosto) e os clientes (quem simula e quem vê)
-- recebem o mesmo forçado.
function ops.variant(_, a)
    NOM_VariantRules.forced[a.id] = a.kind
    if isServer() then sendServerCommand(MODULE, "debugVariant", { id = a.id, kind = a.kind }) end
    return "variante id=" .. a.id .. " forcada=" .. tostring(a.kind)
end

function ops.spawnEco(player)
    local ok = NOM_Eco.spawnAt(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
    return "eco spawn=" .. tostring(ok)
end

function ops.status()
    local w, f = NOM_World, NOM_World.forced
    return NOM_DebugRules.line("[NOM] debug servidor", {
        hora = fmt(w.tod),
        noite = w.night,
        nevoa = w.fog,
        nevoaI = fmt(w.fogIntensity),
        noiteN = tostring(NOM_NightCount.current()),
        nevoaN = tostring(NOM_Fog.period()),
        forcarNoite = tostring(f.night),
        forcarNevoa = tostring(f.fog),
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
