-- Regras puras das almas esqueléticas (sprint 0055): ciclo constante na névoa
-- (branca, vermelha ou preta), população viva 4–20, 68% crawler / 32% shambler.
-- Params ajustáveis em runtime pelo debug/painel (POP_*, CRAWLER_*, cores).
-- Sem API do jogo; testável com ./run-tests.sh. Rua + TTL curto mantidos da 0050.
require "NOM_FlakeRules"

NOM_AlmaRules = {
    CRAWLER_CHANCE = 0.68,
    POP_MIN = 4,
    POP_MAX = 20,
    -- throttle real entre tentativas de repor (quando abaixo do mínimo)
    REFILL_MS = 2000,
    -- TTL real por indivíduo (ms): ~10 s / ~30 s / ~1 min
    TTL_MS = { 10000, 30000, 60000 },
    HEALTH = 0.25, -- vida baixa (vanilla "normal" nasce ~1,5)
    SPAWN_MIN = 12,
    SPAWN_MAX = 28,
    SEEK_MS = 2500, -- path pro jogador de novo
    SOUND_EVENT_MS = 8000, -- crawl/shamble esporádico por alma
    FEMALE_CHANCE = 50,
    -- cores onde o ciclo roda (debug/painel pode desligar)
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

R.POP_HARD_MIN = 0
R.POP_HARD_MAX = 50
R.DEFAULT = {
    CRAWLER_CHANCE = 0.68,
    POP_MIN = 4,
    POP_MAX = 20,
    REFILL_MS = 2000,
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

-- Névoa aberta e a cor atual permitida.
function R.active(world)
    if not world or world.fog ~= true then return false end
    if world.black == true then return R.COLOR_BLACK == true end
    if world.red == true then return R.COLOR_RED == true end
    return R.COLOR_WHITE == true
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
    -- duas casas (painel em %)
    return math.floor(u * 100 + 0.5) / 100
end

function R.reset()
    local d = R.DEFAULT
    R.CRAWLER_CHANCE = d.CRAWLER_CHANCE
    R.POP_MIN = d.POP_MIN
    R.POP_MAX = d.POP_MAX
    R.REFILL_MS = d.REFILL_MS
    R.COLOR_WHITE = d.COLOR_WHITE
    R.COLOR_RED = d.COLOR_RED
    R.COLOR_BLACK = d.COLOR_BLACK
end

-- field: popMin|popMax|crawler|white|red|black|reset. value nil = toggle (cores).
-- Devolve o valor efetivo (número/bool) ou a string do reset.
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
    return "pop=" .. R.POP_MIN .. "-" .. R.POP_MAX
        .. " crawler=" .. pct .. "%"
        .. " cores=" .. cor
        .. " refill_ms=" .. R.REFILL_MS
end

-- Quantas almas spawnar agora pra manter [POP_MIN, POP_MAX].
-- alive < POP_MIN → alvo sorteado em [POP_MIN, POP_MAX]; senão 0. u em [0, 1).
function R.refillCount(alive, u)
    alive = math.floor(tonumber(alive) or 0)
    if alive < 0 then alive = 0 end
    if alive >= R.POP_MIN then return 0 end
    if alive >= R.POP_MAX then return 0 end
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    local span = R.POP_MAX - R.POP_MIN + 1
    local target = R.POP_MIN + math.floor(u * span)
    if target < R.POP_MIN then target = R.POP_MIN end
    if target > R.POP_MAX then target = R.POP_MAX end
    local need = target - alive
    local floorNeed = R.POP_MIN - alive
    if need < floorNeed then need = floorNeed end
    local room = R.POP_MAX - alive
    if need > room then need = room end
    if need < 0 then need = 0 end
    return need
end

-- TTL (ms) de um indivíduo.
function R.ttl(u)
    local t = R.TTL_MS
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    return t[1 + math.floor(u * #t)]
end

function R.isCrawler(u)
    u = tonumber(u) or 0
    return u < R.CRAWLER_CHANCE
end

-- Som de evento enquanto viva: crawler vs shambler.
function R.loopSound(crawler)
    if crawler then return R.SOUND.crawl end
    return R.SOUND.shamble
end

-- Ponto de spawn na rua: anel SPAWN_MIN..SPAWN_MAX em volta do jogador.
-- outside(x,y,z) = true se o square existe, está livre e isOutside.
-- Devolve { x, y, z } ou nil.
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

-- Interior: alma some / não spawna. outsideFlag = square:isOutside().
function R.streetOk(outsideFlag)
    return outsideFlag == true
end

return NOM_AlmaRules
