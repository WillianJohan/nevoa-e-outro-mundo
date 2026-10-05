-- Som da névoa, só no jogo de quem ouve (solo e cliente de MP): drone grave em
-- loop, ruídos metálicos de vez em quando e o rádio chiando "na cabeça" mais
-- forte quanto mais perto o Sem-rosto. Nada vai pra rede: player:playSoundLocal
-- é getEmitter():playSoundImpl(nome, nil), sem pacote (bytecode
-- IsoGameCharacter.playSoundLocal; uso vanilla client/ISUI/Maps/ISMap.lua:210).
-- emitter:playSound e stopSound mandam pacote no cliente de MP (FMODSoundEmitter
-- 0–104, sendStopSound) e não são usados aqui.
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_AtmosphereRules"
require "NOM_SemRostoRules"
require "NOM_SemRosto"

NOM_FogSound = {
    DRONE = "NOM_FogDrone",      -- media/scripts/NOM_sounds.txt
    METAL = "NOM_FogMetal",
    STATIC = "NOM_RadioStatic",
    DRONE_MAX = 0.6,
    STATIC_MAX = 0.8,
    FADE_MS = 8000,              -- do silêncio ao drone cheio e de volta (tempo real)
    STATIC_FADE_MS = 500,        -- o rádio acompanha a distância rápido
    METAL_MIN_MS = 20000,
    METAL_MAX_MS = 60000,
    UPDATE_TICKS = 10,
}

local S = NOM_FogSound
local A = NOM_AtmosphereRules

-- { p = jogador dono do emitter, id = som tocando, vol = volume atual }
local drone = { vol = 0 }
local static = { vol = 0 }
local lastMs, nextMetal

local function stop(loop)
    if loop.id then loop.p:getEmitter():stopSoundLocal(loop.id) end
    loop.id, loop.p = nil, nil
end

-- Leva o loop ao volume alvo com fade; para quando chega a 0. O arquivo é
-- declarado com loop = true, mas se o som morrer (sem loop, cortado), toca de novo.
local function update(loop, p, name, target, dt, fadeMs)
    loop.vol = A.approach(loop.vol, target, dt, fadeMs)
    if loop.p and loop.p ~= p then stop(loop) end -- outro personagem
    if loop.vol <= 0 then
        stop(loop)
        return
    end
    local e = p:getEmitter()
    if not loop.id or not e:isPlaying(loop.id) then
        loop.id, loop.p = p:playSoundLocal(name), p
    end
    e:setVolume(loop.id, loop.vol)
end

local function metal(p, now, on)
    if not on then
        nextMetal = nil
        return
    end
    nextMetal = nextMetal or now + S.METAL_MIN_MS + ZombRand(S.METAL_MAX_MS - S.METAL_MIN_MS)
    if now < nextMetal then return end
    p:playSoundLocal(S.METAL)
    nextMetal = now + S.METAL_MIN_MS + ZombRand(S.METAL_MAX_MS - S.METAL_MIN_MS)
end

local ticks = 0
local function onTick()
    ticks = ticks + 1
    if ticks < S.UPDATE_TICKS then return end
    ticks = 0
    local now = getTimestampMs()
    local dt = lastMs and now - lastMs or 0
    lastMs = now
    local p = getPlayer()
    if not p or p:isDead() then
        stop(drone)
        stop(static)
        drone.vol, static.vol = 0, 0
        return
    end
    local fog = NOM_FogState.on
    local ambience = fog and NOM_Config.get("FogAmbience")
    -- approach anda 1 por fadeMs: escala pra o fade inteiro levar FADE_MS
    update(drone, p, S.DRONE, ambience and S.DRONE_MAX or 0, dt, S.FADE_MS / S.DRONE_MAX)
    metal(p, now, ambience)
    local radio = 0
    if fog and NOM_Config.get("SemRostoEnabled") then
        radio = NOM_SemRostoRules.staticVolume(NOM_SemRosto.nearest(p)) * S.STATIC_MAX
    end
    update(static, p, S.STATIC, radio, dt, S.STATIC_FADE_MS)
end

Events.OnTick.Add(onTick)

return NOM_FogSound
