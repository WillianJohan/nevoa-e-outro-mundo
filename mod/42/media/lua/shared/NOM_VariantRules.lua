-- Regras puras das variantes noturnas (Estalador, Corredor): sem API do jogo,
-- testável com ./run-tests.sh. A variante não é guardada em lugar nenhum: é
-- função do persistentOutfitID do zumbi e do número da noite (ADR-006). Servidor
-- e clientes chegam à mesma resposta sem sincronizar nada, e ela sobrevive a
-- recarregar o chunk ou o save.
NOM_VariantRules = {}

-- Forçado pelo NOM_Debug (só em -debug, server/NOM_DebugServer.lua):
-- [persistentOutfitID] = "estalador" | "corredor" | "semrosto". Vale contra
-- chance e toggle, mas não sem noite/período conhecido. Só em memória; servidor e
-- clientes recebem o mesmo, então concordam (ADR-006).
NOM_VariantRules.forced = {}

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
-- Sorteio 0–99 do zumbi no período n. salt separa sorteios que usam o mesmo
-- número (noite 3 e névoa 3 não podem dar o mesmo resultado).
local function roll(id, n, salt)
    -- id negativo (bit 31 = feminino): o % do Lua com Q positivo dá ≥ 0.
    local h = mix(mix(mix(id % Q + math.floor(id / Q) % Q * 7 + salt) + n * 1000003 % Q))
    return math.floor(h / Q * 100)
end

function NOM_VariantRules.variant(id, night, cfg)
    if not id or id == 0 or not night then return nil end
    local f = NOM_VariantRules.forced[id]
    if f == "estalador" or f == "corredor" then return f end
    local roll = roll(id, night, 0)
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

-- Sem-rosto: só existe na névoa, sorteado por período de névoa (o servidor conta
-- como conta as noites). Independente do sorteio da noite: um zumbi pode ser
-- Estalador e Sem-rosto ao mesmo tempo (noite + névoa valem juntas).
local SEM_ROSTO_SALT = 4999999

function NOM_VariantRules.semRosto(id, period, cfg)
    if not id or id == 0 or not period then return false end
    if NOM_VariantRules.forced[id] == "semrosto" then return true end
    if not cfg.semRostoOn then return false end
    return roll(id, period, SEM_ROSTO_SALT) < cfg.semRostoChance
end

function NOM_VariantRules.semRostoConfig(get)
    return { semRostoOn = get("SemRostoEnabled"), semRostoChance = get("SemRostoChance") }
end

-- lastAt/now em horas de jogo (GameTime.getWorldAgeHours).
function NOM_VariantRules.screamReady(lastAt, now)
    return lastAt == nil or now - lastAt >= NOM_VariantRules.SCREAM_COOLDOWN_HOURS
end

return NOM_VariantRules
