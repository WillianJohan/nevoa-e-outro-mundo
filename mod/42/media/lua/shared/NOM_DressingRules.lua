-- Regras puras do Outro Mundo sangrento (sprint 0015, ajustes da 0021, anexado na 0023): o
-- que cada square ganha na névoa. Chão: chão queimado (dentro) ou mato e folha (fora),
-- rachadura e sangue (poças e rastros), e sujeira em manchas à parte (mais leve). Parede: um
-- sprite por lado (sangue, sujeira, rachadura; trepadeira só fora). Sem API do jogo, testável
-- com ./run-tests.sh. Quem anexa: client/NOM_FogOverlays.lua (ADR-017).
--
-- Nada é guardado: a resposta é função do square, do período de névoa e da
-- densidade (hash do NOM_VariantRules, ADR-006). Andar e voltar dá o mesmo desenho.
require "NOM_VariantRules"
require "NOM_Math"

NOM_DressingRules = {
    -- Tiles do jogador (sprint 0023). O anexo vai pro save com o chunk: fica bem dentro da
    -- distância em que o chunk sai do mapa e é gravado (≥ 48 tiles, IsoChunkMap.chunkGridWidth
    -- 13 × 8; ADR-017).
    RADIUS = 15,
    MAX_LAYERS = 4,    -- camadas no piso (a sujeira, à parte)
    RED_MULT = 1.6,    -- névoa vermelha = o máximo
    CELL = 7,          -- uma poça possível por célula de 7×7
    -- Calibrado pro zoom do Johan (print de 05/10, névoa vermelha: ~6×6 tiles na tela e
    -- "ainda não tá o outro mundo"): a mudança tem que se ver de relance perto do jogador.
    POOL = 0.85,       -- chance de poça por célula, na densidade 1
    BACKGROUND = 0.15, -- respingo solto por square
    CRACKS = 0.45,
    -- Sujeira (print 7: losango cheio por tile lia como xadrez): em manchas (ruído numa rede
    -- de GRIME_CELL tiles, recortado por um ruído fino de GRIME_FINE), sprite parcial que não
    -- repete o do vizinho e num marcador próprio, com alfa × GRIME_ALPHA. A chance para em
    -- GRIME_MAX: acima disso as manchas se emendam e volta o tile a tile (review 0021).
    GRIME = 0.4,       -- o ruído passa de 1 − min(GRIME·d, GRIME_MAX)
    GRIME_MAX = 0.4,   -- medido: ~27% do chão a partir da densidade 1 (dressing_rules_grime_rarer)
    GRIME_CELL = 4,
    GRIME_FINE = 2,    -- o ruído fino passa de GRIME_CUT: borda irregular, sem furo isolado
    GRIME_CUT = 0.3,
    GRIME_ALPHA = 0.5,
    -- Chão queimado (só dentro, sprint 0023: "casa destruída"): manchas pelo ruído numa rede de
    -- BURNT_CELL tiles, como a sujeira; no miolo o tile cheio, na borda a marca pequena.
    BURNT = 0.3,       -- o ruído passa de 1 − min(BURNT·d, BURNT_MAX)
    BURNT_MAX = 0.35,
    BURNT_CELL = 5,
    BURNT_FULL = 0.22, -- acima do corte: cheio; acima de BURNT_MID: médio; senão pequeno
    BURNT_MID = 0.1,
    -- Mato e folha (só fora): manchas do mesmo jeito.
    PLANTS = 0.35,
    PLANTS_MAX = 0.45,
    PLANTS_CELL = 4,
    -- O prefixo que só o mod anexa (ninguém no vanilla anexa floors_burnt_01_*: ADR-017). Um
    -- anexo com ele que não é nosso agora é vazado de uma sessão que caiu: sai no LoadGridsquare.
    OWN_PREFIX = "floors_burnt_01_",
    WALL = 0.75,       -- chance de cada parede ter algo
}

