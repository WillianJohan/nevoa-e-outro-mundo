-- Regras puras das variantes da névoa (Estalador, Corredor, Sem-rosto): sem API do jogo,
-- testável com ./run-tests.sh. A variante não é guardada em lugar nenhum: é
-- função do persistentOutfitID do zumbi e do número do período de névoa (ADR-006). Servidor
-- e clientes chegam à mesma resposta sem sincronizar nada, e ela sobrevive a
-- recarregar o chunk ou o save.
NOM_VariantRules = {}

-- Forçado pelo NOM_Debug (só em -debug, server/NOM_DebugServer.lua):
-- [persistentOutfitID] = "estalador" | "corredor" | "semrosto". Vale contra
-- chance e toggle, mas não sem período conhecido. Só em memória; servidor e
-- clientes recebem o mesmo, então concordam (ADR-006).
NOM_VariantRules.forced = {}

-- Grito do Corredor: no máximo um por zumbi a cada meia hora de jogo.
NOM_VariantRules.SCREAM_COOLDOWN_HOURS = 0.5

-- Mistura sem operadores de bit (Kahlua): quadrados módulo um primo Q < 2^26.
-- Todo produto fica abaixo de 2^53 (h < Q + 31337, h² < 4.6e15), então a conta
-- é exata em double. É não linear de propósito: a versão linear (minstd) dava
-- sorteios correlacionados entre períodos seguidos (variante de novo em ~25% contra
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

-- Ordem das faixas do sorteio. Uma variante nova entra NO FIM (a Carpideira, sprint
-- 0010): as faixas de hoje não andam e cada zumbi continua o que era.
NOM_VariantRules.KINDS = { "estalador", "corredor", "semrosto" }
local CHANCE = { estalador = "estaladorChance", corredor = "corredorChance", semrosto = "semRostoChance" }
local ON = { estalador = "estaladorOn", corredor = "corredorOn", semrosto = "semRostoOn" }

-- Sorteio 0–99 do zumbi no período n.
-- id = persistentOutfitID (int com sinal; o % do Lua devolve positivo).
local function roll(id, n)
    -- id negativo (bit 31 = feminino): o % do Lua com Q positivo dá ≥ 0.
    local h = mix(mix(mix(id % Q + math.floor(id / Q) % Q * 7) + n * 1000003 % Q))
    return math.floor(h / Q * 100)
end

-- Variante do zumbi no período de névoa (decisão do Johan, 05/10: todo monstro,
-- menos o Eco, só existe na névoa). Um sorteio só, faixas contíguas na ordem de
-- KINDS: os tipos não se sobrepõem e o total é a soma das chances. A faixa de um
-- tipo desligado continua ocupando o lugar (desligar o Estalador não muda quem é
-- Corredor). period = número do período de névoa (nil = desconhecido). ID 0 é
-- zumbi sem outfit: todos iguais, nenhum vira variante.
-- Devolve "estalador" | "corredor" | "semrosto" | nil.
function NOM_VariantRules.variant(id, period, cfg)
    if not id or id == 0 or not period then return nil end
    local f = NOM_VariantRules.forced[id]
    if f then return f end
    local r, lo = roll(id, period), 0
    for _, kind in ipairs(NOM_VariantRules.KINDS) do
        local hi = lo + (cfg[CHANCE[kind]] or 0)
        if r < hi then return cfg[ON[kind]] and kind or nil end
        lo = hi
    end
    return nil
end

function NOM_VariantRules.semRosto(id, period, cfg)
    return NOM_VariantRules.variant(id, period, cfg) == "semrosto"
end

-- get = NOM_Config.get (injetado: este arquivo não depende do sandbox).
function NOM_VariantRules.config(get)
    return {
        estaladorOn = get("EstaladorEnabled"),
        corredorOn = get("CorredorEnabled"),
        semRostoOn = get("SemRostoEnabled"),
        estaladorChance = get("EstaladorChance"),
        corredorChance = get("CorredorChance"),
        semRostoChance = get("SemRostoChance"),
    }
end

-- lastAt/now em horas de jogo (GameTime.getWorldAgeHours).
function NOM_VariantRules.screamReady(lastAt, now)
    return lastAt == nil or now - lastAt >= NOM_VariantRules.SCREAM_COOLDOWN_HOURS
end

return NOM_VariantRules
