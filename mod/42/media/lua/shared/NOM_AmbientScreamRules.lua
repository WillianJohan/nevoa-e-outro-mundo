-- Gritos ambiente da névoa (sprint 0048, produto §3.1.1): “gente” longe, só no cliente,
-- sem horda / sem comando de servidor. Intensidade por cor: branca rarefeita, vermelha um
-- pouco mais perto/frequente, preta off (não compete com Tição). Quem toca é
-- client/NOM_AmbientScream.lua; desliga com FogAmbience.
NOM_AmbientScreamRules = {
    -- Clips em media/scripts/NOM_sounds.txt (gerados por scripts/gen_sounds.py).
    SOUNDS = {
        "NOM_AmbientScream1",
        "NOM_AmbientScream2",
        "NOM_AmbientScream3",
        "NOM_AmbientScream4",
    },
    -- Intervalo entre gritos (ms reais). Sprint 0053: média ~1/min na branca;
    -- vermelha um pouco mais apertada. Preta off (não compete com Tição).
    GAP = {
        white = { min = 30000, max = 90000 },
        red = { min = 20000, max = 70000 },
        black = nil, -- silêncio: não agenda
    },
    -- Distância do emitter ao jogador (tiles). Longe + passa-baixa no OGG = presença.
    DIST = {
        white = { min = 40, max = 90 },
        red = { min = 28, max = 70 },
    },
}

local A = NOM_AmbientScreamRules

-- Ambiente toca? fogAmbience = sandbox; color = "white"|"red"|"black"|nil.
function A.enabled(fogAmbience, color)
    if not fogAmbience then return false end
    if color ~= "white" and color ~= "red" then return false end
    return A.GAP[color] ~= nil
end

-- Gap até o próximo grito. roll = ZombRand(max - min + 1). nil se a cor não tem agenda.
function A.gap(color, roll)
    local g = A.GAP[color]
    if g == nil then return nil end
    local span = g.max - g.min + 1
    if roll == nil then roll = 0 end
    if roll < 0 then roll = 0 end
    if roll >= span then roll = span - 1 end
    return g.min + roll
end

-- Índice do clip (1..#SOUNDS). roll = ZombRand(#SOUNDS).
function A.pick(roll)
    local n = #A.SOUNDS
    if n < 1 then return nil end
    if roll == nil or roll < 0 then roll = 0 end
    return A.SOUNDS[(roll % n) + 1]
end

-- Distância do emitter. roll = ZombRand(max - min + 1). nil se a cor não emite.
function A.distance(color, roll)
    local d = A.DIST[color]
    if d == nil then return nil end
    local span = d.max - d.min + 1
    if roll == nil then roll = 0 end
    if roll < 0 then roll = 0 end
    if roll >= span then roll = span - 1 end
    return d.min + roll
end

-- Ângulo em radianos a partir de roll = ZombRand(360), pra espalhar o emitter em volta.
function A.bearing(roll)
    if roll == nil then roll = 0 end
    return (roll % 360) * (math.pi / 180)
end

-- Posição do emitter: (px, py) + distância na direção do bearing.
function A.spot(px, py, dist, bearing)
    return px + dist * math.cos(bearing), py + dist * math.sin(bearing)
end

return NOM_AmbientScreamRules
