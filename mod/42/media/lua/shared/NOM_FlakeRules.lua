-- Regras puras das lascas do Outro Mundo (sprint 0035, estilo Silent Hill): pedaços de tinta
-- velha e cinza que saem do chão e das paredes vestidos pelo client/NOM_FogOverlays.lua e
-- sobem devagar, girando, com o vento de lado. Sem API do jogo; o sorteio vem por parâmetro
-- (rand() em [0, 1)). Cada lasca guarda o ponto do mundo onde nasceu (x, y, z, em tiles; z em
-- andares) e anda em pixels de tela no zoom 1 a partir dele (y negativo = pra cima); quem
-- desenha projeta o ponto e divide o movimento pelo zoom (client/NOM_Flakes.lua).
-- Na vermelha (sprint 0040) também nasce cinza solta no ar em volta do jogador (R.air).
require "NOM_Math"

NOM_FlakeRules = {
    MAX = 160,            -- lascas vivas ao mesmo tempo
    BIRTHS_PER_S = 48,    -- teto de nascimentos por segundo
    RATE = 14,            -- nascimentos por segundo com densidade 1 e intensidade 1
    RADIUS = 14,          -- fontes até aqui do jogador, em tiles (dentro da tela no zoom 1)
    WALL_WEIGHT = 3,      -- uma parede solta tanto quanto 3 squares de chão
    WALL_HEIGHT = 0.5,    -- nasce do pé até meia parede (1 = um andar)
    ASH_SHARE = 0.7,      -- fração de cinza entre os nascimentos
    LIFE_MIN_MS = 3000,
    LIFE_MAX_MS = 7000,
    FADE_IN_MS = 500,
    FADE_OUT = 0.35,      -- fração final da vida em que apaga
    MAX_RISE = 30,        -- px/s no zoom 1, a subida mais rápida
    WIND = 7,             -- px/s no zoom 1, deriva do vento
    WIND_SIGN = 1,        -- o vento empurra pra direita da tela
    FRAMES = 8,           -- quadros de giro no sprite sheet (colunas)
    SHAPES = 4,           -- formatos de lasca (linhas)
    CELL = 32,            -- pixels de uma célula do sheet
    TEXTURES = {
        lasca = "media/textures/NOM/NOM_Lascas.png",
        cinza = "media/textures/NOM/NOM_Cinza.png",
    },
    -- Cinza no ar (vermelha, sprint 0040): nasce solta a até AIR_RADIUS tiles do jogador, entre
    -- AIR_Z_MIN e AIR_Z_MAX andares acima do chão, AIR_PER_RATE do ritmo das lascas, até AIR_MAX
    -- vivas (lugar reservado dentro de MAX enquanto o ar está ligado). Flutua a até AIR_DRIFT
    -- px/s pra qualquer lado e aparece devagar.
    AIR_PER_RATE = 0.3,
    AIR_MAX = 40,
    AIR_RADIUS = 9,
    AIR_Z_MIN = 0.15,
    AIR_Z_MAX = 1.1,
    AIR_DRIFT = 6,
    AIR_LIFE_MIN_MS = 5000,
    AIR_LIFE_MAX_MS = 10000,
    AIR_FADE_IN_MS = 1500,
}

local R = NOM_FlakeRules
local M = 2147483647 -- Park–Miller: s·16807 < 2^46, exato em double (Kahlua e luajit)

-- Sorteio em [0, 1) pela semente. O math do Kahlua não tem random (MathLib, bytecode B42.21).
function R.rng(seed)
    local s = NOM_Math.mod(math.floor(math.abs(tonumber(seed) or 1)), M - 1) + 1
    return function()
        s = NOM_Math.mod(s * 16807, M)
        return s / M
    end
end

-- Multiplica a cor da textura (DrawSubTextureRGBA / DrawTextureScaledColor). A lasca do sheet
-- já é escura com borda clara ou ferrugem; a cinza é branca. Na preta (sprint 0038), carvão e
-- cinza escura com um resto de brasa.
local PALETTES = {
    white = { lasca = { 1, 0.96, 0.9 }, cinza = { 0.8, 0.79, 0.77 } },
    red = { lasca = { 0.72, 0.34, 0.3 }, cinza = { 0.66, 0.44, 0.42 } },
    black = { lasca = { 0.3, 0.2, 0.17 }, cinza = { 0.34, 0.33, 0.33 } },
}

