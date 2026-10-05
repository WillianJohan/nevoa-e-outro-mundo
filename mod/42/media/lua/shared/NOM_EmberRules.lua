-- Regras puras das brasas da morte do Eco (sprint 0018, ADR-016): partículas de
-- brasa e cinza que sobem do corpo. Sem API do jogo. Posições em pixels de tela no
-- zoom 1, relativas ao pé do Eco (y negativo = pra cima); quem desenha divide pelo
-- zoom (client/NOM_Embers.lua).
require "NOM_Math"

NOM_EmberRules = {
    COUNT = 18,      -- brasas por morte
    LIFE_MS = 1600,  -- vida máxima de uma brasa
    CAP = 4,         -- mortes com brasa ao mesmo tempo
    ORANGE = { 1, 0.55, 0.15 },
    ASH = { 0.45, 0.42, 0.4 },
}

local E = NOM_EmberRules
local M = 2147483647 -- Park–Miller: s·16807 < 2^46, exato em double (Kahlua e luajit)

-- Sorteio determinístico pela semente (o jogo e o teste dão o mesmo).
local function rng(seed)
    local s = NOM_Math.mod(math.floor(math.abs(seed)), M - 1) + 1
    return function()
        s = NOM_Math.mod(s * 16807, M)
        return s / M
    end
end

function E.burst(seed)
    local r = rng(seed)
    local out = {}
    for i = 1, E.COUNT do
        out[i] = {
            x = (r() - 0.5) * 24, y = -r() * 48,           -- do tronco ao chão
            vx = (r() - 0.5) * 36, vy = -(45 + r() * 60),   -- px/s, sobe
            life = E.LIFE_MS * (0.55 + 0.45 * r()),
            size = 2 + math.floor(r() * 3),
        }
    end
    return out
end

-- dx, dy, alfa, r, g, b, tamanho da brasa p aos ms de vida; nil se apagou.
function E.at(p, ms)
    if ms >= p.life then return nil end
    local k = math.max(0, ms) / p.life
    local s = math.max(0, ms) / 1000
    local a = (1 - k) * math.min(1, k * 10 + 0.3)
    local o, g = E.ORANGE, E.ASH
    return p.x + p.vx * s, p.y + p.vy * s, a,
        o[1] + (g[1] - o[1]) * k, o[2] + (g[2] - o[2]) * k, o[3] + (g[3] - o[3]) * k, p.size
end

return NOM_EmberRules
