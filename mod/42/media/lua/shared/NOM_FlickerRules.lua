-- Regras puras da luz que pisca (sprint 0045): sem API do jogo, testável com ./run-tests.sh.
-- Padrão = lista de durações (ms) que alterna apagado/aceso, começando apagado; depois do último
-- trecho (sempre apagado, número ímpar de trechos) a luz volta acesa. rnd() devolve 0..1.
NOM_FlickerRules = {}

local R = NOM_FlickerRules

-- Gagueira: trechos curtos de STUTTER_MIN_MS..STUTTER_MAX_MS.
R.STUTTER_MIN_MS = 40
R.STUTTER_MAX_MS = 140
-- Lanterna: TORCH_STUTTER pares (apaga, acende) antes do escuro e TORCH_BACK depois.
R.TORCH_STUTTER = { 3, 6 }
R.TORCH_BACK = { 2, 4 }
-- Poste: LAMP_STUTTER pares; com LAMP_DARK_CHANCE (0..1) o último apagado vira um escuro de
-- LAMP_DARK_MIN_MS..LAMP_DARK_MAX_MS.
R.LAMP_STUTTER = { 4, 9 }
R.LAMP_DARK_CHANCE = 0.3
R.LAMP_DARK_MIN_MS = 400
R.LAMP_DARK_MAX_MS = 1200

-- Sorteio do poste (server/NOM_LampFlicker.lua): a cada LAMP_CHECK_MS, com LAMP_CHANCE (%), um dos
-- postes da rede, de fora e acesos a até LAMP_NEAR de um jogador. Esses vêm de uma volta pela lista
-- da célula a cada LAMP_SCAN_MS, LAMP_BATCH por tick. No máximo LAMP_MAX piscando juntos.
R.LAMP_CHECK_MS = 2000
R.LAMP_CHANCE = 30
R.LAMP_NEAR = 25
R.LAMP_MAX = 2
R.LAMP_SCAN_MS = 2000
R.LAMP_BATCH = 40

-- Chave do poste pela posição (o cliente acha a luz dele pela mesma posição).
function R.lampKey(x, y, z) return x .. "," .. y .. "," .. z end

local function pick(lo, hi, r)
    return math.floor(lo + (hi - lo) * math.max(0, math.min(r, 0.999999)) + 0.5)
end

local function short(rnd) return pick(R.STUTTER_MIN_MS, R.STUTTER_MAX_MS, rnd()) end

local function count(range, rnd) return pick(range[1], range[2], rnd()) end

local function pairsOf(segs, n, rnd)
    for _ = 1, n do
        segs[#segs + 1] = short(rnd)
        segs[#segs + 1] = short(rnd)
    end
end

-- Lanterna: gagueira, escuro de darkMs, gagueira de volta.
function R.torch(darkMs, rnd)
    local segs = {}
    pairsOf(segs, count(R.TORCH_STUTTER, rnd), rnd)
    segs[#segs + 1] = math.max(1, math.floor(darkMs))
    for _ = 1, count(R.TORCH_BACK, rnd) do
        segs[#segs + 1] = short(rnd)
        segs[#segs + 1] = short(rnd)
    end
    return segs
end

-- Teto do total da lanterna (o servidor conta a janela inteira como apagada).
function R.torchMax(darkMs)
    return math.floor(darkMs) + 2 * (R.TORCH_STUTTER[2] + R.TORCH_BACK[2]) * R.STUTTER_MAX_MS
end

-- Poste: gagueira e, às vezes, um escuro no fim.
-- opts (sprint 0051, só na preta): lampDarkChance, lampDarkMinMs, lampDarkMaxMs do perfil.
function R.lamp(rnd, opts)
    opts = opts or {}
    local darkChance = opts.lampDarkChance
    if darkChance == nil then darkChance = R.LAMP_DARK_CHANCE end
    local darkMin = opts.lampDarkMinMs or R.LAMP_DARK_MIN_MS
    local darkMax = opts.lampDarkMaxMs or R.LAMP_DARK_MAX_MS
    local segs = {}
    pairsOf(segs, count(R.LAMP_STUTTER, rnd), rnd)
    if rnd() < darkChance then
        segs[#segs + 1] = pick(darkMin, darkMax, rnd())
    else
        segs[#segs + 1] = short(rnd)
    end
    return segs
end

function R.lampMax(opts)
    opts = opts or {}
    local darkMax = opts.lampDarkMaxMs or R.LAMP_DARK_MAX_MS
    return 2 * R.LAMP_STUTTER[2] * R.STUTTER_MAX_MS + darkMax
end

function R.total(segs)
    local t = 0
    for _, ms in ipairs(segs) do t = t + ms end
    return t
end

-- Aceso em t ms desde o começo? done = o padrão acabou (aceso de vez).
function R.stateAt(segs, t)
    if t < 0 then return true, false end
    local acc = 0
    for i, ms in ipairs(segs) do
        acc = acc + ms
        if t < acc then return i % 2 == 0, false end
    end
    return true, true
end

return NOM_FlickerRules
