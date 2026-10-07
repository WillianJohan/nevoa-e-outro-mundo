-- NOM_WanderRules (sprint 0036): quem perambula na névoa e pra onde. Regra pura.
local function load()
    package.loaded.NOM_WanderRules, NOM_WanderRules = nil, nil
    require "NOM_WanderRules"
    return NOM_WanderRules
end

local function d2(ax, ay, bx, by) return (ax - bx) * (ax - bx) + (ay - by) * (ay - by) end

-- distância do ponto ao segmento, pra conferir sem confiar na conta da regra
local function segDist(px, py, ax, ay, bx, by)
    local best = math.huge
    for k = 0, 200 do
        local t = k / 200
        best = math.min(best, math.sqrt(d2(px, py, ax + (bx - ax) * t, ay + (by - ay) * t)))
    end
    return best
end

-- zumbis em volta do jogador, de 0 a 40 tiles, sorteados pelo rng do teste
local function crowd(R, seed, n, px, py)
    local rand = R.rng(seed)
    local out = {}
    for i = 1, n do
        local a, r = rand() * 2 * math.pi, rand() * 40
        out[i] = { x = math.floor(px + math.cos(a) * r), y = math.floor(py + math.sin(a) * r), z = 0 }
    end
    return out
end

return {
    wander_gap_in_range = function()
        local R = load()
        assert(R.gap(0) == R.MIN_GAP and R.gap(0.9999) == R.MAX_GAP, R.gap(0) .. " " .. R.gap(0.9999))
        assert(R.gap(-1) == R.MIN_GAP and R.gap(2) == R.MAX_GAP, "fora de [0, 1) escapou")
    end,
    -- critério: grupos de 1 a 3, todos os tamanhos aparecem
    wander_group_sizes_one_to_three = function()
        local R = load()
        local seen = {}
        for seed = 1, 200 do
            local zs = crowd(R, seed, 60, 100, 100)
            local plan = R.plan({ { x = 100, y = 100, z = 0 } }, zs, R.rng(seed * 7))
            assert(#plan <= R.GROUP_MAX, "grupo grande: " .. #plan)
            seen[#plan] = true
        end
        assert(seen[1] and seen[2] and seen[3], "algum tamanho nunca saiu")
    end,
    -- critério: nunca direto ao jogador. O destino fica na região, longe dele, e o caminho
    -- reto não passa perto
    wander_never_toward_player = function()
        local R = load()
        local n = 0
        for seed = 1, 300 do
            local zs = crowd(R, seed, 40, 0, 0)
            for _, g in ipairs(R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(seed + 1000))) do
                local z = zs[g.i]
                local dist = math.sqrt(d2(g.x, g.y, 0, 0))
                assert(dist >= R.DEST_MIN and dist <= R.REGION_MAX, "destino a " .. dist)
                assert(segDist(0, 0, z.x, z.y, g.x, g.y) >= R.PASS_MIN - 0.01, "caminho passa perto do jogador")
                n = n + 1
            end
        end
        assert(n > 200, "quase ninguém saiu: " .. n)
    end,
    -- só quem está perto (NEAR_MIN a NEAR_MAX) e no andar do jogador
    wander_only_near_same_floor = function()
        local R = load()
        local zs = {
            { x = 2, y = 0, z = 0 },  -- perto demais: já está na visão
            { x = 60, y = 0, z = 0 }, -- longe demais
            { x = 12, y = 0, z = 1 }, -- outro andar
        }
        for seed = 1, 50 do
            assert(#R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(seed)) == 0, "pegou quem não devia")
        end
        zs[4] = { x = 12, y = 3, z = 0 }
        local any = false
        for seed = 1, 50 do
            local plan = R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(seed))
            for _, g in ipairs(plan) do
                assert(g.i == 4, "pegou o índice " .. g.i)
                any = true
            end
        end
        assert(any, "o candidato certo nunca saiu")
    end,
    -- o grupo sai junto: todos a até GROUP_RADIUS de quem puxa, e andam em formação
    wander_group_is_together = function()
        local R = load()
        for seed = 1, 100 do
            local zs = crowd(R, seed, 80, 0, 0)
            local plan = R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(seed))
            local lead = plan[1] and zs[plan[1].i]
            for _, g in ipairs(plan) do
                local z = zs[g.i]
                assert(d2(z.x, z.y, lead.x, lead.y) <= R.GROUP_RADIUS * R.GROUP_RADIUS, "longe do grupo")
            end
        end
    end,
    -- dois jogadores juntos: um grupo pra cada, ninguém em dois grupos
    wander_one_group_per_player_no_repeats = function()
        local R = load()
        for seed = 1, 100 do
            local zs = crowd(R, seed, 80, 0, 0)
            local ps = { { x = 0, y = 0, z = 0 }, { x = 2, y = 1, z = 0 } }
            local plan = R.plan(ps, zs, R.rng(seed))
            assert(#plan <= 2 * R.GROUP_MAX)
            local used = {}
            for _, g in ipairs(plan) do
                assert(not used[g.i], "zumbi em dois grupos")
                used[g.i] = true
                -- longe de todos os jogadores, não só de quem o grupo é
                for _, p in ipairs(ps) do
                    assert(math.sqrt(d2(g.x, g.y, p.x, p.y)) >= R.DEST_MIN, "destino em cima do outro jogador")
                end
            end
        end
    end,
    wander_is_deterministic = function()
        local R = load()
        local zs = crowd(R, 5, 50, 0, 0)
        local a = R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(42))
        local b = R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(42))
        assert(#a == #b and #a > 0)
        for k = 1, #a do assert(a[k].i == b[k].i and a[k].x == b[k].x and a[k].y == b[k].y) end
    end,
    -- o chão manda: ponto recusado (parede, água, fora do mapa) não vira destino
    wander_respects_floor_check = function()
        local R = load()
        local zs = crowd(R, 9, 50, 0, 0)
        assert(#R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(1), function() return false end) == 0)
        local plan = R.plan({ { x = 0, y = 0, z = 0 } }, zs, R.rng(1), function(x) return x > 0 end)
        for _, g in ipairs(plan) do assert(g.x > 0, "destino recusado") end
    end,
    wander_empty_inputs = function()
        local R = load()
        assert(#R.plan({}, { { x = 10, y = 0, z = 0 } }, R.rng(1)) == 0)
        assert(#R.plan({ { x = 0, y = 0, z = 0 } }, {}, R.rng(1)) == 0)
    end,
}
