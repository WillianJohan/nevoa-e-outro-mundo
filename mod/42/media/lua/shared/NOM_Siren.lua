-- Sirene do evento de névoa (sprint 0009, ADR-009), no jogo de quem ouve: solo
-- (o server/NOM_FogEvent.lua chama direto) e cliente de MP (comando "siren", em
-- client/NOM_FogClient.lua). Sprint 0034: não é mais um som chapado no jogador. São 3
-- sirenes em volta do jogador local, uma perto e duas longe, cada uma num emitter do mundo
-- parado onde foi posto (posições e atrasos: shared/NOM_SirenSpotsRules.lua). Tudo local,
-- sem pacote (pz-api-notes §22 e §23):
-- * tocar: getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, false, nil). Com
--   (nome, nil) o Kahlua escolhe o overload do IsoGridSquare, que dá NPE em square.x
--   (FMODSoundEmitter 1208–1235; visto no console.txt); o de 3 argumentos cai no do
--   IsoObject com nil (1245–1250), e a posição é a do getFreeEmitter;
-- * parar: stopSoundLocal(id) no emitter guardado, nunca stopAll (o emitter é do pool e,
--   depois que a sirene acaba, pode estar tocando o som de outro sistema).
-- A sirene acaba sozinha (one-shot); o stop é pro cancelamento (sirenStop).
require "NOM_SirenSpotsRules"

NOM_Siren = {}

local playing = {} -- { e = emitter, id }
local pending = {} -- { at = ms reais, x, y, z, sound }
local ticking = false

local function start(x, y, z, sound)
    local e = getWorld():getFreeEmitter(x, y, z)
    local id = e:playSoundImpl(sound, false, nil)
    playing[#playing + 1] = { e = e, id = id }
    if getDebug() then
        print(string.format("[NOM] sirene tocando som=%s x=%d y=%d id=%s", sound, math.floor(x), math.floor(y), tostring(id)))
    end
end

-- As longe entram no atraso delas (getTimestampMs, CONFIRMED server/ISObjectClickHandler.lua:352).
local function tick()
    if #pending == 0 then return end
    local now = getTimestampMs()
    local left = {}
    for _, s in ipairs(pending) do
        if now >= s.at then start(s.x, s.y, s.z, s.sound) else left[#left + 1] = s end
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
    local now = getTimestampMs()
    local spots = NOM_SirenSpotsRules.spots(p:getX(), p:getY(), red and "red" or "white", rand)
    for _, s in ipairs(spots) do
        if s.delayMs <= 0 then
            start(s.x, s.y, z, s.sound)
        else
            pending[#pending + 1] = { at = now + s.delayMs, x = s.x, y = s.y, z = z, sound = s.sound }
        end
    end
    return #spots
end

return NOM_Siren
