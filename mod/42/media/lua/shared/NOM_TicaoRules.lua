-- Regras puras do Tição (sprint 0038): o zumbi da névoa preta. Sem API do jogo, testável
-- com ./run-tests.sh. Na preta todo zumbi com ID vira Tição (NOM_VariantRules.variant);
-- a velocidade é sorteada por zumbi e período, como as variantes (ADR-006): servidor e
-- clientes chegam à mesma resposta sem sincronizar nada. Caça e bias de velocidade leem
-- NOM_BlackPressureRules (sprint 0051); HUNT_* espelham o Padrão.
require "NOM_VariantRules"
require "NOM_BlackPressureRules"

NOM_TicaoRules = {}

local R = NOM_TicaoRules

-- Velocidade: arrastado (3) ou arrastado rápido (2). Nunca corredor. Em Leve/Padrão ~50%%;
-- em Pesadelo o bias sobe (BlackPressureRules.fastBias).
R.SHAMBLER = 3
R.FAST_SHAMBLER = 2
-- Visão ruim e audição apurada (degraus do jogo, 1 = melhor): enxerga mal no escuro, ouve tudo.
R.SIGHT = 3
R.HEARING = 1
-- Visão curta da preta (tiles): no lugar do FogZombieVision enquanto a preta durar.
R.VISION_TILES = 3
-- Caça da preta (espelho do Padrão): preferir R.huntMinutes() / R.huntReach().
R.HUNT_MINUTES = 12
R.HUNT_REACH = 40

local SPEED_SALT = 52711

function R.huntMinutes()
    return NOM_BlackPressureRules.current().huntMinutes
end

function R.huntReach()
    return NOM_BlackPressureRules.current().huntReach
end

-- id: persistentOutfitID (com ou sem o bit do chapéu caído); period: número do período.
function R.speed(id, period)
    id = NOM_VariantRules.baseId(id) or 0
    local Q = NOM_VariantRules.Q
    local u = NOM_VariantRules.hash(id, period or 0, SPEED_SALT) / Q
    local bias = NOM_BlackPressureRules.current().fastBias
    if u < bias then return R.FAST_SHAMBLER end
    return R.SHAMBLER
end

return NOM_TicaoRules
