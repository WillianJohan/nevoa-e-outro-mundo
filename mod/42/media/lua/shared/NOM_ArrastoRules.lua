-- Spike Arrasto / Rastejante (sprint 0059, refinamento §3.5 caminho A).
-- Criatura "baixa": mesmo IsoZombie, sempre crawler, lento, só vermelha/preta.
-- Sem API do jogo — testável com luajit. Quem aplica é server/client.
NOM_ArrastoRules = {
    -- Distância (tiles) pra considerar "ataque perto" no spike de IA.
    ATTACK_RANGE = 2,
    -- Sons (stubs no script; gerados depois se o spike passar no jogo).
    SOUND_LOOP = "NOM_ArrastoDrag",
    SOUND_ATTACK = "NOM_ArrastoLunge",
}

local A = NOM_ArrastoRules

-- Só vermelha ou preta (fantasy §3.5); branca fica com almas.
function A.enabled(color)
    return color == "red" or color == "black"
end

function A.alwaysCrawler()
    return true
end

-- Degrau do doZombieSpeed: 3 = shambler lento (mesmo piso das almas).
function A.speedDeg()
    return 3
end

function A.inAttackRange(dist)
    if dist == nil or dist ~= dist then return false end
    return dist <= A.ATTACK_RANGE
end

function A.mark(md)
    if md == nil then return end
    md.NOM_arrasto = true
end

function A.clear(md)
    if md == nil then return end
    md.NOM_arrasto = nil
end

function A.isArrasto(md)
    return md ~= nil and md.NOM_arrasto == true
end

return NOM_ArrastoRules
