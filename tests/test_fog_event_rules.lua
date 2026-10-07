-- Regras puras do evento de névoa (shared/NOM_FogEventRules.lua), agenda por dia
-- da sprint 0033 (spec do modelo novo §2).
require "NOM_FogEventRules"
local R = NOM_FogEventRules

local function seq(...)
    local v, i = { ... }, 0
    return function()
        i = i + 1
        return v[(i - 1) % #v + 1]
    end
end

local SEED = 4242
-- Agenda que sempre tem névoa e nunca segunda, sem curva: os testes do mecanismo
-- ligam o que medem.
local function cfg(over)
    local c = { dailyChance = 100, maxDailyChance = 100, escalationDays = 60, escalation = false,
        secondChance = 0, minGapHours = 6, maxDaysWithout = 2, minHours = 3, maxHours = 5,
        redMinHours = 4, redMaxHours = 6, redGraceDays = 7, calmHours = 2 }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

return {
    -- sprint 0034: a contagem é a fuga de 30 s (o som da sirene dura 15 s e não conta)
    fog_event_rules_grace_is_30_seconds = function()
        assert(R.GRACE_MS == 30000)
        assert(R.SIREN_MS == nil, "sobrou a constante velha")
    end,
    -- sprint 0034: o presságio (estática na tela) vem 3 s reais antes da sirene
    fog_event_rules_presage_is_3_seconds = function()
        assert(R.PRESAGE_MS == 3000)
    end,
    -- 65% subindo em linha reta até 85% no dia 60, fixo depois; sem curva, o sandbox
    fog_event_rules_day_chance_curve = function()
        local c = cfg({ dailyChance = 65, maxDailyChance = 85, escalation = true })
        assert(R.dayChance(c, 0) == 65 and R.dayChance(c, 30) == 75 and R.dayChance(c, 60) == 85)
        assert(R.dayChance(c, 365) == 85, "passou do teto")
        c.escalation = false
        assert(R.dayChance(c, 0) == 65 and R.dayChance(c, 90) == 65, "sem curva")
        c.escalation, c.escalationDays = true, 0
        assert(R.dayChance(c, 0) == 85, "curva de 0 dias é o teto")
    end,
    fog_event_rules_frac_deterministic = function()
        local a = R.frac(SEED, 10, 1)
        assert(a >= 0 and a < 1 and a == R.frac(SEED, 10, 1))
        assert(a ~= R.frac(SEED, 11, 1) and a ~= R.frac(SEED, 10, 2), "dia e sal mudam o sorteio")
    end,
    -- a primeira do dia cai no dia; se a hora já passou (save carregado no meio do
    -- dia), vai pra parte que sobra do dia, na mesma proporção
    fog_event_rules_first_start_in_day = function()
        for D = 0, 50 do
            local t = R.firstStart(SEED, D, D * 24)
            assert(t >= D * 24 and t < D * 24 + 24, "fora do dia " .. D)
            local late = R.firstStart(SEED, D, D * 24 + 20)
            assert(late >= D * 24 + 20 and late < D * 24 + 24, "antes de agora no dia " .. D)
        end
    end,
    -- dia com 100%: uma sirene no dia, planejada uma vez só
    fog_event_rules_plans_once_per_day = function()
        local s = { seed = SEED, bornAt = 0 }
        assert(R.update(s, 240.01, cfg(), seq(0)) == nil or s.next <= 240.01)
        assert(s.day == 10 and s.next == R.firstStart(SEED, 10, 240.01))
        local first = s.next
        R.update(s, 240.5, cfg(), seq(0))
        assert(s.next == first, "replanejou no mesmo dia")
    end,
    -- passou da hora: pede sirene até o evento começar
    fog_event_rules_sirens_until_start = function()
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, cfg(), seq(0))
        local t = s.next
        assert(R.update(s, t, cfg(), seq(0)) == "siren")
        assert(R.update(s, t + 0.1, cfg(), seq(0)) == "siren", "pedido sumiu antes do evento")
    end,
    -- garantia: 2 dias seguidos sem névoa, o 3º tem com certeza
    fog_event_rules_guarantee_third_day = function()
        local c = cfg({ dailyChance = 0, maxDailyChance = 0 })
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        assert(s.next == nil and s.daysWithout == 0, "dia 10")
        R.update(s, 264, c, seq(0))
        assert(s.next == nil and s.daysWithout == 1, "dia 11")
        R.update(s, 288, c, seq(0))
        assert(s.next ~= nil and s.daysWithout == 2, "dia 12 sem a garantia")
    end,
    -- dias pulados (servidor parado, sono) contam como dias sem névoa
    fog_event_rules_skipped_days_count = function()
        local c = cfg({ dailyChance = 0, maxDailyChance = 0 })
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        R.update(s, 240 + 3 * 24, c, seq(0))
        assert(s.daysWithout == 3 and s.next ~= nil)
    end,
    -- dia que teve névoa zera a contagem
    fog_event_rules_fog_resets_count = function()
        local s = { seed = SEED, bornAt = 0, daysWithout = 1 }
        R.update(s, 240, cfg(), seq(0))
        R.start(s, s.next, cfg(), seq(0), false)
        assert(s.hadFog == true)
        R.update(s, 264, cfg({ dailyChance = 0, maxDailyChance = 0 }), seq(0))
        assert(s.daysWithout == 0)
    end,
    -- save antigo: a sirene já agendada que cai no dia vale pelo dia, sem sorteio novo
    fog_event_rules_pending_counts_for_day = function()
        local s = { seed = SEED, bornAt = 0, next = 255 }
        R.update(s, 240, cfg(), seq(0))
        assert(s.next == 255 and s.day == 10)
    end,
    -- review final da 0033 (I3): a marcada pra depois do dia sai e o dia sorteia
    fog_event_rules_pending_after_day_is_dropped = function()
        local s = { seed = SEED, bornAt = 0, next = 300 }
        R.update(s, 240, cfg({ dailyChance = 0, maxDailyChance = 0 }), seq(0))
        assert(s.next == nil and s.day == 10, "next: " .. tostring(s.next))
        local t = { seed = SEED, bornAt = 0, next = 300 }
        R.update(t, 240, cfg({ dailyChance = 100, maxDailyChance = 100 }), seq(0))
        assert(t.next ~= nil and R.dayOf(t.next) == 10, "o dia não sorteou: " .. tostring(t.next))
    end,
    -- duração pelo tipo: branca 3–5, vermelha 4–6
    fog_event_rules_duration_by_kind = function()
        local s = { seed = SEED }
        assert(R.start(s, 10, cfg(), seq(0), false) and s.endAt == 13 and s.red == false)
        R.stop(s, 13, cfg())
        assert(R.start(s, 20, cfg(), seq(0.5), true) and s.endAt == 25 and s.red == true)
        assert(not R.start(s, 21, cfg(), seq(0), false), "evento dentro de evento")
    end,
    -- fim: calmaria de calmHours e folga mínima pra próxima
    fog_event_rules_stop_sets_calm = function()
        local s = { seed = SEED }
        R.start(s, 241, cfg(), seq(0), false)
        assert(not R.calm(s, 242), "calmaria durante a névoa")
        R.stop(s, 245, cfg())
        assert(s.lastEnd == 245 and s.calmUntil == 247 and s.red == nil and not s.inNight)
        assert(R.calm(s, 246) and not R.calm(s, 247))
        R.stop(s, 250, cfg({ calmHours = 0 }))
        assert(not R.calm(s, 250), "calmaria 0 desliga")
    end,
    -- segunda névoa: depois de minGap, começando antes da meia-noite
    fog_event_rules_second_after_gap = function()
        local c = cfg({ secondChance = 100 })
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        assert(s.wantSecond == true)
        R.start(s, 241, c, seq(0), false)
        R.stop(s, 250, c)
        assert(s.next >= 256 and s.next < 264, "segunda fora da janela: " .. tostring(s.next))
        assert(s.wantSecond == false)
        -- sem espaço no dia: não tem segunda
        s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, c, seq(0))
        R.start(s, 241, c, seq(0), false)
        R.stop(s, 259, c)
        assert(s.next == nil, "segunda sem caber no dia")
    end,
    -- névoa que cruza a meia-noite: a do dia seguinte respeita a folga
    fog_event_rules_gap_after_midnight_fog = function()
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, cfg(), seq(0))
        R.start(s, 262, cfg(), seq(0), false) -- até 265
        assert(R.update(s, 264.5, cfg(), seq(0)) == nil)
        assert(R.update(s, 265, cfg(), seq(0)) == "end")
        assert(s.day == 11 and s.next ~= nil and s.next >= 271, "sem folga depois da névoa da véspera")
    end,
    -- cancelar a sirene (debug) tira a pendente
    fog_event_rules_cancel_clears_next = function()
        local s = { seed = SEED, bornAt = 0 }
        R.update(s, 240, cfg(), seq(0))
        s.red = true -- a cor decidida na sirene cancelada também sai
        R.cancel(s)
        assert(s.next == nil and s.red == nil)
    end,
    -- vermelha: 0 antes da carência, a chance do sandbox depois (sem a subida da 0019)
    fog_event_rules_red_grace_only = function()
        local c = cfg({ escalation = true })
        assert(R.redChance(20, c, 6.99) == 0 and R.redChance(20, c, 7) == 20 and R.redChance(20, c, 90) == 20)
    end,
    fog_event_rules_closes_stale_0008_save = function()
        local s = { night = 4, inNight = true, seed = SEED, bornAt = 0 }
        R.update(s, 100, cfg(), seq(0))
        assert(s.inNight == false and s.night == 4)
    end,
    fog_event_rules_countdown_pauses_and_caps = function()
        assert(R.countdown(R.GRACE_MS, 16, false) == R.GRACE_MS - 16)
        assert(R.countdown(R.GRACE_MS, 16, true) == R.GRACE_MS, "pausado contou")
        assert(R.countdown(R.GRACE_MS, 10000, false) == R.GRACE_MS - R.MAX_STEP_MS, "travada comeu a sirene")
        assert(R.countdown(R.GRACE_MS, -5, false) == R.GRACE_MS, "relógio voltou")
    end,
    fog_event_rules_config_reads_sandbox = function()
        local t = { FogDailyChance = 65, FogMaxDailyChance = 85, FogEscalationDays = 60, FogEscalation = true,
            FogSecondChance = 15, FogMinGapHours = 6, FogMaxDaysWithout = 2, FogMinHours = 3, FogMaxHours = 5,
            RedFogMinHours = 4, RedFogMaxHours = 6, RedFogGraceDays = 7, FogCalmHours = 2 }
        local c = R.config(function(k) return t[k] end)
        assert(c.dailyChance == 65 and c.maxDailyChance == 85 and c.escalationDays == 60 and c.escalation == true)
        assert(c.secondChance == 15 and c.minGapHours == 6 and c.maxDaysWithout == 2)
        assert(c.minHours == 3 and c.maxHours == 5 and c.redMinHours == 4 and c.redMaxHours == 6)
        assert(c.redGraceDays == 7 and c.calmHours == 2)
    end,
    fog_event_rules_days_since_born = function()
        assert(R.days({ bornAt = 100 }, 148) == 2)
        assert(R.days({}, 500) == 0, "sem bornAt")
        assert(R.days({ bornAt = 100 }, 90) == 0, "relógio antes do nascimento")
    end,
    fog_event_rules_duration_within_bounds = function()
        assert(R.durationHours(2, 6, 0) == 2 and R.durationHours(2, 6, 0.5) == 4)
        assert(R.durationHours(6, 2, 0) == 2, "min > max não troca")
    end,
    -- preta (sprint 0038): 0 na carência, a chance do sandbox depois, desligada pelo toggle
    fog_event_rules_black_grace_and_toggle = function()
        local c = cfg({ blackOn = true, blackChance = 100, blackGraceDays = 14 })
        assert(R.blackFog(1, SEED, c, 13.99) == false, "preta na carência")
        assert(R.blackFog(1, SEED, c, 14) == true and R.blackFog(1, SEED, c, 90) == true)
        c.blackOn = false
        assert(R.blackFog(1, SEED, c, 90) == false, "preta desligada")
        c.blackOn, c.blackChance = true, 0
        assert(R.blackFog(1, SEED, c, 90) == false, "chance 0")
        assert(R.blackFog(nil, SEED, cfg({ blackOn = true, blackChance = 100 }), 90) == false, "sem período")
    end,
    -- 5% dos períodos, determinístico e sem casar com o sorteio da vermelha
    fog_event_rules_black_chance_deterministic = function()
        local c = cfg({ blackOn = true, blackChance = 5, blackGraceDays = 0 })
        local vc = { redFogOn = true, redFogChance = 20 }
        local n, both, redN = 0, 0, 0
        for p = 1, 20000 do
            local b = R.blackFog(p, SEED, c, 30)
            assert(b == R.blackFog(p, SEED, c, 30), "re-sorteou")
            local red = NOM_VariantRules.redFog(p, vc, SEED)
            if b then n = n + 1 end
            if red then redN = redN + 1 end
            if b and red then both = both + 1 end
        end
        assert(n > 850 and n < 1150, "preta em " .. n .. " de 20000")
        -- independentes: P(preta e vermelha) ≈ 5% × 20% = 1%
        assert(both > 120 and both < 280, "preta e vermelha juntas " .. both)
        assert(redN > 3700 and redN < 4300)
    end,
    -- a preta dura o que o sandbox dela manda e nunca é vermelha junto
    fog_event_rules_black_start_duration = function()
        local s = { seed = SEED, bornAt = 0 }
        local c = cfg({ blackMinHours = 2, blackMaxHours = 3 })
        assert(R.start(s, 100, c, seq(0.5), true, true))
        assert(s.black == true and s.red == false, "preta e vermelha juntas")
        assert(s.endAt == 102.5, "duração da preta " .. tostring(s.endAt))
        R.stop(s, 102.5, c)
        assert(s.black == nil and s.red == nil, "a cor ficou depois do fim")
        assert(R.start(s, 200, c, seq(0), false))
        assert(s.black == false and s.endAt == 203, "branca com a duração da preta")
    end,
    fog_event_rules_cancel_clears_black = function()
        local s = { seed = SEED, bornAt = 0, black = true, red = false, next = 10 }
        R.cancel(s)
        assert(s.black == nil and s.red == nil and s.next == nil)
    end,
    fog_event_rules_config_reads_black = function()
        local t = { BlackFogEnabled = true, BlackFogChance = 5, BlackFogGraceDays = 14, BlackFogMinHours = 2,
            BlackFogMaxHours = 3 }
        local c = R.config(function(k) return t[k] end)
        assert(c.blackOn == true and c.blackChance == 5 and c.blackGraceDays == 14)
        assert(c.blackMinHours == 2 and c.blackMaxHours == 3)
    end,
}
