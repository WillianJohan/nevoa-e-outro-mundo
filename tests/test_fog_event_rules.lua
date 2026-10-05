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
        local t = { FogEventEveryDays = 1, FogMinHours = 3, FogMaxHours = 4 }
        local c = R.config(function(k) return t[k] end)
        assert(c.everyDays == 1 and c.minHours == 3 and c.maxHours == 4)
    end,
}
