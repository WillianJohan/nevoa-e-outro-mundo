-- Regras puras da Carpideira (sprint 0011; andar chorando e volume do soluço na
-- 0052): sem API do jogo, testável com ./run-tests.sh. Quem é Carpideira sai do
-- sorteio da névoa (NOM_VariantRules); aqui fica o que acorda ela, a memória de
-- quem já gritou, o intervalo/destino da caminhada calma e o volume do soluço.
require "NOM_FlakeRules"

NOM_CarpideiraRules = {
    -- Lanterna e barulho alcançam até aqui (tiles): "perto" pra quem a acorda de longe.
    ALERT_RANGE = 10,
    -- Barulho alto: raio do addSound a partir disto. Tarefas vanilla ficam em 6–20
    -- (shared/TimedActions/ISRemoveBush.lua:41, ISRemoveGrass.lua:30); arma de fogo,
    -- SoundRadius 50–200 nos scripts.
    LOUD_RADIUS = 30,
    -- Folga da conferência do servidor (tiles): a posição dele está atrasada.
    SLACK = 2,
    -- Servidor: um aviso por jogador a cada RATE_MS reais (contando os inválidos).
    RATE_MS = 1000,
    -- Cliente: um aviso por Carpideira a cada REPORT_GAP_MS reais.
    REPORT_GAP_MS = 2000,
    -- Sprint 0052 (Witch): caminhada curta chorando, sem caçar (§3.2.1).
    WALK_GAP_MIN_MS = 20000,
    WALK_GAP_MAX_MS = 60000,
    WALK_DIST_MIN = 2,
    WALK_DIST_MAX = 6,
    WALK_TRIES = 8,
    WALK_TIMEOUT_MS = 15000,
    -- Playtest 2026-10-10: gap global entre gritos (qualquer Carpideira/Screamer).
    -- Um grito por PID por período continua; isto evita clusters de várias ao mesmo tempo.
    SCREAM_GAP_MIN_MS = 45000,
    SCREAM_GAP_MAX_MS = 180000,
    -- Volume do soluço pela distância (mesmo espírito do rádio do Sem-rosto).
    SOB_NEAR = 3,
    SOB_FAR = 12,
}

local R = NOM_CarpideiraRules
R.rng = NOM_FlakeRules.rng

-- O servidor confere o aviso do cliente. why: "near" (jogador a até triggerRadius) ou
-- "light" (lanterna acesa, ela vista, a até ALERT_RANGE). dist: do jogador que avisou
-- até ela, na posição que o servidor conhece. lit: o servidor vê a lanterna acesa.
function R.woke(why, dist, triggerRadius, lit)
    if type(dist) ~= "number" then return false end
    if why == "near" then return dist <= triggerRadius + R.SLACK end
    if why == "light" then return lit == true and dist <= R.ALERT_RANGE + R.SLACK end
    return false
end

-- Barulho que acorda: alto, que chega até ela, nascido a até ALERT_RANGE.
-- dist: da origem do som até ela; radius: o do addSound.
function R.loud(dist, radius)
    return radius >= R.LOUD_RADIUS and dist <= R.ALERT_RANGE and dist <= radius
end

-- Quem já gritou no período: { [persistentOutfitID] = true }, dentro de data (o
-- ModData global do servidor). Período novo, tabela nova: um grito por névoa, e
-- salvar e carregar no meio não deixa gritar de novo. nextAt (gap global) fica.
function R.screamed(data, period)
    local s = data.carpideira
    if not s or s.period ~= period then
        local nextAt = s and s.nextAt
        s = { period = period, pids = {}, nextAt = nextAt }
        data.carpideira = s
    end
    return s.pids
end

-- Estado completo (pids + nextAt) no ModData; cria/renova período se preciso.
function R.screamState(data, period)
    R.screamed(data, period)
    return data.carpideira
end

-- Pronto pro próximo grito global? nextAt nil = nunca gritou nesta sessão.
function R.globalScreamReady(state, nowMs)
    if state == nil or state.nextAt == nil then return true end
    return (tonumber(nowMs) or 0) >= state.nextAt
end

-- Agenda o próximo grito permitido; u em [0, 1]. Devolve o gap aplicado (ms).
function R.scheduleNextScream(state, nowMs, u)
    local gap = R.screamGapMs(u)
    state.nextAt = (tonumber(nowMs) or 0) + gap
    return gap
end

-- Milissegundos até a próxima caminhada calma; u em [0, 1].
function R.walkGapMs(u)
    u = math.max(0, math.min(tonumber(u) or 0, 1))
    local span = R.WALK_GAP_MAX_MS - R.WALK_GAP_MIN_MS
    return R.WALK_GAP_MIN_MS + math.floor(u * span + 0.5)
end

-- Gap global entre gritos de Carpideira/Screamer; u em [0, 1].
function R.screamGapMs(u)
    u = math.max(0, math.min(tonumber(u) or 0, 1))
    local span = R.SCREAM_GAP_MAX_MS - R.SCREAM_GAP_MIN_MS
    return R.SCREAM_GAP_MIN_MS + math.floor(u * span + 0.5)
end

-- Volume do soluço (0..1) pela distância em tiles até o jogador local mais perto.
function R.sobVolume(d)
    if d == nil or d >= R.SOB_FAR then return 0 end
    if d <= R.SOB_NEAR then return 1 end
    return (R.SOB_FAR - d) / (R.SOB_FAR - R.SOB_NEAR)
end

local function d2(ax, ay, bx, by)
    return (ax - bx) * (ax - bx) + (ay - by) * (ay - by)
end

-- Destino aceito: mesmo andar, não chega mais perto de nenhum jogador do andar.
-- players: { { x, y, z } }.
function R.walkFair(zx, zy, zz, tx, ty, players)
    if tx == zx and ty == zy then return false end
    local floor = math.floor(zz or 0)
    for _, p in ipairs(players or {}) do
        if math.floor(p.z or 0) == floor then
            if d2(tx, ty, p.x, p.y) < d2(zx, zy, p.x, p.y) then return false end
        end
    end
    return true
end

-- Sorteia um destino em tile inteiro a WALK_DIST_MIN..MAX, que não aproxime
-- jogadores. rand: R.rng(semente); ok(x,y,z): chão aceita (nil = aceita tudo).
-- Devolve { x, y, z } ou nil.
function R.pickWalk(zx, zy, zz, players, rand, ok)
    zx, zy, zz = math.floor(zx), math.floor(zy), math.floor(zz or 0)
    for _ = 1, R.WALK_TRIES do
        local ang = rand() * 2 * math.pi
        local dist = R.WALK_DIST_MIN + math.floor(rand() * (R.WALK_DIST_MAX - R.WALK_DIST_MIN + 1))
        local tx = zx + math.floor(math.cos(ang) * dist + 0.5)
        local ty = zy + math.floor(math.sin(ang) * dist + 0.5)
        if R.walkFair(zx, zy, zz, tx, ty, players)
            and (ok == nil or ok(tx, ty, zz)) then
            return { x = tx, y = ty, z = zz }
        end
    end
    return nil
end

return NOM_CarpideiraRules
