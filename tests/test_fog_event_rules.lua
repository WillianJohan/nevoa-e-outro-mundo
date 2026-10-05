-- Regras puras do evento de névoa (shared/NOM_FogEventRules.lua).
require "NOM_FogEventRules"
local R = NOM_FogEventRules

-- rand() que devolve a sequência dada, em ciclo
local function seq(...)
    local v, i = { ... }, 0
    return function()
        i = i + 1
        return v[(i - 1) % #v + 1]
    end
end

local cfg = { everyDays = 3, minHours = 2, maxHours = 6 }

return {
    -- intervalo entre 0,5× e 1,5× do configurado, média = o configurado
    fog_event_rules_gap_within_bounds = function()
        assert(R.gapHours(3, 0) == 36, "mínimo")
        assert(math.abs(R.gapHours(3, 0.999999) - 108) < 1e-3, "máximo")
        local sum, n = 0, 1000
        for i = 0, n - 1 do
            local g = R.gapHours(3, (i + 0.5) / n)
            assert(g >= 36 and g < 108)
            sum = sum + g
        end
        assert(math.abs(sum / n - 72) < 1e-6, "média ≠ 3 dias: " .. sum / n)
    end,
    fog_event_rules_duration_within_bounds = function()
        assert(R.durationHours(2, 6, 0) == 2 and R.durationHours(2, 6, 0.5) == 4)
        assert(R.durationHours(2, 6, 0.999999) < 6)
        assert(R.durationHours(6, 2, 0) == 2 and R.durationHours(6, 2, 0.5) == 4, "min > max não troca")
        assert(R.durationHours(3, 3, 0.7) == 3)
    end,
    -- primeira leitura agenda; passou da hora, pede sirene até o evento começar
    fog_event_rules_schedules_then_sirens = function()
        local s = {}
        assert(R.update(s, 10, cfg, seq(0.5)) == nil and s.next == 10 + 72)
        assert(R.update(s, 81.9, cfg, seq(0.5)) == nil)
        assert(R.update(s, 82, cfg, seq(0.5)) == "siren")
        assert(R.update(s, 83, cfg, seq(0.5)) == "siren", "pedido de sirene sumiu antes do evento")
        assert(s.next == 82, "reagendou sem evento")
    end,
    -- período conta uma vez por evento; evento dentro de evento não existe
    fog_event_rules_period_once_per_event = function()
        local s = { next = 0 }
        assert(R.start(s, 5, cfg, seq(0.25)) and s.night == 1 and s.inNight and s.endAt == 8)
        assert(not R.start(s, 6, cfg, seq(0)), "evento dentro de evento")
        assert(s.night == 1 and s.endAt == 8)
        assert(R.update(s, 7.9, cfg, seq(0)) == nil and s.inNight)
        assert(R.update(s, 8, cfg, seq(0)) == "end")
        assert(not s.inNight and s.endAt == nil and s.next == 8 + 36, "próximo conta do fim")
        assert(R.update(s, 9, cfg, seq(0)) == nil, "fim avisado duas vezes")
        R.start(s, 50, cfg, seq(0))
        assert(s.night == 2)
    end,
    -- save da sprint 0008 com a névoa natural aberta: fecha sem contar e agenda
    fog_event_rules_closes_stale_0008_save = function()
        local s = { night = 4, inNight = true }
        assert(R.update(s, 100, cfg, seq(0)) == nil)
        assert(s.inNight == false and s.night == 4 and s.next == 136)
    end,
    -- pausado não conta; travada longa (ou volta da pausa) conta no máximo MAX_STEP_MS
    fog_event_rules_countdown_pauses_and_caps = function()
        assert(R.countdown(30000, 16, false) == 29984)
        assert(R.countdown(30000, 16, true) == 30000, "pausado contou")
        assert(R.countdown(30000, 10000, false) == 30000 - R.MAX_STEP_MS, "travada comeu a sirene")
        assert(R.countdown(30000, -5, false) == 30000, "relógio voltou")
    end,
    fog_event_rules_config_reads_sandbox = function()
        local t = { FogEventEveryDays = 1, FogMinHours = 3, FogMaxHours = 4, FogEscalation = false, RedFogGraceDays = 9 }
        local c = R.config(function(k) return t[k] end)
        assert(c.everyDays == 1 and c.minHours == 3 and c.maxHours == 4)
        assert(c.escalation == false and c.redGraceDays == 9, "opções da curva (sprint 0019)")
    end,
    -- névoa vermelha (sprint 0010): o start guarda o que a sirene decidiu, o stop limpa
    fog_event_rules_start_stores_red = function()
        local s = { next = 0 }
        assert(R.start(s, 5, cfg, seq(0), true) and s.red == true)
        assert(not R.start(s, 6, cfg, seq(0), false) and s.red == true, "evento dentro de evento mexeu no vermelho")
        R.stop(s, 7, cfg, seq(0))
        assert(s.red == nil)
        R.start(s, 50, cfg, seq(0))
        assert(s.red == false)
    end,
    -- curva de tensão (sprint 0019) -----------------------------------------------

    -- dias desde o nascimento do save (bornAt, horas de mundo); sem bornAt = 0
    fog_event_rules_days_since_born = function()
        assert(R.days({ bornAt = 100 }, 148) == 2)
        assert(R.days({}, 500) == 0, "sem bornAt")
        assert(R.days({ bornAt = 100 }, 90) == 0, "relógio antes do nascimento")
    end,
    -- critério 1: base 2 com a escalada, dia 0 → 3 dias de média (gap 1,5–4,5 dias);
    -- dia 30 → 2; dia 45 em diante → 1,5 (gap 0,75–2,25 dias)
    fog_event_rules_interval_curve = function()
        local c = { everyDays = 2, escalation = true }
        assert(R.everyDays(c, 0) == 3 and R.everyDays(c, 30) == 2)
        assert(R.everyDays(c, 45) == 1.5 and R.everyDays(c, 200) == 1.5)
        for _, d in ipairs({ 0, 45, 300 }) do
            local lo, hi = R.gapHours(R.everyDays(c, d), 0), R.gapHours(R.everyDays(c, d), 0.999999)
            local wlo, whi = d == 0 and 36 or 18, d == 0 and 108 or 54
            assert(lo == wlo and math.abs(hi - whi) < 1e-3, "dia " .. d .. ": " .. lo .. "–" .. hi)
        end
    end,
    -- vermelha: 0 antes da carência; 1× até o dia 30; sobe linear até 2× no dia 90
    fog_event_rules_red_curve = function()
        local c = { escalation = true, redGraceDays = 7 }
        assert(R.redChance(10, c, 6.99) == 0, "vermelha na carência")
        assert(R.redChance(10, c, 7) == 10 and R.redChance(10, c, 30) == 10)
        assert(R.redChance(10, c, 60) == 15 and R.redChance(10, c, 90) == 20)
    end,
    -- sono de meses: o fator não passa de 0,75 nem a chance de 2× (nem fica negativo)
    fog_event_rules_escalation_clamps = function()
        local c = { everyDays = 2, escalation = true, redGraceDays = 0 }
        for _, d in ipairs({ 90, 365, 10000 }) do
            assert(R.everyDays(c, d) == 1.5, "intervalo no dia " .. d)
            assert(R.redChance(10, c, d) == 20, "chance no dia " .. d)
        end
        assert(R.everyDays(c, 0) == 3 and R.redChance(10, c, 0) == 10, "começo")
    end,
    -- critério 4: sem a escalada, os números do sandbox valem em qualquer dia; a
    -- carência é opção própria e vale com ou sem ela (0 desliga)
    fog_event_rules_escalation_off_is_flat = function()
        local c = { everyDays = 2, escalation = false, redGraceDays = 0 }
        for _, d in ipairs({ 0, 30, 90, 1000 }) do
            assert(R.everyDays(c, d) == 2 and R.redChance(10, c, d) == 10, "dia " .. d)
        end
        c.redGraceDays = 7
        assert(R.redChance(10, c, 3) == 0 and R.redChance(10, c, 90) == 10, "carência sem escalada")
    end,
    -- o intervalo é sorteado no fim do evento com o fator daquele dia e salvo no next;
    -- a primeira agenda (save novo) usa o dia de agora
    fog_event_rules_stop_uses_curve = function()
        local c = { everyDays = 2, minHours = 3, maxHours = 6, escalation = true }
        local s = { bornAt = 0 }
        R.stop(s, 45 * 24, c, seq(0))
        assert(s.next == 45 * 24 + 18, "next no dia 45: " .. tostring(s.next))
        s = { bornAt = 0 }
        assert(R.update(s, 0, c, seq(0)) == nil and s.next == 36, "primeira agenda no dia 0")
    end,
}
