-- Sonar do Estalador (sprint 0037, spec §6), a regra pura: o estalo solta um anel que
-- avança RANGE tiles em DURATION_MS reais. O anel que cruza um jogador no mesmo andar, em
-- pé ou andando, faz o Estalador achá-lo; agachado e parado, o anel passa. Sem API do jogo:
-- quem decide é o server/NOM_SonarServer.lua; quem desenha, o client/NOM_SonarFx.lua; o
-- mod3 tem os mesmos números em mod3/java/nom/render/Sonar.java (teste de contrato).
NOM_SonarRules = {
    RANGE = 8,             -- tiles
    DURATION_MS = 1500,    -- ms reais até os 8 tiles: ~5,3 tiles/s, mais rápido que qualquer corrida
    FADE_MS = 400,         -- o desenho some nesse tempo depois do fim
    ALPHA = 0.35,          -- discreto
    -- Depois de achar, o Estalador não é cegado de novo por FOUND_MS reais: dá tempo de ele
    -- andar os 8 tiles (~1 tile/s) mesmo que o jogador se agache logo depois do anel.
    FOUND_MS = 10000,
    CLICK_ODDS = 2,        -- chance 1/2 por minuto de jogo: um estalo a cada 2 min em média
    SEND_RANGE = 40,       -- só estala com jogador a até isso (o som chega a 25, o anel a 8)
    SAMPLE_MS = 250,       -- amostra de posição dos jogadores (o "andando")
    MOVE_EPS = 0.1,        -- tiles entre amostras: ≥ 0,2 tile/s é andar
    MAX_RINGS = 8,         -- anéis vivos ao mesmo tempo (servidor, tela e mod3)
    DEBUG_REACH = 60,      -- NOM.sonar(): Estalador a até isso de quem pede
    MAX_COORD = 100000,    -- coordenada de tile aceita na mensagem
    MIN_FLOOR = -32, MAX_FLOOR = 32,
}
local R = NOM_SonarRules

-- Raio do anel (tiles) com age ms de vida.
function R.radius(age)
    if age <= 0 then return 0 end
    if age >= R.DURATION_MS then return R.RANGE end
    return R.RANGE * age / R.DURATION_MS
end

function R.done(age) return age >= R.DURATION_MS end

-- d2 = distância² ao centro. O anel cruzou neste tick se a frente foi de r0 a r1 e passou
-- por d. r0 nil: primeiro tick (o centro conta).
function R.crossed(d2, r0, r1)
    if d2 > r1 * r1 then return false end
    return r0 == nil or d2 > r0 * r0
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

-- Índices dos jogadores ({ x, y, z }) que o anel cruzou ao ir de r0 a r1, no andar dele.
function R.sweep(ring, r0, r1, players)
    local out = {}
    if r0 ~= nil and r1 <= r0 then return out end
    local floor = math.floor(ring.z)
    for i, p in ipairs(players) do
        if math.floor(p.z) == floor then
            local dx, dy = p.x - ring.x, p.y - ring.y
            if R.crossed(dx * dx + dy * dy, r0, r1) then out[#out + 1] = i end
        end
    end
    return out
end

-- roll = ZombRand(CLICK_ODDS).
function R.clicks(roll) return roll == 0 end

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

local function finite(v)
    return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function coord(v) return finite(v) and v >= 0 and v <= R.MAX_COORD end

-- Mensagem "sonar" do servidor: { x, y, z, id = onlineID do Estalador ou -1 }. nil se não serve.
function R.valid(a)
    if type(a) ~= "table" or not coord(a.x) or not coord(a.y) or not finite(a.z) then return nil end
    if a.z ~= math.floor(a.z) or a.z < R.MIN_FLOOR or a.z > R.MAX_FLOOR then return nil end
    if a.id ~= nil and not finite(a.id) then return nil end
    return { x = a.x, y = a.y, z = a.z, id = a.id or -1 }
end

-- Mensagem "sonarFound": { id = onlineID do Estalador, pl = onlineID do jogador achado }.
function R.validFound(a)
    if type(a) ~= "table" or not finite(a.id) or not finite(a.pl) or a.id == -1 then return nil end
    return { id = a.id, pl = a.pl }
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

return NOM_SonarRules
