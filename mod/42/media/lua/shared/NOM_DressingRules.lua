-- Regras puras do Outro Mundo sangrento (sprint 0015): o que cada square ganha na
-- névoa. Chão: camadas de sangue (poças e rastros) e de erosão (sujeira, rachadura,
-- musgo); parede: um sprite por lado (sangue, sujeira, rachadura, trepadeira). Sem
-- API do jogo, testável com ./run-tests.sh. Quem desenha: client/NOM_FogOverlays.lua.
--
-- Nada é guardado: a resposta é função do square, do período de névoa e da
-- densidade (hash do NOM_VariantRules, ADR-006). Andar e voltar dá o mesmo desenho.
require "NOM_VariantRules"

NOM_DressingRules = {
    RADIUS = 25,       -- tiles do jogador
    MAX_FLOOR = 600,   -- marcadores de chão ativos (um por square)
    MAX_WALL = 120,    -- paredes desenhadas por quadro
    MAX_LAYERS = 4,    -- texturas num marcador de chão
    RED_MULT = 1.6,    -- névoa vermelha = o máximo
    CELL = 7,          -- uma poça possível por célula de 7×7
    -- Calibrado pro zoom do Johan (print de 05/10, névoa vermelha: ~6×6 tiles na tela e
    -- "ainda não tá o outro mundo"): a mudança tem que se ver de relance perto do jogador.
    POOL = 0.85,       -- chance de poça por célula, na densidade 1
    BACKGROUND = 0.15, -- respingo solto por square
    GRIME = 0.5, CRACKS = 0.35, MOSS = 0.2,
    WALL = 0.75,       -- chance de cada parede ter algo
}

local R = NOM_DressingRules
local V = NOM_VariantRules

