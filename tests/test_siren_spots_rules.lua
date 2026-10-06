-- shared/NOM_SirenSpotsRules.lua (puro): onde tocam as 5 sirenes de cada jogador, todas
-- longe (150 a 500 tiles), qual som e com que atraso.
require "NOM_SirenSpotsRules"

local R = NOM_SirenSpotsRules

-- rand em [0, 1) reproduzível (o cliente usa ZombRand(10000) / 10000)
local function lcg(seed)
    local s = seed
    return function()
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648
    end
end

local function const(v) return function() return v end end

local function gap(a, b)
    local d = math.abs(a - b) % 360
    return math.min(d, 360 - d)
end

local function angle(s, px, py)
    return math.deg(math.atan2(s.y - py, s.x - px))
end

local function has(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- confere o que vale pra qualquer sorteio
local function check(spots, px, py, kind)
    local sounds = R.SOUNDS[kind] or R.SOUNDS.white
    assert(#spots == R.COUNT, "sirenes: " .. #spots)
    local seen = {}
    for i, s in ipairs(spots) do
        local d = math.sqrt((s.x - px) ^ 2 + (s.y - py) ^ 2)
        assert(math.abs(d - s.dist) < 1e-6, "dist não bate com a posição")
        assert(d >= R.DIST_MIN - 1e-6 and d <= R.DIST_MAX + 1e-6, "sirene a " .. d .. " tiles")
        assert(s.near == nil, "ainda tem sirene perto")
        assert(has(sounds, s.sound), kind .. " com som de outra névoa: " .. s.sound)
        assert(type(s.pitch) == "number" and s.pitch >= R.PITCH_MIN - 1e-9 and s.pitch <= R.PITCH_MAX + 1e-9,
            "afinação " .. tostring(s.pitch))
        assert(not seen[s.sound], "repetiu no coro: " .. s.sound)
        seen[s.sound] = true
        if i == 1 then
            assert(s.delayMs == 0, "a primeira com atraso " .. s.delayMs)
        else
            assert(s.delayMs <= R.DELAY_MAX_MS, "atraso " .. s.delayMs)
            assert(s.delayMs - spots[i - 1].delayMs >= R.DELAY_MIN_GAP_MS - 1e-6,
                "duas entrando juntas: " .. spots[i - 1].delayMs .. " e " .. s.delayMs)
        end
    end
    for i = 1, #spots do
        for j = i + 1, #spots do
            local g = gap(angle(spots[i], px, py), angle(spots[j], px, py))
            assert(g >= R.MIN_GAP_DEG - 1e-6, "duas sirenes a " .. g .. "° uma da outra")
        end
    end
end

return {
    -- pedido do Johan (2026-10-06): 5 sirenes, todas longe, de lados diferentes, desencontradas
    siren_spots_parameters = function()
        assert(R.COUNT == 5, "COUNT " .. R.COUNT)
        assert(R.DIST_MIN == 150 and R.DIST_MAX == 500, "faixa " .. R.DIST_MIN .. "–" .. R.DIST_MAX)
        assert(R.MIN_GAP_DEG >= 40 and R.COUNT * R.MIN_GAP_DEG <= 360, "folga " .. R.MIN_GAP_DEG)
        assert(R.DELAY_MAX_MS <= 4000 and R.DELAY_MIN_GAP_MS > 0, "atrasos")
        assert(R.NEAR_MIN == nil and R.FAR_MIN == nil, "o conceito perto/longe saiu")
        -- afinação por sirene: sutil, menos de um semitom (5,9%) pra cada lado do arquivo
        assert(R.PITCH_MIN < 1 and R.PITCH_MAX > 1, "a faixa tem que conter o tom do arquivo")
        assert(R.PITCH_MIN >= 0.94 and R.PITCH_MAX <= 1.06, "faixa " .. R.PITCH_MIN .. "–" .. R.PITCH_MAX)
    end,
    -- cada sirene do coro com afinação própria, nos dois sentidos, cobrindo a faixa
    siren_spots_pitch_varies = function()
        local rand = lcg(13)
        local lo, hi, below, above, flat = math.huge, -math.huge, 0, 0, 0
        for _ = 1, 300 do
            local s = R.spots(0, 0, "white", rand)
            local same = true
            for i, x in ipairs(s) do
                lo, hi = math.min(lo, x.pitch), math.max(hi, x.pitch)
                if x.pitch < 1 then below = below + 1 else above = above + 1 end
                if i > 1 and x.pitch ~= s[1].pitch then same = false end
            end
            if same then flat = flat + 1 end
        end
        local span = R.PITCH_MAX - R.PITCH_MIN
        assert(lo < R.PITCH_MIN + 0.05 * span and hi > R.PITCH_MAX - 0.05 * span, "faixa não coberta: " .. lo .. "–" .. hi)
        assert(below > 500 and above > 500, "afinação pendendo pra um lado: " .. below .. " abaixo, " .. above .. " acima")
        assert(flat == 0, "coro com as 5 na mesma afinação")
    end,
    siren_spots_ranges_angles_delays = function()
        local rand = lcg(7)
        for _, kind in ipairs({ "white", "red", "black" }) do
            for _ = 1, 300 do
                local px, py = rand() * 10000, rand() * 10000
                check(R.spots(px, py, kind, rand), px, py, kind)
            end
        end
    end,
    -- sorteio degenerado (ZombRand fixo nos testes, ou o pior caso): continua valendo
    siren_spots_degenerate_rand = function()
        for _, v in ipairs({ 0, 0.3721, 0.5, 0.9999 }) do
            for _, kind in ipairs({ "white", "red", "black" }) do
                check(R.spots(100, 100, kind, const(v)), 100, 100, kind)
            end
        end
    end,
    -- as listas oficiais (sprint 0034, tarefa 3, com as 9 da V9): cada névoa com as suas, sem misturar
    siren_spots_official_lists = function()
        local counts = { white = 9, red = 9, black = 13 }
        local prefix = { white = "NOM_SirenWhite", red = "NOM_SirenRed", black = "NOM_SirenBlack" }
        local all = {}
        for kind, n in pairs(counts) do
            local list = assert(R.SOUNDS[kind], "sem lista: " .. kind)
            assert(#list == n, kind .. ": " .. #list .. " sirenes")
            for i, name in ipairs(list) do
                assert(name == prefix[kind] .. i, kind .. ": " .. name)
                assert(not all[name], "som em duas listas: " .. name)
                all[name] = true
            end
        end
        check(R.spots(0, 0, "green", lcg(3)), 0, 0, "white") -- sem lista própria: a branca
    end,
    -- lista menor que o coro (não acontece com as oficiais): repete só depois de usar todas
    siren_spots_short_list_repeats_after_all = function()
        local saved = R.SOUNDS.white
        R.SOUNDS.white = { "a", "b" }
        local ok, err = pcall(function()
            local s = R.spots(0, 0, "white", lcg(11))
            local n = {}
            for _, x in ipairs(s) do n[x.sound] = (n[x.sound] or 0) + 1 end
            assert(#s == R.COUNT and n.a and n.b and n.a + n.b == R.COUNT, "lista curta")
        end)
        R.SOUNDS.white = saved
        assert(ok, err)
    end,
    -- os ângulos, as distâncias e a ordem de entrada variam com o sorteio: o coro não gira
    -- sempre no mesmo sentido em volta do jogador
    siren_spots_vary = function()
        local a = R.spots(0, 0, "white", lcg(1))
        local b = R.spots(0, 0, "white", lcg(2))
        assert(a[1].x ~= b[1].x or a[1].y ~= b[1].y, "mesma posição com sorteios diferentes")
        local function turns(s, sign)
            local sum = 0
            for i = 2, #s do sum = sum + NOM_Math.mod(sign * (s[i].deg - s[i - 1].deg), 360) end
            return sum < 360
        end
        local rounds, sounds, ns = 0, {}, 0
        local rand = lcg(5)
        for _ = 1, 200 do
            local s = R.spots(0, 0, "red", rand)
            if turns(s, 1) or turns(s, -1) then rounds = rounds + 1 end
            for _, x in ipairs(s) do sounds[x.sound] = true end
        end
        for _ in pairs(sounds) do ns = ns + 1 end
        assert(rounds < 150, "o coro entra girando em volta do jogador: " .. rounds .. "/200")
        assert(ns == #R.SOUNDS.red, "nem todas as vermelhas saem: " .. ns)
    end,
}
