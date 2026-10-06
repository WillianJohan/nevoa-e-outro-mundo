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
    fog_event_rules_siren_is_45_seconds = function()
        assert(R.SIREN_MS == 45000)
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
    -- save antigo: a sirene já agendada vale pelo dia, sem sorteio novo
    fog_event_rules_pending_counts_for_day = function()
        local s = { seed = SEED, bornAt = 0, next = 300 }
        R.update(s, 240, cfg(), seq(0))
        assert(s.next == 300 and s.day == 10)
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
        R.cancel(s)
        assert(s.next == nil)
    end,
    -- vermelha: 0 antes da carência, a chance do sandbox depois (sem a subida da 0019)
    fog_event_rules_red_grace_only = function()
        local c = cfg({ escalation = true })
        assert(R.redChance(20, c, 6.99) == 0 and R.redChance(20, c, 7) == 20 and R.redChance(20, c, 90) == 20)
    end,
    fog_event_rules_siren_dir = function()
        local d = R.sirenDir(SEED, 3)
        assert(d >= 0 and d < 360 and d == R.sirenDir(SEED, 3) and d ~= R.sirenDir(SEED, 4))
    end,
    fog_event_rules_closes_stale_0008_save = function()
        local s = { night = 4, inNight = true, seed = SEED, bornAt = 0 }
        R.update(s, 100, cfg(), seq(0))
        assert(s.inNight == false and s.night == 4)
    end,
    fog_event_rules_countdown_pauses_and_caps = function()
        assert(R.countdown(45000, 16, false) == 44984)
        assert(R.countdown(45000, 16, true) == 45000, "pausado contou")
        assert(R.countdown(45000, 10000, false) == 45000 - R.MAX_STEP_MS, "travada comeu a sirene")
        assert(R.countdown(45000, -5, false) == 45000, "relógio voltou")
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
}
