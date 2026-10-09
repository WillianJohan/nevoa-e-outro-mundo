-- Identidade por cor da névoa (sprint 0049): puro, sem API do jogo, testável com
-- ./run-tests.sh. Transform 100% em toda fog; a cor muda o clima emocional
-- (branca = cotidiano / vermelha = agitação / preta = só Tição). Quem aplica
-- velocidade e path é o dono do zumbi (ADR-005; doZombieSpeed / pathToLocationF,
-- pz-api-notes §2.1 e §27).

NOM_ColorIdentityRules = {}

-- Cooldown do grito do Corredor (horas de jogo). Branca = o de sempre (0,5 h);
-- vermelha mais curta: agitação / caça (refinamento §3.9).
NOM_ColorIdentityRules.SCREAM_WHITE = 0.5
NOM_ColorIdentityRules.SCREAM_RED = 0.15

-- red/black: flags do evento (NOM_World / NOM_FogState). Preta ganha da vermelha.
function NOM_ColorIdentityRules.mood(red, black)
    if black then return "black" end
    if red then return "red" end
    return "white"
end

function NOM_ColorIdentityRules.wanderAllowed(mood)
    return mood == "white"
end

-- Na branca com transform 100%, quase não sobra zumbi comum: o Estalador (cego,
-- sem mira de caça) pode perambular. Corredor, Carpideira, Sem-rosto e Tição têm
-- regra própria e ficam de fora (mesmo espírito da 0036).
function NOM_ColorIdentityRules.canWanderKind(kind, mood)
    if mood ~= "white" then return false end
    return kind == nil or kind == "estalador"
end

function NOM_ColorIdentityRules.screamCooldownHours(mood)
    if mood == "red" then return NOM_ColorIdentityRules.SCREAM_RED end
    return NOM_ColorIdentityRules.SCREAM_WHITE
end

-- Degrau de velocidade do Estalador na vermelha (1 corredor, 2 rápido, 3 arrastado;
-- IsoZombie.doZombieSpeed, pz-api-notes §2.1). nil = não forçar (fica o da noite/dia).
function NOM_ColorIdentityRules.estaladorSpeed(mood)
    if mood == "red" then return 2 end
    return nil
end

return NOM_ColorIdentityRules
