-- Regras puras do Sem-rosto: sem API do jogo, testável com ./run-tests.sh.
-- Quem é Sem-rosto fica no NOM_VariantRules (sorteio por período de névoa).
NOM_SemRostoRules = {}

NOM_SemRostoRules.MIN_DIST = 3      -- nunca reaparece colado no jogador
NOM_SemRostoRules.STEP = 3          -- quanto chega mais perto a cada sumiço
NOM_SemRostoRules.COOLDOWN_MS = 4000 -- tempo real entre sumiços do mesmo zumbi (sem piscar)
NOM_SemRostoRules.REPORT_RANGE = 30 -- até onde o jogador "vê" o Sem-rosto
NOM_SemRostoRules.STATIC_NEAR = 3   -- rádio no máximo
NOM_SemRostoRules.STATIC_FAR = 30   -- rádio mudo

-- Arredondar o ponto pro tile põe o destino até ~0,71 tile fora do raio.
local SLACK = 0.75

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
end

function NOM_SemRostoRules.nextRadius(d)
    return math.max(NOM_SemRostoRules.MIN_DIST, d - NOM_SemRostoRules.STEP)
end

-- Tiles no círculo de raio r em volta de (px, py), começando atrás do jogador
-- (faceAngle + π, em radianos, como getForwardDirection():getDirection()) e
-- abrindo 30° de cada lado até ±120°: nunca na frente.
function NOM_SemRostoRules.spots(px, py, faceAngle, r)
    local out, seen = {}, {}
    local back = faceAngle + math.pi
    for k = 0, 8 do
        local step = math.floor((k + 1) / 2) * math.rad(30)
        local a = back + ((k % 2 == 1) and step or -step)
        local x = math.floor(px + r * math.cos(a) + 0.5)
        local y = math.floor(py + r * math.sin(a) + 0.5)
        local key = x .. "," .. y
        if not seen[key] then
            seen[key] = true
            out[#out + 1] = { x = x, y = y }
        end
    end
    return out
end

-- lastMs/nowMs em tempo real (getTimestampMs).
function NOM_SemRostoRules.ready(lastMs, nowMs)
    return lastMs == nil or nowMs - lastMs >= NOM_SemRostoRules.COOLDOWN_MS
end

-- (sx, sy) jogador que viu, (zx, zy) zumbi, (tx, ty) destino. O servidor confere
-- o que o cliente mandou: destino mais perto do jogador que o zumbi (ou no
-- mínimo), nem colado, e o zumbi ao alcance de quem diz que viu.
function NOM_SemRostoRules.validMove(sx, sy, zx, zy, tx, ty)
    local R = NOM_SemRostoRules
    local dz, dt = dist(sx, sy, zx, zy), dist(sx, sy, tx, ty)
    if dz > R.REPORT_RANGE then return false end
    if dt < R.MIN_DIST - SLACK then return false end
    return dt <= math.max(dz, R.MIN_DIST) + SLACK
end

-- Volume do rádio pela distância do Sem-rosto mais perto (nil = nenhum).
function NOM_SemRostoRules.staticVolume(d)
    local R = NOM_SemRostoRules
    if d == nil or d >= R.STATIC_FAR then return 0 end
    if d <= R.STATIC_NEAR then return 1 end
    return (R.STATIC_FAR - d) / (R.STATIC_FAR - R.STATIC_NEAR)
end

return NOM_SemRostoRules
