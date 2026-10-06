-- Sirenes posicionais (sprint 0034): onde tocam as 3 sirenes de cada jogador, qual som e com
-- que atraso. Uma perto (40 a 80 tiles) e duas longe (80 a 200), de lados diferentes (pelo
-- menos 60° entre elas), e as longe entram depois, em coro desencontrado. Puro, sem API do
-- jogo; quem toca é o shared/NOM_Siren.lua. O sorteio é local: dois jogadores não precisam
-- ouvir as mesmas posições.
require "NOM_Math"

NOM_SirenSpotsRules = {
    NEAR_MIN = 40, NEAR_MAX = 80,
    FAR_MIN = 80, FAR_MAX = 200,
    MIN_GAP_DEG = 60,
    DELAY_MIN_MS = 400, DELAY_MAX_MS = 2500,
    -- Ponto único dos sons por tipo de névoa: "near" pra sirene perto, "far" pras longe (a
    -- distância embutida no arquivo). Tipo sem lista usa a branca. A vermelha é o aviso da
    -- névoa vermelha (ADR-010): as listas não se misturam.
    SOUNDS = {
        white = { near = { "NOM_Siren" }, far = { "NOM_SirenFar" } },
        red = { near = { "NOM_SirenRed" }, far = { "NOM_SirenRedFar" } },
    },
}
local R = NOM_SirenSpotsRules

local function lerp(a, b, u) return a + (b - a) * u end

-- Sorteia da lista sem repetir o que já saiu (used), enquanto houver outra opção.
local function pick(list, used, rand)
    local free = {}
    for _, s in ipairs(list) do
        if not used[s] then free[#free + 1] = s end
    end
    if #free == 0 then free = list end
    local s = free[math.min(#free, math.floor(rand() * #free) + 1)]
    used[s] = true
    return s
end

-- Três ângulos com pelo menos MIN_GAP_DEG entre vizinhos no círculo: as três folgas somam 360,
-- cada uma com MIN_GAP_DEG mais um pedaço sorteado do que sobra. Vale pra qualquer rand.
local function angles(rand)
    local spare = 360 - 3 * R.MIN_GAP_DEG
    local u, v = rand(), rand()
    if u > v then u, v = v, u end
    local a = rand() * 360
    return { a, a + R.MIN_GAP_DEG + spare * u, a + 2 * R.MIN_GAP_DEG + spare * v }
end

local function spot(px, py, deg, dist, near, sound, delayMs)
    local a = math.rad(deg)
    return { x = px + math.cos(a) * dist, y = py + math.sin(a) * dist, deg = NOM_Math.mod(deg, 360),
        dist = dist, near = near, sound = sound, delayMs = delayMs }
end

-- As 3 sirenes em volta de (px, py): a perto primeiro (atraso 0), depois as duas longe.
-- kind: "white"/"red". rand: função que devolve [0, 1).
function R.spots(px, py, kind, rand)
    local sounds = R.SOUNDS[kind] or R.SOUNDS.white
    local deg = angles(rand)
    local nearAt = math.min(3, math.floor(rand() * 3) + 1)
    local used = {}
    local out = { spot(px, py, deg[nearAt], lerp(R.NEAR_MIN, R.NEAR_MAX, rand()), true, pick(sounds.near, used, rand), 0) }
    for i = 1, 3 do
        if i ~= nearAt then
            out[#out + 1] = spot(px, py, deg[i], lerp(R.FAR_MIN, R.FAR_MAX, rand()), false, pick(sounds.far, used, rand),
                lerp(R.DELAY_MIN_MS, R.DELAY_MAX_MS, rand()))
        end
    end
    return out
end

return NOM_SirenSpotsRules
