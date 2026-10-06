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

-- Medida do pack (scripts/audit_floor_sprites.py, sprints 0021 e 0023): por nome, inside, cov,
-- rise, wind (geometria do sprite anexado ao piso).
local AUDIT = dofile("tests/floor_sprites.lua")
-- Paredes (scripts/audit_wall_sprites.py, sprint 0034): left, lo, hi, depth, attached.
local WALLS = dofile("tests/wall_sprites.lua")

-- tipo da camada de parede: "blood", "grime", "cracks", "vines" ou "writing" (pichação e mensagem)
local function wallKind(layer)
    local k = layer[1]:match("^(%l+)Wall[NW]$")
    if k == "graffiti" or k == "messages" then return "writing" end
    return k
end

local ORDER = { cracks = 1, grime = 2, vines = 2, blood = 3, writing = 4 }

-- paredes de um quarteirão, dentro ou fora: { [x,y,lado] = camadas }
local function wallsOf(R, outside, d, per, size)
    local out = {}
    for x = 0, (size or 60) - 1 do
        for y = 0, (size or 60) - 1 do
            for _, north in ipairs({ true, false }) do
                out[(3000 + x) .. "," .. (5000 + y) .. "," .. (north and "N" or "W")] =
                    R.wall(3000 + x, 5000 + y, 0, per or 5, d or 1, north, outside) or false
            end
        end
    end
    return out
end

-- o run e a posição de uma peça de pichação/mensagem no set
local function runOf(R, layer)
    for _, run in ipairs(R.SETS[layer[1]].runs) do
        for k, i in ipairs(run) do
            if i == layer[2] then return run, k end
        end
    end
end

