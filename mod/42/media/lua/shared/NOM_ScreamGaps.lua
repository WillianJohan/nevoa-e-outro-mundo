-- Intervalos de gritos (ms reais): defaults + overrides do painel (NOM_PanelParams).
-- O cliente empurra pro servidor (VM separada no solo/MP); regras puras leem daqui.
NOM_ScreamGaps = {
    ambientMin = 30000,
    ambientMax = 500000,
    monsterMin = 45000,
    monsterMax = 180000,
}

local G = NOM_ScreamGaps

local function clampSpan(minMs, maxMs)
    minMs = tonumber(minMs) or G.ambientMin
    maxMs = tonumber(maxMs) or G.ambientMax
    if maxMs < minMs then maxMs = minMs end
    return minMs, maxMs
end

function G.setAmbient(minMs, maxMs)
    G.ambientMin, G.ambientMax = clampSpan(minMs, maxMs)
end

function G.setMonster(minMs, maxMs)
    minMs = tonumber(minMs) or G.monsterMin
    maxMs = tonumber(maxMs) or G.monsterMax
    if maxMs < minMs then maxMs = minMs end
    G.monsterMin, G.monsterMax = minMs, maxMs
end

-- u em [0, 1]; roll inteiro 0..span-1 (ambiente).
function G.monsterGapMs(u)
    u = math.max(0, math.min(tonumber(u) or 0, 1))
    local span = G.monsterMax - G.monsterMin
    return G.monsterMin + math.floor(u * span + 0.5)
end

function G.ambientGapMs(roll)
    local span = G.ambientMax - G.ambientMin + 1
    if span < 1 then span = 1 end
    roll = tonumber(roll) or 0
    if roll < 0 then roll = 0 end
    if roll >= span then roll = span - 1 end
    return G.ambientMin + roll
end

function G.ambientRollSpan()
    local span = G.ambientMax - G.ambientMin + 1
    if span < 1 then return 1 end
    return span
end

return NOM_ScreamGaps
