-- Regras puras das almas esqueléticas (sprint 0055): ciclo constante na névoa
-- (branca, vermelha ou preta), população viva 4–20 na branca/vermelha e 20–40
-- na preta (playtest 2026-10-10), 68% crawler / 32% shambler.
-- Params ajustáveis em runtime pelo debug/painel (POP_*, CRAWLER_*, cores).
-- Sem API do jogo; testável com ./run-tests.sh. Rua + TTL curto mantidos da 0050.
require "NOM_FlakeRules"

NOM_AlmaRules = {
    CRAWLER_CHANCE = 0.68,
    POP_MIN = 4,
    POP_MAX = 20,
    POP_MIN_BLACK = 20,
    POP_MAX_BLACK = 40,
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
    POP_MIN_BLACK = 20,
    POP_MAX_BLACK = 40,
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

-- Piso/teto efetivos pra cor da névoa (preta ≠ branca/vermelha).
function R.popBounds(world)
    if world and world.black == true then
        return R.POP_MIN_BLACK, R.POP_MAX_BLACK
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
    -- duas casas (painel em %)
    return math.floor(u * 100 + 0.5) / 100
end

function R.reset()
    local d = R.DEFAULT
    R.CRAWLER_CHANCE = d.CRAWLER_CHANCE
    R.POP_MIN = d.POP_MIN
    R.POP_MAX = d.POP_MAX
    R.POP_MIN_BLACK = d.POP_MIN_BLACK
    R.POP_MAX_BLACK = d.POP_MAX_BLACK
    R.REFILL_MS = d.REFILL_MS
    R.COLOR_WHITE = d.COLOR_WHITE
    R.COLOR_RED = d.COLOR_RED
    R.COLOR_BLACK = d.COLOR_BLACK
end

-- field: popMin|popMax|popMinBlack|popMaxBlack|crawler|white|red|black|reset.
-- value nil = toggle (cores). Devolve o valor efetivo (número/bool) ou a string do reset.
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
    return "pop=" .. R.POP_MIN .. "-" .. R.POP_MAX
        .. " pop_preta=" .. R.POP_MIN_BLACK .. "-" .. R.POP_MAX_BLACK
        .. " crawler=" .. pct .. "%"
        .. " cores=" .. cor
        .. " refill_ms=" .. R.REFILL_MS
end

-- Quantas almas spawnar agora pra manter [popMin, popMax] da cor (world.black → 20–40).
-- alive < popMin → alvo sorteado em [popMin, popMax]; senão 0. u em [0, 1).
-- world nil = faixa branca/vermelha (compat dos testes e do debug sem névoa).
function R.refillCount(alive, u, world)
    local popMin, popMax = R.popBounds(world)
    alive = math.floor(tonumber(alive) or 0)
    if alive < 0 then alive = 0 end
    if alive >= popMin then return 0 end
    if alive >= popMax then return 0 end
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    local span = popMax - popMin + 1
    local target = popMin + math.floor(u * span)
    if target < popMin then target = popMin end
    if target > popMax then target = popMax end
    local need = target - alive
    local floorNeed = popMin - alive
    if need < floorNeed then need = floorNeed end
    local room = popMax - alive
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
