-- Regras puras dos aparelhos do Outro Mundo (sprint 0034): TV, rádio, caixa de som e
-- rádio de carro chiam e "falam" na névoa. Sem API do jogo, testável com ./run-tests.sh.
-- Quem varre e toca é o client/NOM_Devices.lua.
--
-- Candidato (montado pelo cliente a cada varredura): { d2 = distância² ao jogador,
-- live = ligado e com energia, tv = é TV, kind = "tv"/"radio"/"speaker"/"car",
-- sound = som do kind na névoa atual, x, y = tile do aparelho, semRosto = Sem-rosto perto }.
require "NOM_Math"
require "NOM_FogEventRules"

NOM_DeviceRules = {
    OMEN_RANGE = 25,       -- presságio: todo aparelho até aqui estoura
    OMEN_MAX = 8,          -- teto de estouros juntos (pool de emitters, cidade cheia de aparelhos)
    -- presságio velho sem sirene (comando perdido) não fala: 3 s de presságio e folga de rede
    OMEN_MS = NOM_FogEventRules.PRESAGE_MS + 2000,
    CALL_NEAR = 6,         -- o chamado vem de um aparelho entre 6 e 18 tiles
    CALL_FAR = 18,
    STOP_RANGE = 20,       -- o FMOD não zera depois do distanceMax: o cliente para aqui
    SEMROSTO_RANGE = 10,   -- Sem-rosto a até 10 tiles do aparelho: ele chia junto
    SEMROSTO_GAP_MS = 8000,
    SCREAM_RANGE = 20,     -- grito na vermelha: o aparelho a até 20 tiles do grito respira
    CALL_MIN_MS = 90000,   -- tempo real entre chamados
    CALL_MAX_MS = 180000,
    GAP_MS = 60000,        -- nunca menos que isto depois do último som de aparelho
    REPEAT_GAP = 3,        -- o mesmo arquivo só volta no 3º chamado depois
    TV_CHANCE = 0.5,       -- a TV é mais rara: perde a vez na outra metade dos chamados
    OFF_VOLUME = 0.6,      -- desligado ou sem energia fala mais baixo que o ligado
    SPEAKER_SHARE = 3,     -- 1 em cada 3 rádios tem a voz de caixa de som
    BURST = "NOM_DevBurst", -- media/scripts/NOM_sounds.txt
    -- Ponto único de escolha por névoa (R.sound). A preta (sprint 0038) já tem os sons.
    SOUNDS = {
        tv = { white = "NOM_DevTv", red = "NOM_DevTvRed", black = "NOM_DevTvBlack" },
        radio = { white = "NOM_DevRadio", red = "NOM_DevRadioRed", black = "NOM_DevRadioBlack" },
        speaker = { white = "NOM_DevSpeaker" },
        car = { white = "NOM_DevCar" },
    },
}

local R = NOM_DeviceRules

-- s = NOM_FogState. "omen": presságio até a sirene; "fog": névoa aberta; nil: fuga,
-- calmaria ou sem névoa (silêncio).
function R.mode(s, now)
    if s.on then return "fog" end
    if s.rising or not s.omenAt or s.sirenAt then return nil end
    if now - s.omenAt >= R.OMEN_MS then return nil end
    return "omen"
end

function R.fogKind(s)
    return s.red and "red" or "white"
end

-- Kind sem a versão da névoa usa a branca.
function R.sound(kind, fog)
    local byFog = R.SOUNDS[kind]
    return byFog[fog] or byFog.white
end

-- "Voz" estável por tile: o mesmo rádio sempre soa igual (todo cliente sorteia igual).
function R.voice(x, y, z)
    local h = math.floor(x) * 73856093 + math.floor(y) * 19349663 + math.floor(z) * 83492791
    if NOM_Math.mod(h, R.SPEAKER_SHARE) == 0 then return "speaker" end
    return "radio"
end

function R.kind(tv, car, x, y, z)
    if tv then return "tv" end
    if car then return "car" end
    return R.voice(x, y, z)
end

-- "Pode ligar" vanilla (shared/RadioCom/ISRadioAction.lua:57): pilha com carga, ou
-- canBePoweredHere (rede, gerador; no carro, a bateria).
function R.powered(battery, power, grid)
    return (battery and power > 0) or grid == true
end

-- rand: inteiro em [0, CALL_MAX_MS - CALL_MIN_MS).
function R.nextCall(now, rand)
    return now + R.CALL_MIN_MS + rand
end

function R.callDue(now, nextAt, lastEnd)
    if not nextAt or now < nextAt then return false end
    return lastEnd == nil or now - lastEnd >= R.GAP_MS
end

-- Ligado com energia antes; depois o mais perto.
local function better(a, b)
    if b == nil then return true end
    if a.live ~= b.live then return a.live end
    return a.d2 < b.d2
end

local function best(cands, ok)
    local out
    for _, c in ipairs(cands) do
        if ok(c) and better(c, out) then out = c end
    end
    return out
end

local function wasRecent(recent, name)
    for _, n in ipairs(recent) do
        if n == name then return true end
    end
    return false
end

-- Últimos REPEAT_GAP - 1 chamados (false = chamado em silêncio).
function R.remember(recent, name)
    local out = { name }
    for i = 1, R.REPEAT_GAP - 2 do out[#out + 1] = recent[i] end
    return out
end

-- O aparelho do chamado. tvRoll em [0, 1). Devolve (candidato, bloqueado): bloqueado =
-- tinha aparelho na faixa, mas todos repetiriam o arquivo ou a TV perdeu a vez; o
-- chamado passa em silêncio (e conta). Sem aparelho na faixa, o chamado espera.
function R.pick(cands, recent, tvRoll)
    local near2, far2 = R.CALL_NEAR * R.CALL_NEAR, R.CALL_FAR * R.CALL_FAR
    local inBand = false
    local c = best(cands, function(c)
        if c.d2 < near2 or c.d2 > far2 then return false end
        inBand = true
        if c.tv and tvRoll >= R.TV_CHANCE then return false end
        return not wasRecent(recent, c.sound)
    end)
    return c, c == nil and inBand
end

function R.omenTargets(cands)
    local r2 = R.OMEN_RANGE * R.OMEN_RANGE
    local out = {}
    for _, c in ipairs(cands) do
        if c.d2 <= r2 then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.d2 < b.d2 end)
    for i = #out, R.OMEN_MAX + 1, -1 do out[i] = nil end
    return out
end

function R.pickSemRosto(cands)
    local far2 = R.CALL_FAR * R.CALL_FAR
    return best(cands, function(c) return c.semRosto == true and c.d2 <= far2 end)
end

-- (sx, sy): onde a Carpideira gritou.
function R.pickScream(cands, sx, sy)
    local far2, s2 = R.CALL_FAR * R.CALL_FAR, R.SCREAM_RANGE * R.SCREAM_RANGE
    return best(cands, function(c)
        local dx, dy = c.x + 0.5 - sx, c.y + 0.5 - sy
        return c.d2 <= far2 and dx * dx + dy * dy <= s2
    end)
end

function R.outOfRange(d2)
    return d2 > R.STOP_RANGE * R.STOP_RANGE
end

function R.volume(live)
    return live and 1 or R.OFF_VOLUME
end

return NOM_DeviceRules
