-- Sonar do Estalador (sprint 0037): a regra pura (shared/NOM_SonarRules.lua).
require "NOM_SonarRules"
local R = NOM_SonarRules

local function near(a, b) return math.abs(a - b) < 1e-9 end

return {
    -- 8 tiles em 1,5 s reais, linear, preso em 8 depois
    sonar_radius_in_time = function()
        assert(R.RANGE == 8 and R.DURATION_MS == 1500)
        assert(R.radius(0) == 0 and R.radius(-5) == 0)
        assert(near(R.radius(750), 4))
        assert(R.radius(1500) == 8 and R.radius(9000) == 8)
        assert(not R.done(1499) and R.done(1500))
    end,

    -- o anel passa por quem está entre o raio do tick anterior e o de agora; no primeiro
    -- tick (r0 nil), quem está no centro conta
    sonar_crossed_between_ticks = function()
        assert(R.crossed(0, nil, 0.1), "no centro, no primeiro tick")
        assert(R.crossed(9, 2, 3) and not R.crossed(9, 3, 4), "d = 3 cruza em 2→3, não em 3→4")
        assert(not R.crossed(4, 2.5, 3), "já tinha passado")
        assert(not R.crossed(64.01, 7, 8), "fora do alcance")
        assert(R.crossed(64, 7, 8), "na borda dos 8 tiles")
    end,

    -- quem anda na direção do anel não pula a frente entre dois ticks: estava fora do raio
    -- anterior (p2, posição do tick anterior) e agora está dentro do novo: cruzou
    sonar_crossed_uses_previous_position = function()
        assert(not R.crossed(2.9 ^ 2, 3, 3.1), "sem a posição anterior, pulou a frente")
        assert(R.crossed(2.9 ^ 2, 3, 3.1, 3.05 ^ 2), "cruzou a frente andando pra dentro")
        assert(not R.crossed(2.9 ^ 2, 3, 3.1, 2.95 ^ 2), "já estava dentro")
        assert(not R.crossed(3.5 ^ 2, 3, 3.1, 3.6 ^ 2), "ainda fora")
        local ring = { x = 0, y = 0, z = 0 }
        local a = R.sweep(ring, 3, 3.1, { { x = 2.9, y = 0, z = 0, px = 3.05, py = 0 } })
        assert(#a == 1, "o sweep não usa a posição anterior")
    end,

    -- casa protege (decisão do Johan, 2026-10-06): um dentro e o outro fora, o anel não acha;
    -- os dois fora, ou os dois na mesma casa, acha. Casas diferentes: não acha. Sem square
    -- (nil): não sabe, não protege.
    sonar_sheltered_by_house = function()
        local A, B = {}, {}
        assert(R.sheltered(true, A, false, nil), "jogador em casa, Estalador na rua")
        assert(R.sheltered(false, nil, true, A), "jogador na rua, Estalador em casa")
        assert(not R.sheltered(false, nil, false, nil), "os dois na rua")
        assert(not R.sheltered(true, A, true, A), "os dois na mesma casa")
        assert(R.sheltered(true, A, true, B), "casas diferentes")
        assert(not R.sheltered(nil, nil, false, nil) and not R.sheltered(true, A, nil, nil), "sem square")
    end,

    -- em pé ou andando: achado; agachado e parado: passa
    sonar_exposed_standing_or_moving = function()
        assert(R.exposed(false, false), "em pé parado")
        assert(R.exposed(false, true), "andando em pé")
        assert(R.exposed(true, true), "agachado andando")
        assert(not R.exposed(true, false), "agachado e parado passa")
    end,

    -- andando = deslocou pelo menos MOVE_EPS entre as amostras
    sonar_moving_by_displacement = function()
        assert(not R.moving(10, 10, 10, 10))
        assert(not R.moving(10, 10, 10.05, 10.05), "jitter de rede")
        assert(R.moving(10, 10, 10.2, 10))
        assert(not R.moving(nil, nil, 10, 10), "sem amostra: parado")
    end,

    -- quem o anel cruza neste tick, só no mesmo andar (o anel não sobe escada)
    sonar_sweep_same_floor = function()
        local ring = { x = 100.5, y = 100.5, z = 0 }
        local players = {
            { x = 103.5, y = 100.5, z = 0 },    -- d = 3
            { x = 103.5, y = 100.5, z = 1 },    -- outro andar
            { x = 100.5, y = 106.5, z = 0.6 },  -- d = 6, escada no andar 0
            { x = 110.5, y = 100.5, z = 0 },    -- d = 10, fora
        }
        local a = R.sweep(ring, 2, 4, players)
        assert(#a == 1 and a[1] == 1, "tick 2→4: " .. #a)
        local b = R.sweep(ring, 4, 8, players)
        assert(#b == 1 and b[1] == 3)
        assert(#R.sweep(ring, 8, 8, players) == 0, "parado em 8 não cruza ninguém de novo")
    end,

    -- ritmo (decisão do Johan, 2026-10-06): intervalo aleatório de 5 a 30 s reais, sorteado a
    -- cada estalo; roll = ZombRand(GAP_ROLL), inteiro em [0, GAP_ROLL)
    sonar_click_gap = function()
        assert(R.GAP_MIN_MS == 5000 and R.GAP_MAX_MS == 30000)
        assert(R.GAP_ROLL == R.GAP_MAX_MS - R.GAP_MIN_MS + 1)
        assert(R.gap(0) == 5000 and R.gap(R.GAP_ROLL - 1) == 30000)
        assert(R.gap(12345) == 17345)
        assert(R.gap(-3) == 5000 and R.gap(99999) == 30000, "sorteio fora da faixa é preso")
        assert(R.CLICK_ODDS == nil and R.clicks == nil, "o sorteio por minuto de jogo saiu")
    end,

    -- teto de anéis: anel cujo jogador mais perto (mesmo andar) está além de REACH não acha
    -- ninguém (nem quem corre na direção dele: a frente chega em RANGE em DURATION_MS)
    sonar_reach_for_cap = function()
        assert(R.REACH >= R.RANGE + R.DURATION_MS / 1000 * 5.3, "REACH curto pra quem corre: " .. R.REACH)
        assert(R.REACH < R.SEND_RANGE, "REACH tem que deixar anel anunciado de fora")
        local players = { { x = 0, y = 0, z = 0 }, { x = 3, y = 0, z = 1 } }
        assert(R.nearest2(10, 0, 0, players) == 100)
        assert(R.nearest2(3, 0, 1, players) == 0, "outro andar")
        assert(R.nearest2(3, 0, 2, players) == math.huge, "ninguém no andar")
    end,

    -- o anel vai só a quem está a até SEND_RANGE, em qualquer andar (o estalo se ouve)
    sonar_hears = function()
        assert(R.hears(0, 0, R.SEND_RANGE, 0) and not R.hears(0, 0, R.SEND_RANGE + 0.1, 0))
        assert(R.hears(100, 100, 120, 120))
    end,

    -- só estala na rede com jogador perto, no mesmo andar
    sonar_near_player = function()
        local players = { { x = 0, y = 0, z = 0 }, { x = 30, y = 0, z = 1 } }
        assert(R.near(10, 0, 0, players))
        assert(not R.near(50, 0, 0, players), "longe de todos")
        assert(not R.near(30, 0, 0, { players[2] }), "outro andar")
    end,

    -- a mensagem do servidor é conferida antes de desenhar
    sonar_valid_message = function()
        local m = R.valid({ x = 100.5, y = 200.5, z = 0, id = 7 })
        assert(m and m.x == 100.5 and m.y == 200.5 and m.z == 0 and m.id == 7)
        assert(R.valid({ x = 100, y = 200, z = -1 }).id == -1, "sem id: anel sem Estalador")
        assert(R.valid(nil) == nil and R.valid("x") == nil)
        assert(R.valid({ x = "1", y = 2, z = 0 }) == nil)
        assert(R.valid({ x = 0 / 0, y = 2, z = 0 }) == nil, "NaN")
        assert(R.valid({ x = 1 / 0, y = 2, z = 0 }) == nil, "infinito")
        assert(R.valid({ x = 1, y = 2, z = 0.5 }) == nil, "andar quebrado")
        assert(R.valid({ x = 1, y = 2, z = 99 }) == nil, "andar fora")
        assert(R.valid({ x = -5, y = 2, z = 0 }) == nil, "fora do mapa")
        assert(R.valid({ x = 1, y = 2, z = 0, id = "a" }) == nil)
        local f = R.validFound({ id = 7, pl = 3 })
        assert(f and f.id == 7 and f.pl == 3)
        assert(R.validFound({ id = 7 }) == nil and R.validFound({ id = -1, pl = 3 }) == nil)
        assert(R.validFound({ id = 7, pl = 0 / 0 }) == nil)
        assert(R.validFound({ id = 7, pl = 3, pid = 99 }).pid == 99, "persistentOutfitID")
        assert(R.validFound({ id = 7, pl = 3, pid = "x" }) == nil)
    end,

    -- visual: sobe rápido, segura na expansão e some em FADE_MS depois do fim
    sonar_alpha_curve = function()
        assert(R.alpha(0) == 0, "nasce invisível")
        assert(near(R.alpha(750), R.ALPHA), "no meio, inteiro")
        assert(R.alpha(R.DURATION_MS + R.FADE_MS / 2) < R.ALPHA)
        assert(R.alpha(R.DURATION_MS + R.FADE_MS) == 0, "acabou")
        assert(R.alpha(-1) == 0)
        assert(R.ALPHA <= 0.4, "discreto")
    end,

    -- No chão isométrico o círculo de raio r vira elipse 2:1; a ponta da direita é o ponto
    -- (x + r/√2, y − r/√2). A textura tem a frente em TEX_RING da meia-largura, então o
    -- retângulo cresce pra frente cair na ponta projetada.
    sonar_screen_rect = function()
        local x, y, w, h = R.rect(500, 300, 600)
        assert(near(w, 2 * 100 / R.TEX_RING) and near(h, w / 2), "2:1")
        assert(near(x, 500 - w / 2) and near(y, 300 - h / 2), "centrado")
        assert(near(x + w / 2 + R.TEX_RING * w / 2, 600), "frente na ponta")
        assert(R.rect(500, 300, 500) == nil, "raio zero")
        local o = 1 / math.sqrt(2)
        local ox, oy = R.edge(10, 20, 4)
        assert(near(ox, 10 + 4 * o) and near(oy, 20 - 4 * o))
    end,

    -- a janela anti-recegueira cobre o tempo de o Estalador chegar: 8 tiles a ~1 tile/s
    sonar_found_window_covers_walk = function()
        assert(R.FOUND_MS >= R.RANGE * 1000, "janela curta demais: " .. R.FOUND_MS)
    end,

    -- sprint 0048: burst clicker — 6–12 batidas em ~1–2 s, irregular, espelho do OGG
    sonar_burst_beats = function()
        local n = R.beatCount()
        assert(n >= 6 and n <= 12, "batidas: " .. n)
        assert(R.BEAT_MS[1] == 0, "primeira batida no zero")
        local last = R.BEAT_MS[n]
        assert(last >= 1000 and last <= 2000, "burst em ~1–2 s: " .. last)
        for i = 2, n do
            assert(R.BEAT_MS[i] > R.BEAT_MS[i - 1], "batidas fora de ordem em " .. i)
            local gap = R.BEAT_MS[i] - R.BEAT_MS[i - 1]
            assert(gap >= 40 and gap <= 400, "intervalo interno " .. gap)
        end
        assert(R.MAX_RIPPLES >= n * 3, "teto curto pra vários Estaladores")
        assert(R.MAX_RINGS == 8, "find ainda é um anel por burst no servidor")
    end,

    -- ripples curtos de presença (não substituem o anel de achado)
    sonar_ripple_curve = function()
        assert(R.RIPPLE_RANGE == 3 and R.RIPPLE_DURATION_MS == 550)
        assert(R.rippleRadius(0) == 0 and R.rippleRadius(-1) == 0)
        assert(near(R.rippleRadius(275), 1.5))
        assert(R.rippleRadius(550) == 3 and R.rippleRadius(9000) == 3)
        assert(not R.rippleDone(550) and R.rippleDone(550 + R.RIPPLE_FADE_MS))
        assert(R.rippleAlpha(0) == 0)
        assert(near(R.rippleAlpha(275), R.RIPPLE_ALPHA))
        assert(R.rippleAlpha(R.RIPPLE_DURATION_MS + R.RIPPLE_FADE_MS) == 0)
        assert(R.RIPPLE_ALPHA <= 0.12, "ripple bem sutil (0053): " .. R.RIPPLE_ALPHA)
        assert(R.SCREEN_DRAW == false, "0053: sem anel na tela por padrão")
    end,

    -- gen_sounds.py declara os mesmos offsets (CLICK_BEATS_MS)
    sonar_beats_match_gen_sounds = function()
        local f = assert(io.open("scripts/gen_sounds.py"))
        local s = f:read("*a")
        f:close()
        local list = s:match("CLICK_BEATS_MS%s*=%s*%[([^%]]+)%]")
        assert(list, "gen_sounds sem CLICK_BEATS_MS")
        local beats = {}
        for n in list:gmatch("%d+") do beats[#beats + 1] = tonumber(n) end
        assert(#beats == #R.BEAT_MS, "contagem: lua=" .. #R.BEAT_MS .. " py=" .. #beats)
        for i = 1, #beats do
            assert(beats[i] == R.BEAT_MS[i], "beat " .. i .. ": " .. beats[i] .. " ≠ " .. R.BEAT_MS[i])
        end
    end,
}
