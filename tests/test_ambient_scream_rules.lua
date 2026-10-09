-- Gritos ambiente (sprint 0048): regra pura shared/NOM_AmbientScreamRules.lua.
require "NOM_AmbientScreamRules"
local A = NOM_AmbientScreamRules

local function near(a, b) return math.abs(a - b) < 1e-9 end

return {
    ambient_enabled_by_color_and_option = function()
        assert(A.enabled(true, "white") and A.enabled(true, "red"))
        assert(not A.enabled(true, "black"), "preta sem wall of screams")
        assert(not A.enabled(false, "white"), "FogAmbience desliga")
        assert(not A.enabled(true, nil) and not A.enabled(true, "purple"))
    end,

    ambient_gap_white_and_red = function()
        local w, r = A.GAP.white, A.GAP.red
        assert(w.min == 60000 and w.max == 180000)
        assert(r.min == 45000 and r.max == 120000)
        assert(r.max < w.max, "vermelha um pouco mais apertada")
        assert(A.gap("white", 0) == w.min)
        assert(A.gap("white", w.max - w.min) == w.max)
        assert(A.gap("red", 0) == r.min)
        assert(A.gap("black", 0) == nil)
        assert(A.gap("white", -5) == w.min and A.gap("white", 999999) == w.max)
    end,

    ambient_pick_cycles_bank = function()
        assert(#A.SOUNDS >= 3)
        assert(A.pick(0) == A.SOUNDS[1])
        assert(A.pick(1) == A.SOUNDS[2])
        assert(A.pick(#A.SOUNDS) == A.SOUNDS[1], "rola")
    end,

    ambient_distance_farther_on_white = function()
        assert(A.DIST.white.min > A.DIST.red.min)
        assert(A.distance("white", 0) == A.DIST.white.min)
        assert(A.distance("red", A.DIST.red.max - A.DIST.red.min) == A.DIST.red.max)
        assert(A.distance("black", 0) == nil)
    end,

    ambient_spot_around_player = function()
        local x, y = A.spot(100, 200, 50, 0)
        assert(near(x, 150) and near(y, 200))
        local x2, y2 = A.spot(0, 0, 10, math.pi / 2)
        assert(near(x2, 0) and near(y2, 10))
        assert(near(A.bearing(0), 0) and near(A.bearing(180), math.pi))
    end,
}