function R.palette(fog)
    return PALETTES[fog] or PALETTES.white
end

-- t: relógio do estado em ms (só anda com o step); debt: nascimentos fracionários pendentes.
function R.new()
    return { parts = {}, t = 0, debt = 0 }
end

function R.count(state)
    return #state.parts
end

-- Nascimentos por segundo pela densidade da névoa (NOM_DressingRules.density) e pela
-- intensidade dos efeitos de tela (0 com eles desligados).
function R.rate(density, intensity)
    local d, i = tonumber(density) or 0, tonumber(intensity) or 0
    if d <= 0 or i <= 0 then return 0 end
    return math.min(R.BIRTHS_PER_S, R.RATE * d * i)
end

local function weight(kind)
    if kind == "F" then return 1 end
    return R.WALL_WEIGHT
end

-- Fontes válidas da lista ({ x, y, z, kind = "F"|"N"|"W" }): do andar do jogador e a até
-- RADIUS tiles, com o peso acumulado pro sorteio.
function R.sources(list, px, py, pz)
    local out = { items = {}, cum = {}, total = 0 }
    local r2 = R.RADIUS * R.RADIUS
    for _, s in ipairs(list or {}) do
        local dx, dy = s.x - px, s.y - py
        if s.z == pz and dx * dx + dy * dy <= r2 then
            out.total = out.total + weight(s.kind)
            out.items[#out.items + 1] = s
            out.cum[#out.cum + 1] = out.total
        end
    end
    return out
end

-- Fonte pelo sorteio u em [0, 1) (busca binária no peso acumulado).
function R.pick(src, u)
    local want = u * src.total
    local lo, hi = 1, #src.items
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if src.cum[mid] > want then hi = mid else lo = mid + 1 end
    end
    return src.items[lo]
end

-- Uma lasca nascendo agora (t) na fonte s; as: "lasca" ou "cinza" (sem: sorteia).
function R.spawn(s, t, rand, as)
    as = as or (rand() < R.ASH_SHARE and "cinza" or "lasca")
    local kind = s.kind or "F"
    local x, y, z = s.x, s.y, s.z
    if kind == "N" then
        x, z = x + rand(), z + rand() * R.WALL_HEIGHT
    elseif kind == "W" then
        y, z = y + rand(), z + rand() * R.WALL_HEIGHT
    else
        x, y = x + rand(), y + rand()
    end
    local ash = as == "cinza"
    local p = {
        type = as, from = kind, x = x, y = y, z = z, born = t,
        life = R.LIFE_MIN_MS + (R.LIFE_MAX_MS - R.LIFE_MIN_MS) * rand(),
        -- a cinza é leve: sobe mais rápido e balança mais
        vy = -(ash and (14 + 16 * rand()) or (8 + 12 * rand())),
        vx = R.WIND_SIGN * R.WIND * (0.6 + 0.8 * rand()),
        sway = (ash and 4 or 3) + 4 * rand(),
        swayHz = 0.25 + 0.35 * rand(),
        phase = 2 * math.pi * rand(),
        size = ash and (3 + 3 * rand()) or (10 + 6 * rand()),
        peak = ash and (0.55 + 0.25 * rand()) or (0.85 + 0.15 * rand()),
        shape = 0, f0 = 0, spin = 0,
    }
    if not ash then
        p.shape = math.min(R.SHAPES - 1, math.floor(rand() * R.SHAPES))
        p.f0 = math.floor(rand() * R.FRAMES)
        -- 2 a 5 quadros por segundo, pra um lado ou pro outro
        p.spin = (2 + 3 * rand()) * (rand() < 0.5 and -1 or 1)
    end
    return p
end

-- dx, dy, alfa, quadro, tamanho da lasca p aos ms de vida; nil se acabou.
function R.at(p, ms)
    if ms >= p.life then return nil end
    ms = math.max(0, ms)
    local s = ms / 1000
    local w = 2 * math.pi * p.swayHz * s
    local dx = p.vx * s + p.sway * (math.sin(p.phase + w) - math.sin(p.phase))
    local dy = p.vy * s
    local a = p.peak * math.min(1, ms / (p.fadeIn or R.FADE_IN_MS)) * math.min(1, (p.life - ms) / (p.life * R.FADE_OUT))
    local f = math.floor(NOM_Math.mod(p.f0 + p.spin * s, R.FRAMES))
    return dx, dy, a, f, p.size
end

-- Tira as que acabaram (na ordem, sem buraco) e reconta as do ar.
local function prune(state)
    local parts, n, air = state.parts, 0, 0
    for i = 1, #parts do
        local p = parts[i]
        if state.t - p.born < p.life then
            n = n + 1
            parts[n] = p
            if p.from == "A" then air = air + 1 end
        end
    end
    for i = #parts, n + 1, -1 do parts[i] = nil end
    state.air = air
end

-- Lugar das lascas do chão: MAX menos o reservado pro ar enquanto ele está ligado.
local function room(state)
    local keep = state.airOn and math.max(0, R.AIR_MAX - (state.air or 0)) or 0
    return R.MAX - #state.parts - keep
end

-- Anda dt ms: tira as que acabaram e faz nascer rate por segundo nas fontes src, até o teto
-- de vivas (o que não cabe se perde, não acumula). Devolve quantas nasceram.
function R.step(state, dt, rate, src, rand)
    state.t = state.t + math.max(0, dt)
    prune(state)
    if not rate or rate <= 0 or not src or #src.items == 0 then
        state.debt = 0
        return 0
    end
    state.debt = state.debt + math.min(rate, R.BIRTHS_PER_S) * math.max(0, dt) / 1000
    local n = math.floor(state.debt)
    state.debt = state.debt - n
    n = math.min(n, room(state))
    for _ = 1, n do
        state.parts[#state.parts + 1] = R.spawn(R.pick(src, rand()), state.t, rand)
    end
    return math.max(0, n)
end

-- Um ponto de cinza no ar nascendo agora (t) perto de (x, y), no andar z.
local function airSpawn(x, y, z, t, rand)
    local ang, r = 2 * math.pi * rand(), R.AIR_RADIUS * math.sqrt(rand())
    return {
        type = "cinza", from = "A", born = t, fadeIn = R.AIR_FADE_IN_MS,
        x = x + r * math.cos(ang), y = y + r * math.sin(ang),
        z = z + R.AIR_Z_MIN + (R.AIR_Z_MAX - R.AIR_Z_MIN) * rand(),
        life = R.AIR_LIFE_MIN_MS + (R.AIR_LIFE_MAX_MS - R.AIR_LIFE_MIN_MS) * rand(),
        vx = R.AIR_DRIFT * (2 * rand() - 1),
        vy = R.AIR_DRIFT * (2 * rand() - 1) * 0.5,
        sway = 3 + 5 * rand(),
        swayHz = 0.1 + 0.2 * rand(),
        phase = 2 * math.pi * rand(),
        size = 2 + 3 * rand(),
        peak = 0.35 + 0.3 * rand(),
        shape = 0, f0 = 0, spin = 0,
    }
end

-- Cinza no ar (vermelha): nascem rate × AIR_PER_RATE por segundo em volta de (x, y, z), até
-- AIR_MAX vivas e o teto MAX. Chamar depois do step do quadro (não anda o relógio). Com rate 0
-- o ar desliga e devolve o lugar reservado. Devolve quantas nasceram.
function R.air(state, rate, x, y, z, dt, rand)
    if not rate or rate <= 0 then
        state.airOn, state.airDebt = false, 0
        return 0
    end
    state.airOn = true
    state.airDebt = (state.airDebt or 0) + rate * R.AIR_PER_RATE * math.max(0, dt) / 1000
    local n = math.floor(state.airDebt)
    state.airDebt = state.airDebt - n
    n = math.max(0, math.min(n, math.min(R.AIR_MAX - (state.air or 0), R.MAX - #state.parts)))
    for _ = 1, n do
        state.parts[#state.parts + 1] = airSpawn(x, y, z, state.t, rand)
    end
    state.air = (state.air or 0) + n
    return n
end

-- Rajada de n numa fonte (o square revelado, Tarefa 2), até o teto. Devolve quantas nasceram.
function R.burst(state, n, s, rand)
    n = math.min(math.floor(tonumber(n) or 0), R.MAX - #state.parts)
    for _ = 1, n do
        state.parts[#state.parts + 1] = R.spawn(s, state.t, rand)
    end
    return math.max(0, n)
end

return NOM_FlakeRules
