-- Sonar do Estalador (sprint 0037 + 0048 + 0056), a regra pura: o estalo solta um anel que
-- avança RANGE tiles em DURATION_MS reais. O anel que cruza um jogador no mesmo andar, em
-- pé ou andando, faz o Estalador achá-lo; agachado e parado, o anel passa. Sem API do jogo:
-- quem decide é o server/NOM_SonarServer.lua; quem desenha, o client/NOM_SonarFx.lua; o
-- mod3 tem os mesmos números em mod3/java/nom/render/Sonar.java (teste de contrato).
-- Sprint 0048: o som é um burst rítmico; a névoa mostra ripples curtos no ritmo;
-- o achado continua UM anel RANGE por burst.
-- Sprint 0056: três variações (A rápida, B 500/500/800, C irregular). Por padrão o servidor
-- rotaciona A→B→C a cada estalo; debug pode forçar e editar gaps (NOM.sonarBurst / sonarGaps).
NOM_SonarRules = {
    RANGE = 8,             -- tiles (anel de achado; servidor)
    DURATION_MS = 1500,    -- ms reais até os 8 tiles: ~5,3 tiles/s, mais rápido que qualquer corrida
    FADE_MS = 400,         -- o desenho some nesse tempo depois do fim
    ALPHA = 0.35,          -- discreto (anel grande legado; ripples usam RIPPLE_ALPHA)
    -- Depois de achar, o Estalador não é cegado de novo por FOUND_MS reais: dá tempo de ele
    -- andar os 8 tiles (~1 tile/s) mesmo que o jogador se agache logo depois do anel.
    FOUND_MS = 10000,
    -- Ritmo (decisão do Johan, 2026-10-06): cada Estalador estala num intervalo aleatório de
    -- GAP_MIN_MS a GAP_MAX_MS reais, sorteado de novo a cada estalo. Tempo real que para na
    -- pausa: não depende do tamanho do dia.
    GAP_MIN_MS = 5000,
    GAP_MAX_MS = 30000,
    SCAN_MS = 1000,        -- a lista de zumbis é lida a cada isso (acha Estalador novo, tira quem saiu)
    SEND_RANGE = 40,       -- só estala com jogador a até isso (o som chega a 25, o anel a 8)
    SAMPLE_MS = 250,       -- amostra de posição dos jogadores (o "andando")
    MOVE_EPS = 0.1,        -- tiles entre amostras: ≥ 0,2 tile/s é andar
    MAX_RINGS = 8,         -- anéis de achado vivos no servidor (um por burst)
    -- Sprint 0056: gaps padrão por variação (espelho em scripts/gen_sounds.py CLICK_BURSTS).
    -- A = clicker rápido (0048); B = pausada; C = irregular com double (~65 ms).
    BURST_GAPS = {
        { 90, 75, 85, 70, 90, 80, 110, 120, 160, 220, 300 },           -- A
        { 500, 500, 800 },                                             -- B
        { 1000, 1000, 65, 2000, 3000 },                                -- C
    },
    BURST_IDS = { "A", "B", "C" },
    CLICK_SOUND = "NOM_EstaladorClick", -- tac curto; agenda um por batida
    GAP_NUDGE_MIN = 30,    -- ms: gap não some no nudge do painel
    GAP_NUDGE_MAX = 5000,
    RIPPLE_RANGE = 3,      -- tiles por ondulação de presença
    RIPPLE_DURATION_MS = 550,
    RIPPLE_FADE_MS = 280,
    RIPPLE_ALPHA = 0.28,
    MAX_RIPPLES = 36,      -- ripples na tela / mod3 (vários Estaladores × batidas)
    -- Anel sem jogador a até REACH (mesmo andar) não acha ninguém, nem quem corre (~6 tiles/s)
    -- na direção dele: é o que sai quando lota (NOM_SonarServer.emit)
    REACH = 17,
    DEBUG_REACH = 60,      -- NOM.sonar(): Estalador a até isso de quem pede
    MAX_COORD = 100000,    -- coordenada de tile aceita na mensagem
    MIN_FLOOR = -32, MAX_FLOOR = 32,
    -- desenho sem mod3 (client/NOM_SonarFx.lua)
    TEXTURE = "media/textures/NOM/ScreenFx/NOM_SonarAnel.png",
    TEX_RING = 0.9,        -- raio da frente na textura, em meias-larguras (scripts/gen_textures.py)
    VIEW = 30,             -- tiles: anel mais longe que isso do jogador não é desenhado
    COLOR = { white = { 0.85, 0.9, 0.95 }, red = { 0.95, 0.42, 0.36 } },
}
local R = NOM_SonarRules

