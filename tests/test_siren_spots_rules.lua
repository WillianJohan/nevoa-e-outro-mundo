-- shared/NOM_SirenSpotsRules.lua (puro): onde tocam as 3 sirenes de cada jogador, qual
-- som e com que atraso.
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
    assert(#spots == 3, "sirenes: " .. #spots)
    local near = 0
    for i, s in ipairs(spots) do
        local d = math.sqrt((s.x - px) ^ 2 + (s.y - py) ^ 2)
        assert(math.abs(d - s.dist) < 1e-6, "dist não bate com a posição")
        if s.near then
            near = near + 1
            assert(i == 1, "a perto não é a primeira")
            assert(d >= R.NEAR_MIN and d <= R.NEAR_MAX, "perto a " .. d)
            assert(s.delayMs == 0, "a perto com atraso")
            assert(has(sounds.near, s.sound), "perto com som de longe: " .. s.sound)
        else
            assert(d >= R.FAR_MIN and d <= R.FAR_MAX, "longe a " .. d)
            assert(s.delayMs >= R.DELAY_MIN_MS and s.delayMs <= R.DELAY_MAX_MS, "atraso " .. s.delayMs)
            assert(has(sounds.far, s.sound), "longe com som de perto: " .. s.sound)
        end
    end
    assert(near == 1, "perto: " .. near)
    for i = 1, 3 do
        for j = i + 1, 3 do
            local g = gap(angle(spots[i], px, py), angle(spots[j], px, py))
            assert(g >= R.MIN_GAP_DEG - 1e-6, "duas sirenes a " .. g .. "° uma da outra")
        end
    end
end

return {
    siren_spots_ranges_angles_delays = function()
        local rand = lcg(7)
        for _ = 1, 500 do
            local px, py = rand() * 10000, rand() * 10000
            check(R.spots(px, py, "white", rand), px, py, "white")
        end
    end,
    -- sorteio degenerado (ZombRand fixo nos testes, ou o pior caso): continua valendo
    siren_spots_degenerate_rand = function()
        for _, v in ipairs({ 0, 0.5, 0.9999 }) do
            check(R.spots(100, 100, "white", const(v)), 100, 100, "white")
        end
    end,
    siren_spots_red_and_unknown_kind = function()
        local rand = lcg(3)
        local red = R.spots(0, 0, "red", rand)
        check(red, 0, 0, "red")
        assert(red[1].sound == "NOM_SirenRed" and red[2].sound == "NOM_SirenRedFar")
        local white = R.spots(0, 0, "white", rand)
        assert(white[1].sound == "NOM_Siren" and white[3].sound == "NOM_SirenFar")
        check(R.spots(0, 0, "black", rand), 0, 0, "white") -- sem lista própria: a branca
    end,
    -- variantes: não repetem entre as três quando a lista tem opção; com uma só, repete
    siren_spots_variants_do_not_repeat = function()
        local saved = R.SOUNDS.white
        R.SOUNDS.white = { near = { "a", "b" }, far = { "a", "c", "d" } }
        local ok, err = pcall(function()
            local rand = lcg(11)
            for _ = 1, 200 do
                local s = R.spots(0, 0, "white", rand)
                assert(s[1].sound ~= s[2].sound and s[1].sound ~= s[3].sound and s[2].sound ~= s[3].sound,
                    "repetiu: " .. s[1].sound .. " " .. s[2].sound .. " " .. s[3].sound)
            end
            R.SOUNDS.white = { near = { "a" }, far = { "f" } }
            local s = R.spots(0, 0, "white", rand)
            assert(s[2].sound == "f" and s[3].sound == "f", "lista de um só")
        end)
        R.SOUNDS.white = saved
        assert(ok, err)
    end,
    -- os ângulos e as distâncias variam com o sorteio (não é sempre o mesmo lugar)
    siren_spots_vary = function()
        local a = R.spots(0, 0, "white", lcg(1))
        local b = R.spots(0, 0, "white", lcg(2))
        assert(a[1].x ~= b[1].x or a[1].y ~= b[1].y, "mesma posição com sorteios diferentes")
    end,
}
