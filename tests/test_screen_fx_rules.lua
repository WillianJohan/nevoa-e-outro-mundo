-- Regras puras dos efeitos de tela (sprint 0013): alfas das camadas por estado.
require "NOM_ScreenFxRules"
require "NOM_SemRostoRules"
require "NOM_FogEventRules"

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

    -- preta (sprint 0038): vinheta bem mais fechada que a da vermelha, sem vermelho; estática cinza-escura
    screenfx_rules_black_fog_closes_and_greys = function()
        local function blackened(red)
            local s = R.new()
            R.step(s, { fog = true, red = red, black = true }, R.FADE_MS)
            return s
        end
        local r, b = R.layers(fogged(true), 0, 1), R.layers(blackened(false), 0, 1)
        assert(b.vignette > r.vignette, "preta não fecha mais que a vermelha")
        assert(b.vr == 0, "vinheta preta com vermelho")
        local s = blackened(false)
        R.step(s, { fog = false }, R.FADE_MS)
        assert(s.black == 0, "preta não sai com a névoa")
        local sr, sg, sb = R.staticColor("black")
        assert(sr < 0.4 and sr > 0.15 and math.abs(sr - sg) < 0.05 and sb >= sr, "estática preta não é cinza-escura")
    end,

    -- linhas pela distância do Sem-rosto (o mesmo volume do rádio, sprint 0005)
    screenfx_rules_lines_grow_near_semrosto = function()
        local far = R.layers(fogged(false, NOM_SemRostoRules.staticVolume(28)), 0, 1).lines
        local near = R.layers(fogged(false, NOM_SemRostoRules.staticVolume(5)), 0, 1).lines
        local none = R.layers(fogged(false, NOM_SemRostoRules.staticVolume(nil)), 0, 1).lines
        assert(none == 0 and far > 0 and near > far, "linhas: " .. none .. " " .. far .. " " .. near)
    end,

    -- sprint 0052: vinheta sobe perto do soluço da Carpideira (ZB-free)
    screenfx_rules_sob_vignette_near_carpideira = function()
        assert(R.sobStrength(nil) == 0 and R.sobStrength(R.SOB_FAR) == 0)
        assert(R.sobStrength(R.SOB_NEAR) == 1)
        local base = fogged(false)
        local far, near = fogged(false), fogged(false)
        far.sob, near.sob = R.sobStrength(10), R.sobStrength(2)
        local vf = R.layers(far, 0, 1).vignette
        local vn = R.layers(near, 0, 1).vignette
        local v0 = R.layers(base, 0, 1).vignette
        assert(vf > v0 and vn > vf, "vinheta do soluço: " .. v0 .. " " .. vf .. " " .. vn)
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

    -- sprint 0035: tontura de ~5 s na revelação do Outro Mundo. Sobe rápido (~0,6 s), segura e
    -- desce até DIZZY_MS, sem degrau
    screenfx_rules_dizzy_curve = function()
        assert(R.DIZZY_MS >= 4500 and R.DIZZY_MS <= 5500, "~5 s: " .. R.DIZZY_MS)
        assert(R.DIZZY_RISE_MS >= 400 and R.DIZZY_RISE_MS <= 800, "sobe em ~0,6 s")
        assert(R.DIZZY_RISE_MS + R.DIZZY_HOLD_MS < R.DIZZY_MS, "não sobra descida")
        assert(R.dizzy(nil) == 0 and R.dizzy(-10) == 0 and R.dizzy(0) == 0)
        local half = R.dizzy(R.DIZZY_RISE_MS / 2)
        assert(half > 0.2 and half < 0.8, "subida: " .. half)
        assert(R.dizzy(R.DIZZY_RISE_MS) == 1 and R.dizzy(R.DIZZY_RISE_MS + R.DIZZY_HOLD_MS) == 1, "não segura")
        assert(R.dizzy(R.DIZZY_MS) == 0 and R.dizzy(R.DIZZY_MS + 60000) == 0, "não acaba")
        local prev, peak = 0, false
        for t = 0, R.DIZZY_MS, 25 do
            local v = R.dizzy(t)
            assert(v >= 0 and v <= 1)
            assert(math.abs(v - prev) <= 0.1, "degrau em " .. t .. " ms: " .. prev .. " → " .. v)
            if v == 1 then peak = true end
            if peak and t > R.DIZZY_RISE_MS + R.DIZZY_HOLD_MS then assert(v <= prev, "subiu na descida em " .. t) end
            prev = v
        end
        -- a intensidade dos efeitos reduz e nunca aumenta (tontura incomoda)
        local t = R.DIZZY_RISE_MS
        assert(R.dizzyLevel(t, 1) == 1 and R.dizzyLevel(t, 2) == 1, "intensidade 2 aumentou")
        assert(R.dizzyLevel(t, 0.5) == 0.5 and R.dizzyLevel(t, 0) == 0 and R.dizzyLevel(nil, 1) == 0)
    end,

    -- sem o shader: a vinheta pulsa e uma camada preta escurece um pouco
    screenfx_rules_dizzy_layers = function()
        local s = R.new()
        local none = R.layers(s, 0, 1, 0)
        assert(not R.visible(none) and none.dark == 0)
        assert(R.layers(s, 0, 1).dark == 0, "sem tontura escurece")
        local lo, hi = 1, 0
        for t = 0, R.DIZZY_PULSE_MS, R.DIZZY_PULSE_MS / 20 do
            local l = R.layers(s, t, 1, 1)
            assert(R.visible(l) and l.dark > 0 and l.dark <= 0.3, "escuro: " .. l.dark)
            lo, hi = math.min(lo, l.vignette), math.max(hi, l.vignette)
        end
        assert(hi - lo > 0.15, "a vinheta não pulsa: " .. lo .. " " .. hi)
        assert(R.DIZZY_PULSE_MS >= 600 and R.DIZZY_PULSE_MS <= 2000)
        local l = R.layers(s, 0, 1, 0.5)
        assert(math.abs(l.dark - 0.5 * R.layers(s, 0, 1, 1).dark) < 1e-9, "não segue a curva")
        -- na névoa a pulsação soma na vinheta da névoa, sem passar de 1
        local f = fogged(true)
        assert(R.layers(f, 0, 2, 1).vignette <= 1)
        local mx = 0
        for t = 0, R.DIZZY_PULSE_MS, R.DIZZY_PULSE_MS / 20 do mx = math.max(mx, R.layers(f, t, 1, 1).vignette - R.layers(f, t, 1, 0).vignette) end
        assert(mx > 0.1, "a tontura sumiu na vinheta da névoa")
    end,

    -- canal do shader: a tontura vai na parte inteira do darkness (VarInfo.y), o pulso do grito
    -- na resto (0..2); o shader decodifica com floor(v / DIZZY_BASE)
    screenfx_rules_channel_dizzy = function()
        local function decode(v)
            local k = math.floor(v / R.DIZZY_BASE)
            return v - k * R.DIZZY_BASE, k / R.DIZZY_STEPS
        end
        assert(R.DIZZY_BASE > 2, "o pulso (até 2) cruza a base")
        local s = fogged(false)
        assert(R.channel(s, 0, 1, 0).darkness == 0 and R.channel(s, 0, 1, 0, 0).darkness == 0, "sem tontura mudou o canal")
        s.flashAt, s.flashStrength = 0, 1
        for _, case in ipairs({ { 1, 0.37 }, { 2, 1 }, { 0.5, 0.002 }, { 4, 0.8 }, { 0, 1 } }) do
            local i, dz = case[1], case[2]
            local c = R.channel(s, 0, i, 0, dz)
            local p, d = decode(c.darkness)
            assert(math.abs(p - math.min(i, 2)) < 1e-6, "pulso " .. i .. ": " .. p)
            assert(math.abs(d - dz) <= 0.5 / R.DIZZY_STEPS + 1e-9, "tontura " .. dz .. ": " .. d)
        end
        -- em float de 32 bits (o uniform) o floor ainda acerta: o pulso fica longe da borda
        assert((2 + R.DIZZY_BASE * R.DIZZY_STEPS) < 2 ^ 20, "valor grande demais pro float do shader")
        assert(R.channel(R.new(), 0, 1, 0, 1).blur == 0, "a tontura mexeu na névoa")
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

    -- sprint 0034: estática da névoa. Presságio de 0,1 a 0,6 em 3 s (t², acelera), desce a
    -- 0,14 em ~4 s depois da sirene, fica em 0,14 na subida e na névoa
    screenfx_rules_static_curve = function()
        local P = NOM_FogEventRules.PRESAGE_MS
        local function near(a, b) return math.abs(a - b) < 1e-9 end
        assert(R.staticLevel({}, 5000) == 0, "estática sem nada")
        local omen = { omenAt = 1000 }
        assert(near(R.staticLevel(omen, 1000), R.STATIC_START) and near(R.STATIC_START, 0.1))
        local q = R.staticLevel(omen, 1000 + P / 4)
        local h = R.staticLevel(omen, 1000 + P / 2)
        local e = R.staticLevel(omen, 1000 + P * 3 / 4)
        assert(q > R.STATIC_START and h > q and e > h, "não cresce")
        assert(e - h > h - q, "não acelera (t²)")
        assert(near(h, R.STATIC_START + (R.STATIC_PEAK - R.STATIC_START) * 0.25), "não é t²: " .. h)
        assert(near(R.staticLevel(omen, 1000 + P), 0.6) and near(R.STATIC_PEAK, 0.6))
        assert(near(R.staticLevel(omen, 1000 + P * 9), 0.6), "passou do pico (pausa segura o servidor)")
        assert(near(R.staticLevel(omen, 500), R.STATIC_START), "relógio que volta")
        -- a sirene: desce do pico ao sutil em STATIC_SETTLE_MS e fica
        local siren = { omenAt = 1000, sirenAt = 1000 + P, visible = true }
        assert(near(R.staticLevel(siren, 1000 + P), 0.6))
        local mid = R.staticLevel(siren, 1000 + P + R.STATIC_SETTLE_MS / 2)
        assert(mid < 0.6 and mid > 0.14, "não desce aos poucos: " .. mid)
        assert(near(R.staticLevel(siren, 1000 + P + R.STATIC_SETTLE_MS), 0.14) and near(R.STATIC_SUBTLE, 0.14))
        assert(R.STATIC_SETTLE_MS >= 3000 and R.STATIC_SETTLE_MS <= 5000, "~4 s")
        assert(near(R.staticLevel(siren, 1000 + P + 60000), 0.14))
        -- subida ou névoa sem presságio (quem entra no meio, debug com skip): só o sutil
        assert(near(R.staticLevel({ visible = true }, 9), 0.14))
        assert(near(R.staticLevel({ visible = true, sirenAt = 9 }, 9), 0.14), "pico sem presságio")
    end,

    -- fim da névoa ou sirene cancelada: desce a 0 em ~3 s a partir de onde estava; a cor fica
    -- a da névoa que acabou até sumir
    screenfx_rules_static_fades_out = function()
        local s = R.new()
        assert(s.fogStatic == 0)
        R.stepStatic(s, { visible = true, kind = "red" }, 1000)
        assert(math.abs(s.fogStatic - 0.14) < 1e-9 and s.staticKind == "red")
        R.stepStatic(s, { kind = "white" }, 2000)
        assert(math.abs(s.fogStatic - 0.14) < 1e-9, "sumiu de uma vez")
        R.stepStatic(s, { kind = "white" }, 2000 + R.STATIC_FADE_MS / 2)
        assert(s.fogStatic > 0 and s.fogStatic < 0.14, "não desce: " .. s.fogStatic)
        assert(s.staticKind == "red", "a cor trocou no fade")
        R.stepStatic(s, {}, 2000 + R.STATIC_FADE_MS)
        assert(s.fogStatic == 0)
        assert(R.STATIC_FADE_MS >= 2000 and R.STATIC_FADE_MS <= 4000, "~3 s")
        -- cancelada no meio do presságio: desce do nível em que estava
        local c = R.new()
        R.stepStatic(c, { omenAt = 0 }, NOM_FogEventRules.PRESAGE_MS)
        assert(math.abs(c.fogStatic - 0.6) < 1e-9)
        R.stepStatic(c, {}, 10000)
        R.stepStatic(c, {}, 10000 + R.STATIC_FADE_MS / 2)
        assert(math.abs(c.fogStatic - 0.3) < 1e-9, "fade não saiu do pico: " .. c.fogStatic)
        -- volta no meio do fade (névoa nova): segue a curva de novo
        R.stepStatic(c, { visible = true }, 10000 + R.STATIC_FADE_MS * 3 / 4)
        assert(math.abs(c.fogStatic - 0.14) < 1e-9)
    end,

    -- cor da névoa: branca = FOG_COLOR, vermelha = o RGB de RED_FOG_COLOR (sem o alfa)
    screenfx_rules_static_color_and_layer = function()
        require "NOM_Rules"
        local wr, wg, wb, wa = R.staticColor("white")
        local F = NOM_Rules.FOG_COLOR
        assert(wr == F[1] and wg == F[2] and wb == F[3] and wa == nil)
        local rr, rg, rb, ra = R.staticColor("red")
        local C = NOM_Rules.RED_FOG_COLOR
        assert(rr == C[1] and rg == C[2] and rb == C[3] and ra == nil, "vermelha")
        assert(R.staticColor(nil) == F[1], "sem tipo: branca")
        -- camada: alfa pela intensidade da opção, cor pelo tipo; visível sozinha (fora da névoa)
        local s = R.new()
        R.stepStatic(s, { omenAt = 0, kind = "red" }, NOM_FogEventRules.PRESAGE_MS)
        local l = R.layers(s, 0, 1)
        assert(math.abs(l.fogStatic - 0.6) < 1e-9 and R.visible(l), "presságio não aparece")
        assert(l.grain == 0 and l.vignette == 0 and l.lines == 0, "o presságio ligou o Outro Mundo")
        assert(l.sr == C[1] and l.sg == C[2] and l.sb == C[3])
        assert(math.abs(R.layers(s, 0, 2).fogStatic - 1) < 1e-9, "o dobro do pico satura em 1")
        assert(R.layers(s, 0, 0).fogStatic == 0 and not R.visible(R.layers(s, 0, 0)), "intensidade 0")
    end,

    -- 0060c: LookForce → look limpo (overlay + canal shader zerados)
    screenfx_rules_look_clean_kills_glitch = function()
        assert(not R.lookClean(), "sem PanelParams não é limpo")
        NOM_PanelParams = { lookForce = function() return "misaligned" end }
        assert(R.lookClean())
        local s = fogged(true, 1)
        s.flashAt, s.flashStrength = 0, 1
        s.fogStatic = 0.5
        local l = R.layers(s, 0, 1, 1)
        assert(l.grain == 0 and l.lines == 0 and l.fogStatic == 0 and l.flash == 0
            and l.vignette == 0 and l.dark == 0, "camadas ainda pintam")
        assert(not R.visible(l), "look limpo ainda visível")
        local c = R.channel(s, 0, 1, 2, 1)
        assert(c.blur == 0 and c.radius == 0 and c.desat == 0 and c.darkness == 0
            and c.gradient == 0, "canal shader ainda suja")
        NOM_PanelParams = { lookForce = function() return "" end }
        assert(not R.lookClean())
        assert(R.layers(fogged(true), 0, 1).grain > 0, "Auto não deve zerar")
        NOM_PanelParams = nil
    end,

}
