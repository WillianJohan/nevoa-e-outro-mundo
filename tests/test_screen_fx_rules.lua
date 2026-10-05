-- Regras puras dos efeitos de tela (sprint 0013): alfas das camadas por estado.
require "NOM_ScreenFxRules"
require "NOM_SemRostoRules"

local R = NOM_ScreenFxRules

local function fogged(red, static)
    local s = R.new()
    R.step(s, { fog = true, red = red }, R.FADE_MS)
    s.static = static or 0
    return s
end

return {
    screenfx_rules_nothing_outside_fog = function()
        local s = R.new()
        R.step(s, { fog = false }, 60000)
        local l = R.layers(s, 1234, 1)
        for _, k in ipairs({ "grain", "vignette", "lines", "flash" }) do assert(l[k] == 0, k) end
        assert(not R.visible(l))
    end,

    screenfx_rules_fog_fades_in_and_out = function()
        local s = R.new()
        R.step(s, { fog = true }, R.FADE_MS / 2)
        assert(s.fog > 0.4 and s.fog < 0.6, "sem fade: " .. s.fog)
        R.step(s, { fog = true }, R.FADE_MS)
        assert(s.fog == 1)
        local l = R.layers(s, 0, 1)
        assert(l.grain > 0 and l.vignette > 0 and R.visible(l))
        R.step(s, { fog = false }, R.FADE_MS)
        assert(s.fog == 0 and s.red == 0)
    end,

    -- vermelha: vinheta mais forte e vermelha; normal: preta
    screenfx_rules_red_fog_stronger_and_red = function()
        local n, r = R.layers(fogged(false), 0, 1), R.layers(fogged(true), 0, 1)
        assert(r.vignette > n.vignette, "vermelha não é mais forte")
        assert(n.vr == 0 and n.vg == 0 and n.vb == 0, "vinheta normal não é preta")
        assert(r.vr > 0 and r.vg == 0 and r.vb == 0, "vinheta vermelha sem vermelho")
    end,

    -- linhas pela distância do Sem-rosto (o mesmo volume do rádio, sprint 0005)
    screenfx_rules_lines_grow_near_semrosto = function()
        local far = R.layers(fogged(false, NOM_SemRostoRules.staticVolume(28)), 0, 1).lines
        local near = R.layers(fogged(false, NOM_SemRostoRules.staticVolume(5)), 0, 1).lines
        local none = R.layers(fogged(false, NOM_SemRostoRules.staticVolume(nil)), 0, 1).lines
        assert(none == 0 and far > 0 and near > far, "linhas: " .. none .. " " .. far .. " " .. near)
    end,

    screenfx_rules_scream_flash_decays = function()
        assert(R.screamStrength(nil) == 0 and R.screamStrength(R.FLASH_FAR) == 0)
        assert(R.screamStrength(R.FLASH_NEAR) == 1)
        local mid = R.screamStrength((R.FLASH_NEAR + R.FLASH_FAR) / 2)
        assert(mid > 0 and mid < 1)
        assert(R.flash(1000, 1000, 1) == 1)
        local half = R.flash(1000 + R.FLASH_MS / 2, 1000, 1)
        assert(half > 0 and half < 1)
        assert(R.flash(1000 + R.FLASH_MS, 1000, 1) == 0)
        assert(R.flash(5000, nil, 1) == 0)
        local s = R.new()
        s.flashAt, s.flashStrength = 1000, 1
        local l = R.layers(s, 1100, 1)
        assert(l.flash > 0 and R.visible(l), "pulso fora da névoa não aparece")
        assert(R.layers(s, 1000 + R.FLASH_MS, 1).flash == 0)
    end,

    screenfx_rules_intensity_scales_and_clamps = function()
        local s = fogged(true, 1)
        s.flashAt, s.flashStrength = 0, 1
        local zero = R.layers(s, 0, 0)
        assert(not R.visible(zero), "intensidade 0 desenha")
        local one, two = R.layers(s, 0, 1), R.layers(s, 0, 2)
        for _, k in ipairs({ "grain", "vignette", "lines", "flash" }) do
            assert(two[k] >= one[k] and two[k] <= 1, k)
        end
        assert(R.layers(s, 0, 9).vignette <= 1)
    end,

    screenfx_rules_vignette_breathes = function()
        local s = fogged(false)
        local lo, hi = 1, 0
        for t = 0, R.BREATH_MS, R.BREATH_MS / 20 do
            local v = R.layers(s, t, 1).vignette
            lo, hi = math.min(lo, v), math.max(hi, v)
        end
        assert(hi - lo > 0.05, "não respira")
        assert(lo > 0.2, "some no meio da respiração")
    end,

    screenfx_rules_grain_frames_cycle = function()
        local seen = {}
        for t = 0, R.GRAIN_FRAME_MS * R.GRAIN_FRAMES * 3, R.GRAIN_FRAME_MS do
            local f = R.grainFrame(t)
            assert(f >= 1 and f <= R.GRAIN_FRAMES and f == math.floor(f))
            seen[f] = true
        end
        for f = 1, R.GRAIN_FRAMES do assert(seen[f], "quadro " .. f) end
    end,

    -- canal Lua → shader (mod2): marcador no gradiente, valores pela intensidade
    screenfx_rules_channel = function()
        local c = R.channel(R.new(), 0, 1)
        assert(c.gradient == R.MARKER and c.blur == 0 and c.radius == 0 and c.desat == 0 and c.darkness == 0)
        local s = fogged(true, 0.5)
        s.flashAt, s.flashStrength = 0, 1
        c = R.channel(s, 0, 1)
        assert(c.blur == 1 and c.desat == 1 and c.radius == 0.5 and c.darkness == 1)
        local c2 = R.channel(s, 0, 2)
        assert(c2.blur == 2 and c2.radius == 1)
        assert(R.channel(s, 0, 0).blur == 0)
    end,

    -- sprint 0018: a intensidade do bloom do jogador vai no marcador (13 + bloom·escala),
    -- independente da intensidade dos efeitos; sem bloom, o marcador da 0013
    screenfx_rules_channel_bloom = function()
        assert(R.channel(R.new(), 0, 1).gradient == R.MARKER, "sem bloom muda o marcador")
        assert(R.channel(R.new(), 0, 1, 0).gradient == R.MARKER)
        assert(R.channel(R.new(), 0, 0, 1).gradient == R.MARKER + R.BLOOM_SCALE, "o bloom dependeu da intensidade")
        assert(R.channel(R.new(), 0, 1, 2).gradient == R.MARKER + 2 * R.BLOOM_SCALE)
        assert(R.channel(R.new(), 0, 1, 9).gradient == R.MARKER + 2 * R.BLOOM_SCALE, "fora da faixa")
        assert(2 * R.BLOOM_SCALE < 1, "o bloom não pode chegar no próximo inteiro do marcador")
    end,
}
