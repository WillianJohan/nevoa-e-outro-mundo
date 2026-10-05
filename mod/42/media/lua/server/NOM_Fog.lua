-- Névoa, lado do servidor: conta os períodos de névoa, avisa quem vê (no solo,
-- o próprio processo; no dedicado, os clientes) e decide o sumiço do Sem-rosto
-- (ADR-007). Cada período tem um número, base do sorteio do Sem-rosto (ADR-006),
-- contado como as noites: pelo estado salvo no ModData global, não pela borda.
if isClient() then return end

require "NOM_World"
require "NOM_EcoRules"
require "NOM_Config"
require "NOM_FogState"
require "NOM_SemRostoRules"
require "NOM_SemRosto"

local MODULE = "NevoaEOutroMundo"

local function debugLog(msg)
    if getDebug() then print("[NOM] nevoa " .. msg) end
end

NOM_Fog = {}

local function state()
    local data = ModData.getOrCreate(MODULE)
    data.fog = data.fog or {}
    return data.fog
end

-- nil antes do primeiro OnClimateTick (estado do clima desconhecido).
function NOM_Fog.period()
    if NOM_World.tod == nil then return nil end
    return NOM_EcoRules.syncNight(state(), NOM_World.fog)
end

NOM_World.onChange(function(flag, on)
    if flag ~= "fog" then return end
    local period = NOM_Fog.period()
    if isServer() then
        sendServerCommand(MODULE, "fog", { on = on, period = period })
    else
        NOM_FogState.set(on, period)
    end
    debugLog("fog=" .. tostring(on) .. " periodo=" .. tostring(period))
end)

-- Save com a névoa aberta (inNight salvo true) carregado sem névoa: não há borda
-- e o período ficaria aberto, e a névoa seguinte herdaria o número (e o sorteio)
-- da velha. Na primeira leitura do clima, o estado salvo é acertado. Roda depois
-- do OnClimateTick do NOM_ClimateLook (que atualiza o NOM_World): carga em ordem
-- alfabética; se vier antes, tenta de novo no próximo.
local synced = false
Events.OnClimateTick.Add(function()
    if synced or NOM_World.tod == nil then return end
    NOM_Fog.period()
    synced = true
end)

-- Cliente que entra no meio da névoa não viu a borda: pergunta.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "fogState" then return end
    sendServerCommand(player, MODULE, "fog", { on = NOM_World.fog, period = NOM_Fog.period() })
end)

-- Sem-rosto ------------------------------------------------------------------

local R = NOM_SemRostoRules
-- Fallback (ADR-007): visto de novo, até STUCK_WINDOW_MS depois do movimento, a
-- até STUCK_TILES de onde saiu e a mais de ARRIVED_TILES do destino, quer dizer
-- que o dono não aplicou. A janela é curta (o cooldown é 4 s): um zumbi que corre
-- de volta pela origem depois disso não é confundido com travado.
local STUCK_TILES = 1.5
local ARRIVED_TILES = 2
local STUCK_WINDOW_MS = 5000
local REPLACE_OUTFIT = "Naked" -- só pro spawn: o substituto é vestido pelo ID em seguida

-- [zumbi] = { at = ms do último movimento, ox, oy = de onde saiu, dx, dy = destino }.
-- ponytail: chave é o objeto; zumbi que vai pro virtual fica até a névoa acabar.
local moved = {}

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
end

local function stuck(z, last, now)
    if not isServer() or last == nil or now - last.at > STUCK_WINDOW_MS then return false end
    local zx, zy = z:getX(), z:getY()
    return dist(zx, zy, last.ox, last.oy) <= STUCK_TILES and dist(zx, zy, last.dx, last.dy) > ARRIVED_TILES
end

