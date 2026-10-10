-- Gritos ambiente da névoa (sprint 0048, produto §3.1.1): “gente” longe, só no cliente,
-- sem horda / sem comando de servidor. Intensidade por cor: branca e vermelha tocam,
-- preta off (não compete com Tição). Quem toca é client/NOM_AmbientScream.lua; desliga
-- com FogAmbience.
--
-- Intervalo (hotfix 0063 / playtest Johan): uniforme 60–500 s reais, sorteado de novo
-- depois de cada grito. Knobs live AmbientGapMinMs/MaxMs no painel (seção de sons).
NOM_AmbientScreamRules = {
    -- Clips em media/scripts/NOM_sounds.txt (gerados por scripts/gen_sounds.py).
    SOUNDS = {
        "NOM_AmbientScream1",
        "NOM_AmbientScream2",
        "NOM_AmbientScream3",
        "NOM_AmbientScream4",
    },
    -- Intervalo entre gritos (ms reais). Um único intervalo pra branca e vermelha.
    GAP_MIN_MS = 60000,
    GAP_MAX_MS = 500000,
    -- Distância do emitter ao jogador (tiles). Longe + passa-baixa no OGG = presença.
    -- Playtest: um pouco mais distante que 40–90 / 28–70.
    DIST = {
        white = { min = 50, max = 110 },
        red = { min = 36, max = 85 },
    },
}

local A = NOM_AmbientScreamRules

A.GAP_ROLL = A.GAP_MAX_MS - A.GAP_MIN_MS + 1

-- Ambiente toca? fogAmbience = sandbox; color = "white"|"red"|"black"|nil.
function A.enabled(fogAmbience, color)
    if not fogAmbience then return false end
    if color ~= "white" and color ~= "red" then return false end
    return true
end

-- Gap até o próximo grito. roll = ZombRand(GAP_ROLL). nil se a cor não tem agenda.
function A.gap(color, roll)
    if color ~= "white" and color ~= "red" then return nil end
    local span = A.GAP_MAX_MS - A.GAP_MIN_MS + 1
    if roll == nil then roll = 0 end
    if roll < 0 then roll = 0 end
    if roll >= span then roll = span - 1 end
    return A.GAP_MIN_MS + roll
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
