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

    -- sprint 0052: intervalo da caminhada calma em 20–60 s reais
    carpideira_rules_walk_gap_ms = function()
        assert(R.walkGapMs(0) == R.WALK_GAP_MIN_MS)
        assert(R.walkGapMs(1) == R.WALK_GAP_MAX_MS)
        local mid = R.walkGapMs(0.5)
        assert(mid > R.WALK_GAP_MIN_MS and mid < R.WALK_GAP_MAX_MS)
    end,

    -- volume do soluço sobe perto (curva do Sem-rosto)
    carpideira_rules_sob_volume = function()
        assert(R.sobVolume(nil) == 0 and R.sobVolume(R.SOB_FAR) == 0)
        assert(R.sobVolume(R.SOB_NEAR) == 1)
        local mid = R.sobVolume((R.SOB_NEAR + R.SOB_FAR) / 2)
        assert(mid > 0 and mid < 1)
        assert(R.sobVolume(R.SOB_NEAR - 1) == 1)
    end,

    -- destino da caminhada não aproxima o jogador
    carpideira_rules_pick_walk_away_from_player = function()
        local players = { { x = 10, y = 0, z = 0 } }
        local rand = R.rng(42)
        local d = R.pickWalk(0, 0, 0, players, rand, nil)
        assert(d, "não sorteou destino")
        local before = (10 - 0) * (10 - 0)
        local after = (10 - d.x) * (10 - d.x) + (0 - d.y) * (0 - d.y)
        assert(after >= before, "andou na direção do jogador: " .. d.x .. "," .. d.y)
        assert(not R.walkFair(0, 0, 0, 5, 0, players), "indo pra cima do jogador valeu")
        assert(R.walkFair(0, 0, 0, -4, 0, players), "afastar falhou")
    end,

    -- 0064 K3: getup 2c pronto / timeout fallback B
    carpideira_rules_getup_done = function()
        local ok, why = R.getupDone("zombie.ai.states.ZombieOnGroundState", false, 100)
        assert(not ok, "OnGround ainda não")
        ok, why = R.getupDone("zombie.ai.states.ZombieGetUpState", false, 100)
        assert(not ok, "GetUp ainda não")
        ok, why = R.getupDone("zombie.ai.states.WalkTowardState", true, 100)
        assert(not ok, "ainda crawling")
        ok, why = R.getupDone("zombie.ai.states.WalkTowardState", false, 100)
        assert(ok and why == "stood", "de pé: " .. tostring(why))
        ok, why = R.getupDone("zombie.ai.states.ZombieOnGroundState", true, R.GETUP_TIMEOUT_MS)
        assert(ok and why == "timeout", "fallback B: " .. tostring(why))
    end,
}
