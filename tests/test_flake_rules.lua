-- shared/NOM_FlakeRules.lua (sprint 0035): lascas de tinta e cinza que sobem do chão e das
-- paredes no Outro Mundo, puro. Posições do movimento em pixels de tela no zoom 1, relativas
-- ao ponto onde a lasca nasceu (y negativo = pra cima); o rand vem por parâmetro.
require "NOM_FlakeRules"

local R = NOM_FlakeRules

-- Park–Miller pra o teste ter o mesmo sorteio sempre
local function seq(seed)
    local s = seed or 7
    return function()
        s = (s * 16807) % 2147483647
        return s / 2147483647
    end
end

local function src(list, px, py, pz)
    return R.sources(list, px or 0, py or 0, pz or 0)
end

-- um bloco de squares de chão e de parede em volta de (0, 0)
local function field(n, kinds)
    local out = {}
    for x = -n, n do
        for y = -n, n do
            for _, k in ipairs(kinds or { "F" }) do out[#out + 1] = { x = x, y = y, z = 0, kind = k } end
        end
    end
    return out
end

local function run(state, ms, rate, s, rand, step)
    step = step or 16
    local born = 0
    for _ = 1, math.floor(ms / step) do born = born + R.step(state, step, rate, s, rand) end
    return born
end

return {
    -- densidade 0 (ou intensidade 0) = nada nasce
    flakes_density_zero_nothing = function()
        assert(R.rate(0, 1) == 0 and R.rate(1, 0) == 0 and R.rate(-1, 1) == 0)
        assert(R.rate(1, 1) > 0)
        local st = R.new()
        run(st, 10000, R.rate(0, 1), src(field(3)), seq())
        assert(R.count(st) == 0, "nasceu com densidade 0")
    end,

    -- a taxa sobe com a densidade e a intensidade, até o teto de nascimentos
    flakes_rate_scales_and_caps = function()
        assert(R.rate(2, 1) > R.rate(1, 1) and R.rate(1, 2) > R.rate(1, 1))
        assert(R.rate(100, 2) == R.BIRTHS_PER_S, "sem teto de nascimentos")
    end,

    -- nunca mais que MAX vivas, nem mais que BIRTHS_PER_S nascimentos por segundo
    flakes_cap = function()
        local st, s, rand = R.new(), src(field(5, { "F", "N", "W" })), seq(3)
        for sec = 1, 20 do
            local born = run(st, 1000, 1e9, s, rand)
            assert(born <= R.BIRTHS_PER_S + 1, "segundo " .. sec .. ": " .. born .. " nascimentos")
            assert(R.count(st) <= R.MAX, "vivas " .. R.count(st))
        end
        assert(R.count(st) >= R.MAX * 0.8, "não encheu: " .. R.count(st))
    end,

    -- vida de 3 a 7 s; morta depois da vida
    flakes_life = function()
        local st, rand = R.new(), seq(11)
        run(st, 3000, R.rate(1, 1), src(field(3, { "F", "N" })), rand)
        assert(R.count(st) > 10)
        for _, p in ipairs(st.parts) do
            assert(p.life >= R.LIFE_MIN_MS and p.life <= R.LIFE_MAX_MS, "vida " .. p.life)
            assert(R.at(p, p.life - 1) ~= nil, "morreu antes da vida")
            assert(R.at(p, p.life) == nil, "viva depois da vida")
        end
    end,

    -- nasce no ponto (dx = dy = 0), sobe devagar e deriva pro lado com o vento, ondulando
    flakes_rise_and_drift = function()
        local rand = seq(5)
        local wavy, downwind = 0, 0
        for i = 1, 60 do
            local kind = i % 2 == 0 and "lasca" or "cinza"
            local p = R.spawn({ x = 0, y = 0, z = 0, kind = "F" }, 0, rand, kind)
            local x0, y0 = R.at(p, 0)
            assert(math.abs(x0) < 1e-9 and math.abs(y0) < 1e-9, "não nasce no ponto")
            local x1, y1 = R.at(p, 1000)
            local x2, y2 = R.at(p, 2000)
            assert(y1 < 0 and y2 < y1, "não sobe")
            assert(-y1 <= R.MAX_RISE, "sobe rápido demais: " .. -y1 .. " px/s")
            local xe = R.at(p, R.LIFE_MIN_MS - 1)
            if xe * R.WIND_SIGN > 0 then downwind = downwind + 1 end
            if math.abs((x2 - x1) - x1) > 0.5 then wavy = wavy + 1 end
        end
        assert(downwind >= 55, "não deriva com o vento: " .. downwind .. " de 60")
        assert(wavy > 30, "deriva sem ondular: " .. wavy)
    end,

    -- a lasca gira pelos quadros do sprite sheet; a cinza é menor
    flakes_frames_and_sizes = function()
        local rand = seq(9)
        for _ = 1, 40 do
            local p = R.spawn({ x = 0, y = 0, z = 0, kind = "N" }, 0, rand, "lasca")
            assert(p.shape >= 0 and p.shape < R.SHAPES and p.shape == math.floor(p.shape), "formato " .. p.shape)
            local seen, n = {}, 0
            for ms = 0, p.life - 1, 50 do
                local _, _, _, f = R.at(p, ms)
                assert(f >= 0 and f < R.FRAMES and f == math.floor(f), "quadro " .. tostring(f))
                if not seen[f] then seen[f], n = true, n + 1 end
            end
            assert(n >= 4, "girou pouco: " .. n .. " quadros")
            local c = R.spawn({ x = 0, y = 0, z = 0, kind = "N" }, 0, rand, "cinza")
            local _, _, _, _, ls = R.at(p, 100)
            local _, _, _, _, cs = R.at(c, 100)
            assert(cs < ls, "cinza maior que a lasca")
        end
    end,

    -- cinza mais numerosa que lasca
    flakes_ash_more_numerous = function()
        local st = R.new()
        run(st, 4000, R.rate(1, 1), src(field(4, { "F", "N" })), seq(13))
        local ash, chip = 0, 0
        for _, p in ipairs(st.parts) do if p.type == "cinza" then ash = ash + 1 else chip = chip + 1 end end
        assert(chip > 0 and ash > chip, "cinza " .. ash .. " lasca " .. chip)
    end,

    -- aparece e some com fade
    flakes_fade = function()
        local rand = seq(17)
        for _ = 1, 30 do
            local p = R.spawn({ x = 0, y = 0, z = 0, kind = "F" }, 0, rand)
            local _, _, a0 = R.at(p, 0)
            local _, _, am = R.at(p, p.life * 0.45)
            local _, _, ae = R.at(p, p.life - 20)
            assert(a0 < 0.1, "nasce aceso: " .. a0)
            assert(am > 0.4 and am <= 1, "meio apagado: " .. am)
            assert(ae < 0.1, "some sem fade: " .. ae)
        end
    end,

    -- vermelha: lasca mais escura e puxada pro vermelho; a cor sem caso vira a branca
    flakes_palette = function()
        local w, r = R.palette("white"), R.palette("red")
        for _, t in ipairs({ "lasca", "cinza" }) do
            assert(#w[t] == 3 and #r[t] == 3, "cor de " .. t)
        end
        local function sum(c) return c[1] + c[2] + c[3] end
        assert(sum(r.lasca) < sum(w.lasca), "a vermelha não escurece")
        assert(r.lasca[1] / r.lasca[2] > w.lasca[1] / w.lasca[2] + 0.3, "a vermelha não avermelha")
        assert(sum(w.cinza) > 1.8, "cinza da branca não é clara")
        local x = R.palette("nada")
        assert(x.lasca[1] == w.lasca[1] and x.cinza[3] == w.cinza[3], "cor sem caso")
    end,

    -- a parede solta mais que o chão (mesmo número de squares)
    flakes_walls_shed_more = function()
        local list = {}
        for i = 1, 30 do
            list[#list + 1] = { x = i - 15, y = 0, z = 0, kind = "F" }
            list[#list + 1] = { x = i - 15, y = 1, z = 0, kind = i % 2 == 0 and "N" or "W" }
        end
        local st, wall, floor = R.new(), 0, 0
        local s, rand = src(list), seq(19)
        for _ = 1, 40 do
            run(st, 1000, R.rate(1, 1), s, rand)
            for _, p in ipairs(st.parts) do
                if p.born > st.t - 1000 then
                    if p.from == "F" then floor = floor + 1 else wall = wall + 1 end
                end
            end
        end
        assert(wall > floor * 2, "parede " .. wall .. " chão " .. floor)
    end,

    -- só squares do andar e a até RADIUS tiles; sem fonte, nada nasce
    flakes_sources_radius_and_floor = function()
        local list = { { x = 100 + R.RADIUS + 3, y = 100, z = 0, kind = "F" }, { x = 101, y = 100, z = 1, kind = "N" },
            { x = 103, y = 102, z = 0, kind = "W" } }
        local s = R.sources(list, 100, 100, 0)
        assert(#s.items == 1 and s.items[1].kind == "W", "fonte errada: " .. #s.items)
        local st = R.new()
        run(st, 5000, R.rate(2, 2), R.sources({}, 0, 0, 0), seq())
        assert(R.count(st) == 0, "nasceu sem fonte")
        run(st, 5000, R.rate(2, 2), nil, seq())
        assert(R.count(st) == 0, "nasceu sem lista")
    end,

    -- onde nasce: no chão, dentro do square; na parede N, na linha de cima do square; na W, na
    -- da esquerda; do pé até meia parede
    flakes_spawn_spot = function()
        local rand = seq(23)
        for _ = 1, 50 do
            local f = R.spawn({ x = 4, y = 7, z = 1, kind = "F" }, 0, rand)
            assert(f.x >= 4 and f.x < 5 and f.y >= 7 and f.y < 8 and f.z == 1, "chão fora do square")
            local n = R.spawn({ x = 4, y = 7, z = 1, kind = "N" }, 0, rand)
            assert(n.x >= 4 and n.x < 5 and n.y == 7 and n.z >= 1 and n.z <= 1 + R.WALL_HEIGHT, "parede N")
            local w = R.spawn({ x = 4, y = 7, z = 1, kind = "W" }, 0, rand)
            assert(w.y >= 7 and w.y < 8 and w.x == 4 and w.z >= 1 and w.z <= 1 + R.WALL_HEIGHT, "parede W")
            assert(f.from == "F" and n.from == "N" and w.from == "W")
        end
    end,

    -- rajada (a Tarefa 2 pede quando o square é revelado): respeita o teto
    flakes_burst_cap = function()
        local st, rand = R.new(), seq(29)
        assert(R.burst(st, 10, { x = 1, y = 1, z = 0, kind = "N" }, rand) == 10)
        assert(R.count(st) == 10)
        assert(R.burst(st, R.MAX, { x = 1, y = 1, z = 0, kind = "F" }, rand) == R.MAX - 10)
        assert(R.burst(st, 5, { x = 1, y = 1, z = 0, kind = "F" }, rand) == 0, "passou do teto")
        assert(R.count(st) == R.MAX)
        assert(R.burst(st, 0, { x = 1, y = 1, z = 0 }, rand) == 0)
    end,

    -- a taxa vai a 0: as vivas terminam o fade e somem
    flakes_end_fades_out = function()
        local st, rand, s = R.new(), seq(31), src(field(4, { "F", "N" }))
        run(st, 5000, R.rate(1, 1), s, rand)
        local before = R.count(st)
        assert(before > 0)
        local born = run(st, 1000, 0, s, rand)
        assert(born == 0 and R.count(st) <= before and R.count(st) > 0, "parou de golpe ou nasceu")
        run(st, R.LIFE_MAX_MS, 0, s, rand)
        assert(R.count(st) == 0, "sobrou " .. R.count(st))
    end,

    -- o quadro longo não despeja a fila de uma vez (o resto além da vaga se perde)
    flakes_capped_debt_does_not_spike = function()
        local st, rand, s = R.new(), seq(37), src(field(4))
        run(st, 10000, 1e9, s, rand)
        local full = R.count(st)
        assert(full == R.MAX or full > R.MAX * 0.9)
        R.step(st, 16, 0, s, rand)
        assert(st.debt < 1, "dívida acumulada no teto: " .. st.debt)
    end,

    -- o sorteio próprio (o Kahlua não tem math.random): [0, 1), pela semente, e a semente do
    -- relógio (~1.76e12) não estoura
    flakes_rng = function()
        local a, b = R.rng(1759999999123), R.rng(1759999999123)
        local sum = 0
        for _ = 1, 2000 do
            local u = a()
            assert(u >= 0 and u < 1 and u == b(), "fora de [0, 1) ou não determinístico")
            sum = sum + u
        end
        assert(math.abs(sum / 2000 - 0.5) < 0.05, "média " .. sum / 2000)
        assert(R.rng(1)() ~= R.rng(2)(), "semente não muda nada")
    end,

    -- o mesmo rand dá o mesmo resultado (testável); outro rand muda
    flakes_rand_injected = function()
        local function shot(seed)
            local st = R.new()
            run(st, 2000, R.rate(1, 1), src(field(3, { "F", "W" })), seq(seed))
            local out = {}
            for _, p in ipairs(st.parts) do out[#out + 1] = string.format("%.4f,%.4f,%s", p.x, p.y, p.type) end
            return table.concat(out, ";")
        end
        assert(shot(41) == shot(41), "mesmo rand, resultado diferente")
        assert(shot(41) ~= shot(43), "rand não muda nada")
    end,
}
