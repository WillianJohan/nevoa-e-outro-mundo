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

-- squares vestidos e anexos no chão (camadas mais a sujeira) num quarteirão
local function sweep(R, period, d, size, red)
    local n, layers = 0, 0
    for x = 1000, 1000 + size - 1 do
        for y = 2000, 2000 + size - 1 do
            local f = R.floor(x, y, 0, period, d, nil, red)
            if f then
                n = n + 1
                layers = layers + #f + (f.grime and 1 or 0)
            end
        end
    end
    return n, layers
end

-- Medida do pack (scripts/audit_floor_sprites.py, sprints 0021 e 0023): por nome, inside, cov,
-- rise, wind (geometria do sprite anexado ao piso).
local AUDIT = dofile("tests/floor_sprites.lua")
-- Paredes (scripts/audit_wall_sprites.py, sprint 0034): left, lo, hi, depth, attached.
local WALLS = dofile("tests/wall_sprites.lua")

-- tipo da camada de parede: "paint" (tinta descascando: Tinta ou Descasca), "rust", "blood",
-- "grime", "cracks", "vines" ou "writing" (pichação e mensagem)
local function wallKind(layer)
    local k = layer[1]:match("^(%l+)Wall[NW]$")
    if k == "graffiti" or k == "messages" then return "writing" end
    if k == "peel" then return "paint" end
    return k
end

-- de baixo pra cima: a tinta que descasca é a pele da parede, a ferrugem escorre por cima dela
local ORDER = { paint = 0, rust = 0.5, cracks = 1, grime = 2, vines = 2, blood = 3, writing = 4 }

-- paredes de um quarteirão, dentro ou fora: { [x,y,lado] = camadas }
local function wallsOf(R, outside, d, per, size, red)
    local out = {}
    for x = 0, (size or 60) - 1 do
        for y = 0, (size or 60) - 1 do
            for _, north in ipairs({ true, false }) do
                out[(3000 + x) .. "," .. (5000 + y) .. "," .. (north and "N" or "W")] =
                    R.wall(3000 + x, 5000 + y, 0, per or 5, d or 1, north, outside, red) or false
            end
        end
    end
    return out
end

-- Silent Hill (sprint 0035): as camadas com textura nossa
local function isOwnSet(R, name)
    return R.SETS[name].own == true
end

-- o run e a posição de uma peça de pichação/mensagem no set
local function runOf(R, layer)
    for _, run in ipairs(R.SETS[layer[1]].runs) do
        for k, i in ipairs(run) do
            if i == layer[2] then return run, k end
        end
    end
end

