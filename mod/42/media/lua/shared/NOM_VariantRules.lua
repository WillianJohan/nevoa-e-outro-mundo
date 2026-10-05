-- Regras puras das variantes noturnas (Estalador, Corredor): sem API do jogo,
-- testável com ./run-tests.sh. A variante não é guardada em lugar nenhum: é
-- função do persistentOutfitID do zumbi e do número da noite (ADR-006). Servidor
-- e clientes chegam à mesma resposta sem sincronizar nada, e ela sobrevive a
-- recarregar o chunk ou o save.
NOM_VariantRules = {}

-- Grito do Corredor: no máximo um por zumbi a cada meia hora de jogo.
NOM_VariantRules.SCREAM_COOLDOWN_HOURS = 0.5

-- Mistura sem operadores de bit (Kahlua): minstd com módulo primo de Mersenne.
-- h < 2^31 e h * A < 2^53, então a conta é exata em double. A dobra
-- (h / 65536) quebra a linearidade, senão IDs vizinhos (sementes seguidas)
-- cairiam em sorteios correlacionados.
local M = 2147483647
local A = 48271

local function mix(h)
    h = (h * A) % M
    return (h + math.floor(h / 65536) * 31) % M
end

-- id = persistentOutfitID (int com sinal; o % do Lua devolve positivo).
-- night = número da noite (nil antes de conhecido). cfg = NOM_VariantRules.config.
-- ID 0 é zumbi sem outfit: todos iguais, nenhum vira variante.
function NOM_VariantRules.variant(id, night, cfg)
    if not id or id == 0 or not night then return nil end
    local h = mix(mix(id % M + 1) + night * 7919)
    local roll = mix(h) % 100
    local e = cfg.estaladorOn and cfg.estaladorChance or 0
    local c = cfg.corredorOn and cfg.corredorChance or 0
    if roll < e then return "estalador" end
    if roll < e + c then return "corredor" end
    return nil
end

-- get = NOM_Config.get (injetado: este arquivo não depende do sandbox).
function NOM_VariantRules.config(get)
    return {
        estaladorOn = get("EstaladorEnabled"),
        corredorOn = get("CorredorEnabled"),
        estaladorChance = get("EstaladorChance"),
        corredorChance = get("CorredorChance"),
    }
end

-- lastAt/now em horas de jogo (GameTime.getWorldAgeHours).
function NOM_VariantRules.screamReady(lastAt, now)
    return lastAt == nil or now - lastAt >= NOM_VariantRules.SCREAM_COOLDOWN_HOURS
end

return NOM_VariantRules
