-- Regras puras do dissolve (sprint 0018, ADR-016): quanto da peça está à mostra e qual
-- Alpha o personagem recebe a cada quadro. Sem API do jogo, testável com ./run-tests.sh.
-- Quem aplica é o client/NOM_Dissolve.lua.
--
-- O shader media/shaders/NOM_Dissolve.frag lê o Alpha do personagem como limiar só na
-- faixa limiar = (Alpha − BAND) / (1 − BAND): com Alpha entre BAND e 1 a peça se forma
-- ou se desfaz e o corpo, que é basicEffect e multiplica a cor pelo Alpha, fica a no
-- mínimo BAND de opacidade. Abaixo de BAND a peça não aparece (o fade vanilla de quem
-- sai da vista passa por essa faixa no começo: a peça queima antes de o corpo sumir).
NOM_DissolveRules = {
    BAND = 0.85,   -- igual ao NOM_BAND do NOM_Dissolve.frag (teste)
    MS = 1000,     -- limiar de 0 a 1: a peça inteira se forma ou se desfaz
    FADE_MS = 500, -- morte: depois da queima, o que sobra do corpo some em fade
    -- morte: depois do fade, segura o Alpha em 0 até o corpo nascer (o zumbi sai do
    -- square e o efeito acaba); soltar antes deixaria o jogo trazê-lo de volta no fim da
    -- animação. Teto pra quem nunca vira corpo e não está morto (o driver não solta um
    -- morto que ainda tem square, client/NOM_Dissolve.lua).
    HOLD_MS = 5000,
    CAP = 12,      -- efeitos ao mesmo tempo; o resto é instantâneo (névoa vermelha)
}

local R = NOM_DissolveRules

local function clamp01(v)
    return math.max(0, math.min(1, v))
end

-- Alpha do personagem pra um limiar (0 = peça sumida, 1 = inteira).
function R.alpha(t)
    return R.BAND + (1 - R.BAND) * clamp01(t)
end

-- mode: "in" (forma), "out" (desfaz) ou "death" (desfaz e o corpo some). from: o
-- limiar de partida (o de um efeito trocado no meio); sem ele, 0 no "in" e 1 nos outros.
function R.start(mode, now, from)
    if from == nil then from = mode == "in" and 0 or 1 end
    return { mode = mode, at = now, from = clamp01(from) }
end

local function elapsed(e, now)
    return math.max(0, now - e.at)
end

function R.threshold(e, now)
    local k = elapsed(e, now) / R.MS
    if e.mode == "in" then return math.min(1, e.from + k) end
    return math.max(0, e.from - k)
end

-- Alpha do quadro e se o efeito acabou.
function R.step(e, now)
    local t = R.threshold(e, now)
    if e.mode == "in" then return R.alpha(t), t >= 1 end
    if e.mode == "out" then return R.alpha(t), t <= 0 end
    local burn = e.from * R.MS
    local dt = elapsed(e, now)
    if dt < burn then return R.alpha(t), false end
    local u = (dt - burn) / R.FADE_MS
    if u >= 1 then return 0, dt >= burn + R.FADE_MS + R.HOLD_MS end
    return R.BAND * (1 - u), false
end

return NOM_DissolveRules