-- os sprites do pack no chão (os nossos têm auditoria própria: tests/test_om_tiles.py)
local function floorNames(R)
    local out = {}
    for setName, s in pairs(R.SETS) do
        if not s.wall and not s.own then
            for _, i in ipairs(s.idx) do out[#out + 1] = { set = setName, name = s.prefix .. i } end
        end
    end
    return out
end

local function isPlant(name)
    return name:find("^d_plants") ~= nil or name:find("^d_floorleaves") ~= nil
end

-- conta camadas por set num quarteirão, dentro ou fora
local function kinds(R, outside, d, red)
    local n = {}
    for x = 0, 59 do
        for y = 0, 59 do
            local f = R.floor(4000 + x, 4000 + y, 0, 5, d or 1, outside, red)
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
    -- sprint 0023: o sprite vai anexado ao piso e sai na posição do piso. Decalque (sujeira,
    -- rachadura, queimado) com o conteúdo deitado no diamante do chão (não flutua); mato
    -- e folha rasteiros (quase tudo no diamante e no máximo 8 px acima dele: o anexo do piso sai
    -- antes dos personagens e das paredes, um mato alto ficaria por baixo do que está atrás dele)
    dressing_rules_floor_pools_lie_on_floor = function()
        local R = load()
        local names = floorNames(R)
        assert(#names > 120, "pool vazio demais: " .. #names)
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

    -- Johan, 06/10: o sangue no chão parecia textura ruim de jogo antigo e saiu. Nenhuma camada
    -- de chão (nem a sujeira) é de sangue, dentro e fora, em qualquer densidade, inclusive na
    -- névoa vermelha; o sangue fica só na parede
    dressing_rules_no_blood_on_floor = function()
        local R = load()
        for setName, s in pairs(R.SETS) do
            if not s.wall then
                assert(not setName:find("^blood"), "set de sangue no chão: " .. setName)
                for _, i in ipairs(s.idx) do
                    assert(not R.name({ setName, i }):lower():find("blood"), "sprite de sangue no chão: " .. R.name({ setName, i }))
                end
            end
        end
        -- branca e vermelha (sprint 0035: a vermelha ganhou ferrugem no chão, sangue não)
        local cases = { { 0.3, false }, { 1, false }, { 2, false }, { R.density(1, true), true }, { R.density(2, true), true },
            { 1, true } }
        for _, outside in ipairs({ false, true }) do
            for _, c in ipairs(cases) do
                local d, red = c[1], c[2]
                for _, per in ipairs({ 1, 7 }) do
                    for x = 0, 39 do
                        for y = 0, 39 do
                            local f = R.floor(2500 + x, 3500 + y, 0, per, d, outside, red)
                            local all = {}
                            for _, l in ipairs(f or {}) do all[#all + 1] = l end
                            if f and f.grime then all[#all + 1] = f.grime end
                            for _, l in ipairs(all) do
                                assert(not l[1]:find("^blood") and not R.name(l):lower():find("blood"),
                                    "sangue no chão: " .. R.name(l) .. " d=" .. d)
                            end
                        end
                    end
                end
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
    -- tem vizinho queimado dos 4 lados: o ruído anda até ~0,3 por tile, o corte não garante 100%).
    -- Na vermelha, que mantém o chão de antes (sprint 0035: na branca a mancha de metal tem a vez
    -- e recorta o queimado)
    dressing_rules_burnt_patches = function()
        local R = load()
        for _, d in ipairs({ 1, 1.6, 2, 3.2 }) do
            local has, full, n, tot = {}, {}, 0, 0
            for x = 0, 89 do
                for y = 0, 89 do
                    local k = x .. "," .. y
                    for _, l in ipairs(R.floor(6000 + x, 6000 + y, 0, 4, d, false, true) or {}) do
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

    -- o nome só do mod (ninguém no vanilla anexa floors_burnt_01_*, ADR-017, nem as texturas
    -- nossas de media/textures/NOM/OutroMundo/, sprint 0035): R.own diz exatamente os nomes dos
    -- sets de queimado e dos sets próprios; o LoadGridsquare limpa por ele
    dressing_rules_own_prefix_burnt_and_own_sprites = function()
        local R = load()
        local burnt, own = 0, 0
        for setName, s in pairs(R.SETS) do
            for _, i in ipairs(s.idx) do
                local name = R.name({ setName, i })
                if s.own then
                    assert(name:sub(1, #NOM_OwnSpriteList.DIR) == NOM_OwnSpriteList.DIR, "nome próprio fora da pasta: " .. name)
                else
                    assert(name == s.prefix .. i)
                end
                local mine = setName:find("^burnt") ~= nil or s.own == true
                assert(R.own(name) == mine, "dono errado: " .. name)
                if setName:find("^burnt") then burnt = burnt + 1 end
                if s.own then own = own + 1 end
            end
        end
        assert(burnt >= 20, "poucos queimados: " .. burnt)
        assert(own == #NOM_OwnSpriteList.SPRITES, "sprites próprios nos sets: " .. own .. " de " .. #NOM_OwnSpriteList.SPRITES)
        assert(not R.own("overlay_blood_floor_01_3") and not R.own("blends_natural_01_5") and not R.own(nil))
        assert(not R.own("media/textures/NOM/NOM_Lascas.png"), "a pasta de fora não é do Outro Mundo")
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

    -- chão bem coberto na densidade 1 (sem o sangue, sprint 0034: medido ~66% vestido e ~1,3
    -- anexo por square vestido)
    dressing_rules_heavy_floor = function()
        local R = load()
        local n, layers = sweep(R, 7, 1, 60)
        assert(n >= 3600 * 0.55, "chão vazio demais: " .. n)
        assert(layers / n >= 1.2, "anexos por square: " .. layers / n)
    end,

    -- calibração pelo print do Johan (05/10, névoa vermelha, ~7×7 tiles na tela, "ainda não
    -- tá o outro mundo"): nenhum enquadramento assim fica limpo. Sem o sangue (sprint 0034) o
    -- pior medido caiu pra ~0,35 na normal e ~0,7 na vermelha
    dressing_rules_visible_at_close_zoom = function()
        local R = load()
        for _, red in ipairs({ false, true }) do
            local d = R.density(1, red)
            local worst = 1
            for k = 0, 39 do
                local cx, cy = 10700 + k * 37, 10200 + k * 53
                local n = 0
                for x = cx - 3, cx + 3 do
                    for y = cy - 3, cy + 3 do
                        if R.floor(x, y, 0, 9, d) then n = n + 1 end
                    end
                end
                worst = math.min(worst, n / 49)
            end
            assert(worst >= (red and 0.6 or 0.3), "enquadramento limpo demais: " .. worst)
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
        local red = select(2, sweep(R, 5, R.density(1, true), 50, true))
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
            for _, l in ipairs(f) do t[#t + 1] = l[1] .. l[2] end
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
            if s.wall and not s.own then -- os nossos: dressing_rules_own_sets_match_list
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
        for _, red in ipairs({ false, true }) do
            local walls, dressed, layers, three, n = 0, 0, 0, 0, {}
            for _, ls in pairs(wallsOf(R, false, 1, nil, nil, red)) do
                walls = walls + 1
                if ls then
                    dressed = dressed + 1
                    layers = layers + #ls
                    if #ls == 3 then three = three + 1 end
                    assert(#ls <= R.WALL_LAYERS, "camadas demais: " .. #ls)
                    local kinds, last = {}, -1
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
            local tone = red and "vermelha" or "branca"
            assert(dressed / walls >= 0.9, tone .. ": parede de dentro limpa: " .. dressed / walls)
            assert(layers / dressed >= 1.6, tone .. ": camadas por parede de dentro: " .. layers / dressed)
            assert(three / walls >= 0.1, tone .. ": pouca parede com 3 camadas: " .. three / walls)
            -- "apagadas, acabadas, sujas" (Johan): dentro, a sujeira não fica atrás do sangue
            assert((n.grime or 0) >= (n.blood or 0), tone .. ": sujeira " .. (n.grime or 0) .. ", sangue " .. (n.blood or 0))
        end
    end,

    -- fora: uma camada por lado, como antes, pichação entra. Na vermelha o sangue continua
    -- mandando; na branca (sprint 0035) manda o Silent Hill: tinta descascando e ferrugem
    dressing_rules_outside_walls_one_layer = function()
        local R = load()
        for _, red in ipairs({ false, true }) do
            local n, total = {}, 0
            for _, ls in pairs(wallsOf(R, true, 1, nil, nil, red)) do
                if ls then
                    assert(#ls == 1, "parede de fora com " .. #ls .. " camadas")
                    local k = wallKind(ls[1])
                    n[k] = (n[k] or 0) + 1
                    total = total + 1
                end
            end
            local writing = n.writing or 0
            assert(writing > 150, "pouca pichação fora: " .. writing)
            if red then
                for k, v in pairs(n) do
                    if k ~= "blood" then assert((n.blood or 0) > v, "sangue não manda fora: blood " .. (n.blood or 0) .. ", " .. k .. " " .. v) end
                end
            else
                local sh = (n.paint or 0) + (n.rust or 0)
                assert(sh > total * 0.45, "branca sem Silent Hill fora: " .. sh .. " de " .. total)
                assert((n.blood or 0) < (n.paint or 0) and (n.blood or 0) < (n.rust or 0), "sangue manda na branca")
            end
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

    -- sprint 0035, transição descascando: o atraso de revelação de cada square (0..1) vem de
    -- um ruído de manchas de alguns tiles. Dentro da faixa, espalhado (tem square que abre na
    -- hora e square que só abre no fim), em manchas (o vizinho abre perto do square), igual ao
    -- andar e voltar, outro com outro período
    dressing_rules_reveal_patches = function()
        local R = load()
        local n, early, late, step, steps, jump = 0, 0, 0, 0, 0, 0
        local first, diff = {}, 0
        for x = 0, 59 do
            for y = 0, 59 do
                local v = R.reveal(700 + x, 900 + y, 0, 3)
                assert(type(v) == "number" and v >= 0 and v <= 1, "fora de 0..1: " .. tostring(v))
                first[x .. "," .. y] = v
                n = n + 1
                if v < 0.2 then early = early + 1 end
                if v > 0.8 then late = late + 1 end
                if x > 0 then
                    local d = math.abs(v - first[(x - 1) .. "," .. y])
                    step, steps = step + d, steps + 1
                    if d > 0.35 then jump = jump + 1 end
                end
                if math.abs(v - R.reveal(700 + x, 900 + y, 0, 4)) > 0.1 then diff = diff + 1 end
            end
        end
        assert(early > n * 0.08 and late > n * 0.08, "pouco espalhado: cedo " .. early .. ", tarde " .. late .. " de " .. n)
        -- o vizinho de lado: perto (manchas), mas com a borda irregular (não liso de tile em tile)
        assert(step / steps < 0.15, "sem manchas: passo médio " .. step / steps)
        assert(jump < steps * 0.02, "salto entre vizinhos: " .. jump)
        assert(diff > n * 0.4, "período novo quase igual: " .. diff)
        R = load()
        for x = 0, 59, 7 do
            for y = 0, 59, 7 do assert(R.reveal(700 + x, 900 + y, 0, 3) == first[x .. "," .. y], "mudou sem mudar a entrada") end
        end
    end,

    -- sprint 0035, Tarefa 4b: os sets próprios saem da lista gerada (shared/NOM_OwnSpriteList,
    -- scripts/gen_tiles.py). Cada nome está na lista, no lado do set (chão em set de chão, W em
    -- parede W, N em parede N: a flag do sprite e o recorte do PNG são desse lado), e todo PNG da
    -- lista está em algum set
    dressing_rules_own_sets_match_list = function()
        local R = load()
        local L = NOM_OwnSpriteList
        local byName, used = {}, {}
        for _, s in ipairs(L.SPRITES) do byName[s.name] = s end
        local kinds = {}
        for setName, s in pairs(R.SETS) do
            if s.own then
                assert(#s.idx >= 4, "set próprio pequeno: " .. setName)
                local kind
                for _, i in ipairs(s.idx) do
                    local name = R.name({ setName, i })
                    local e = byName[name]
                    assert(e, "nome fora da lista: " .. tostring(name))
                    assert(e.side == (s.wall or "F"), name .. " (lado " .. e.side .. ") no set " .. setName)
                    assert(kind == nil or e.kind == kind, "set misturado: " .. setName)
                    kind = e.kind
                    assert(not used[name], "nome em dois sets: " .. name)
                    used[name] = true
                end
                kinds[setName] = kind
            end
        end
        for _, s in ipairs(L.SPRITES) do assert(used[s.name], "PNG sem set: " .. s.name) end
        assert(kinds.grateFloor == "Grade" and kinds.plateFloor == "Chapa" and kinds.rustFloor == "Ferrugem"
            and kinds.paintFloor == "Tinta", "sets de chão")
        assert(kinds.ashFloor == "Cinza" and kinds.emberFloor == "Brasa", "sets de chão da preta")
        for _, side in ipairs({ "W", "N" }) do
            assert(kinds["paintWall" .. side] == "Tinta" and kinds["peelWall" .. side] == "Descasca"
                and kinds["rustWall" .. side] == "Ferrugem" and kinds["sootWall" .. side] == "Fuligem",
                "sets de parede " .. side)
        end
    end,

    -- a parede só ganha sprite próprio do lado dela, nas duas cores, dentro e fora (sprite W na
    -- parede N cai fora da face e com a profundidade da outra parede)
    dressing_rules_own_wall_side = function()
        local R = load()
        local byName = {}
        for _, s in ipairs(NOM_OwnSpriteList.SPRITES) do byName[s.name] = s end
        local own = 0
        for _, red in ipairs({ false, true }) do
            for _, outside in ipairs({ false, true }) do
                for key, ls in pairs(wallsOf(R, outside, 1.5, 4, 40, red)) do
                    local side = key:sub(-1)
                    for _, l in ipairs(ls or {}) do
                        local e = byName[R.name(l)]
                        if e then
                            own = own + 1
                            assert(e.side == side, R.name(l) .. " na parede " .. side)
                        end
                    end
                end
            end
        end
        assert(own > 1000, "pouco sprite próprio em parede: " .. own)
    end,

    -- "mais Silent Hill" (Johan, 06/10): na branca o chão ganha metal (grade, chapa, ferrugem,
    -- tinta lascada); a grade é a mais comum; as paredes de dentro descascam e enferrujam.
    -- Hotfix do chão: dentro, ~15% do chão (era 37%), os quatro tipos; no pavimento de fora,
    -- ~3% (era 37%), peça solta de grade, ferrugem ou tinta, sem chapa
    dressing_rules_white_favors_silent_hill = function()
        local R = load()
        local cases = {
            { outside = false, lo = 0.1, hi = 0.22, sets = { "grateFloor", "plateFloor", "rustFloor", "paintFloor" }, min = 50 },
            { outside = true, lo = 0.015, hi = 0.06, sets = { "grateFloor", "rustFloor", "paintFloor" }, min = 5 },
        }
        for _, c in ipairs(cases) do
            local n, metal, by = 0, 0, {}
            for x = 0, 79 do
                for y = 0, 79 do
                    n = n + 1
                    local f = R.floor(11000 + x, 12000 + y, 0, 5, 1, c.outside, false, false)
                    local any = false
                    for _, l in ipairs(f or {}) do
                        if isOwnSet(R, l[1]) then
                            any = true
                            by[l[1]] = (by[l[1]] or 0) + 1
                        end
                    end
                    if any then metal = metal + 1 end
                end
            end
            local where = c.outside and "fora" or "dentro"
            assert(metal / n >= c.lo and metal / n <= c.hi, where .. ": metal no chão " .. metal / n)
            for _, s in ipairs(c.sets) do
                assert((by[s] or 0) > c.min, where .. ": pouco " .. s .. " (" .. (by[s] or 0) .. ")")
            end
            for k, v in pairs(by) do
                if k ~= "grateFloor" then assert(by.grateFloor > v, where .. ": grade não é a mais comum (" .. k .. ")") end
            end
        end
        local walls, sh = 0, 0
        for _, ls in pairs(wallsOf(R, false, 1, 6, 60, false)) do
            if ls then
                walls = walls + 1
                for _, l in ipairs(ls) do
                    if isOwnSet(R, l[1]) then
                        sh = sh + 1
                        break
                    end
                end
            end
        end
        assert(sh / walls >= 0.6, "branca: parede de dentro sem Silent Hill " .. sh / walls)
    end,

    -- dentro, o metal vem em manchas (o chão inteiro de grade leria como textura repetida) e,
    -- dentro da mancha, em painéis do mesmo tipo. Hotfix do chão: a mancha é quebrada por tile,
    -- então a troca entre vizinhos fica mais perto do sorteio por tile (medido 0,72; era < 0,6);
    -- a mancha aparece na escala do bloco: a variância da contagem em blocos 6×6 é ~5,5× a de
    -- um sorteio por tile
    dressing_rules_metal_patches = function()
        local R = load()
        local has, kind, n, tot = {}, {}, 0, 0
        for x = 0, 89 do
            for y = 0, 89 do
                local k = x .. "," .. y
                for _, l in ipairs(R.floor(13000 + x, 9000 + y, 0, 3, 1, false, false) or {}) do
                    if isOwnSet(R, l[1]) then
                        has[k], kind[k] = true, l[1]
                    end
                end
                if has[k] then n = n + 1 end
                tot = tot + 1
            end
        end
        local p = n / tot
        local flips, pairs_, same, both = 0, 0, 0, 0
        for x = 0, 88 do
            for y = 0, 88 do
                for _, o in ipairs({ { 1, 0 }, { 0, 1 } }) do
                    local a, b = x .. "," .. y, (x + o[1]) .. "," .. (y + o[2])
                    pairs_ = pairs_ + 1
                    if (has[a] or false) ~= (has[b] or false) then flips = flips + 1 end
                    if has[a] and has[b] then
                        both = both + 1
                        if kind[a] == kind[b] then same = same + 1 end
                    end
                end
            end
        end
        assert(flips / pairs_ / (2 * p * (1 - p)) < 0.85, "metal tile a tile")
        assert(same / both > 0.6, "vizinhos de metal com tipo trocado demais: " .. same / both)
        local B, sum, sum2, nb = 6, 0, 0, 0
        for bx = 0, 89 - B, B do
            for by = 0, 89 - B, B do
                local c = 0
                for i = 0, B - 1 do
                    for j = 0, B - 1 do
                        if has[(bx + i) .. "," .. (by + j)] then c = c + 1 end
                    end
                end
                sum, sum2, nb = sum + c, sum2 + c * c, nb + 1
            end
        end
        local mean = sum / nb
        local ratio = (sum2 / nb - mean * mean) / (B * B * p * (1 - p))
        assert(ratio > 3, "metal sem mancha na escala do bloco: " .. ratio)
    end,

    -- vermelha: o sangue de parede fica (manda fora), a parede ganha ferrugem, o chão ganha
    -- ferrugem em manchas; sem grade, chapa nem tinta (isso é da branca) e sem sangue no chão
    dressing_rules_red_keeps_wall_blood_gains_rust = function()
        local R = load()
        local d = R.density(1, true)
        local floorRust, other = 0, 0
        for x = 0, 79 do
            for y = 0, 79 do
                for _, outside in ipairs({ false, true }) do
                    for _, l in ipairs(R.floor(14000 + x, 3000 + y, 0, 5, d, outside, true) or {}) do
                        if l[1] == "rustFloor" then floorRust = floorRust + 1 elseif isOwnSet(R, l[1]) then other = other + 1 end
                    end
                end
            end
        end
        assert(floorRust > 300, "vermelha sem ferrugem no chão: " .. floorRust)
        assert(other == 0, "metal da branca na vermelha: " .. other)
        local blood, rust = 0, 0
        for _, outside in ipairs({ false, true }) do
            for _, ls in pairs(wallsOf(R, outside, d, 5, 60, true)) do
                for _, l in ipairs(ls or {}) do
                    if wallKind(l) == "blood" then blood = blood + 1 end
                    if wallKind(l) == "rust" then rust = rust + 1 end
                end
            end
        end
        assert(blood > 1000, "vermelha sem sangue de parede: " .. blood)
        assert(rust > 400 and rust < blood, "ferrugem na parede vermelha: " .. rust .. " (sangue " .. blood .. ")")
    end,

    -- a cor entra no sorteio sem tirar o determinismo: mesma entrada, mesma resposta, nas duas
    -- cores; branca e vermelha dão desenhos diferentes no mesmo square
    dressing_rules_tone_deterministic = function()
        local R = load()
        local function key(ls)
            if not ls then return "-" end
            local t = {}
            for _, l in ipairs(ls) do t[#t + 1] = l[1] .. l[2] end
            return table.concat(t, ";")
        end
        local first, diff = {}, 0
        for x = 0, 29 do
            for y = 0, 29 do
                for _, red in ipairs({ false, true }) do
                    first[x .. "," .. y .. tostring(red)] = key(R.floor(1500 + x, 1600 + y, 0, 3, 1, false, red))
                        .. "|" .. key(R.wall(1500 + x, 1600 + y, 0, 3, 1, x % 2 == 0, false, red))
                end
            end
        end
        R = load()
        for x = 0, 29 do
            for y = 0, 29 do
                for _, red in ipairs({ false, true }) do
                    local k = key(R.floor(1500 + x, 1600 + y, 0, 3, 1, false, red))
                        .. "|" .. key(R.wall(1500 + x, 1600 + y, 0, 3, 1, x % 2 == 0, false, red))
                    assert(k == first[x .. "," .. y .. tostring(red)], "mudou sem mudar a entrada")
                end
                if first[x .. "," .. y .. "false"] ~= first[x .. "," .. y .. "true"] then diff = diff + 1 end
            end
        end
        assert(diff > 450, "branca e vermelha quase iguais: " .. diff)
    end,

    -- HOTFIX DO CHÃO (teste do Johan, 06/10) ----------------------------------------------------
    -- Na branca o metal ia em qualquer chão: na calçada, painéis 4×4 inteiros (quadrados escuros
    -- em xadrez); na grama, ferrugem e tinta em todo tile da mancha (cada decalque centrado no
    -- losango: uma grade de bolotas marrons).

    -- o nome do piso natural é a conta do IsoGridSquare.hasNaturalFloor (bytecode do B42.21):
    -- começa com blends_natural_01 (grama, terra, areia, barro) ou floors_exterior_natural
    dressing_rules_natural_names = function()
        local R = load()
        for _, n in ipairs({ "blends_natural_01_16", "blends_natural_01_64", "blends_natural_01_0",
            "floors_exterior_natural_01_13" }) do
            assert(R.natural(n) == true, "não é natural: " .. n)
        end
        for _, n in ipairs({ "blends_street_01_0", "floors_exterior_street_01_0", "floors_interior_tilesandwood_01_0",
            "blends_natural_02_0", "", "xblends_natural_01_16" }) do
            assert(R.natural(n) == false, "natural: " .. n)
        end
        assert(R.natural(nil) == false and R.natural(7) == false, "nome que não é string")
    end,

    -- piso natural não ganha metal, ferrugem nem tinta, nas duas cores, dentro e fora; fica o
    -- que havia antes da 0035 (mato, folha, sujeira, rachadura)
    dressing_rules_natural_floor_no_metal = function()
        local R = load()
        local plants = 0
        for _, c in ipairs({ { 1, false }, { 2, false }, { R.density(1, true), true }, { R.density(2, true), true } }) do
            for _, outside in ipairs({ true, false }) do
                for x = 0, 69 do
                    for y = 0, 69 do
                        for _, l in ipairs(R.floor(15000 + x, 16000 + y, 0, 5, c[1], outside, c[2], true) or {}) do
                            assert(not isOwnSet(R, l[1]), "textura nossa em piso natural: " .. R.name(l))
                            if isPlant(R.name(l)) then plants = plants + 1 end
                        end
                    end
                end
            end
        end
        assert(plants > 1000, "a grama perdeu o mato: " .. plants)
    end,

    -- o cliente só lê o nome do piso (uma ida ao Java) quando a regra pôs textura nossa: o
    -- natural só tira metal, ferrugem e tinta; sem elas, a resposta é a mesma
    dressing_rules_natural_only_drops_own = function()
        local R = load()
        local function key(f)
            if not f then return "-" end
            local t = {}
            for _, l in ipairs(f) do t[#t + 1] = l[1] .. l[2] end
            if f.grime then t[#t + 1] = "g" .. f.grime[2] end
            return table.concat(t, ";")
        end
        assert(R.hasOwn(nil) == false, "hasOwn(nil)")
        local dropped = 0
        for _, c in ipairs({ { 1, false }, { 2, false }, { R.density(2, true), true } }) do
            for _, outside in ipairs({ true, false }) do
                for x = 0, 49 do
                    for y = 0, 49 do
                        local a = R.floor(19000 + x, 2000 + y, 0, 4, c[1], outside, c[2])
                        local b = R.floor(19000 + x, 2000 + y, 0, 4, c[1], outside, c[2], true)
                        assert(not R.hasOwn(b), "natural com textura nossa")
                        if R.hasOwn(a) then
                            dropped = dropped + 1
                        else
                            assert(key(a) == key(b), "natural mudou um chão sem textura nossa")
                        end
                    end
                end
            end
        end
        assert(dropped > 100, "pouca textura nossa (teste não mede): " .. dropped)
    end,

    -- calçada e rua (fora, não natural): peça solta e rara, como bueiro. Nenhuma textura nossa
    -- ao lado de outra (4-vizinhança), sem chapa, e no máximo 6% do chão em qualquer densidade
    -- da branca (o teto do hotfix; era 37% a d=1)
    dressing_rules_pavement_metal_isolated = function()
        local R = load()
        local by = {}
        for _, d in ipairs({ 0.5, 1, 2 }) do
            local has, n, own = {}, 0, 0
            for dx = -60, 60 do
                for dy = -60, 60 do
                    if dx * dx + dy * dy <= 3600 then
                        n = n + 1
                        for _, l in ipairs(R.floor(17000 + dx, 18000 + dy, 0, 6, d, true, false, false) or {}) do
                            if isOwnSet(R, l[1]) then
                                has[dx .. "," .. dy] = true
                                by[l[1]] = (by[l[1]] or 0) + 1
                            end
                        end
                        if has[dx .. "," .. dy] then own = own + 1 end
                    end
                end
            end
            for dx = -60, 60 do
                for dy = -60, 60 do
                    if has[dx .. "," .. dy] then
                        assert(not has[(dx + 1) .. "," .. dy] and not has[dx .. "," .. (dy + 1)],
                            "metal vizinho na calçada em " .. dx .. "," .. dy .. " d=" .. d)
                    end
                end
            end
            assert(own / n <= 0.06, "calçada com metal demais: d=" .. d .. " " .. own / n)
            assert(own / n >= 0.01, "calçada sem metal: d=" .. d .. " " .. own / n)
        end
        assert(not by.plateFloor, "chapa na calçada")
        assert((by.grateFloor or 0) > 20 and (by.rustFloor or 0) > 10, "grade " .. tostring(by.grateFloor)
            .. ", ferrugem " .. tostring(by.rustFloor))
    end,

    -- dentro de casa o metal fica, quebrado: nenhuma janela 3×3 cheia (nem painel 4×4), menos
    -- cobertura que na 0035 (37% a d=1; agora ~16%, ~19% a d=2, teto 22%) e ferrugem/tinta
    -- espalhadas, sem grade de manchas
    dressing_rules_inside_metal_broken = function()
        local R = load()
        local S = 100
        for _, d in ipairs({ 1, 2 }) do
            local has, n, own, spots = {}, 0, 0, 0
            for x = 0, S - 1 do
                for y = 0, S - 1 do
                    n = n + 1
                    for _, l in ipairs(R.floor(21000 + x, 22000 + y, 0, 3, d, false, false, false) or {}) do
                        if isOwnSet(R, l[1]) then
                            has[x * S + y] = true
                            if l[1] == "rustFloor" or l[1] == "paintFloor" then spots = spots + 1 end
                        end
                    end
                    if has[x * S + y] then own = own + 1 end
                end
            end
            for x = 0, S - 3 do
                for y = 0, S - 3 do
                    local full = true
                    for i = 0, 2 do
                        for j = 0, 2 do
                            if not has[(x + i) * S + y + j] then full = false end
                        end
                    end
                    assert(not full, "bloco 3×3 cheio de metal em " .. x .. "," .. y .. " d=" .. d)
                end
            end
            assert(own / n <= 0.22 and own / n >= 0.08, "metal dentro: d=" .. d .. " " .. own / n)
            assert(spots / n <= 0.05, "ferrugem e tinta dentro: d=" .. d .. " " .. spots / n)
        end
    end,

    -- NÉVOA PRETA (sprint 0039) -----------------------------------------------------------------
    -- "Chão queimado, cinzas, brasas apagando" (spec §1): queimado dentro e fora (fora no lugar
    -- do mato), sem metal; cinza em manchas e brasa rara por cima. Na parede a fuligem manda, com
    -- sujeira e rachadura; sem tinta, ferrugem nem trepadeira.
    dressing_rules_black_burnt_world = function()
        local R = load()
        local d = R.density(1, false, true)
        assert(d == R.BLACK_MULT, "densidade da preta: " .. d)
        for _, outside in ipairs({ false, true }) do
            local n, burnt, ash, ember, bad, tiles = {}, 0, 0, 0, 0, 0
            for x = 0, 79 do
                for y = 0, 79 do
                    tiles = tiles + 1
                    for _, l in ipairs(R.floor(31000 + x, 32000 + y, 0, 5, d, outside, false, false, true) or {}) do
                        n[l[1]] = (n[l[1]] or 0) + 1
                        if l[1]:find("^burntFloor") then burnt = burnt + 1
                        elseif l[1] == "ashFloor" then ash = ash + 1
                        elseif l[1] == "emberFloor" then ember = ember + 1
                        elseif isOwnSet(R, l[1]) or isPlant(R.name(l)) then bad = bad + 1 end
                    end
                end
            end
            local where = outside and "fora" or "dentro"
            assert(bad == 0, "metal ou mato na preta " .. where .. ": " .. bad)
            assert(burnt / tiles > 0.25, "pouco queimado " .. where .. ": " .. burnt / tiles)
            assert(ash / tiles > 0.08 and ash / tiles < 0.4, "cinza " .. where .. ": " .. ash / tiles)
            assert(ember > 0 and ember < ash / 3, "brasa " .. where .. ": " .. ember .. " (cinza " .. ash .. ")")
        end
        local byKind = {}
        for _, outside in ipairs({ false, true }) do
            for x = 0, 59 do
                for y = 0, 59 do
                    for _, north in ipairs({ true, false }) do
                        for _, l in ipairs(R.wall(33000 + x, 34000 + y, 0, 5, d, north, outside, false, true) or {}) do
                            local k = wallKind(l)
                            byKind[k] = (byKind[k] or 0) + 1
                            if k == "soot" then
                                assert(l[1] == "sootWall" .. (north and "N" or "W"), "fuligem do lado errado: " .. l[1])
                            end
                        end
                    end
                end
            end
        end
        local soot = byKind.soot or 0
        for k, v in pairs(byKind) do
            assert(k == "soot" or k == "grime" or k == "cracks" or k == "writing", "parede preta com " .. k .. ": " .. v)
            if k ~= "soot" then assert(v < soot, "fuligem não manda: " .. k .. " " .. v .. " × " .. soot) end
        end
        assert(soot > 2000, "pouca fuligem: " .. soot)
    end,

    -- a preta é determinística e diferente da branca e da vermelha no mesmo square
    dressing_rules_black_differs_and_deterministic = function()
        local R = load()
        local function key(ls)
            if not ls then return "-" end
            local t = {}
            for _, l in ipairs(ls) do t[#t + 1] = l[1] .. l[2] end
            return table.concat(t, ";")
        end
        local diffW, diffR = 0, 0
        for x = 0, 29 do
            for y = 0, 29 do
                local b = key(R.floor(1500 + x, 1600 + y, 0, 3, 1, false, false, false, true))
                assert(b == key(R.floor(1500 + x, 1600 + y, 0, 3, 1, false, false, false, true)), "mudou sem mudar a entrada")
                if b ~= key(R.floor(1500 + x, 1600 + y, 0, 3, 1, false)) then diffW = diffW + 1 end
                if b ~= key(R.floor(1500 + x, 1600 + y, 0, 3, 1, false, true)) then diffR = diffR + 1 end
            end
        end
        assert(diffW > 300 and diffR > 300, "preta quase igual: branca " .. diffW .. ", vermelha " .. diffR)
    end,
}