-- Troca o zumbi por outro igual no destino: mesmo persistentOutfitID (mesma
-- variante, ADR-006; dressInPersistentOutfitID grava o ID e veste, bytecode).
-- removeFromWorld no servidor não avisa o cliente (ADR-003): vai semRostoGone.
local function replace(z, x, y, zz)
    local female = z:isFemale() and 100 or 0
    local list = addZombiesInOutfit(x, y, zz, 1, z:getOutfitName() or REPLACE_OUTFIT, female)
    if not list or list:size() == 0 then return nil end
    local nz = list:get(0)
    nz:dressInPersistentOutfitID(z:getPersistentOutfitID())
    NOM_SemRosto.move(nz, x, y, zz) -- centro do tile
    local id = z:getOnlineID()
    z:removeFromWorld()
    z:removeFromSquare()
    sendServerCommand(MODULE, "semRostoGone", { ids = { id } })
    return nz
end

-- O destino tem que ser chão de verdade no andar de quem viu: square carregado,
-- livre e sem água (NOM_SemRosto.floorOk). Vale pro movimento e pro fallback.
local function destinationOk(player, x, y, zz)
    if zz ~= math.floor(player:getZ()) then return false end
    return NOM_SemRosto.floorOk(getCell():getGridSquare(x, y, zz))
end

-- player viu o Sem-rosto z; (x, y, zz) é o destino que o cliente achou fora da
-- vista dele. O servidor confere o que dá pra conferir sem a luz do cliente:
-- névoa, variante, destino mais perto e não colado (nem o zumbi colado: aí ele
-- ataca), chão, cooldown.
function NOM_Fog.seen(player, z, x, y, zz)
    if not NOM_World.fog or not NOM_Config.get("SemRostoEnabled") then return false end
    if not NOM_SemRosto.isSemRosto(z, NOM_Fog.period()) then return false end
    if not R.validMove(player:getX(), player:getY(), z:getX(), z:getY(), x + 0.5, y + 0.5) then return false end
    if not destinationOk(player, x, y, zz) then return false end
    local now, last = getTimestampMs(), moved[z]
    if last and not R.ready(last.at, now) then return false end
    if stuck(z, last, now) then
        local nz = replace(z, x, y, zz)
        moved[z] = nil
        if nz then moved[nz] = { at = now, ox = x + 0.5, oy = y + 0.5, dx = x + 0.5, dy = y + 0.5 } end
        debugLog("semrosto substituido x=" .. x .. " y=" .. y)
        return nz ~= nil
    end
    moved[z] = { at = now, ox = z:getX(), oy = z:getY(), dx = x + 0.5, dy = y + 0.5 }
    -- Dedicado: a cópia do servidor só vale se ninguém for dono; o dono recebe
    -- semRostoMove e move a dele (o servidor aceita a posição do dono).
    NOM_SemRosto.move(z, x, y, zz)
    if isServer() then
        sendServerCommand(MODULE, "semRostoMove", { id = z:getOnlineID(), x = x, y = y, z = zz })
    end
    debugLog("semrosto some x=" .. x .. " y=" .. y)
    return true
end

NOM_World.onChange(function(flag, on)
    if flag == "fog" and not on then moved = {} end
end)

-- Solo: este processo vê e simula.
if not isServer() then
    NOM_SemRosto.install(function(z, x, y, zz, p) NOM_Fog.seen(p, z, x, y, zz) end)
end

-- O aviso vem do cliente. Cada jogador manda no máximo um a cada RATE_MS reais
-- (procurar o zumbi custa uma volta na lista).
local RATE_MS = 250
-- ponytail: chave é o objeto do jogador; quem desconecta fica até reiniciar.
local lastSeen = {}

local function rateOk(player)
    local now = getTimestampMs()
    local last = lastSeen[player]
    if last and now - last < RATE_MS then return false end
    lastSeen[player] = now
    return true
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "semRostoSeen" then return end
    if not rateOk(player) or type(args) ~= "table" then return end
    local id, x, y, zz = args.id, args.x, args.y, args.z
    if type(id) ~= "number" or id == -1 or type(x) ~= "number" or type(y) ~= "number" or type(zz) ~= "number" then return end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then
            NOM_Fog.seen(player, z, math.floor(x), math.floor(y), math.floor(zz))
            return
        end
    end
end)

return NOM_Fog
