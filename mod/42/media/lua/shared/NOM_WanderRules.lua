-- Perambular na névoa (sprint 0036, spec §5), a regra pura: de quanto em quanto tempo sai
-- uma onda, quem sai e pra onde. Sem API do jogo; quem aplica é o shared/NOM_Wander.lua.
-- Uma onda dá no máximo um grupo de 1 a GROUP_MAX zumbis parados por jogador. O grupo sai
-- de NEAR_MIN a NEAR_MAX tiles do jogador (fora da visão curta, dentro do que está
-- carregado) e anda em formação até um ponto da região: a até REGION_MAX de todo jogador e a
-- pelo menos DEST_MIN, com o caminho reto passando a pelo menos PASS_MIN de todo jogador.
-- Nunca vai direto a ninguém: o encontro vem de o jogador andar e cruzar com eles.
require "NOM_FlakeRules"

NOM_WanderRules = {
    MIN_GAP = 4, MAX_GAP = 8, -- minutos de jogo entre ondas
    NEAR_MIN = 6, NEAR_MAX = 30,
    GROUP_MAX = 3, GROUP_RADIUS = 5,
    LEG_MIN = 8, LEG_MAX = 20, -- quanto o grupo anda
    DEST_MIN = 8, REGION_MAX = 35, PASS_MIN = 5,
    TRIES = 8, -- sorteios de ponto por grupo
    SCAN_MAX = 40, -- candidatos que quem aplica junta por onda (custo, NOM_Wander)
}
local R = NOM_WanderRules

-- rand() em [0, 1), determinístico pela semente (Kahlua não tem math.random).
R.rng = NOM_FlakeRules.rng

-- Minutos até a próxima onda, de um sorteio u em [0, 1).
function R.gap(u)
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    return R.MIN_GAP + math.floor(u * (R.MAX_GAP - R.MIN_GAP + 1))
end

local function d2(ax, ay, bx, by) return (ax - bx) * (ax - bx) + (ay - by) * (ay - by) end

-- Distância² do ponto (px, py) ao segmento a→b.
local function segD2(px, py, ax, ay, bx, by)
    local vx, vy = bx - ax, by - ay
    local len2 = vx * vx + vy * vy
    local t = 0
    if len2 > 0 then t = math.max(0, math.min(1, ((px - ax) * vx + (py - ay) * vy) / len2)) end
    return d2(px, py, ax + vx * t, ay + vy * t)
end

-- Caminho de (ax, ay) até o destino (x, y) aceito por todos os jogadores do andar.
local function fair(players, floor, ax, ay, x, y)
    local nearOne = false
    for _, p in ipairs(players) do
        if math.floor(p.z or 0) == floor then
            local dd = d2(x, y, p.x, p.y)
            if dd < R.DEST_MIN * R.DEST_MIN then return false end
            if dd <= R.REGION_MAX * R.REGION_MAX then nearOne = true end
            if segD2(p.x, p.y, ax, ay, x, y) < R.PASS_MIN * R.PASS_MIN then return false end
        end
    end
    return nearOne
end

local function near(p, z)
    if math.floor(z.z or 0) ~= math.floor(p.z or 0) then return false end
    local dd = d2(z.x, z.y, p.x, p.y)
    return dd >= R.NEAR_MIN * R.NEAR_MIN and dd <= R.NEAR_MAX * R.NEAR_MAX
end

-- players: { { x, y, z } }; zombies: candidatos { x, y, z } (parados, de quem aplica);
-- rand: R.rng(semente); ok(x, y, z): o chão aceita o destino (nil: aceita tudo).
-- Devolve { { i = índice em zombies, x, y, z } }, destinos em tile inteiro.
function R.plan(players, zombies, rand, ok)
    local out, used = {}, {}
    for _, p in ipairs(players or {}) do
        local cands = {}
        for i, z in ipairs(zombies or {}) do
            if not used[i] and near(p, z) then cands[#cands + 1] = i end
        end
        if #cands > 0 then
            local li = cands[1 + math.floor(rand() * #cands)]
            local lead = zombies[li]
            local size = 1 + math.floor(rand() * R.GROUP_MAX)
            local group = { li }
            for _, i in ipairs(cands) do
                if #group >= size then break end
                local z = zombies[i]
                if i ~= li and d2(z.x, z.y, lead.x, lead.y) <= R.GROUP_RADIUS * R.GROUP_RADIUS then
                    group[#group + 1] = i
                end
            end
            local floor = math.floor(lead.z or 0)
            local dx, dy
            for _ = 1, R.TRIES do
                local a = rand() * 2 * math.pi
                local leg = R.LEG_MIN + rand() * (R.LEG_MAX - R.LEG_MIN)
                local x, y = math.floor(lead.x + math.cos(a) * leg), math.floor(lead.y + math.sin(a) * leg)
                if fair(players, floor, lead.x, lead.y, x, y) and (ok == nil or ok(x, y, floor)) then
                    dx, dy = x, y
                    break
                end
            end
            if dx then
                for _, i in ipairs(group) do
                    local z = zombies[i]
                    local x, y = dx + math.floor(z.x - lead.x + 0.5), dy + math.floor(z.y - lead.y + 0.5)
                    if i == li or (fair(players, floor, z.x, z.y, x, y) and (ok == nil or ok(x, y, floor))) then
                        used[i] = true
                        out[#out + 1] = { i = i, x = x, y = y, z = floor }
                    end
                end
            end
        end
    end
    return out
end

return NOM_WanderRules
