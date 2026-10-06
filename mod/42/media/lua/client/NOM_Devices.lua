-- Aparelhos do Outro Mundo (sprint 0034), só no jogo de quem ouve (solo e cliente de MP):
-- TV, rádio, caixa de som e rádio de carro perto do jogador 0 chiam e "falam" na névoa,
-- ligados ou não. É atmosfera local (ADR-007): nada vai pra rede nem pro save, não chama
-- zumbi (nada de addSound) e o aparelho não muda de estado. Quando e qual:
-- shared/NOM_DeviceRules.lua. Evidência das APIs: docs/architecture/pz-api-notes.md §22.
-- * Aparelhos: getZomboidRadio():getDevices(), a lista que o jogo mantém com todo
--   IsoWaveSignal e VehiclePart com rádio em chunk carregado. Nada de varrer quadrados.
-- * Tocar: getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, nil), local; no carro,
--   vehicle:playSoundImpl(nome, nil) (o emitter segue o carro). O emitter do próprio
--   aparelho só existe ligado e perto, e playSound/PlayWorldSound mandam pacote.
-- * Parar: stopSoundLocal(id) no emitter guardado, nunca stopAll (o emitter é do pool e
--   pode estar tocando som de outro sistema).
-- Desliga junto com o som de ambiente da névoa (sandbox FogAmbience).
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_DeviceRules"
require "NOM_SemRosto"
require "NOM_Carpideira"

NOM_Devices = {
    UPDATE_TICKS = 10,
    SCAN_MS = 1000, -- a lista do jogo no máximo uma vez por segundo
}

local S = NOM_Devices
local R = NOM_DeviceRules

-- Som tocando: { e = emitter, id, d = aparelho (posição atual), kind = "call"/"semrosto"/"scream" }.
-- slot: o único som de aparelho do jogador fora do presságio; omen: os estouros.
local slot
local omen = {}
local omenFor     -- omenAt do presságio que já estourou
local nextCall    -- ms reais do próximo chamado
local lastEnd     -- ms reais do fim do último som do slot
local lastChirp   -- ms reais do último chiado do Sem-rosto
local lastScan
local recent = {} -- R.remember

local function playing(h)
    return h ~= nil and h.e:isPlaying(h.id)
end

local function stop(h)
    if playing(h) then h.e:stopSoundLocal(h.id) end
end

local function stopOmen()
    for _, h in ipairs(omen) do stop(h) end
    omen = {}
end

local function d2(d, p)
    local dx, dy = d:getX() - p:getX(), d:getY() - p:getY()
    return dx * dx + dy * dy
end

-- Candidatos a até OMEN_RANGE, no andar do jogador (R: formato do candidato).
-- Rádio de carro sem rádio instalado (getInventoryItem nil) não fala.
local function scan(p, fogKind)
    local out = {}
    local pz = math.floor(p:getZ())
    local r2 = R.OMEN_RANGE * R.OMEN_RANGE
    local list = getZomboidRadio():getDevices()
    for i = 0, list:size() - 1 do
        local d = list:get(i)
        local dist2 = d2(d, p)
        local dd = dist2 <= r2 and math.floor(d:getZ()) == pz and d:getDeviceData() or nil
        if dd then
            local car = dd:isVehicleDevice()
            local vehicle = car and d:getInventoryItem() and d:getVehicle() or nil
            if not car or vehicle then
                local x, y = math.floor(d:getX()), math.floor(d:getY())
                local tv = dd:getIsTelevision()
                local live = dd:getIsTurnedOn() and R.powered(dd:getIsBatteryPowered(), dd:getPower(), dd:canBePoweredHere())
                local kind = R.kind(tv, car, x, y, pz)
                out[#out + 1] = { d = d, vehicle = vehicle, x = x, y = y, z = pz, d2 = dist2, tv = tv,
                    live = live == true, kind = kind, sound = R.sound(kind, fogKind) }
            end
        end
    end
    return out
end