local R = NOM_DressingRules
local V = NOM_VariantRules

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
-- Chão (sprint 0023, pz-api-notes §16.6): o sprite vai anexado ao piso e sai na posição dele.
-- Decalque com o conteúdo deitado no diamante do chão; mato e folha rasteiros (o anexo do piso
-- sai antes de personagens e paredes). Medido por scripts/audit_floor_sprites.py
-- (tests/floor_sprites.lua).
R.SETS = {
    bloodFloor = { prefix = "overlay_blood_floor_01_", idx = every(0, 1, 27) },
    -- sujeira: além disso, parcial (cobertura < 50%) e sem as faixas de borda de tile (sprint 0021)
    grimeFloor = { prefix = "overlay_grime_floor_01_", idx = { 12, 13, 14, 15, 17, 20, 22, 23, 26, 38, 88 } },
    cracksFloor = { prefix = "d_streetcracks_1_",
        idx = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
            27, 28, 31, 32, 33, 35, 36, 38, 39, 40, 43, 44, 48, 49, 51, 52, 55, 56, 57, 59, 60, 63, 65, 67, 68,
            72, 76, 79, 87, 96, 100, 103, 111 } },
    -- queimado: marca pequena (borda da mancha), média e o tile cheio (miolo)
    burntFloorS = { prefix = "floors_burnt_01_", idx = { 16, 17, 18, 19, 20, 21, 22, 23, 28, 29, 30, 31 } },
    burntFloorM = { prefix = "floors_burnt_01_", idx = { 1, 9, 10, 11, 12, 24, 25, 26, 27 } },
    burntFloorF = { prefix = "floors_burnt_01_", idx = { 0, 8, 13, 14, 15 } },
    plantsFloor = { prefix = "d_plants_1_", idx = { 0, 1, 3, 4, 6, 7, 8, 11, 14, 23, 38, 39, 49, 50, 51, 52, 53,
        55, 57, 58, 59 } },
    leavesFloor = { prefix = "d_floorleaves_1_", idx = every(0, 1, 11) },
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
for i = 32, 46 do R.SETS.bloodFloor.idx[#R.SETS.bloodFloor.idx + 1] = i end

-- Nome do sprite de uma camada { set, índice }.
function R.name(layer)
    return R.SETS[layer[1]].prefix .. layer[2]
end

-- O nome é do prefixo que só o mod anexa?
function R.own(name)
    return type(name) == "string" and name:sub(1, #R.OWN_PREFIX) == R.OWN_PREFIX
end

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

-- Cada square olha 9 células (e 4 cantos da rede da sujeira): guardados por período e
-- densidade (o hash é o caro no Kahlua). Zera quando um dos dois muda; cresce com o
-- caminho andado numa névoa.
local pools, corners, poolsPeriod, poolsD = {}, {}, nil, nil

local function fresh(period, d)
    if period ~= poolsPeriod or d ~= poolsD then pools, corners, poolsPeriod, poolsD = {}, {}, period, d end
end

local function pool(cx, cy, z, period, d)
    fresh(period, d)
    local k = sqId(cx, cy, z) -- chave numérica: nada de string por chamada
    local p = pools[k]
    if p == nil then
        p = makePool(cx, cy, z, period, d)
        pools[k] = p
    end
    return p or nil
end

local function corner(i, j, z, period, salt)
    local t = corners[salt]
    if not t then
        t = {}
        corners[salt] = t
    end
    local k = sqId(i, j, z)
    local v = t[k]
    if v == nil then
        v = u(k + 3, period, salt)
        t[k] = v
    end
    return v
end

local function smooth(t)
    return t * t * (3 - 2 * t)
end

-- Ruído de valor em (x, y) numa rede de `cell` tiles: 0..1, contínuo de tile pra tile.
local function noise(x, y, z, period, cell, salt)
    local gx, gy = (x + 0.5) / cell, (y + 0.5) / cell
    local i, j = math.floor(gx), math.floor(gy)
    local sx, sy = smooth(gx - i), smooth(gy - j)
    local c00, c10 = corner(i, j, z, period, salt), corner(i + 1, j, z, period, salt)
    local c01, c11 = corner(i, j + 1, z, period, salt), corner(i + 1, j + 1, z, period, salt)
    local a = c00 + (c10 - c00) * sx
    local b = c01 + (c11 - c01) * sx
    return a + (b - a) * sy
end

-- Ruído das manchas de sujeira em (x, y): 0..1.
function R.grimeNoise(x, y, z, period)
    return noise(x, y, z, period, R.GRIME_CELL, 54)
end

-- Sprite de sujeira do square: a classe (x + 2y) mod 5 nunca é a de um vizinho de lado
-- (±1, ±2), e cada classe tem os seus sprites: dois vizinhos nunca repetem o sprite.
local function grimePick(x, y, id, period)
    local idx = R.SETS.grimeFloor.idx
    local class = NOM_Math.mod(x + 2 * y, 5)
    local own = {}
    for k = class + 1, #idx, 5 do own[#own + 1] = idx[k] end
    return { "grimeFloor", own[math.floor(u(id, period, 61) * #own) + 1] }
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

-- Mancha pelo ruído: quanto o ruído passa do corte (≥ 0), ou nil fora da mancha.
local function patch(x, y, z, period, d, base, max, cell, salt)
    local over = noise(x, y, z, period, cell, salt) - (1 - math.min(max, base * d))
    if over >= 0 then return over end
    return nil
end

-- Camada de baixo: queimado dentro (cheio no miolo da mancha, pequeno na borda), mato ou folha
-- fora; ou nil.
local function ground(x, y, z, id, period, d, outside)
    if outside then
        if not patch(x, y, z, period, d, R.PLANTS, R.PLANTS_MAX, R.PLANTS_CELL, 57) then return nil end
        return pick(u(id, period, 63) < 0.5 and "plantsFloor" or "leavesFloor", id, period, 64)
    end
    local over = patch(x, y, z, period, d, R.BURNT, R.BURNT_MAX, R.BURNT_CELL, 56)
    if not over then return nil end
    local set = over >= R.BURNT_FULL and "burntFloorF" or over >= R.BURNT_MID and "burntFloorM" or "burntFloorS"
    return pick(set, id, period, 65)
end

-- Camadas do chão do square, de baixo pra cima (queimado ou mato, rachadura, depois sangue), e
-- a sujeira à parte em out.grime (anexo próprio, mais leve), ou nil. outside: o square é de fora
-- (sem telhado).
function R.floor(x, y, z, period, d, outside)
    if not d or d <= 0 then return nil end
    fresh(period, d)
    local id = sqId(x, y, z)
    local out = {}
    out[1] = ground(x, y, z, id, period, d, outside)
    -- mancha pelo ruído; um tile em 7 falha (borda irregular, não losango cheio)
    local grime = R.grimeNoise(x, y, z, period) >= 1 - math.min(R.GRIME_MAX, R.GRIME * d)
        and noise(x, y, z, period, R.GRIME_FINE, 55) >= R.GRIME_CUT
    if u(id, period, 52) < chance(R.CRACKS, d) then out[#out + 1] = pick("cracksFloor", id, period, 62) end
    local blood = bloodLevel(x, y, z, id, period, d)
    while #out + blood > R.MAX_LAYERS do table.remove(out) end
    for k = 1, blood do out[#out + 1] = pick("bloodFloor", id, period, 40 + k) end
    if grime then out.grime = grimePick(x, y, id, period) end
    if #out == 0 and not grime then return nil end
    return out
end

-- Sprite da parede norte (north = true) ou oeste do square, ou nil. A face que se vê é a do
-- square dono da parede: trepadeira só se ele é de fora (outside); dentro, a faixa dela vira
-- sangue.
function R.wall(x, y, z, period, d, north, outside)
    if not d or d <= 0 then return nil end
    local id = sqId(x, y, z)
    local salt = north and 70 or 80
    if u(id, period, salt) >= chance(R.WALL, d) then return nil end
    local roll, acc = u(id, period, salt + 1), 0
    for _, k in ipairs(WALL_KINDS) do
        acc = acc + k[2]
        if roll < acc or k == WALL_KINDS[#WALL_KINDS] then
            local kind = k[1]
            if kind == "vines" and not outside then kind = "blood" end
            return pick(kind .. "Wall" .. (north and "N" or "W"), id, period, salt + 2)
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