local function range(a, b, out)
    out = out or {}
    for i = a, b do out[#out + 1] = i end
    return out
end

local function byMod(n, m, keep)
    local out = {}
    for i = 0, n - 1 do
        if keep[i % m] then out[#out + 1] = i end
    end
    return out
end

local function every(first, step, last)
    local out = {}
    for i = first, last, step do out[#out + 1] = i end
    return out
end

-- Sprites vanilla por nome (<prefixo><índice>). Índices conferidos no pack Tiles2x
-- e o lado (N/W) pelo recorte da textura e por tileDepthTextureAssignments.txt
-- (pz-api-notes §16). O cliente ainda confere cada nome com getTexture.
R.SETS = {
    bloodFloor = { prefix = "overlay_blood_floor_01_",
        idx = range(43, 46, range(37, 40, { 34, 35, unpack(range(7, 27, range(0, 5))) })) },
    grimeFloor = { prefix = "overlay_grime_floor_01_",
        idx = { 44, 48, 88, 89, unpack(range(50, 85, range(27, 42, range(0, 25)))) } },
    cracksFloor = { prefix = "d_streetcracks_1_", idx = range(28, 119, range(16, 26, range(0, 14))) },
    mossFloor = { prefix = "d_plants_1_",
        idx = { 23, 35, 38, 39, 55, 57, 58, 59, 63, unpack(range(46, 53, range(0, 15))) } },
    bloodWallW = { wall = "W", prefix = "overlay_blood_wall_01_", idx = { 1, 2, 3, 8, 9, 10, 11, 16, 17, 18, 19 } },
    bloodWallN = { wall = "N", prefix = "overlay_blood_wall_01_", idx = { 4, 5, 13, 14, 15, 20, 21, 22, 23 } },
    grimeWallW = { wall = "W", prefix = "overlay_grime_wall_01_", idx = every(0, 4, 32) },
    grimeWallN = { wall = "N", prefix = "overlay_grime_wall_01_", idx = every(1, 4, 33) },
    cracksWallW = { wall = "W", prefix = "d_wallcracks_1_", idx = { 0, 1, 2, 9, 10, 11, 19, 20, 27, 28, 29, 35, 36,
        37, 38, 45, 46, 47, 54, 55, 56, 63, 64, 65 } },
    cracksWallN = { wall = "N", prefix = "d_wallcracks_1_", idx = { 3, 4, 5, 12, 13, 14, 21, 22, 23, 30, 31, 32, 39,
        41, 48, 49, 50, 57, 58, 59, 66, 67, 68, 69 } },
    vinesWallW = { wall = "W", prefix = "f_wallvines_1_", idx = byMod(72, 6, { [0] = true, [1] = true }) },
    vinesWallN = { wall = "N", prefix = "f_wallvines_1_", idx = byMod(72, 6, { [2] = true, [3] = true }) },
}

-- Faixas do sorteio da parede, por tipo (somam 1): sangue manda.
local WALL_KINDS = { { "blood", 0.45 }, { "grime", 0.25 }, { "cracks", 0.15 }, { "vines", 0.15 } }

local function u(id, period, salt)
    return V.hash(id, period or 0, salt) / V.Q
end

-- Andar de -32 a 31 (porão no B42) sem colidir com o vizinho; fora disso, só repete o desenho.
local function sqId(x, y, z)
    return (x * 16411 + y) * 64 + (z + 32) % 64
end

local function pick(set, id, period, salt)
    local idx = R.SETS[set].idx
    return { set, idx[math.floor(u(id, period, salt) * #idx) + 1] }
end

local function chance(base, d)
    return math.min(0.95, base * d)
end

-- Opção do jogador (0..2) e névoa vermelha → densidade (0..3.2).
function R.density(option, red)
    local d = math.max(0, math.min(2, tonumber(option) or 0))
    return d * (red and R.RED_MULT or 1)
end

-- Poça da célula (cx, cy): centro, raio e rastro (direção, tamanho); nil = sem poça.
local function makePool(cx, cy, z, period, d)
    local id = sqId(cx, cy, z) + 7
    if u(id, period, 11) >= chance(R.POOL, d) then return false end
    local c = R.CELL
    local a = u(id, period, 14) * 2 * math.pi
    return { x = (cx + u(id, period, 12)) * c, y = (cy + u(id, period, 13)) * c, r = 1.6 + 1.8 * u(id, period, 15),
        dx = math.cos(a), dy = math.sin(a), len = 3 + 6 * u(id, period, 16) }
end

-- Cada square olha 9 células: guardadas por período e densidade (o hash é o caro no
-- Kahlua). Zera quando um dos dois muda; cresce com o caminho andado numa névoa.
local pools, poolsPeriod, poolsD = {}, nil, nil

local function pool(cx, cy, z, period, d)
    if period ~= poolsPeriod or d ~= poolsD then pools, poolsPeriod, poolsD = {}, period, d end
    local k = sqId(cx, cy, z) -- chave numérica: nada de string por chamada
    local p = pools[k]
    if p == nil then
        p = makePool(cx, cy, z, period, d)
        pools[k] = p
    end
    return p or nil
end

-- Camadas de sangue do square pelas poças das 9 células em volta: 3 no miolo, 2 na
-- borda, 1 no rastro (com falhas). 0 = nada.
local function bloodLevel(x, y, z, id, period, d)
    local px, py = x + 0.5, y + 0.5
    local cx, cy = math.floor(x / R.CELL), math.floor(y / R.CELL)
    local level = 0
    for i = cx - 1, cx + 1 do
        for j = cy - 1, cy + 1 do
            local p = pool(i, j, z, period, d)
            if p then
                local ox, oy = px - p.x, py - p.y
                local dist = math.sqrt(ox * ox + oy * oy)
                if dist <= p.r * 0.65 then return 3 end
                if dist <= p.r then
                    level = 2
                elseif level == 0 then
                    local t = ox * p.dx + oy * p.dy
                    if t > 0 and t < p.len and math.abs(ox * p.dy - oy * p.dx) <= 1
                        and u(id, period, 31) < 0.8 then
                        level = 1
                    end
                end
            end
        end
    end
    if level == 0 and u(id, period, 32) < chance(R.BACKGROUND, d) then level = 1 end
    return level
end

-- Camadas do chão do square, de baixo pra cima (erosão, depois sangue), ou nil.
function R.floor(x, y, z, period, d)
    if not d or d <= 0 then return nil end
    local id = sqId(x, y, z)
    local out = {}
    if u(id, period, 51) < chance(R.GRIME, d) then out[#out + 1] = pick("grimeFloor", id, period, 61) end
    if u(id, period, 52) < chance(R.CRACKS, d) then out[#out + 1] = pick("cracksFloor", id, period, 62) end
    if u(id, period, 53) < chance(R.MOSS, d) then out[#out + 1] = pick("mossFloor", id, period, 63) end
    local blood = bloodLevel(x, y, z, id, period, d)
    while #out + blood > R.MAX_LAYERS do table.remove(out) end
    for k = 1, blood do out[#out + 1] = pick("bloodFloor", id, period, 40 + k) end
    if #out == 0 then return nil end
    return out
end

-- Sprite da parede norte (north = true) ou oeste do square, ou nil.
function R.wall(x, y, z, period, d, north)
    if not d or d <= 0 then return nil end
    local id = sqId(x, y, z)
    local salt = north and 70 or 80
    if u(id, period, salt) >= chance(R.WALL, d) then return nil end
    local roll, acc = u(id, period, salt + 1), 0
    for _, k in ipairs(WALL_KINDS) do
        acc = acc + k[2]
        if roll < acc or k == WALL_KINDS[#WALL_KINDS] then
            return pick(k[1] .. "Wall" .. (north and "N" or "W"), id, period, salt + 2)
        end
    end
end

-- Deslocamentos no raio, mais perto primeiro (a varredura do cliente segue esta ordem).
R.OFFSETS = {}
for dx = -R.RADIUS, R.RADIUS do
    for dy = -R.RADIUS, R.RADIUS do
        if dx * dx + dy * dy <= R.RADIUS * R.RADIUS then R.OFFSETS[#R.OFFSETS + 1] = { dx, dy } end
    end
end
table.sort(R.OFFSETS, function(a, b)
    local da, db = a[1] * a[1] + a[2] * a[2], b[1] * b[1] + b[2] * b[2]
    if da ~= db then return da < db end
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
end)

-- WITHIN[r] = quantos deslocamentos estão a até r tiles (os primeiros de OFFSETS).
R.WITHIN = {}
for r = 0, R.RADIUS do
    local n = 0
    for _, o in ipairs(R.OFFSETS) do
        if o[1] * o[1] + o[2] * o[2] <= r * r then n = n + 1 end
    end
    R.WITHIN[r] = n
end

return NOM_DressingRules
