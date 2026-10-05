-- Regras puras da Carpideira (sprint 0011): sem API do jogo, testável com
-- ./run-tests.sh. Quem é Carpideira sai do sorteio da névoa (NOM_VariantRules);
-- aqui fica o que acorda ela e a memória de quem já gritou.
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
}

local R = NOM_CarpideiraRules

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
-- salvar e carregar no meio não deixa gritar de novo.
function R.screamed(data, period)
    local s = data.carpideira
    if not s or s.period ~= period then
        s = { period = period, pids = {} }
        data.carpideira = s
    end
    return s.pids
end

return NOM_CarpideiraRules
