-- shared/NOM_DressingRules.lua: o que cada square ganha na névoa (sprint 0015), puro.
local function load()
    _G.NOM_DressingRules = nil
    package.loaded.NOM_DressingRules = nil
    require "NOM_DressingRules"
    return NOM_DressingRules
end

-- Índices que existem no pack Tiles2x, pelo lado (recorte da textura e profundidade;
-- pz-api-notes §16). Uma regra que sorteie fora disso desenha nada no jogo.
local PACK = {
    bloodWallW = { 1, 2, 3, 8, 9, 10, 11, 16, 17, 18, 19 },
    bloodWallN = { 4, 5, 13, 14, 15, 20, 21, 22, 23 },
    grimeWallW = { 0, 4, 8, 12, 16, 20, 24, 28, 32 },
    grimeWallN = { 1, 5, 9, 13, 17, 21, 25, 29, 33 },
}

local function set(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

local function sweep(R, period, d, size)
    local n, layers, pools = 0, 0, 0
    for x = 1000, 1000 + size - 1 do
        for y = 2000, 2000 + size - 1 do
            local f = R.floor(x, y, 0, period, d)
            if f then
                n = n + 1
                layers = layers + #f
                local blood = 0
                for _, l in ipairs(f) do if l[1] == "bloodFloor" then blood = blood + 1 end end
                if blood >= 3 then pools = pools + 1 end
            end
        end
    end
    return n, layers, pools
end

return {
    dressing_rules_deterministic_per_square_and_period = function()
        local R = load()
        local a = R.floor(1234, 5678, 0, 3, 1)
        local b = load().floor(1234, 5678, 0, 3, 1)
        assert((a == nil) == (b == nil))
        local diff = 0
        for x = 0, 39 do
            for y = 0, 39 do
                local p3 = R.floor(500 + x, 700 + y, 0, 3, 1)
                local again = R.floor(500 + x, 700 + y, 0, 3, 1)
                local p4 = R.floor(500 + x, 700 + y, 0, 4, 1)
                local k = function(f)
                    if not f then return "-" end
                    local s = ""
                    for _, l in ipairs(f) do s = s .. l[1] .. l[2] .. ";" end
                    return s
                end
                assert(k(p3) == k(again), "mudou sem mudar a entrada")
                if k(p3) ~= k(p4) then diff = diff + 1 end
            end
        end
        assert(diff > 400, "período novo quase igual: " .. diff)
    end,

    -- poças (3 camadas de sangue num square) e chão bem coberto na densidade 1
    dressing_rules_pools_and_heavy_floor = function()
        local R = load()
        local n, layers, pools = sweep(R, 7, 1, 60)
        assert(pools >= 20, "poucas poças: " .. pools)
        assert(n >= 3600 * 0.35, "chão vazio demais: " .. n)
        assert(layers / n >= 1.3, "camadas por square: " .. layers / n)
    end,

    -- calibração pelo print do Johan (05/10, névoa vermelha, ~7×7 tiles na tela, "ainda não
    -- tá o outro mundo"): em qualquer enquadramento assim, quase todo chão muda e tem sangue
    dressing_rules_visible_at_close_zoom = function()
        local R = load()
        for _, red in ipairs({ false, true }) do
            local d = R.density(1, red)
            local worst, noBlood = 1, 0
            for k = 0, 39 do
                local cx, cy = 10700 + k * 37, 10200 + k * 53
                local n, blood = 0, 0
                for x = cx - 3, cx + 3 do
                    for y = cy - 3, cy + 3 do
                        local f = R.floor(x, y, 0, 9, d)
                        if f then
                            n = n + 1
                            for _, l in ipairs(f) do if l[1] == "bloodFloor" then blood = blood + 1 break end end
                        end
                    end
                end
                worst = math.min(worst, n / 49)
                if blood < 3 then noBlood = noBlood + 1 end
            end
            assert(worst >= (red and 0.8 or 0.6), "enquadramento limpo demais: " .. worst)
            assert(noBlood <= (red and 2 or 8), "enquadramentos quase sem sangue: " .. noBlood)
        end
    end,

    dressing_rules_layers_valid_and_capped = function()
        local R = load()
        for x = 0, 49 do
            for y = 0, 49 do
                local f = R.floor(300 + x, 300 + y, 1, 2, 3.2)
                if f then
                    assert(#f >= 1 and #f <= R.MAX_LAYERS, "camadas: " .. #f)
                    for _, l in ipairs(f) do
                        local s = R.SETS[l[1]]
                        assert(s and not s.wall, "set de chão: " .. tostring(l[1]))
                        assert(set(s.idx)[l[2]], l[1] .. " índice fora: " .. l[2])
                    end
                end
            end
        end
    end,

    dressing_rules_red_denser_and_zero_empty = function()
        local R = load()
        assert(R.density(1, true) > R.density(1, false))
        assert(R.density(0, true) == 0 and R.density(-3, false) == 0)
        assert(R.density(9, false) == R.density(2, false), "densidade fora da faixa")
        local normal = select(2, sweep(R, 5, R.density(1, false), 50))
        local red = select(2, sweep(R, 5, R.density(1, true), 50))
        assert(red > normal * 1.2, "vermelha não é mais densa: " .. red .. " vs " .. normal)
        assert(sweep(R, 5, 0, 30) == 0, "densidade 0 com mancha")
        for x = 0, 30 do assert(R.wall(x, 0, 0, 5, 0, true) == nil) end
    end,

    dressing_rules_walls_by_side = function()
        local R = load()
        local got = { N = 0, W = 0 }
        for x = 0, 59 do
            for y = 0, 59 do
                for _, north in ipairs({ true, false }) do
                    local w = R.wall(800 + x, 900 + y, 0, 6, 1, north)
                    if w then
                        local s = R.SETS[w[1]]
                        assert(s.wall == (north and "N" or "W"), w[1] .. " no lado errado")
                        assert(set(s.idx)[w[2]], w[1] .. " índice fora: " .. w[2])
                        local pack = PACK[w[1]]
                        if pack then assert(set(pack)[w[2]], w[1] .. " fora do pack: " .. w[2]) end
                        got[north and "N" or "W"] = got[north and "N" or "W"] + 1
                    end
                end
            end
        end
        assert(got.N > 3600 * 0.5 and got.W > 3600 * 0.5, "parede pouco suja: " .. got.N .. "/" .. got.W)
    end,

    -- porão (z < 0) e andar alto (z ≥ 8): o id do square não pode colidir entre andares
    dressing_rules_z_independent = function()
        local R = load()
        local function key(f)
            if not f then return "-" end
            local t = {}
            -- só a erosão: ela sai direto do id do square (o sangue vem das células)
            for _, l in ipairs(f) do if l[1] ~= "bloodFloor" then t[#t + 1] = l[1] .. l[2] end end
            return table.concat(t, ";")
        end
        -- { z1, z2, dy }: com um id que só soma z, (x, y, z1) e (x, y + dy, z2) colidiriam
        for _, pair in ipairs({ { 8, 0, 1 }, { -1, 7, -1 }, { 9, 1, 1 }, { 0, 0, 0 } }) do
            local same = 0
            for x = 0, 29 do
                for y = 0, 29 do
                    if pair[3] ~= 0 and key(R.floor(400 + x, 400 + y, pair[1], 2, 1)) == key(R.floor(400 + x, 400 + y + pair[3], pair[2], 2, 1)) then
                        same = same + 1
                    end
                end
            end
            assert(same < 200, "andares " .. pair[1] .. " e " .. pair[2] .. " iguais: " .. same)
        end
    end,

    -- quantos deslocamentos há até cada raio (a varredura limita o cursor por ele)
    dressing_rules_offsets_within = function()
        local R = load()
        for r = 0, R.RADIUS do
            local n = 0
            for _, o in ipairs(R.OFFSETS) do if o[1] * o[1] + o[2] * o[2] <= r * r then n = n + 1 end end
            assert(R.WITHIN[r] == n, "WITHIN[" .. r .. "]")
        end
    end,

    dressing_rules_offsets_nearest_first = function()
        local R = load()
        local last = -1
        local seen = {}
        for _, o in ipairs(R.OFFSETS) do
            local d = o[1] * o[1] + o[2] * o[2]
            assert(d >= last and d <= R.RADIUS * R.RADIUS)
            last = d
            seen[o[1] .. "," .. o[2]] = true
        end
        assert(R.OFFSETS[1][1] == 0 and R.OFFSETS[1][2] == 0)
        assert(seen[R.RADIUS .. ",0"] and seen["0,-" .. R.RADIUS])
        assert(#R.OFFSETS > 1900, "raio pequeno: " .. #R.OFFSETS)
    end,
}
