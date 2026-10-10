-- Regras puras das almas esqueléticas (sprint 0068 / proposta névoas v2):
-- a cada TICK_MS, por zona de jogador (MP: quem está a ≤ COUNT_RADIUS não multiplica),
-- sorteia alvo na faixa da cor, conta esqueletos no raio e spawna a diferença.
-- Branca 5–30 só crawler; vermelha 25–50 crawler+shambler; preta 30–100 e TTL ilimitado.
-- Params ajustáveis pelo debug/painel. Sem API do jogo; testável com ./run-tests.sh.
require "NOM_FlakeRules"

NOM_AlmaRules = {
    CRAWLER_CHANCE = 0.5,
    POP_MIN = 5,
    POP_MAX = 30,
    POP_MIN_RED = 25,
    POP_MAX_RED = 50,
    POP_MIN_BLACK = 30,
    POP_MAX_BLACK = 100,
    TICK_MS = 5000,
    COUNT_RADIUS = 50,
    TTL_MS_MIN = 5000,
    TTL_MS_MAX = 15000,
    HEALTH = 0.25,
    SPAWN_MIN = 12,
    SPAWN_MAX = 50,
    SEEK_MS = 2500,
    SOUND_EVENT_MS = 8000,
    FEMALE_CHANCE = 50,
    COLOR_WHITE = true,
    COLOR_RED = true,
    COLOR_BLACK = true,
    SOUND = {
        spawn = "NOM_AlmaSpawn",
        crawl = "NOM_AlmaCrawl",
        shamble = "NOM_AlmaShamble",
        group = "NOM_AlmaGroup",
        despawn = "NOM_AlmaDespawn",
    },
}
local R = NOM_AlmaRules

R.COUNT_RADIUS_SQ = R.COUNT_RADIUS * R.COUNT_RADIUS
R.POP_HARD_MIN = 0
R.POP_HARD_MAX = 100
R.DEFAULT = {
    CRAWLER_CHANCE = 0.5,
    POP_MIN = 5,
    POP_MAX = 30,
    POP_MIN_RED = 25,
    POP_MAX_RED = 50,
    POP_MIN_BLACK = 30,
    POP_MAX_BLACK = 100,
    TICK_MS = 5000,
    COLOR_WHITE = true,
    COLOR_RED = true,
    COLOR_BLACK = true,
}

R.rng = NOM_FlakeRules.rng

local COLOR_FIELD = {
    white = "COLOR_WHITE",
    red = "COLOR_RED",
    black = "COLOR_BLACK",
}

function R.colorEnabled(color)
    local f = COLOR_FIELD[color]
    if not f then return false end
    return R[f] == true
end

function R.setColor(color, on)
    local f = COLOR_FIELD[color]
    if not f then return false end
    R[f] = on == true
    return R[f]
end

function R.active(world)
    if not world or world.fog ~= true then return false end
    if world.black == true then return R.COLOR_BLACK == true end
    if world.red == true then return R.COLOR_RED == true end
    return R.COLOR_WHITE == true
end

function R.popBounds(world)
    if world and world.black == true then
        return R.POP_MIN_BLACK, R.POP_MAX_BLACK
    end
    if world and world.red == true then
        return R.POP_MIN_RED, R.POP_MAX_RED
    end
    return R.POP_MIN, R.POP_MAX
end

function R.clampPopMin(n, max)
    n = math.floor(tonumber(n) or 0)
    max = math.floor(tonumber(max) or R.POP_MAX)
    if n < R.POP_HARD_MIN then n = R.POP_HARD_MIN end
    if n > R.POP_HARD_MAX then n = R.POP_HARD_MAX end
    if n > max then n = max end
    return n
end

function R.clampPopMax(n, min)
    n = math.floor(tonumber(n) or 0)
    min = math.floor(tonumber(min) or R.POP_MIN)
    if n < R.POP_HARD_MIN then n = R.POP_HARD_MIN end
    if n > R.POP_HARD_MAX then n = R.POP_HARD_MAX end
    if n < min then n = min end
    return n
end

function R.clampCrawler(u)
    u = tonumber(u) or 0
    if u < 0 then u = 0 end
    if u > 1 then u = 1 end
    return math.floor(u * 100 + 0.5) / 100
end

function R.reset()
    local d = R.DEFAULT
    R.CRAWLER_CHANCE = d.CRAWLER_CHANCE
    R.POP_MIN = d.POP_MIN
    R.POP_MAX = d.POP_MAX
    R.POP_MIN_RED = d.POP_MIN_RED
    R.POP_MAX_RED = d.POP_MAX_RED
    R.POP_MIN_BLACK = d.POP_MIN_BLACK
    R.POP_MAX_BLACK = d.POP_MAX_BLACK
    R.TICK_MS = d.TICK_MS
    R.COLOR_WHITE = d.COLOR_WHITE
    R.COLOR_RED = d.COLOR_RED
    R.COLOR_BLACK = d.COLOR_BLACK
end

-- field: popMin|popMax|popMinRed|popMaxRed|popMinBlack|popMaxBlack|crawler|white|red|black|reset.
function R.apply(field, value)
    if field == "reset" then
        R.reset()
        return "reset"
    elseif field == "popMin" then
        R.POP_MIN = R.clampPopMin(value, R.POP_MAX)
        return R.POP_MIN
    elseif field == "popMax" then
        R.POP_MAX = R.clampPopMax(value, R.POP_MIN)
        return R.POP_MAX
    elseif field == "popMinRed" then
        R.POP_MIN_RED = R.clampPopMin(value, R.POP_MAX_RED)
        return R.POP_MIN_RED
    elseif field == "popMaxRed" then
        R.POP_MAX_RED = R.clampPopMax(value, R.POP_MIN_RED)
        return R.POP_MAX_RED
    elseif field == "popMinBlack" then
        R.POP_MIN_BLACK = R.clampPopMin(value, R.POP_MAX_BLACK)
        return R.POP_MIN_BLACK
    elseif field == "popMaxBlack" then
        R.POP_MAX_BLACK = R.clampPopMax(value, R.POP_MIN_BLACK)
        return R.POP_MAX_BLACK
    elseif field == "crawler" then
        R.CRAWLER_CHANCE = R.clampCrawler(value)
        return R.CRAWLER_CHANCE
    elseif COLOR_FIELD[field] then
        if value == nil then
            value = not R.colorEnabled(field)
        end
        return R.setColor(field, value == true)
    end
    return nil
