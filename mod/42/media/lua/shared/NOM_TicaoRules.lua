-- Regras puras do Tição (sprint 0038): o zumbi da névoa preta. Sem API do jogo, testável
-- com ./run-tests.sh. Na preta todo zumbi com ID vira Tição (NOM_VariantRules.variant);
-- a velocidade é sorteada por zumbi e período, como as variantes (ADR-006): servidor e
-- clientes chegam à mesma resposta sem sincronizar nada.
require "NOM_VariantRules"

NOM_TicaoRules = {}

local R = NOM_TicaoRules

-- Velocidade: metade arrastado (3), metade arrastado rápido (2). Decisão conservadora
-- tomada pelo Johan ausente (HANDOFF): nunca corredor, a ameaça é o número e a escuridão.
R.SHAMBLER = 3
R.FAST_SHAMBLER = 2
-- Visão ruim e audição apurada (degraus do jogo, 1 = melhor): enxerga mal no escuro, ouve tudo.
R.SIGHT = 3
R.HEARING = 1
-- Visão curta da preta (tiles): no lugar do FogZombieVision enquanto a preta durar.
R.VISION_TILES = 3
-- Caça da preta: a cada HUNT_MINUTES de jogo, um chamado a HUNT_REACH tiles em volta de cada
-- jogador. Mais forte que a caça da noite (padrão 90 min e 25 tiles).
R.HUNT_MINUTES = 20
R.HUNT_REACH = 40

local SPEED_SALT = 52711

-- id: persistentOutfitID (com ou sem o bit do chapéu caído); period: número do período.
function R.speed(id, period)
    id = NOM_VariantRules.baseId(id) or 0
    local Q = NOM_VariantRules.Q
    if math.floor(NOM_VariantRules.hash(id, period or 0, SPEED_SALT) / Q * 2) == 0 then return R.SHAMBLER end
    return R.FAST_SHAMBLER
end

return NOM_TicaoRules