-- Overrides de debug (solo / painel): force 1..3 ou nil (rodízio); gaps[i] = lista de gaps.
local forceBurst, gapOverride = nil, {}

local function copyGaps(g)
    local out = {}
    for i = 1, #g do out[i] = g[i] end
    return out
end

-- Onsets cumulativos a partir dos gaps entre tacs (primeiro sempre em 0).
function R.beatsFromGaps(gaps)
    local beats = { 0 }
    local t = 0
    for i = 1, #gaps do
        t = t + gaps[i]
        beats[#beats + 1] = t
    end
    return beats
end

-- Defaults de batidas (e BEAT_MS = A, legado 0048 / testes de FX).
do
    local bursts = {}
    for i = 1, #R.BURST_GAPS do
        bursts[i] = R.beatsFromGaps(R.BURST_GAPS[i])
    end
    R.BURSTS = bursts
    R.BEAT_MS = bursts[1]
end

function R.burstCount()
    return #R.BURST_GAPS
end

function R.clampBurst(i)
    if i == nil or not (type(i) == "number") or i ~= i then return 1 end
    if i < 1 then return 1 end
    if i > R.burstCount() then return R.burstCount() end
    return math.floor(i)
end

function R.burstId(i)
    return R.BURST_IDS[R.clampBurst(i)]
end

function R.burstGaps(i)
    i = R.clampBurst(i)
    if gapOverride[i] then return copyGaps(gapOverride[i]) end
    return copyGaps(R.BURST_GAPS[i])
end

function R.burstBeats(i)
    i = R.clampBurst(i or 1)
    if gapOverride[i] then return R.beatsFromGaps(gapOverride[i]) end
    return R.BURSTS[i]
end

function R.parseBurst(mode)
    if mode == nil or mode == "auto" or mode == "Auto" or mode == false then return nil end
    if mode == "A" or mode == "a" or mode == 1 then return 1 end
    if mode == "B" or mode == "b" or mode == 2 then return 2 end
    if mode == "C" or mode == "c" or mode == 3 then return 3 end
    if type(mode) == "number" and mode == mode then return R.clampBurst(mode) end
    return nil
end

function R.setForceBurst(mode)
    forceBurst = R.parseBurst(mode)
end

function R.forceBurst()
    return forceBurst
end

-- Próximo índice no rodízio; com force, devolve o forçado (não avança).
function R.nextBurst(prev)
    if forceBurst ~= nil then return forceBurst end
    return (math.max(0, math.floor(prev or 0)) % R.burstCount()) + 1
end

function R.setGaps(i, gaps)
    i = R.clampBurst(i)
    if type(gaps) ~= "table" or #gaps < 1 then return false end
    local g = {}
    for k = 1, #gaps do
        local v = gaps[k]
        if type(v) ~= "number" or v ~= v then return false end
        g[k] = math.max(R.GAP_NUDGE_MIN, math.min(R.GAP_NUDGE_MAX, math.floor(v)))
    end
    gapOverride[i] = g
    return true
end

function R.resetGaps()
    gapOverride = {}
end

-- Alvo do nudge: variação forçada, ou B (a pausada) no modo auto.
function R.gapTarget()
    return forceBurst or 2
end

function R.nudgeGaps(delta)
    if type(delta) ~= "number" or delta ~= delta or delta == 0 then return false end
    local i = R.gapTarget()
    local g = R.burstGaps(i)
    for k = 1, #g do
        g[k] = math.max(R.GAP_NUDGE_MIN, math.min(R.GAP_NUDGE_MAX, g[k] + math.floor(delta)))
    end
    gapOverride[i] = g
    return true
end

function R.burstStatus()
    local force = forceBurst and R.burstId(forceBurst) or "auto"
    local parts = { "force=" .. force }
    for i = 1, R.burstCount() do
        local g = R.burstGaps(i)
        local s = R.burstId(i) .. "["
        for k = 1, #g do
            if k > 1 then s = s .. "/" end
            s = s .. tostring(g[k])
        end
        parts[#parts + 1] = s .. "]"
    end
    return table.concat(parts, " ")
end

-- Raio do anel de achado (tiles) com age ms de vida.
function R.radius(age)
    if age <= 0 then return 0 end
    if age >= R.DURATION_MS then return R.RANGE end
    return R.RANGE * age / R.DURATION_MS
end

function R.done(age) return age >= R.DURATION_MS end

-- Raio de um ripple de presença (sprint 0048): curto, no ritmo do clique.
function R.rippleRadius(age)
    if age <= 0 then return 0 end
    if age >= R.RIPPLE_DURATION_MS then return R.RIPPLE_RANGE end
    return R.RIPPLE_RANGE * age / R.RIPPLE_DURATION_MS
end

function R.rippleDone(age) return age >= R.RIPPLE_DURATION_MS + R.RIPPLE_FADE_MS end

-- Alfa do ripple: sobe em 80 ms, segura, some em RIPPLE_FADE_MS.
function R.rippleAlpha(age)
    if age <= 0 then return 0 end
    if age < 80 then return R.RIPPLE_ALPHA * age / 80 end
    if age <= R.RIPPLE_DURATION_MS then return R.RIPPLE_ALPHA end
    local k = 1 - (age - R.RIPPLE_DURATION_MS) / R.RIPPLE_FADE_MS
    if k <= 0 then return 0 end
    return R.RIPPLE_ALPHA * k
end

-- Quantas batidas a variação A (legado) tem.
function R.beatCount()
    return #R.burstBeats(1)
end

-- d2 = distância² ao centro agora; p2 = a do tick anterior (nil: sem posição anterior). O anel
-- cruzou neste tick se a frente foi de r0 a r1 e o jogador, que estava fora do raio r0, agora
-- está dentro de r1: quem anda na direção do anel não pula a frente entre dois ticks. r0 nil:
-- primeiro tick (o centro conta).
function R.crossed(d2, r0, r1, p2)
    if d2 > r1 * r1 then return false end
    if r0 == nil then return true end
    local rr = r0 * r0
    return d2 > rr or (p2 ~= nil and p2 > rr)
end

-- Casa protege (decisão do Johan, 2026-10-06): pIn/zIn = jogador/Estalador em interior
-- (nil: sem square, não sabe), pBld/zBld = o prédio de cada um (nil fora ou coberto sem
-- prédio). Um dentro e o outro fora, ou em prédios diferentes: o anel não acha.
function R.sheltered(pIn, pBld, zIn, zBld)
    if pIn == nil or zIn == nil then return false end
    if pIn ~= zIn then return true end
    return pIn and pBld ~= zBld
end

-- Em pé ou andando: achado. Agachado e parado: o anel passa.
function R.exposed(sneaking, moving)
    return not sneaking or moving == true
end

-- Andando: deslocou pelo menos MOVE_EPS desde a amostra (x0, y0). Sem amostra: parado.
function R.moving(x0, y0, x1, y1)
    if x0 == nil or y0 == nil then return false end
    local dx, dy = x1 - x0, y1 - y0
    return dx * dx + dy * dy >= R.MOVE_EPS * R.MOVE_EPS
end

-- Índices dos jogadores ({ x, y, z, px, py = posição do tick anterior ou nil }) que o anel
-- cruzou ao ir de r0 a r1, no andar dele.
function R.sweep(ring, r0, r1, players)
    local out = {}
    if r0 ~= nil and r1 <= r0 then return out end
    local floor = math.floor(ring.z)
    for i, p in ipairs(players) do
        if math.floor(p.z) == floor then
            local dx, dy = p.x - ring.x, p.y - ring.y
            local p2
            if p.px ~= nil and p.py ~= nil then
                local qx, qy = p.px - ring.x, p.py - ring.y
                p2 = qx * qx + qy * qy
            end
            if R.crossed(dx * dx + dy * dy, r0, r1, p2) then out[#out + 1] = i end
        end
    end
    return out
end

R.GAP_ROLL = R.GAP_MAX_MS - R.GAP_MIN_MS + 1

-- Intervalo até o próximo estalo, em ms. roll = ZombRand(GAP_ROLL).
function R.gap(roll)
    return R.GAP_MIN_MS + math.max(0, math.min(roll, R.GAP_ROLL - 1))
end

-- Algum jogador ({ x, y, z }) a até SEND_RANGE do ponto, no mesmo andar.
function R.near(x, y, z, players)
    local floor, rr = math.floor(z), R.SEND_RANGE * R.SEND_RANGE
    for _, p in ipairs(players) do
        if math.floor(p.z) == floor then
            local dx, dy = p.x - x, p.y - y
            if dx * dx + dy * dy <= rr then return true end
        end
    end
    return false
end

-- O jogador em (px, py) recebe o anel de (x, y): a até SEND_RANGE, em qualquer andar (o estalo
-- se ouve de outro andar; o desenho confere o andar).
function R.hears(x, y, px, py)
    local dx, dy = px - x, py - y
    return dx * dx + dy * dy <= R.SEND_RANGE * R.SEND_RANGE
end

-- Distância² do ponto ao jogador mais perto no mesmo andar (math.huge sem ninguém).
function R.nearest2(x, y, z, players)
    local floor, best = math.floor(z), math.huge
    for _, p in ipairs(players) do
        if math.floor(p.z) == floor then
            local dx, dy = p.x - x, p.y - y
            local d = dx * dx + dy * dy
            if d < best then best = d end
        end
    end
    return best
end

local function finite(v)
    return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function coord(v) return finite(v) and v >= 0 and v <= R.MAX_COORD end

-- Mensagem "sonar" do servidor: { x, y, z, id, b = índice do burst 1..3 }. nil se não serve.
function R.valid(a)
    if type(a) ~= "table" or not coord(a.x) or not coord(a.y) or not finite(a.z) then return nil end
    if a.z ~= math.floor(a.z) or a.z < R.MIN_FLOOR or a.z > R.MAX_FLOOR then return nil end
    if a.id ~= nil and not finite(a.id) then return nil end
    if a.b ~= nil and not finite(a.b) then return nil end
    return { x = a.x, y = a.y, z = a.z, id = a.id or -1, b = R.clampBurst(a.b or 1) }
end

-- Mensagem "sonarFound": { id = onlineID do Estalador, pl = onlineID do jogador achado,
-- pid = persistentOutfitID do Estalador (o dono confere: onlineID se reaproveita) }.
function R.validFound(a)
    if type(a) ~= "table" or not finite(a.id) or not finite(a.pl) or a.id == -1 then return nil end
    if a.pid ~= nil and not finite(a.pid) then return nil end
    return { id = a.id, pl = a.pl, pid = a.pid }
end

-- Alfa do desenho com age ms: sobe em 120 ms, segura na expansão, some em FADE_MS.
function R.alpha(age)
    if age <= 0 then return 0 end
    if age < 120 then return R.ALPHA * age / 120 end
    if age <= R.DURATION_MS then return R.ALPHA end
    local k = 1 - (age - R.DURATION_MS) / R.FADE_MS
    if k <= 0 then return 0 end
    return R.ALPHA * k
end

-- Ponta da direita do anel de raio r no chão isométrico: o ponto do círculo que vai mais
-- longe na tela em x.
local DIAG = 1 / math.sqrt(2)
function R.edge(x, y, r) return x + r * DIAG, y - r * DIAG end

-- Retângulo da textura na tela: (cx, cy) é o centro projetado e ex o x projetado da ponta.
-- A elipse é 2:1 (meia-altura = meia-largura / 2) e a frente fica em TEX_RING da textura.
function R.rect(cx, cy, ex)
    local half = (ex - cx) / R.TEX_RING
    if half <= 0 then return nil end
    return cx - half, cy - half / 2, 2 * half, half
end

return NOM_SonarRules
