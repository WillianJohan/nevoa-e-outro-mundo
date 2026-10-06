-- Regras puras do Outro Mundo sangrento (sprint 0015, ajustes da 0021, anexado na 0023): o
-- que cada square ganha na névoa. Chão: chão queimado (dentro) ou mato e folha (fora),
-- rachadura, e sujeira em manchas à parte (mais leve); sem sangue (saiu na sprint 0034: parecia
-- textura ruim de jogo antigo, Johan). Parede de fora:
-- um sprite por lado (sangue, sujeira, rachadura, trepadeira ou pichação). Parede de dentro (casa
-- destruída, sprint 0034): até WALL_LAYERS camadas de tipos diferentes (rachadura, sujeira,
-- sangue, pichação ou mensagem). Sem API do jogo, testável com ./run-tests.sh. Quem anexa:
-- client/NOM_FogOverlays.lua (ADR-017).
--
-- Nada é guardado: a resposta é função do square, do período de névoa e da
-- densidade (hash do NOM_VariantRules, ADR-006). Andar e voltar dá o mesmo desenho.
require "NOM_VariantRules"
require "NOM_Math"

NOM_DressingRules = {
    -- Raio em tiles do jogador: o canto da tela mais longe + MARGIN, entre MIN e MAX (sprint
    -- 0034). O anexo vai pro save com o chunk: fica bem dentro da distância em que o chunk sai
    -- do mapa e é gravado (≥ 48 tiles, IsoChunkMap.chunkGridWidth 13 × 8; ADR-017).
    MIN_RADIUS = 15,
    MAX_RADIUS = 30,
    MARGIN = 2,
    MAX_LAYERS = 2,    -- camadas no piso: queimado ou mato, e rachadura (a sujeira, à parte)
    RED_MULT = 1.6,    -- névoa vermelha = o máximo
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
    WALL = 0.75,       -- chance de cada parede de fora ter algo
    -- Dentro (casa destruída): a 1ª camada quase sempre, a 2ª e a 3ª menos, sem repetir tipo.
    WALL_IN = 1,
    WALL_IN_2 = 0.5,
    WALL_IN_3 = 0.25,
    WALL_LAYERS = 3,
    -- Pichação e mensagem são desenhos de várias paredes (o pack corta em peças de um tile). A
    -- fileira de paredes vai em trechos de RUN_SLOT tiles; um trecho pode ter um desenho inteiro.
    -- O tipo e o desenho do trecho não dependem de dentro/fora; a chance de aparecer, sim.
    RUN_SLOT = 6,
    RUN = { graffiti = { outside = 0.45, inside = 0.35 }, messages = { outside = 0.15, inside = 0.6 } },
    -- Transição descascando (sprint 0035): o atraso de revelação de cada square vem de um ruído
    -- numa rede de REVEAL_CELL tiles, esticado de [REVEAL_LO, REVEAL_HI] pra 0..1 (o ruído de
    -- valor fica quase todo no meio), com REVEAL_JITTER por square (borda irregular).
    REVEAL_CELL = 6,
    REVEAL_LO = 0.25,
    REVEAL_HI = 0.75,
    REVEAL_JITTER = 0.12,
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
    -- Pichação e mensagem (sprint 0034, scripts/audit_wall_sprites.py): cada run é um desenho
    -- inteiro, peças da esquerda pra direita na tela. O lado bate nas três evidências (recorte,
    -- tileDepthTextureAssignments, attachedW/N); fora: graffiti 92 (attachedN num recorte W) e
    -- messages 34–39 (sem attachedW/N, conteúdo além da face).
    graffitiWallW = { wall = "W", prefix = "overlay_graffiti_wall_01_", runs = { { 0, 1, 2 }, { 3, 4, 5 }, { 6, 7 },
        { 8, 9 }, { 10 }, { 11, 12, 13 }, { 14, 15 }, { 40 }, { 41, 42, 43 }, { 44, 45, 46 }, { 47 }, { 54, 55 },
        { 56, 57, 58 }, { 64, 65 }, { 72, 73 }, { 74, 75, 76 }, { 80, 81 }, { 82, 83, 84 }, { 85 }, { 86 }, { 87 },
        { 93, 94, 95 } } },
    graffitiWallN = { wall = "N", prefix = "overlay_graffiti_wall_01_", runs = { { 16, 17, 18 }, { 19, 20 },
        { 21, 22, 23 }, { 24, 25, 26 }, { 27, 28, 29, 30, 31 }, { 32, 33, 34 }, { 35, 36 }, { 37, 38, 39 },
        { 48, 49, 50 }, { 51 }, { 52, 53 }, { 59 }, { 60, 61, 62, 63 }, { 66, 67 }, { 68, 69, 70, 71 },
        { 77, 78, 79 }, { 88, 89, 90 }, { 91 }, { 96, 97, 98 }, { 100 }, { 101 }, { 102 }, { 103 },
        { 104, 105, 106, 107, 108 }, { 112, 113, 114, 115 } } },
    -- "KEEP OUT" (6, 7, 14, 15) e "ALIVE INSIDE" (24–27): duas palavras, um desenho
    messagesWallW = { wall = "W", prefix = "overlay_messages_wall_01_", runs = { { 0, 1, 2 }, { 3, 4, 5 },
        { 6, 7, 14, 15 }, { 8, 9, 10 }, { 16, 17, 18 }, { 24, 25, 26, 27 } } },
    messagesWallN = { wall = "N", prefix = "overlay_messages_wall_01_", runs = { { 11, 12, 13 }, { 19, 20, 21 },
        { 28, 29, 30, 31 } } },
}
for _, s in pairs(R.SETS) do
    if s.runs then
        s.idx = {}
        for _, run in ipairs(s.runs) do
            for _, i in ipairs(run) do s.idx[#s.idx + 1] = i end
        end
    end
end

-- Nome do sprite de uma camada { set, índice }.
function R.name(layer)
    return R.SETS[layer[1]].prefix .. layer[2]
end

-- O nome é do prefixo que só o mod anexa?
function R.own(name)
    return type(name) == "string" and name:sub(1, #R.OWN_PREFIX) == R.OWN_PREFIX
end

-- Faixas do sorteio da parede, por tipo (somam 1). Fora, sangue manda; dentro ("apagadas,
-- acabadas, sujas", Johan, sprint 0034), sujeira e rachadura.
local WALL_KINDS = { { "blood", 0.45 }, { "grime", 0.25 }, { "cracks", 0.15 }, { "vines", 0.15 } }
local WALL_KINDS_IN = { { "grime", 0.4 }, { "cracks", 0.3 }, { "blood", 0.3 } }

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

-- Cada square olha os 4 cantos da rede de cada ruído: guardados por período (o hash é o caro
-- no Kahlua). Zera quando o período muda; cresce com o caminho andado numa névoa.
local corners, cornersPeriod = {}, nil

local function corner(i, j, z, period, salt)
    if period ~= cornersPeriod then corners, cornersPeriod = {}, period end
    local t = corners[salt]
    if not t then
        t = {}
        corners[salt] = t
    end
    local k = sqId(i, j, z) -- chave numérica: nada de string por chamada
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

-- Atraso de revelação do square (0..1): a erosão abre em manchas, do miolo pra borda
-- (client/NOM_FogOverlays.lua, × REVEAL_MS ao abrir; ao contrário, × UNREVEAL_MS ao fechar).
function R.reveal(x, y, z, period)
    local n = (noise(x, y, z, period, R.REVEAL_CELL, 70) - R.REVEAL_LO) / (R.REVEAL_HI - R.REVEAL_LO)
    local j = R.REVEAL_JITTER
    local v = n * (1 - j) + u(sqId(x, y, z), period, 71) * j
    return math.max(0, math.min(1, v))
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

-- Camadas do chão do square, de baixo pra cima (queimado ou mato, depois rachadura; até
-- MAX_LAYERS), e a sujeira à parte em out.grime (anexo próprio, mais leve), ou nil. outside: o
-- square é de fora (sem telhado).
function R.floor(x, y, z, period, d, outside)
    if not d or d <= 0 then return nil end
    local id = sqId(x, y, z)
    local out = {}
    out[1] = ground(x, y, z, id, period, d, outside)
    -- mancha pelo ruído; um tile em 7 falha (borda irregular, não losango cheio)
    local grime = R.grimeNoise(x, y, z, period) >= 1 - math.min(R.GRIME_MAX, R.GRIME * d)
        and noise(x, y, z, period, R.GRIME_FINE, 55) >= R.GRIME_CUT
    if u(id, period, 52) < chance(R.CRACKS, d) then out[#out + 1] = pick("cracksFloor", id, period, 62) end
    if grime then out.grime = grimePick(x, y, id, period) end
    if #out == 0 and not grime then return nil end
    return out
end

-- Tipo do sorteio da parede, pelas faixas de kinds.
local function wallKind(id, period, salt, kinds)
    local roll, acc = u(id, period, salt), 0
    for _, k in ipairs(kinds) do
        acc = acc + k[2]
        if roll < acc or k == kinds[#kinds] then return k[1] end
    end
end

-- Peça de pichação ou mensagem da parede, ou nil. Parede N: a fileira anda em x (a peça k em
-- start + k: x cresce pra direita na tela); W: anda em y, e y cresce pra esquerda (a peça k em
-- start + #run − 1 − k).
local function writing(x, y, z, period, d, north, outside)
    local pos, line = north and x or y, north and y or x
    local slot = math.floor(pos / R.RUN_SLOT)
    local id = sqId(slot, line, z)
    local salt = north and 110 or 120
    local kind = u(id, period, salt) < 0.5 and "messages" or "graffiti"
    if u(id, period, salt + 1) >= chance(R.RUN[kind][outside and "outside" or "inside"], d) then return nil end
    local set = kind .. "Wall" .. (north and "N" or "W")
    local runs = R.SETS[set].runs
    local run = runs[math.floor(u(id, period, salt + 2) * #runs) + 1]
    local k = pos - slot * R.RUN_SLOT - math.floor(u(id, period, salt + 3) * (R.RUN_SLOT - #run + 1))
    if k < 0 or k >= #run then return nil end
    if not north then k = #run - 1 - k end
    return { set, run[k + 1] }
end

-- Dentro, de baixo pra cima.
local INSIDE_KINDS = { "cracks", "grime", "blood" }

-- Camadas da parede norte (north = true) ou oeste do square, de baixo pra cima, ou nil. A face
-- que se vê é a do square dono da parede (outside: ele é de fora). Fora: uma camada, a peça de
-- pichação do trecho ou o sorteio. Dentro: o sorteio, mais até duas de outro tipo, e a peça de
-- pichação/mensagem em cima, até WALL_LAYERS.
function R.wall(x, y, z, period, d, north, outside)
    if not d or d <= 0 then return nil end
    local id = sqId(x, y, z)
    local salt = north and 70 or 80
    local side = north and "N" or "W"
    local write = writing(x, y, z, period, d, north, outside)
    if outside then
        if write then return { write } end
        if u(id, period, salt) >= chance(R.WALL, d) then return nil end
        return { pick(wallKind(id, period, salt + 1, WALL_KINDS) .. "Wall" .. side, id, period, salt + 2) }
    end
    local has, n = {}, 0
    if u(id, period, salt) < chance(R.WALL_IN, d) then
        has[wallKind(id, period, salt + 1, WALL_KINDS_IN)] = true
        n = 1
        local room = R.WALL_LAYERS - (write and 1 or 0)
        for k, base in ipairs({ R.WALL_IN_2, R.WALL_IN_3 }) do
            if n >= room or u(id, period, salt + 2 + k) >= chance(base, d) then break end
            local rest = {}
            for _, kind in ipairs(INSIDE_KINDS) do
                if not has[kind] then rest[#rest + 1] = kind end
            end
            has[rest[math.floor(u(id, period, salt + 4 + k) * #rest) + 1]] = true
            n = n + 1
        end
    end
    local out = {}
    for i, kind in ipairs(INSIDE_KINDS) do
        if has[kind] then out[#out + 1] = pick(kind .. "Wall" .. side, id, period, salt + 6 + i) end
    end
    if write then out[#out + 1] = write end
    if #out == 0 then return nil end
    return out
end

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Raio da varredura: a distância do jogador (px, py) ao canto mais longe (corners = { {x, y}, ... },
-- os cantos da tela no chão, em tiles) + MARGIN, pra cima, preso em [MIN_RADIUS, MAX_RADIUS].
-- Sem cantos ou com um que não é número: MIN_RADIUS.
function R.radius(px, py, corners)
    if not finite(px) or not finite(py) or type(corners) ~= "table" or #corners == 0 then return R.MIN_RADIUS end
    local far = 0
    for _, c in ipairs(corners) do
        if type(c) ~= "table" or not finite(c[1]) or not finite(c[2]) then return R.MIN_RADIUS end
        local dx, dy = c[1] - px, c[2] - py
        far = math.max(far, dx * dx + dy * dy)
    end
    return math.max(R.MIN_RADIUS, math.min(R.MAX_RADIUS, math.ceil(math.sqrt(far) + R.MARGIN)))
end

-- Deslocamentos até MAX_RADIUS, mais perto primeiro (a varredura do cliente segue esta ordem).
R.OFFSETS = {}
for dx = -R.MAX_RADIUS, R.MAX_RADIUS do
    for dy = -R.MAX_RADIUS, R.MAX_RADIUS do
        if dx * dx + dy * dy <= R.MAX_RADIUS * R.MAX_RADIUS then R.OFFSETS[#R.OFFSETS + 1] = { dx, dy } end
    end
end
table.sort(R.OFFSETS, function(a, b)
    local da, db = a[1] * a[1] + a[2] * a[2], b[1] * b[1] + b[2] * b[2]
    if da ~= db then return da < db end
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
end)

-- WITHIN[r] = quantos deslocamentos estão a até r tiles (os primeiros de OFFSETS), r até MAX_RADIUS.
R.WITHIN = {}
do
    local n = 0
    for r = 0, R.MAX_RADIUS do
        local o = R.OFFSETS[n + 1]
        while o and o[1] * o[1] + o[2] * o[2] <= r * r do
            n = n + 1
            o = R.OFFSETS[n + 1]
        end
        R.WITHIN[r] = n
    end
end

return NOM_DressingRules
