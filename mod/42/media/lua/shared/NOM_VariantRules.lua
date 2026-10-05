-- Regras puras das variantes noturnas (Estalador, Corredor): sem API do jogo,
-- testável com ./run-tests.sh. A variante não é guardada em lugar nenhum: é
-- função do persistentOutfitID do zumbi e do número da noite (ADR-006). Servidor
-- e clientes chegam à mesma resposta sem sincronizar nada, e ela sobrevive a
-- recarregar o chunk ou o save.
NOM_VariantRules = {}

-- Grito do Corredor: no máximo um por zumbi a cada meia hora de jogo.
NOM_VariantRules.SCREAM_COOLDOWN_HOURS = 0.5

-- Mistura sem operadores de bit (Kahlua): quadrados módulo um primo Q < 2^26.
-- Todo produto fica abaixo de 2^53 (h < Q + 31337, h² < 4.6e15), então a conta
-- é exata em double. É não linear de propósito: a versão linear (minstd) dava
-- sorteios correlacionados entre noites seguidas (variante de novo em ~25% contra
-- 15% esperado). Teste: variant_rules_nights_independent.
local Q = 67108859

local function sq(h)
    return (h * h) % Q
end

local function mix(h)
    h = h % Q
    h = (sq(h + 12345) + (h * 48271) % Q) % Q
    h = (sq(h + 777) + h) % Q
    return sq(h + 31337)
end

-- id = persistentOutfitID (int com sinal; o % do Lua devolve positivo).
-- night = número da noite (nil antes de conhecido). cfg = NOM_VariantRules.config.
-- ID 0 é zumbi sem outfit: todos iguais, nenhum vira variante.
function NOM_VariantRules.variant(id, night, cfg)
    if not id or id == 0 or not night then return nil end
    -- id negativo (bit 31 = feminino): o % do Lua com Q positivo dá ≥ 0.
    local h = mix(mix(mix(id % Q + math.floor(id / Q) % Q * 7) + night * 1000003 % Q))
    local roll = math.floor(h / Q * 100)
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