end

function R.describe()
    local pct = math.floor(R.CRAWLER_CHANCE * 100 + 0.5)
    local colors = {}
    if R.COLOR_WHITE then colors[#colors + 1] = "branca" end
    if R.COLOR_RED then colors[#colors + 1] = "vermelha" end
    if R.COLOR_BLACK then colors[#colors + 1] = "preta" end
    local cor = #colors > 0 and table.concat(colors, "+") or "nenhuma"
    return "pop_branca=" .. R.POP_MIN .. "-" .. R.POP_MAX
        .. " pop_vermelha=" .. R.POP_MIN_RED .. "-" .. R.POP_MAX_RED
        .. " pop_preta=" .. R.POP_MIN_BLACK .. "-" .. R.POP_MAX_BLACK
        .. " crawler=" .. pct .. "%"
        .. " cores=" .. cor
        .. " tick_ms=" .. R.TICK_MS
        .. " raio=" .. R.COUNT_RADIUS
end

-- Alvo sorteado na faixa da cor; u em [0, 1).
function R.tickTarget(u, world)
    local popMin, popMax = R.popBounds(world)
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    local span = popMax - popMin + 1
    local target = popMin + math.floor(u * span)
    if target < popMin then target = popMin end
    if target > popMax then target = popMax end
    return target
end

-- Quantas almas spawnar neste tick (proposta v2: current < target → target - current).
function R.spawnNeed(current, u, world)
    current = math.floor(tonumber(current) or 0)
    if current < 0 then current = 0 end
    local target = R.tickTarget(u, world)
    if current >= target then return 0 end
    return target - current
end

-- Compat: testes antigos e callers legados.
function R.refillCount(alive, u, world)
    return R.spawnNeed(alive, u, world)
end

function R.ttlUnlimited(world)
    return world and world.black == true
end

-- TTL (ms) de um indivíduo; preta = nil (ilimitado).
function R.ttl(u, world)
    if R.ttlUnlimited(world) then return nil end
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    local span = R.TTL_MS_MAX - R.TTL_MS_MIN + 1
    local ms = R.TTL_MS_MIN + math.floor(u * span)
    if ms > R.TTL_MS_MAX then ms = R.TTL_MS_MAX end
    return ms
end

function R.whiteOnlyCrawlers(world)
    if not world or world.black == true or world.red == true then return false end
    return true
end

function R.isCrawler(u, world)
    if R.whiteOnlyCrawlers(world) then return true end
    u = tonumber(u) or 0
    return u < R.CRAWLER_CHANCE
end

function R.loopSound(crawler)
    if crawler then return R.SOUND.crawl end
    return R.SOUND.shamble
end

-- Distância ao quadrado entre dois pontos {x,y}.
function R.distSq(a, b)
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

function R.nearPoint(x, y, px, py, r2)
    local dx, dy = x - px, y - py
    return dx * dx + dy * dy <= r2
end

-- MP: jogadores a ≤ COUNT_RADIUS tiles ficam na mesma zona (população não multiplica).
function R.clusterPlayers(players)
    local n = #players
    if n == 0 then return {} end
    local parent = {}
    for i = 1, n do parent[i] = i end
    local function find(i)
        while parent[i] ~= i do
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        return i
    end
    local function union(a, b)
        local ra, rb = find(a), find(b)
        if ra ~= rb then parent[rb] = ra end
    end
    local r2 = R.COUNT_RADIUS_SQ
    for i = 1, n do
        for j = i + 1, n do
            if R.distSq(players[i], players[j]) <= r2 then
                union(i, j)
            end
        end
    end
    local buckets = {}
    for i = 1, n do
        local r = find(i)
        buckets[r] = buckets[r] or {}
        buckets[r][#buckets[r] + 1] = players[i]
    end
    local out = {}
    for _, list in pairs(buckets) do
        out[#out + 1] = list
    end
    return out
end

-- Conta posições {x,y} dentro do raio de qualquer âncora da zona.
function R.countNearAnchors(anchors, positions)
    local n = 0
    local r2 = R.COUNT_RADIUS_SQ
    for i = 1, #positions do
        local p = positions[i]
        local px, py = p.x, p.y
        for j = 1, #anchors do
            local a = anchors[j]
            if R.nearPoint(px, py, a.x, a.y, r2) then
                n = n + 1
                break
            end
        end
    end
    return n
end

function R.pickSpawn(px, py, pz, rand, outside, tries)
    tries = tries or 12
    for _ = 1, tries do
        local a = rand() * 2 * math.pi
        local d = R.SPAWN_MIN + rand() * (R.SPAWN_MAX - R.SPAWN_MIN)
        local x = math.floor(px + math.cos(a) * d + 0.5)
        local y = math.floor(py + math.sin(a) * d + 0.5)
        local z = math.floor(pz or 0)
        if outside == nil or outside(x, y, z) then
            return { x = x, y = y, z = z }
        end
    end
    return nil
end

function R.streetOk(outsideFlag)
    return outsideFlag == true
end

return NOM_AlmaRules
