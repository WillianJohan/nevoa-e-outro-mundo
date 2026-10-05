require "NOM_SemRostoRules"

local R = NOM_SemRostoRules

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

return {
    -- some e volta mais perto: o raio encolhe um passo, com piso
    semrosto_rules_next_radius = function()
        assert(R.nextRadius(20) == 20 - R.STEP)
        assert(R.nextRadius(R.MIN_DIST + 1) == R.MIN_DIST)
        assert(R.nextRadius(1) == R.MIN_DIST)
    end,
    -- o primeiro ponto é atrás do jogador; os outros abrem pros lados, nunca na frente
    semrosto_rules_spots_behind_first = function()
        local face = 0 -- olhando pra +x
        local s = R.spots(100, 100, face, 6)
        assert(#s >= 9, "poucos pontos: " .. #s)
        assert(s[1].x == 94 and s[1].y == 100, "primeiro ponto não é atrás: " .. s[1].x .. "," .. s[1].y)
        for _, p in ipairs(s) do
            assert(p.x == math.floor(p.x) and p.y == math.floor(p.y), "ponto não inteiro")
            assert(math.abs(dist(100, 100, p.x, p.y) - 6) < 0.75, "fora do raio")
            assert(p.x <= 100 + 6 * math.cos(math.rad(60)) + 0.5, "ponto na frente do jogador")
        end
    end,
    -- sem duplicata (raio pequeno arredonda pro mesmo tile)
    semrosto_rules_spots_unique = function()
        local seen = {}
        for _, p in ipairs(R.spots(10, 10, 1.3, R.MIN_DIST)) do
            local k = p.x .. "," .. p.y
            assert(not seen[k], "repetido " .. k)
            seen[k] = true
        end
    end,
    semrosto_rules_cooldown = function()
        assert(R.ready(nil, 0))
        assert(not R.ready(1000, 1000 + R.COOLDOWN_MS - 1))
        assert(R.ready(1000, 1000 + R.COOLDOWN_MS))
    end,
    -- o servidor não confia no cliente: destino mais perto, nem colado nem longe
    semrosto_rules_valid_move = function()
        assert(R.validMove(0, 0, 10, 0, -7, 0), "movimento bom recusado")
        assert(not R.validMove(0, 0, 10, 0, -15, 0), "destino mais longe aceito")
        assert(not R.validMove(0, 0, 10, 0, 0, 0), "destino em cima do jogador aceito")
        assert(not R.validMove(0, 0, R.REPORT_RANGE + 5, 0, -10, 0), "zumbi longe demais do jogador")
        -- já no raio mínimo: pode reaparecer no mínimo de novo
        assert(R.validMove(0, 0, R.MIN_DIST, 0, -R.MIN_DIST, 0))
    end,
    -- rádio: no máximo colado, mudo de longe, sobe sempre que chega perto
    semrosto_rules_static_volume = function()
        assert(R.staticVolume(nil) == 0)
        assert(R.staticVolume(0) == 1 and R.staticVolume(R.STATIC_NEAR) == 1)
        assert(R.staticVolume(R.STATIC_FAR) == 0 and R.staticVolume(100) == 0)
        local last = 2
        for d = 0, 40 do
            local v = R.staticVolume(d)
            assert(v <= last, "volume subiu ao se afastar em d=" .. d)
            last = v
        end
        assert(R.staticVolume(15) > 0 and R.staticVolume(15) < 1)
    end,
}
