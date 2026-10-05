-- shared/NOM_DissolveRules.lua (sprint 0018): tempo e limiar do dissolve, puro.
-- O shader NOM_Dissolve lê o Alpha do personagem como limiar só na faixa
-- (Alpha − BAND) / (1 − BAND): o corpo (basicEffect) fica a no mínimo BAND de opacidade
-- enquanto a peça se forma ou se desfaz.
require "NOM_DissolveRules"

local R = NOM_DissolveRules

local function near(a, b) return math.abs(a - b) < 1e-9 end

return {
    dissolve_rules_band = function()
        assert(near(R.alpha(0), R.BAND) and near(R.alpha(1), 1) and near(R.alpha(0.5), R.BAND + (1 - R.BAND) / 2))
        assert(near(R.alpha(-3), R.BAND) and near(R.alpha(7), 1), "fora da faixa")
        assert(R.BAND == 0.85, "a faixa do spike")
    end,

    -- "in": a peça se forma do nada (limiar 0) até inteira (1) em MS
    dissolve_rules_in = function()
        local e = R.start("in", 1000)
        local a, done = R.step(e, 1000)
        assert(near(a, R.BAND) and not done)
        a, done = R.step(e, 1000 + R.MS / 2)
        assert(near(R.threshold(e, 1000 + R.MS / 2), 0.5) and not done)
        a, done = R.step(e, 1000 + R.MS)
        assert(near(a, 1) and done)
        a, done = R.step(e, 999) -- relógio pra trás não anda pra trás
        assert(near(a, R.BAND) and not done)
    end,

    dissolve_rules_out = function()
        local e = R.start("out", 0)
        assert(near(R.step(e, 0), 1))
        assert(near(R.threshold(e, R.MS * 0.25), 0.75))
        local a, done = R.step(e, R.MS)
        assert(near(a, R.BAND) and done)
    end,

    -- troca no meio (névoa que volta): parte do limiar em que estava, no mesmo ritmo
    dissolve_rules_from_current = function()
        local out = R.start("out", 0)
        local t = R.threshold(out, R.MS * 0.3)
        local back = R.start("in", R.MS * 0.3, t)
        assert(near(R.threshold(back, R.MS * 0.3), 0.7))
        local _, done = R.step(back, R.MS * 0.3 + R.MS * 0.3)
        assert(done, "devia acabar em 0,3·MS")
    end,

    -- morte: a peça (e a casca) queimam até o limiar 0, depois o resto do corpo some
    dissolve_rules_death = function()
        local e = R.start("death", 0)
        assert(near(R.step(e, 0), 1))
        assert(near(R.step(e, R.MS), R.BAND), "fim da queima")
        local a, done = R.step(e, R.MS + R.FADE_MS / 2)
        assert(near(a, R.BAND / 2) and not done)
        a, done = R.step(e, R.MS + R.FADE_MS)
        assert(a == 0 and not done, "soltou o alfa com o Eco ainda caindo (o jogo o traria de volta)")
        assert(R.threshold(e, R.MS + R.FADE_MS) == 0)
        -- segura em 0 até o corpo nascer; um teto pra quem nunca vira corpo
        a, done = R.step(e, R.MS + R.FADE_MS + R.HOLD_MS)
        assert(a == 0 and done)
    end,

    dissolve_rules_cap_and_times = function()
        assert(R.CAP >= 4 and R.CAP <= 32, "teto: " .. tostring(R.CAP))
        assert(R.MS >= 500 and R.MS <= 2000 and R.FADE_MS > 0)
    end,
}
