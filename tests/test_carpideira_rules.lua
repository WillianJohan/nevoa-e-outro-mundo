-- Regras puras da Carpideira (sprint 0011): o que o servidor aceita como "acordou",
-- o que é barulho alto e perto, e quem já gritou neste período de névoa.
require "NOM_CarpideiraRules"

local R = NOM_CarpideiraRules

return {
    -- proximidade: até o raio do sandbox, com folga pro atraso da rede
    carpideira_rules_woke_near = function()
        assert(R.woke("near", 4, 4, false))
        assert(R.woke("near", 4 + R.SLACK, 4, false))
        assert(not R.woke("near", 4 + R.SLACK + 0.1, 4, false), "longe demais valeu")
    end,
    -- lanterna: só acesa, e até ALERT_RANGE (com folga); o raio de proximidade não importa
    carpideira_rules_woke_light = function()
        assert(R.woke("light", 9, 4, true))
        assert(not R.woke("light", 9, 4, false), "lanterna apagada valeu")
        assert(R.woke("light", R.ALERT_RANGE + R.SLACK, 4, true))
        assert(not R.woke("light", R.ALERT_RANGE + R.SLACK + 0.1, 4, true))
    end,
    carpideira_rules_woke_rejects_unknown_reason = function()
        assert(not R.woke("noise", 0, 4, true), "barulho é do servidor, não do cliente")
        assert(not R.woke(nil, 0, 4, true))
        assert(not R.woke("near", nil, 4, true))
    end,
    -- barulho: alto (raio ≥ LOUD_RADIUS), que chega nela e nasceu a até ALERT_RANGE
    carpideira_rules_loud_noise = function()
        assert(R.loud(5, 60), "tiro perto não acordou")
        assert(not R.loud(5, 20), "tarefa de casa (raio 20) acordou")
        assert(not R.loud(R.ALERT_RANGE + 1, 200), "tiro longe acordou")
        assert(R.loud(R.ALERT_RANGE, R.LOUD_RADIUS))
    end,
    -- um grito por período: a tabela zera quando o período muda e fica no ModData
    carpideira_rules_screamed_per_period = function()
        local data = {}
        local s = R.screamed(data, 3)
        s[123] = true
        assert(R.screamed(data, 3)[123] == true, "perdeu o grito no mesmo período")
        assert(data.carpideira.period == 3)
        assert(R.screamed(data, 4)[123] == nil, "grito passou pra névoa seguinte")
        assert(R.screamed(data, nil)[123] == nil)
    end,
}
