-- Regras puras da luz que congela o Tição (sprint 0038).
require "NOM_LightRules"

local R = NOM_LightRules

local function beam(x, y, fx, fy, range, dot)
    local l = R.fromItem(true, range or 15, dot or 0.5)
    l.x, l.y, l.z, l.fx, l.fy = x, y, 0, fx, fy
    return l
end

return {
    -- lanterna de cone vira facho; lampião (sem cone, alcance >= 10) vira raio pequeno; isqueiro e
    -- vela (alcance 5) não contam
    light_rules_from_item = function()
        local b = R.fromItem(true, 15, 0.5)
        assert(b.kind == "beam" and b.range == 15 and b.dot == 0.5)
        local l = R.fromItem(false, 15)
        assert(l.kind == "radius" and l.range == R.LANTERN_RADIUS)
        assert(R.fromItem(false, 10).kind == "radius", "lampião elétrico (10)")
        assert(R.fromItem(false, 5) == nil, "isqueiro congelou")
        assert(R.fromItem(true, 0) == nil)
        assert(R.headlight().kind == "radius" and R.headlight().range == R.HEADLIGHT_RADIUS)
    end,
    -- facho: na frente e no alcance acende; atrás, de lado fora do cone, longe ou em outro andar, não
    light_rules_beam_cone = function()
        local l = beam(0, 0, 1, 0, 15, 0.5)
        assert(R.lit(l, 10, 0, 0), "na frente")
        assert(R.lit(l, 10, 5, 0), "dentro do cone")
        assert(not R.lit(l, -5, 0, 0), "atrás")
        assert(not R.lit(l, 2, 10, 0), "de lado")
        assert(not R.lit(l, 16, 0, 0), "longe")
        assert(not R.lit(l, 10, 0, 1), "outro andar")
        assert(R.lit(l, 0.3, 0.3, 0), "colado no jogador")
        -- facho estreito (PenLight 0,75): o mesmo ponto de lado fica fora
        local pen = beam(0, 0, 1, 0, 11, 0.75)
        assert(R.lit(l, 6, 7, 0) and not R.lit(pen, 6, 7, 0), "o cone não estreitou")
        -- a folga do corpo pega quem está meio dentro da borda
        local edge = beam(0, 0, 1, 0, 15, 0.999)
        assert(R.lit(edge, 10, 0.5, 0) and not R.lit(edge, 10, 1.5, 0), "folga do corpo")
    end,
    light_rules_radius = function()
        local l = R.fromItem(false, 15)
        l.x, l.y, l.z = 0, 0, 0
        assert(R.lit(l, 3, 0, 0) and R.lit(l, -2, -2, 0))
        assert(not R.lit(l, 5, 0, 0) and not R.lit(l, 1, 0, 1))
    end,
    -- rodízio: cobre todos a cada SWEEP_MS, pelo menos 1, no máximo a lista
    light_rules_batch = function()
        assert(R.batch(0, 16) == 0)
        assert(R.batch(300, 16) == math.ceil(300 * 16 / R.SWEEP_MS))
        assert(R.batch(300, 100) == 120, "dedicado a 10 Hz")
        assert(R.batch(5, 1) == 1 and R.batch(5, 10000) == 5)
        -- 300 zumbis a 60 FPS: soma dos lotes em SWEEP_MS cobre a lista
        local seen, t = 0, 0
        while t < R.SWEEP_MS do
            seen = seen + R.batch(300, 16)
            t = t + 16
        end
        assert(seen >= 300, "o rodízio não cobre a lista: " .. seen)
    end,
    -- pisca com FLICKER_CHANCE% e dura entre o mínimo e o máximo
    light_rules_flicker = function()
        assert(R.flicker(R.FLICKER_CHANCE, 0.5) == nil and R.flicker(99, 0) == nil)
        assert(R.flicker(0, 0) == R.FLICKER_MIN_MS and R.flicker(0, 1) == R.FLICKER_MAX_MS)
        assert(R.HOLD_MS < R.FLICKER_MIN_MS, "o Tição solto pelo flicker voltaria a congelar antes da luz voltar")
    end,
}
