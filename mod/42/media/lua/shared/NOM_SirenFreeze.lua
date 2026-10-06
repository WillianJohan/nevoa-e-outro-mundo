-- Sirene (spec do modelo novo §3): enquanto ela toca, todo zumbi para em pé, virado
-- pra direção de onde ela "vem", e ignora o jogador. Quando a névoa começa, todos
-- voltam juntos. Roda onde o zumbi é simulado (ADR-005): no solo, chamado pelo
-- server/NOM_FogEvent.lua; no MP, pelo client/NOM_FogClient.lua (comandos "siren",
-- "fog" e "sirenStop"). Cópia remota (z:isRemoteZombie()) é do cliente dono: aqui não
-- se mexe, e o useless dela chega no pacote do dono (pz-api-notes §3.2).
-- Parada: setUseless(true) + setTarget(nil) no dono (pz-api-notes §3.2 e §13).
-- Virar: IsoGameCharacter.faceLocationF(FF)Z (uso vanilla
-- client/BuildingObjects/TimedActions/ISBuildAction.lua:248).
-- No dedicado o servidor não manda "sirenStop" quando a névoa abre: o cliente solta ao
-- receber "fog" (on), ou sozinho no fim do tempo mais SAFETY_MS (comando perdido).
require "NOM_Math"
require "NOM_Carpideira"

NOM_SirenFreeze = { BATCH = 20, FAR = 100, SAFETY_MS = 15000, frozen = {}, active = false }
local F = NOM_SirenFreeze
local cursor, dx, dy, untilMs = 0, 1, 0, nil

-- dirDeg: graus de onde a sirene vem (NOM_FogEventRules.sirenDir). durationMs: o que
-- falta da sirene; passou disso mais SAFETY_MS sem fim (comando perdido), solta sozinho.
function F.start(dirDeg, durationMs)
    local a = math.rad(dirDeg or 0)
    dx, dy = math.cos(a), math.sin(a)
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

local function hold(z)
    if z:isDead() or z:isRemoteZombie() or gameOwns(z) then return end
    if not F.frozen[z] then
        z:setUseless(true)
        z:setTarget(nil)
        F.frozen[z] = true
    end
    z:faceLocationF(z:getX() + dx * F.FAR, z:getY() + dy * F.FAR)
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
    local n = math.min(F.BATCH, size)
    for k = 0, n - 1 do hold(list:get(NOM_Math.mod(cursor + k, size))) end
    cursor = NOM_Math.mod(cursor + n, size)
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