local function floorNames(R)
    local out = {}
    for setName, s in pairs(R.SETS) do
        if not s.wall then
            for _, i in ipairs(s.idx) do out[#out + 1] = { set = setName, name = s.prefix .. i } end
        end
    end
    return out
end

local function isPlant(name)
    return name:find("^d_plants") ~= nil or name:find("^d_floorleaves") ~= nil
end

-- conta camadas por set num quarteirão, dentro ou fora
local function kinds(R, outside, d)
    local n = {}
    for x = 0, 59 do
        for y = 0, 59 do
            local f = R.floor(4000 + x, 4000 + y, 0, 5, d or 1, outside)
            for _, l in ipairs(f or {}) do n[l[1]] = (n[l[1]] or 0) + 1 end
        end
    end
    return n
end

local function count(n, pattern)
    local c = 0
    for k, v in pairs(n) do if k:find(pattern) then c = c + v end end
    return c
end

return {
    -- sprint 0023: o sprite vai anexado ao piso e sai na posição do piso. Decalque (sangue,
    -- sujeira, rachadura, queimado) com o conteúdo deitado no diamante do chão (não flutua); mato
    -- e folha rasteiros (quase tudo no diamante e no máximo 8 px acima dele: o anexo do piso sai
    -- antes dos personagens e das paredes, um mato alto ficaria por baixo do que está atrás dele)
    dressing_rules_floor_pools_lie_on_floor = function()
        local R = load()
        local names = floorNames(R)
        assert(#names > 150, "pool vazio demais: " .. #names)
        for _, n in ipairs(names) do
            local a = AUDIT[n.name]
            assert(a, "sprite fora da auditoria: " .. n.name)
            if isPlant(n.name) then
                assert(a.inside >= 0.8 and a.rise <= 8, "mato alto no chão: " .. n.name)
            else
                assert(a.inside >= 0.95, "decalque fora do chão: " .. n.name)
            end
        end
    end,

    -- chão queimado é de casa destruída (dentro); mato e folha são de fora
    dressing_rules_burnt_only_inside_plants_only_outside = function()
        local R = load()
        local inside, outside = kinds(R, false), kinds(R, true)
        assert(count(inside, "^burnt") > 100, "casa sem chão queimado: " .. count(inside, "^burnt"))
        assert(count(inside, "^plants") + count(inside, "^leaves") == 0, "mato dentro de casa")
        assert(count(outside, "^plants") + count(outside, "^leaves") > 100, "rua sem mato")
        assert(count(outside, "^burnt") == 0, "chão queimado na rua")
    end,

    -- o queimado vem em manchas (não tile a tile): troca queimado/limpo entre vizinhos bem menor
    -- que a de um sorteio por tile; o miolo cheio fica dentro da mancha (quase todo tile cheio
    -- tem vizinho queimado dos 4 lados: o ruído anda até ~0,3 por tile, o corte não garante 100%)
    dressing_rules_burnt_patches = function()
        local R = load()
        for _, d in ipairs({ 1, 1.6, 2, 3.2 }) do
            local has, full, n, tot = {}, {}, 0, 0
            for x = 0, 89 do
                for y = 0, 89 do
                    local k = x .. "," .. y
                    for _, l in ipairs(R.floor(6000 + x, 6000 + y, 0, 4, d, false) or {}) do
                        if l[1]:find("^burnt") then has[k] = true end
                        if l[1] == "burntFloorF" then full[k] = true end
                    end
                    if has[k] then n = n + 1 end
                    tot = tot + 1
                end
            end
            local p = n / tot
            assert(p > 0.05 and p < 0.45, "fração de queimado: d=" .. d .. " " .. p)
            local flips, pairs_ = 0, 0
            for x = 0, 88 do
                for y = 0, 88 do
                    for _, o in ipairs({ { 1, 0 }, { 0, 1 } }) do
                        pairs_ = pairs_ + 1
                        if (has[x .. "," .. y] or false) ~= (has[(x + o[1]) .. "," .. (y + o[2])] or false) then flips = flips + 1 end
                    end
                end
            end
            assert(flips / pairs_ / (2 * p * (1 - p)) < 0.6, "queimado tile a tile: d=" .. d)
            local fulls, edge = 0, 0
            for x = 1, 88 do
                for y = 1, 88 do
                    if full[x .. "," .. y] then
                        fulls = fulls + 1
                        for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                            if not has[(x + o[1]) .. "," .. (y + o[2])] then edge = edge + 1 break end
                        end
                    end
                end
            end
            assert(fulls > 50, "pouco queimado cheio: d=" .. d .. " " .. fulls)
            assert(edge <= fulls * 0.05, "queimado cheio na borda da mancha: d=" .. d .. " " .. edge .. "/" .. fulls)
        end
    end,

    -- o nome só do mod (ninguém no vanilla anexa floors_burnt_01_*, ADR-017): R.own diz
    -- exatamente os nomes dos sets de queimado; nenhum outro set usa o prefixo
    dressing_rules_own_prefix_only_burnt = function()
        local R = load()
        local burnt = 0
        for setName, s in pairs(R.SETS) do
            for _, i in ipairs(s.idx) do
                local name = R.name({ setName, i })
                assert(name == s.prefix .. i)
                assert(R.own(name) == (setName:find("^burnt") ~= nil), "dono errado: " .. name)
                if R.own(name) then burnt = burnt + 1 end
            end
        end
        assert(burnt >= 20, "poucos queimados: " .. burnt)
        assert(not R.own("overlay_blood_floor_01_3") and not R.own("blends_natural_01_5") and not R.own(nil))
    end,

    -- trepadeira é de parede de fora (erosão vanilla: WallVines só em parede externa)
    dressing_rules_vines_only_outside = function()
        local R = load()
        local vinesIn, vinesOut = 0, 0
        for x = 0, 59 do
            for y = 0, 59 do
                for _, north in ipairs({ true, false }) do
                    for _, l in ipairs(R.wall(800 + x, 900 + y, 0, 6, 1, north, false) or {}) do
                        if l[1]:find("^vines") then vinesIn = vinesIn + 1 end
                    end
                    for _, l in ipairs(R.wall(800 + x, 900 + y, 0, 6, 1, north, true) or {}) do
                        if l[1]:find("^vines") then vinesOut = vinesOut + 1 end
                    end
                end
            end
        end
        assert(vinesIn == 0, "trepadeira dentro: " .. vinesIn)
        assert(vinesOut > 200, "pouca trepadeira fora: " .. vinesOut)
    end,

    -- print 7 (05/10): sujeira de tile cheio, um losango por tile, lia como xadrez. Só
    -- sujeira parcial (cobertura < 50% do diamante), a lista da sprint 0021
    dressing_rules_grime_partial_only = function()
        local R = load()
        for _, i in ipairs(R.SETS.grimeFloor.idx) do
            local a = AUDIT[R.SETS.grimeFloor.prefix .. i]
            assert(a.cov < 0.5, "sujeira de tile cheio: " .. i .. " (" .. a.cov .. ")")
        end
        assert(R.GRIME_ALPHA and R.GRIME_ALPHA > 0 and R.GRIME_ALPHA < 1, "sujeira sem alfa próprio")
    end,

    dressing_rules_grime_rarer = function()
        local R = load()
        local n, tot = 0, 0
        for x = 0, 79 do
            for y = 0, 79 do
                tot = tot + 1
                local f = R.floor(5000 + x, 6000 + y, 0, 3, 1)
                if f and f.grime then n = n + 1 end
                for _, l in ipairs(f or {}) do assert(l[1] ~= "grimeFloor", "sujeira nas camadas do marcador principal") end
            end
        end
        assert(n / tot >= 0.1 and n / tot <= 0.35, "fração de sujeira: " .. n / tot)
    end,

    -- manchas, não sal e pimenta: a troca sujo/limpo entre vizinhos é bem menor que a de um
    -- sorteio por tile com a mesma fração (2p(1-p))
    -- manchas, não sal e pimenta, em toda densidade (review 0021: em 1,6/2/3,2 voltava a
    -- ser tile a tile): a troca sujo/limpo entre vizinhos é bem menor que a de um sorteio por
    -- tile com a mesma fração (2p(1-p)), em três períodos
    dressing_rules_grime_clusters = function()
        local R = load()
        for _, d in ipairs({ 1, 1.6, 2, 3.2 }) do
            for _, per in ipairs({ 3, 6, 11 }) do
                local has, n, tot = {}, 0, 0
                for x = 0, 89 do
                    for y = 0, 89 do
                        local f = R.floor(7000 + x, 8000 + y, 0, per, d)
                        has[x .. "," .. y] = f ~= nil and f.grime ~= nil
                        if has[x .. "," .. y] then n = n + 1 end
                        tot = tot + 1
                    end
                end
                local p = n / tot
                assert(p > 0.05, "sem sujeira pra medir: " .. p)
                local flips, pairs = 0, 0
                for x = 0, 88 do
                    for y = 0, 88 do
                        for _, o in ipairs({ { 1, 0 }, { 0, 1 } }) do
                            pairs = pairs + 1
                            if has[x .. "," .. y] ~= has[(x + o[1]) .. "," .. (y + o[2])] then flips = flips + 1 end
                        end
                    end
                end
                local ratio = flips / pairs / (2 * p * (1 - p))
                assert(ratio < 0.6, "sujeira espalhada tile a tile: d=" .. d .. " per=" .. per .. " razão " .. ratio)
            end
        end
    end,

    -- métrica do xadrez: dois vizinhos sujos nunca têm o mesmo sprite (nem cheio nem parcial)
    dressing_rules_grime_no_checkerboard = function()
        local R = load()
        for _, d in ipairs({ 1, 1.6, 2, 3.2 }) do
            local g = {}
            for x = 0, 79 do
                for y = 0, 79 do
                    local f = R.floor(9000 + x, 1000 + y, 0, 6, d)
                    g[x .. "," .. y] = f and f.grime and f.grime[2]
                end
            end
            local same, dirty = 0, 0
            for x = 0, 78 do
                for y = 0, 78 do
                    local a = g[x .. "," .. y]
                    for _, o in ipairs({ { 1, 0 }, { 0, 1 } }) do
                        local b = g[(x + o[1]) .. "," .. (y + o[2])]
                        if a and b then
                            dirty = dirty + 1
                            if a == b then same = same + 1 end
                        end
                    end
                end
            end
            assert(dirty > 300, "pouca sujeira vizinha pra medir: " .. dirty)
            assert(same == 0, "vizinhos com a mesma sujeira: d=" .. d .. " " .. same .. " de " .. dirty)
        end
    end,

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
                    assert((#f >= 1 or f.grime) and #f <= R.MAX_LAYERS, "camadas: " .. #f)
                    if f.grime then
                        assert(f.grime[1] == "grimeFloor" and set(R.SETS.grimeFloor.idx)[f.grime[2]], "sujeira fora do pool")
                    end
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
                    for _, outside in ipairs({ true, false }) do
                        local ws = R.wall(800 + x, 900 + y, 0, 6, 1, north, outside)
                        for _, w in ipairs(ws or {}) do
                            local s = R.SETS[w[1]]
                            assert(s.wall == (north and "N" or "W"), w[1] .. " no lado errado")
                            assert(set(s.idx)[w[2]], w[1] .. " índice fora: " .. w[2])
                            local pack = PACK[w[1]]
                            if pack then assert(set(pack)[w[2]], w[1] .. " fora do pack: " .. w[2]) end
                        end
                        if ws and outside then got[north and "N" or "W"] = got[north and "N" or "W"] + 1 end
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

    -- quantos deslocamentos há até cada raio (a varredura limita o cursor por ele), até o máximo
    dressing_rules_offsets_within = function()
        local R = load()
        for r = 0, R.MAX_RADIUS do
            local n = 0
            for _, o in ipairs(R.OFFSETS) do if o[1] * o[1] + o[2] * o[2] <= r * r then n = n + 1 end end
            assert(R.WITHIN[r] == n, "WITHIN[" .. r .. "]")
        end
        assert(R.WITHIN[R.MAX_RADIUS] == #R.OFFSETS)
    end,

    dressing_rules_offsets_nearest_first = function()
        local R = load()
        local last = -1
        local seen = {}
        for _, o in ipairs(R.OFFSETS) do
            local d = o[1] * o[1] + o[2] * o[2]
            assert(d >= last and d <= R.MAX_RADIUS * R.MAX_RADIUS)
            last = d
            seen[o[1] .. "," .. o[2]] = true
        end
        assert(R.OFFSETS[1][1] == 0 and R.OFFSETS[1][2] == 0)
        assert(seen[R.MAX_RADIUS .. ",0"] and seen["0,-" .. R.MAX_RADIUS])
        assert(#R.OFFSETS > 3 * R.MAX_RADIUS * R.MAX_RADIUS, "raio pequeno: " .. #R.OFFSETS)
    end,

    -- raio pela tela: o canto mais longe do jogador + MARGIN, pra cima, entre MIN e MAX
    dressing_rules_radius_from_screen_corners = function()
        local R = load()
        assert(R.MIN_RADIUS == 15 and R.MAX_RADIUS == 30 and R.MARGIN == 2)
        local function box(px, py, d) -- os 4 cantos a d tiles nos eixos
            return { { px - d, py }, { px + d, py }, { px, py - d }, { px, py + d } }
        end
        assert(R.radius(100, 100, box(100, 100, 5)) == R.MIN_RADIUS, "perto: " .. R.radius(100, 100, box(100, 100, 5)))
        assert(R.radius(100, 100, box(100, 100, 80)) == R.MAX_RADIUS, "longe")
        -- canto mais longe em (+12, +9,1): 15,06 + 2 = 17,06 → 18
        local c = { { 90, 100 }, { 112, 109.1 }, { 100, 101 }, { 101, 100 } }
        local far = math.sqrt(12 * 12 + 9.1 * 9.1)
        assert(R.radius(100, 100, c) == math.ceil(far + R.MARGIN), "meio-termo: " .. R.radius(100, 100, c))
        -- exatamente inteiro não sobe mais um
        assert(R.radius(0, 0, { { 20, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }) == 22)
        -- na borda: 13 + 2 = 15, 28 + 2 = 30, 28,5 + 2 → 31 → 30
        assert(R.radius(0, 0, { { 13, 0 } }) == 15 and R.radius(0, 0, { { 28, 0 } }) == 30)
        assert(R.radius(0, 0, { { 28.5, 0 } }) == 30)
    end,

    -- sem cantos, ou canto que não é número (tela de 0 px, zoom estranho): o mínimo
    dressing_rules_radius_invalid_is_min = function()
        local R = load()
        local nan = 0 / 0
        for _, c in ipairs({ "nil", {}, { { 50, 50 }, "x" }, { { 50 } }, { { nan, 50 } }, { { 1 / 0, 0 } }, 7 }) do
            if c == "nil" then c = nil end
            assert(R.radius(0, 0, c) == R.MIN_RADIUS, "inválido virou " .. tostring(R.radius(0, 0, c)))
        end
        assert(R.radius(nil, 0, { { 50, 0 } }) == R.MIN_RADIUS)
    end,

    -- sprint 0034: todo sprite de parede existe no pack e cai no lado do set pelo recorte e pela
    -- profundidade; pichação e mensagem também pela definição do tile (attachedW/N: o mapa
    -- vanilla anexa pelo lado), as três evidências juntas
    dressing_rules_wall_sets_audited = function()
        local R = load()
        local n = 0
        for name, s in pairs(R.SETS) do
            if s.wall then
                for _, i in ipairs(s.idx) do
                    local a = WALLS[s.prefix .. i]
                    assert(a, "sprite fora do pack: " .. s.prefix .. i)
                    assert((a.left >= 0.5 and "W" or "N") == s.wall, "recorte no lado errado: " .. s.prefix .. i)
                    assert(a.depth == nil or a.depth == s.wall, "profundidade no lado errado: " .. s.prefix .. i)
                    if name:find("^graffiti") or name:find("^messages") then
                        assert(a.depth == s.wall and a.attached == s.wall, "evidência faltando ou divergente: " .. s.prefix .. i)
                    end
                    n = n + 1
                end
            end
        end
        assert(n > 250, "poucos sprites de parede: " .. n)
    end,

    -- pichação e mensagem são desenhos de várias paredes (o pack corta em peças de um tile): o
    -- set lista os desenhos inteiros (runs), nunca metade de um. Duas peças seguidas do pack em
    -- que o desenho atravessa a borda (hi de uma, lo da outra) estão no mesmo run.
    dressing_rules_writing_runs_whole = function()
        local R = load()
        local total = 0
        for _, kind in ipairs({ "graffiti", "messages" }) do
            for _, side in ipairs({ "N", "W" }) do
                local s = R.SETS[kind .. "Wall" .. side]
                assert(s and s.runs and #s.runs >= 3, "sem desenhos: " .. kind .. side)
                local runAt, flat = {}, {}
                for r, run in ipairs(s.runs) do
                    assert(#run >= 1 and #run <= R.RUN_SLOT, "desenho maior que o trecho: " .. kind .. side .. " " .. r)
                    for _, i in ipairs(run) do
                        assert(not runAt[i], "peça repetida: " .. s.prefix .. i)
                        runAt[i] = r
                        flat[#flat + 1] = i
                    end
                end
                assert(table.concat(flat, ",") == table.concat(s.idx, ","), "idx ≠ runs: " .. kind .. side)
                for i in pairs(runAt) do
                    for _, j in ipairs({ i - 1, i + 1 }) do
                        local a, b = WALLS[s.prefix .. math.min(i, j)], WALLS[s.prefix .. math.max(i, j)]
                        local bs = WALLS[s.prefix .. j]
                        if a and b and bs and (bs.left >= 0.5 and "W" or "N") == side and a.hi and b.lo then
                            assert(runAt[j] == runAt[i], "desenho cortado entre " .. s.prefix .. i .. " e " .. j)
                        end
                    end
                end
                total = total + #s.runs
            end
        end
        assert(total >= 50, "poucos desenhos: " .. total)
    end,

    -- o desenho lê inteiro ao longo da parede: peça k em x + k (parede N, x cresce pra direita na
    -- tela) e em y − k (parede W, y cresce pra esquerda); dentro e fora
    dressing_rules_writing_reads_along_the_wall = function()
        local R = load()
        for _, outside in ipairs({ true, false }) do
            local seen, whole = 0, 0
            for line = 0, 39 do
                for pos = 0, 79 do
                    for _, north in ipairs({ true, false }) do
                        local x, y = north and 2000 + pos or 2000 + line, north and 7000 + line or 7000 + pos
                        for _, l in ipairs(R.wall(x, y, 0, 8, 1, north, outside) or {}) do
                            if wallKind(l) == "writing" then
                                seen = seen + 1
                                local run, k = runOf(R, l)
                                assert(run, "peça fora dos desenhos: " .. l[1] .. l[2])
                                local function at(step)
                                    local nx, ny = north and x + step or x, north and y or y - step
                                    for _, m in ipairs(R.wall(nx, ny, 0, 8, 1, north, outside) or {}) do
                                        if wallKind(m) == "writing" then return m end
                                    end
                                end
                                for step = 1 - k, #run - k do
                                    if step ~= 0 then
                                        local m = at(step)
                                        assert(m and m[1] == l[1] and m[2] == run[k + step],
                                            "desenho quebrado em " .. x .. "," .. y .. (north and "N" or "W") .. " passo " .. step)
                                    end
                                end
                                if k == 1 then whole = whole + 1 end
                            end
                        end
                    end
                end
            end
            assert(seen > 200 and whole > 60, "pouca pichação: " .. seen .. "/" .. whole)
        end
    end,

    -- o desenho do trecho não depende de dentro/fora (só se aparece): uma fileira que cruza a
    -- porta da varanda perde peças, nunca emenda dois desenhos
    dressing_rules_writing_same_inside_and_outside = function()
        local R = load()
        local both = 0
        for x = 0, 79 do
            for y = 0, 79 do
                for _, north in ipairs({ true, false }) do
                    local a, b
                    for _, l in ipairs(R.wall(4000 + x, 4000 + y, 0, 3, 1, north, true) or {}) do
                        if wallKind(l) == "writing" then a = l end
                    end
                    for _, l in ipairs(R.wall(4000 + x, 4000 + y, 0, 3, 1, north, false) or {}) do
                        if wallKind(l) == "writing" then b = l end
                    end
                    if a and b then
                        both = both + 1
                        assert(a[1] == b[1] and a[2] == b[2], "desenho diferente dentro e fora")
                    end
                end
            end
        end
        assert(both > 50, "nada pra comparar: " .. both)
    end,

    -- "casa destruída" (sprint 0034): parede de dentro quase sempre com algo, em até WALL_LAYERS
    -- camadas de tipos diferentes, de baixo pra cima rachadura, sujeira, sangue, pichação
    dressing_rules_inside_walls_ruined = function()
        local R = load()
        assert(R.WALL_LAYERS and R.WALL_LAYERS >= 2 and R.WALL_LAYERS <= 3)
        local walls, dressed, layers, three, n = 0, 0, 0, 0, {}
        for _, ls in pairs(wallsOf(R, false, 1)) do
            walls = walls + 1
            if ls then
                dressed = dressed + 1
                layers = layers + #ls
                if #ls == 3 then three = three + 1 end
                assert(#ls <= R.WALL_LAYERS, "camadas demais: " .. #ls)
                local kinds, last = {}, 0
                for _, l in ipairs(ls) do
                    local k = wallKind(l)
                    assert(k ~= "vines", "trepadeira dentro")
                    assert(not kinds[k], "tipo repetido na parede: " .. k)
                    kinds[k] = true
                    n[k] = (n[k] or 0) + 1
                    assert(ORDER[k] > last, "ordem das camadas: " .. k)
                    last = ORDER[k]
                end
            end
        end
        assert(dressed / walls >= 0.9, "parede de dentro limpa: " .. dressed / walls)
        assert(layers / dressed >= 1.6, "camadas por parede de dentro: " .. layers / dressed)
        assert(three / walls >= 0.1, "pouca parede com 3 camadas: " .. three / walls)
        -- "apagadas, acabadas, sujas" (Johan): dentro, a sujeira não fica atrás do sangue
        assert((n.grime or 0) >= (n.blood or 0), "dentro: sujeira " .. (n.grime or 0) .. ", sangue " .. (n.blood or 0))
    end,

    -- fora: uma camada por lado, como antes; sangue continua mandando, pichação entra
    dressing_rules_outside_walls_one_layer = function()
        local R = load()
        local n = {}
        for _, ls in pairs(wallsOf(R, true, 1)) do
            if ls then
                assert(#ls == 1, "parede de fora com " .. #ls .. " camadas")
                local k = wallKind(ls[1])
                n[k] = (n[k] or 0) + 1
            end
        end
        local writing = n.writing or 0
        assert(writing > 150, "pouca pichação fora: " .. writing)
        for k, v in pairs(n) do
            if k ~= "blood" then assert((n.blood or 0) > v, "sangue não manda fora: blood " .. (n.blood or 0) .. ", " .. k .. " " .. v) end
        end
    end,

    -- mensagem escrita é mais de dentro; pichação, de fora
    dressing_rules_messages_more_inside = function()
        local R = load()
        local function count(outside)
            local m, g = 0, 0
            for _, ls in pairs(wallsOf(R, outside, 1, 7, 80)) do
                for _, l in ipairs(ls or {}) do
                    if l[1]:find("^messages") then m = m + 1 elseif l[1]:find("^graffiti") then g = g + 1 end
                end
            end
            return m, g
        end
        local mi, gi = count(false)
        local mo, go = count(true)
        assert(mi > gi, "dentro: mensagem " .. mi .. ", pichação " .. gi)
        assert(go > mo, "fora: pichação " .. go .. ", mensagem " .. mo)
        assert(mi / (mi + gi) > 1.5 * mo / (mo + go), "mensagem não é mais de dentro")
    end,

    -- a densidade e a névoa vermelha escalam a parede de dentro e a pichação
    dressing_rules_walls_scale_with_density = function()
        local R = load()
        local function measure(d, outside)
            local layers, writing = 0, 0
            for _, ls in pairs(wallsOf(R, outside, d, 4, 50)) do
                for _, l in ipairs(ls or {}) do
                    layers = layers + 1
                    if wallKind(l) == "writing" then writing = writing + 1 end
                end
            end
            return layers, writing
        end
        local low, wLow = measure(0.5, false)
        local mid, wMid = measure(1, false)
        local red, wRed = measure(R.density(1, true), false)
        assert(low < mid and mid < red, "camadas dentro: " .. low .. " " .. mid .. " " .. red)
        assert(wLow < wMid and wMid < wRed, "pichação dentro: " .. wLow .. " " .. wMid .. " " .. wRed)
        local _, oMid = measure(1, true)
        local _, oRed = measure(R.density(1, true), true)
        assert(oMid < oRed, "pichação fora: " .. oMid .. " " .. oRed)
    end,

    -- andar e voltar: a mesma parede dá o mesmo desenho; período novo, outro
    dressing_rules_walls_deterministic = function()
        local R = load()
        local function key(ls)
            if not ls then return "-" end
            local t = {}
            for _, l in ipairs(ls) do t[#t + 1] = l[1] .. l[2] end
            return table.concat(t, ";")
        end
        local first = {}
        for x = 0, 29 do
            for y = 0, 29 do
                for _, outside in ipairs({ true, false }) do
                    first[x .. "," .. y .. tostring(outside)] = key(R.wall(600 + x, 600 + y, 0, 3, 1, true, outside))
                end
            end
        end
        R = load()
        local diff = 0
        for x = 0, 29 do
            for y = 0, 29 do
                for _, outside in ipairs({ true, false }) do
                    local a = key(R.wall(600 + x, 600 + y, 0, 3, 1, true, outside))
                    assert(a == first[x .. "," .. y .. tostring(outside)], "mudou sem mudar a entrada")
                    if a ~= key(R.wall(600 + x, 600 + y, 0, 4, 1, true, outside)) then diff = diff + 1 end
                end
            end
        end
        assert(diff > 600, "período novo quase igual: " .. diff)
    end,
}
