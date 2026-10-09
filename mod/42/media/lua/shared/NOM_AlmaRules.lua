-- Regras puras das almas esqueléticas na névoa branca (sprint 0050, §3.9.1):
-- sem API do jogo, testável com ./run-tests.sh. Levas na rua, maioria crawler,
-- seek lento, TTL curto, gap real entre levas. Vermelha/preta/interior: fora.
require "NOM_FlakeRules"

NOM_AlmaRules = {
    CRAWLER_CHANCE = 0.70,
    GAP_MIN_MS = 45000,
    GAP_MAX_MS = 120000,
    -- tamanhos-base das levas (jitter ± WAVE_JITTER)
    WAVE_SIZES = { 10, 15, 20 },
    WAVE_JITTER = 3,
    -- TTL real por indivíduo (ms): ~10 s / ~30 s / ~1 min
    TTL_MS = { 10000, 30000, 60000 },
    HEALTH = 0.25, -- vida baixa (vanilla "normal" nasce ~1,5)
    SPAWN_MIN = 12,
    SPAWN_MAX = 28,
    SEEK_MS = 2500, -- path pro jogador de novo
    SOUND_EVENT_MS = 8000, -- crawl/shamble esporádico por alma
    FEMALE_CHANCE = 50,
    SOUND = {
        spawn = "NOM_AlmaSpawn",
        crawl = "NOM_AlmaCrawl",
        shamble = "NOM_AlmaShamble",
        group = "NOM_AlmaGroup",
        despawn = "NOM_AlmaDespawn",
    },
}
local R = NOM_AlmaRules

R.rng = NOM_FlakeRules.rng

-- Névoa branca aberta (não vermelha, não preta). world: flags NOM_World / FogState.
function R.active(world)
    if not world or world.fog ~= true then return false end
    if world.red == true or world.black == true then return false end
    return true
end

-- Gap real (ms) até a próxima leva, u em [0, 1).
function R.gap(u)
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    return R.GAP_MIN_MS + math.floor(u * (R.GAP_MAX_MS - R.GAP_MIN_MS + 1))
end

-- Tamanho da leva com jitter, mínimo 1.
function R.waveSize(u, uJitter)
    local sizes = R.WAVE_SIZES
    u = math.max(0, math.min(tonumber(u) or 0, 0.9999))
    local base = sizes[1 + math.floor(u * #sizes)]
    uJitter = math.max(0, math.min(tonumber(uJitter) or 0, 0.9999))
    local j = math.floor(uJitter * (2 * R.WAVE_JITTER + 1)) - R.WAVE_JITTER
    return math.max(1, base + j)
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