local function play(c, name, kind)
    local e, id
    if c.vehicle then
        e = c.vehicle:getEmitter()
        id = c.vehicle:playSoundImpl(name, nil)
    else
        e = getWorld():getFreeEmitter(c.x + 0.5, c.y + 0.5, c.z)
        id = e:playSoundImpl(name, nil)
    end
    e:setVolume(id, R.volume(c.live))
    return { e = e, id = id, d = c.d, kind = kind }
end

-- O slot é um só: quem chega (Sem-rosto, grito) corta o que estiver tocando.
local function take(c, name, kind)
    stop(slot)
    slot = play(c, name, kind)
end

local function reset()
    stop(slot)
    slot, nextCall, lastEnd, lastChirp, lastScan, recent = nil, nil, nil, nil, nil, {}
end

local function semRosto(p, cands, now)
    local near = NOM_SemRosto.nearest(p)
    if not near or near > R.CALL_FAR + R.SEMROSTO_RANGE then return end
    if lastChirp and now - lastChirp < R.SEMROSTO_GAP_MS then return end
    if playing(slot) and slot.kind == "semrosto" then return end
    for _, c in ipairs(cands) do
        c.semRosto = NOM_SemRosto.near(c.x + 0.5, c.y + 0.5, c.z, R.SEMROSTO_RANGE)
    end
    local c = R.pickSemRosto(cands)
    if not c then return end
    take(c, R.BURST, "semrosto")
    lastChirp = now
end

local function call(cands, now)
    if playing(slot) or not R.callDue(now, nextCall, lastEnd) then return end
    local c, blocked = R.pick(cands, recent, ZombRand(100) / 100)
    if not c and not blocked then return end -- nenhum aparelho na faixa: espera
    if c then take(c, c.sound, "call") end
    recent = R.remember(recent, c and c.sound or false)
    nextCall = R.nextCall(now, ZombRand(R.CALL_MAX_MS - R.CALL_MIN_MS))
end

local function fog(p, now)
    if slot and (not playing(slot) or R.outOfRange(d2(slot.d, p))) then
        stop(slot)
        slot, lastEnd = nil, now
    end
    nextCall = nextCall or R.nextCall(now, ZombRand(R.CALL_MAX_MS - R.CALL_MIN_MS))
    if lastScan and now - lastScan < S.SCAN_MS then return end
    lastScan = now
    local cands = scan(p, R.fogKind(NOM_FogState))
    semRosto(p, cands, now)
    call(cands, now)
end

local function listener()
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p or p:isDead() or not NOM_Config.get("FogAmbience") then return nil end
    return p
end

local ticks = 0
local function onTick()
    ticks = ticks + 1
    if ticks < S.UPDATE_TICKS then return end
    ticks = 0
    local now = getTimestampMs()
    local p = listener()
    local mode = p and R.mode(NOM_FogState, now) or nil
    if mode ~= "omen" then stopOmen() end
    if mode ~= "fog" then reset() end
    if mode == "omen" and omenFor ~= NOM_FogState.omenAt then
        omenFor = NOM_FogState.omenAt
        for _, c in ipairs(R.omenTargets(scan(p, "white"))) do
            omen[#omen + 1] = play(c, R.BURST, "omen")
        end
    elseif mode == "fog" then
        fog(p, now)
    end
end

-- Grito de Carpideira na vermelha: o aparelho perto do grito respira (o som vermelho dele).
-- O Sem-rosto chiando tem a vez. O grito do Corredor não chega ao cliente pelo Lua
-- (server/NOM_Variants.lua manda sendPlaySound) e fica de fora.
NOM_Carpideira.onScream(function(z)
    local p = listener()
    local now = getTimestampMs()
    if not p or R.mode(NOM_FogState, now) ~= "fog" or not NOM_FogState.red then return end
    if playing(slot) and slot.kind == "semrosto" then return end
    local c = R.pickScream(scan(p, "red"), z:getX(), z:getY())
    if c then take(c, c.sound, "scream") end
end)

Events.OnTick.Add(onTick)

return NOM_Devices
