-- Regras puras do Sem-rosto: sem API do jogo, testável com ./run-tests.sh.
-- Quem é Sem-rosto fica no NOM_VariantRules (sorteio por período de névoa).
NOM_SemRostoRules = {}

NOM_SemRostoRules.MIN_DIST = 3      -- nunca reaparece colado no jogador
-- A até ATTACK_DIST de quem vê, para de sumir e ataca (decisão do coordenador,
-- sprint 0005): senão ele pisca pra sempre atrás de quem o encara e nunca ameaça.
NOM_SemRostoRules.ATTACK_DIST = 2
NOM_SemRostoRules.STEP = 3          -- quanto chega mais perto a cada sumiço
NOM_SemRostoRules.COOLDOWN_MS = 4000 -- tempo real entre sumiços do mesmo zumbi (sem piscar)
-- Sprint 0017: o tile de um sumiço fica reservado RESERVE_MS reais. Uma horda vista junta
-- tem o mesmo raio e o mesmo anel; sem a reserva, todos iam pro primeiro tile livre.
NOM_SemRostoRules.RESERVE_MS = 5000
-- O servidor aceita um semRostoSeen por jogador a cada RATE_MS reais
-- (server/NOM_Fog.lua); o cliente manda no máximo um a cada REPORT_GAP_MS (com
-- margem pro atraso da rede), senão o servidor descarta o segundo e aquele
-- Sem-rosto ficaria mudo o COOLDOWN_MS inteiro. O que não foi tem nova chance na
-- varredura seguinte.
NOM_SemRostoRules.RATE_MS = 250
NOM_SemRostoRules.REPORT_GAP_MS = 300
NOM_SemRostoRules.REPORT_RANGE = 30 -- até onde o jogador "vê" o Sem-rosto
NOM_SemRostoRules.STATIC_NEAR = 3   -- rádio no máximo
NOM_SemRostoRules.STATIC_FAR = 30   -- rádio mudo

-- O destino é o tile que contém o ponto do círculo: o centro dele fica até ~0,71
-- tile fora do raio.
local SLACK = 0.75

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
end

-- Visto a d tiles: some (true) ou ataca (false).
function NOM_SemRostoRules.vanishes(d)
    return d > NOM_SemRostoRules.ATTACK_DIST
end

function NOM_SemRostoRules.nextRadius(d)
    return math.max(NOM_SemRostoRules.MIN_DIST, d - NOM_SemRostoRules.STEP)
end

-- Tiles (coordenada inteira do canto) no círculo de raio r em volta do ponto
-- (px, py) (posição real do jogador, em float), começando atrás do jogador
-- (faceAngle + π, em radianos, como getForwardDirection():getDirection()) e
-- abrindo 30° de cada lado até ±120°: nunca na frente.
function NOM_SemRostoRules.spots(px, py, faceAngle, r)
    local out, seen = {}, {}
    local back = faceAngle + math.pi
    for k = 0, 8 do
        local step = math.floor((k + 1) / 2) * math.rad(30)
        local a = back + ((k % 2 == 1) and step or -step) -- kahlua-%-ok: k de 0 a 8
        local x = math.floor(px + r * math.cos(a))
        local y = math.floor(py + r * math.sin(a))
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
-- mínimo), nem colado, e o zumbi ao alcance de quem diz que viu (e não tão
-- perto que já devia atacar).
function NOM_SemRostoRules.validMove(sx, sy, zx, zy, tx, ty)
    local R = NOM_SemRostoRules
    local dz, dt = dist(sx, sy, zx, zy), dist(sx, sy, tx, ty)
    if dz > R.REPORT_RANGE or not R.vanishes(dz) then return false end
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
