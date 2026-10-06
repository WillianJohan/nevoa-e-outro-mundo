-- Sirene (spec do modelo novo §3): enquanto ela toca, todo zumbi para em pé, virado
-- pro jogador vivo mais perto dele (sprint 0034: as sirenes vêm de vários lados), e ignora
-- o jogador. Quando a névoa começa, todos voltam juntos. Roda onde o zumbi é simulado
-- (ADR-005): no solo, chamado pelo server/NOM_FogEvent.lua; no MP, pelo
-- client/NOM_FogClient.lua (comandos "siren", "fog" e "sirenStop"). Cópia remota
-- (z:isRemoteZombie()) é do cliente dono: aqui não se mexe, e o useless dela chega no
-- pacote do dono (pz-api-notes §3.2).
-- Parada: setUseless(true) + setTarget(nil) no dono (pz-api-notes §3.2 e §13).
-- Virar: IsoGameCharacter.faceLocationF(FF)Z (uso vanilla
-- client/BuildingObjects/TimedActions/ISBuildAction.lua:248), refeito a cada passada do
-- lote, então acompanha o jogador andando.
-- Jogadores: os locais (getSpecificPlayer) e, no cliente de MP, os que ele conhece
-- (getOnlinePlayers, uso vanilla no cliente client/Chat/ISChat.lua:560; no solo a lista
-- vem vazia, bytecode LuaManager$GlobalObject.getOnlinePlayers 23–30).
-- No dedicado o servidor não manda "sirenStop" quando a névoa abre: o cliente solta ao
-- receber "fog" (on), ou sozinho no fim do tempo mais SAFETY_MS (comando perdido).
require "NOM_Math"
require "NOM_Carpideira"

-- RANGE: até onde o zumbi procura jogador pra olhar (tiles); mais longe, fica como está.
-- LOG_MS: no -debug, a cada quanto o log conta congelados e quem ainda anda.
NOM_SirenFreeze = { BATCH = 20, RANGE = 100, SAFETY_MS = 15000, LOG_MS = 3000, frozen = {}, active = false }
local F = NOM_SirenFreeze
local cursor, untilMs, nextLog = 0, nil, nil

-- durationMs: o que falta da sirene; passou disso mais SAFETY_MS sem fim (comando
-- perdido), solta sozinho.
function F.start(durationMs)
    F.active = true
    untilMs = getTimestampMs() + (durationMs or 0) + F.SAFETY_MS
end

-- Solo: quem conta a sirene (server/NOM_FogEvent.lua) renova o prazo a cada tick com o
-- que falta, então a pausa, que segura a contagem, também segura o prazo.
function F.extend(durationMs)
    if F.active then untilMs = getTimestampMs() + durationMs + F.SAFETY_MS end
end

-- Useless que é do jogo: outfit "Useless" e modo Tutorial (o mesmo critério do unstick do
-- NOM_VariantAI). A sirene não congela nem solta.
local function gameOwns(z)
    return getCore():getGameMode() == "Tutorial" or NOM_Carpideira.gameUseless(z)
end

-- Solta quem este processo congelou. Carpideira parada pela regra dela fica parada.
-- Depois, uma passada solta todo zumbi local useless: a posse chega com o useless do dono
-- antigo (pz-api-notes §3.2) num zumbi que o lote daqui ainda não tinha pegado.
-- Sem sirene ativa não faz nada: o "fog" (on) também chega com a névoa já aberta, e a
-- passada soltaria o Estalador cego.
function F.stop()
    if not F.active then return end
    for z in pairs(F.frozen) do
        if not z:isDead() and not NOM_Carpideira.still[z] then z:setUseless(false) end
    end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:isUseless() and not z:isDead() and not z:isRemoteZombie() and not NOM_Carpideira.still[z]
            and not gameOwns(z) then
            z:setUseless(false)
        end
    end
    F.frozen = {}
    F.active = false
    untilMs = nil
end

-- Posições { x, y } dos jogadores vivos. O local aparece de novo na lista online do cliente:
-- repetido não atrapalha o mais perto.
local function players()
    local out = {}
    local function add(p)
        if p and not p:isDead() then out[#out + 1] = { x = p:getX(), y = p:getY() } end
    end
    for i = 0, getNumActivePlayers() - 1 do add(getSpecificPlayer(i)) end
    if isClient() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do add(list:get(i)) end
    end
    return out
end

local function nearest(z, ps)
    local zx, zy = z:getX(), z:getY()
    local best, bestD2 = nil, F.RANGE * F.RANGE
    for _, p in ipairs(ps) do
        local d2 = (p.x - zx) * (p.x - zx) + (p.y - zy) * (p.y - zy)
        if d2 <= bestD2 then best, bestD2 = p, d2 end
    end
    return best
end

-- O useless não interrompe quem já anda: o PathFindState.execute não olha o useless
-- (bytecode). Parar como o próprio execute faz quando o zumbi chega (128–149): bPathfind e
-- bMoving falsos e caminho nil (setVariable em zumbi: client/DebugUIs/DebugContextMenu.lua:642;
-- cancel + setPath2(nil): client/TimedActions/WalkToTimedAction.lua:49-50). A cada passada,
-- caso o jogo refaça o caminho.
local function halt(z)
    z:getPathFindBehavior2():cancel()
    z:setPath2(nil)
    z:setVariable("bPathfind", false)
    z:setVariable("bMoving", false)
end

local function hold(z, ps)
    if z:isDead() or z:isRemoteZombie() or gameOwns(z) then return end
    if not F.frozen[z] then
        z:setUseless(true)
        z:setTarget(nil)
        F.frozen[z] = true
    end
    halt(z)
    local p = nearest(z, ps)
    if p then z:faceLocationF(p.x, p.y) end
end

-- Até BATCH zumbis por tick, em volta na lista (quem chega no meio da sirene entra).
function F.tick()
    if not F.active then return end
    if untilMs and getTimestampMs() > untilMs then
        F.stop()
        return
    end
    local list = getCell():getZombieList()
    local size = list:size()
    if size == 0 then return end
    local ps = players()
    local n = math.min(F.BATCH, size)
    for k = 0, n - 1 do hold(list:get(NOM_Math.mod(cursor + k, size)), ps) end
    cursor = NOM_Math.mod(cursor + n, size)
    if getDebug() and getTimestampMs() >= (nextLog or 0) then
        nextLog = getTimestampMs() + F.LOG_MS
        local frozen, moving = 0, 0
        for z in pairs(F.frozen) do
            frozen = frozen + 1
            if z:isMoving() then moving = moving + 1 end
        end
        print("[NOM] sirene congelados=" .. frozen .. " andando=" .. moving .. " jogadores=" .. #ps)
    end
end

local function forget(z) F.frozen[z] = nil end

-- Objeto reaproveitado (OnZombieCreate): o resetForReuse não limpa o useless, então o
-- que a sirene deixou parado volta solto (a Carpideira parada pela regra dela fica).
local function reused(z)
    if F.frozen[z] and not NOM_Carpideira.still[z] then z:setUseless(false) end
    forget(z)
end

function F.install()
    Events.OnTick.Add(F.tick)
    Events.OnZombieDead.Add(forget)
    Events.OnZombieCreate.Add(reused)
end

return NOM_SirenFreeze
