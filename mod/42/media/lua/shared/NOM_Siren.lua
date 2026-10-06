-- Sirene do evento de névoa (sprint 0009, ADR-009), no jogo de quem ouve: solo
-- (o server/NOM_FogEvent.lua chama direto) e cliente de MP (comando "siren", em
-- client/NOM_FogClient.lua). Sprint 0034: não é mais um som chapado no jogador. São 5
-- sirenes longe do jogador local (150 a 500 tiles), cada uma num emitter do mundo parado onde
-- foi posto (posições, sons e atrasos: shared/NOM_SirenSpotsRules.lua). Tudo local, sem pacote
-- (pz-api-notes §22 e §23):
-- * tocar: getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, false, nil). Com
--   (nome, nil) o Kahlua escolhe o overload do IsoGridSquare, que dá NPE em square.x
--   (FMODSoundEmitter 1208–1235; visto no console.txt); o de 3 argumentos cai no do
--   IsoObject com nil (1245–1250), e a posição é a do getFreeEmitter;
-- * afinar: setPitch(id, fator) logo depois de tocar (FMODSoundEmitter.setPitch 0–112, local).
--   Ele afina TODO som do emitter, não só o do id: vale porque o getFreeEmitter devolve um
--   emitter vazio e a sirene é o único som nele;
-- * parar: stopSoundLocal(id) no emitter guardado, nunca stopAll (o emitter é do pool e,
--   depois que a sirene acaba, pode estar tocando o som de outro sistema).
-- A sirene acaba sozinha (one-shot); o stop é pro cancelamento (sirenStop).
require "NOM_SirenSpotsRules"
require "NOM_FogEventRules"

NOM_Siren = {}

local playing = {} -- { e = emitter, id }
local pending = {} -- { left = ms reais até entrar, x, y, z, sound, pitch }
local lastMs
local ticking = false

local function start(x, y, z, sound, pitch)
    local e = getWorld():getFreeEmitter(x, y, z)
    local id = e:playSoundImpl(sound, false, nil)
    e:setPitch(id, pitch)
    playing[#playing + 1] = { e = e, id = id }
    if getDebug() then
        print(string.format("[NOM] sirene tocando som=%s x=%d y=%d tom=%.3f id=%s", sound, math.floor(x), math.floor(y),
            pitch, tostring(id)))
    end
end

-- As atrasadas entram na hora delas, contada como a fuga (NOM_FogEventRules.countdown): parada
-- com o jogo pausado (isGamePaused, pz-api-notes §11.2) e no máximo MAX_STEP_MS por tick (o
-- OnTick para de todo no dedicado vazio). getTimestampMs: CONFIRMED server/ISObjectClickHandler.lua:352.
local function tick()
    if #pending == 0 then return end
    local now = getTimestampMs()
    local dt, paused = now - lastMs, isGamePaused()
    lastMs = now
    local left = {}
    for _, s in ipairs(pending) do
        s.left = NOM_FogEventRules.countdown(s.left, dt, paused)
        if s.left <= 0 then start(s.x, s.y, s.z, s.sound, s.pitch) else left[#left + 1] = s end
    end
    pending = left
end

function NOM_Siren.stop()
    for _, h in ipairs(playing) do
        if h.e:isPlaying(h.id) then h.e:stopSoundLocal(h.id) end
    end
    playing, pending = {}, {}
end

-- ZombRand(n): inteiro em [0, n) (uso no mod: client/NOM_FogSound.lua)
local function rand() return ZombRand(10000) / 10000 end

-- Devolve quantas sirenes vão tocar, ou nil sem jogador local. Tocar de novo (o comando
-- repetido de quem entra na fuga) troca as que estavam tocando.
function NOM_Siren.play(red)
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p then return nil end
    NOM_Siren.stop()
    if not ticking then
        Events.OnTick.Add(tick)
        ticking = true
    end
    local z = math.floor(p:getZ())
    lastMs = getTimestampMs()
    local spots = NOM_SirenSpotsRules.spots(p:getX(), p:getY(), red and "red" or "white", rand)
    for _, s in ipairs(spots) do
        if s.delayMs <= 0 then
            start(s.x, s.y, z, s.sound, s.pitch)
        else
            pending[#pending + 1] = { left = s.delayMs, x = s.x, y = s.y, z = z, sound = s.sound, pitch = s.pitch }
        end
    end
    return #spots
end

return NOM_Siren
