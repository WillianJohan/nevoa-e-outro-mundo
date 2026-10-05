-- Regras puras das variantes da névoa (Estalador, Corredor, Sem-rosto, Carpideira): sem API do jogo,
-- testável com ./run-tests.sh. A variante não é guardada em lugar nenhum: é
-- função do persistentOutfitID do zumbi e do número do período de névoa (ADR-006). Servidor
-- e clientes chegam à mesma resposta sem sincronizar nada, e ela sobrevive a
-- recarregar o chunk ou o save.
NOM_VariantRules = {}

-- Forçado pelo NOM_Debug (só em -debug, server/NOM_DebugServer.lua):
-- [persistentOutfitID] = "estalador" | "corredor" | "semrosto" | "carpideira". Vale contra
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

-- Ordem das faixas do sorteio. Uma variante nova entra NO FIM (a Carpideira entrou
-- na sprint 0011): as faixas de antes não andam e cada zumbi continua o que era.
-- Na névoa vermelha (sprint 0010) a divisão é por #KINDS: a Carpideira re-dividiu
-- (1/3 virou 1/4), o que é a regra ("todos os tipos, por igual").
NOM_VariantRules.KINDS = { "estalador", "corredor", "semrosto", "carpideira" }
local CHANCE = { estalador = "estaladorChance", corredor = "corredorChance", semrosto = "semRostoChance",
    carpideira = "carpideiraChance" }
local ON = { estalador = "estaladorOn", corredor = "corredorOn", semrosto = "semRostoOn", carpideira = "carpideiraOn" }

-- Hash do zumbi no período n, em [0, Q). salt separa sorteios independentes do
-- mesmo zumbi no mesmo período; sal 0 é o sorteio de sempre (mix(x + 0) = mix(x)).
-- id = persistentOutfitID (int com sinal; o % do Lua devolve positivo).
local function hash(id, n, salt)
    -- id negativo (bit 31 = feminino): o % do Lua com Q positivo dá ≥ 0.
    return mix(mix(mix(id % Q + math.floor(id / Q) % Q * 7) + n * 1000003 % Q) + salt)
end

-- Sorteio 0–99 do zumbi no período n.
local function roll(id, n)
    return math.floor(hash(id, n, 0) / Q * 100)
end

-- Sais da névoa vermelha (sprint 0010): o sorteio do período e a divisão dos tipos
-- não se correlacionam com o sorteio normal.
local RED_SALT = 7919
local SPLIT_SALT = 104729

-- Semente do mundo: inteiro em [0, SEED_RANGE), sorteado uma vez por save
-- (server/NOM_FogEvent.lua, data.fog.seed). Sem ela todo save teria a mesma agenda.
NOM_VariantRules.SEED_RANGE = Q

-- Névoa vermelha no período (sprint 0010): RedFogChance% dos períodos, função do
-- número do período e da semente do mundo (entra no lugar do ID do zumbi).
-- Recarregar não re-sorteia. Só o servidor sorteia; os clientes recebem.
function NOM_VariantRules.redFog(period, cfg, seed)
    if not period or not cfg.redFogOn then return false end
    return math.floor(hash(seed or 0, period, RED_SALT) / Q * 100) < (cfg.redFogChance or 0)
end

-- Variante do zumbi no período de névoa (decisão do Johan, 05/10: todo monstro,
-- menos o Eco, só existe na névoa). Um sorteio só, faixas contíguas na ordem de
-- KINDS: os tipos não se sobrepõem e o total é a soma das chances. A faixa de um
-- tipo desligado continua ocupando o lugar (desligar o Estalador não muda quem é
-- Corredor). period = número do período de névoa (nil = desconhecido). ID 0 é
-- zumbi sem outfit: todos iguais, nenhum vira variante.
-- red: névoa vermelha (sprint 0010): todo zumbi é variante, dividido por igual
-- entre KINDS por um segundo hash; a fatia de um tipo desligado fica comum.
-- Devolve "estalador" | "corredor" | "semrosto" | "carpideira" | nil.
function NOM_VariantRules.variant(id, period, cfg, red)
    if not id or id == 0 or not period then return nil end
    local f = NOM_VariantRules.forced[id]
    if f then return f end
    if red then
        local kinds = NOM_VariantRules.KINDS
        local kind = kinds[math.floor(hash(id, period, SPLIT_SALT) / Q * #kinds) + 1]
        return cfg[ON[kind]] and kind or nil
    end
    local r, lo = roll(id, period), 0
    for _, kind in ipairs(NOM_VariantRules.KINDS) do
        local hi = lo + (cfg[CHANCE[kind]] or 0)
        if r < hi then return cfg[ON[kind]] and kind or nil end
        lo = hi
    end
    return nil
end

function NOM_VariantRules.semRosto(id, period, cfg, red)
    return NOM_VariantRules.variant(id, period, cfg, red) == "semrosto"
end

-- get = NOM_Config.get (injetado: este arquivo não depende do sandbox).
function NOM_VariantRules.config(get)
    return {
        estaladorOn = get("EstaladorEnabled"),
        corredorOn = get("CorredorEnabled"),
        semRostoOn = get("SemRostoEnabled"),
        carpideiraOn = get("CarpideiraEnabled"),
        estaladorChance = get("EstaladorChance"),
        corredorChance = get("CorredorChance"),
        semRostoChance = get("SemRostoChance"),
        carpideiraChance = get("CarpideiraChance"),
        redFogOn = get("RedFogEnabled"),
        redFogChance = get("RedFogChance"),
    }
end

-- lastAt/now em horas de jogo (GameTime.getWorldAgeHours).
function NOM_VariantRules.screamReady(lastAt, now)
    return lastAt == nil or now - lastAt >= NOM_VariantRules.SCREAM_COOLDOWN_HOURS
end

return NOM_VariantRules
