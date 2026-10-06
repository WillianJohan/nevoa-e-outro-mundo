-- Sirenes posicionais (sprint 0034): onde tocam as 5 sirenes de cada jogador, qual som e com
-- que atraso. Todas longe, de 150 a 500 tiles ("não quero que fique gritando no ouvido do
-- jogador", Johan, 2026-10-06), de lados diferentes (pelo menos 40° entre vizinhas) e
-- desencontradas: a primeira entra na hora e cada uma das outras na sua janela de 1 s, até 4 s,
-- pelo menos 0,3 s depois da anterior. Puro, sem API do jogo; quem toca é o shared/NOM_Siren.lua.
-- O sorteio é local: dois jogadores não precisam ouvir as mesmas posições.
require "NOM_Math"

NOM_SirenSpotsRules = {
    COUNT = 5,
    DIST_MIN = 150, DIST_MAX = 500,
    MIN_GAP_DEG = 40,
    DELAY_MAX_MS = 4000, DELAY_MIN_GAP_MS = 300,
    -- Ponto único dos sons por tipo de névoa (gerados em scripts/gen_sounds.py, OFICIAIS). Tipo
    -- sem lista usa a branca. A vermelha é o aviso da névoa vermelha (ADR-010): as listas não se
    -- misturam. A preta só toca a partir da sprint 0038.
    SOUNDS = {
        white = { "NOM_SirenWhite1", "NOM_SirenWhite2", "NOM_SirenWhite3", "NOM_SirenWhite4", "NOM_SirenWhite5",
            "NOM_SirenWhite6" },
        red = { "NOM_SirenRed1", "NOM_SirenRed2", "NOM_SirenRed3", "NOM_SirenRed4", "NOM_SirenRed5", "NOM_SirenRed6" },
        black = { "NOM_SirenBlack1", "NOM_SirenBlack2", "NOM_SirenBlack3", "NOM_SirenBlack4", "NOM_SirenBlack5",
            "NOM_SirenBlack6", "NOM_SirenBlack7", "NOM_SirenBlack8", "NOM_SirenBlack9", "NOM_SirenBlack10" },
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

-- COUNT ângulos com pelo menos MIN_GAP_DEG entre vizinhos no círculo: as folgas somam 360,
-- cada uma com MIN_GAP_DEG mais um pedaço sorteado do que sobra. Vale pra qualquer rand.
local function angles(rand)
    local spare = 360 - R.COUNT * R.MIN_GAP_DEG
    local u = {}
    for i = 1, R.COUNT - 1 do u[i] = rand() end
    table.sort(u)
    local a = rand() * 360
    local out = { a }
    for i = 1, R.COUNT - 1 do out[i + 1] = a + i * R.MIN_GAP_DEG + spare * u[i] end
    return out
end

-- Ordem de entrada embaralhada: senão o coro sempre giraria em volta do jogador.
local function shuffled(n, rand)
    local order = {}
    for i = 1, n do order[i] = i end
    for i = n, 2, -1 do
        local j = math.min(i, math.floor(rand() * i) + 1)
        order[i], order[j] = order[j], order[i]
    end
    return order
end

-- Atraso da k-ésima a entrar (k = 1 é a primeira, na hora).
local function delay(k, rand)
    if k == 1 then return 0 end
    local slot = R.DELAY_MAX_MS / (R.COUNT - 1)
    return (k - 2) * slot + R.DELAY_MIN_GAP_MS + (slot - R.DELAY_MIN_GAP_MS) * rand()
end

-- As COUNT sirenes em volta de (px, py), na ordem em que entram (a primeira com atraso 0).
-- kind: "white"/"red"/"black". rand: função que devolve [0, 1).
function R.spots(px, py, kind, rand)
    local sounds = R.SOUNDS[kind] or R.SOUNDS.white
    local deg = angles(rand)
    local used = {}
    local out = {}
    for k, i in ipairs(shuffled(R.COUNT, rand)) do
        local a, dist = math.rad(deg[i]), lerp(R.DIST_MIN, R.DIST_MAX, rand())
        out[k] = { x = px + math.cos(a) * dist, y = py + math.sin(a) * dist, deg = NOM_Math.mod(deg[i], 360),
            dist = dist, sound = pick(sounds, used, rand), delayMs = delay(k, rand) }
    end
    return out
end

return NOM_SirenSpotsRules
