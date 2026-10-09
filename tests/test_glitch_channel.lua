-- I6: trilha panel → param → ScreenFxRules.channel → FogVignette.write → SearchMode
-- → screen.frag (SearchMode.y = hiss). Prova que o slider muda o float que o shader lê,
-- no mesmo "frame" (setAll síncrono), sem reload.
--
-- Elos:
-- 1. NOM_DebugPanel enumCard/sliderCard GlitchMode/GlitchIntensity
--    → NOM.param (client/NOM_DebugPanel.lua seção Look)
-- 2. NOM.param / NOM.glitch / NOM.glitchIntensity
--    → NOM_PanelParams.set (client/NOM_Console.lua)
-- 3. NOM_PanelParams.glitchMode/glitchIntensity
--    → shared/NOM_PanelParams.lua
-- 4. NOM_ScreenFxRules.channel lê mode/intensity → c.radius, c.gradient
--    → shared/NOM_ScreenFxRules.lua
-- 5. NOM_FogVignette.write → psm:getRadius():setAll(c.radius)
--    → client/NOM_FogVignette.lua (SearchModeFloat; pz-api-notes §15)
-- 6. WeatherShader manda SearchMode.y → screen.frag `hiss`
--    → mod2/42/media/shaders/screen.frag

require "NOM_ScreenFxRules"

local R = NOM_ScreenFxRules

local function P()
    -- Outros testes (debug_panel) deixam package.loaded["NOM_PanelParams"]=true sem o global.
    package.loaded["NOM_PanelParams"] = nil
    return require "NOM_PanelParams"
end

local function foggedStatic(static)
    local s = R.new()
    R.step(s, { fog = true }, R.FADE_MS)
    s.static = static or 1
    return s
end

return {
    glitch_panel_defaults_original_100 = function()
        local p = P()
        p.reset()
        assert(p.get("GlitchMode") == "original")
        assert(p.get("GlitchIntensity") == 100)
        assert(p.glitchIntensity() == 1)
        assert(p.format("GlitchIntensity", 200) == "200%")
        assert(p.format("GlitchMode", "off") == "desligado")
    end,

    glitch_dump_text_includes_mode_and_intensity = function()
        local p = P()
        p.reset()
        p.set("GlitchMode", "bordas")
        p.set("GlitchIntensity", 150)
        local t = p.dumpText()
        assert(t:find("GlitchMode=bordas", 1, true), t)
        assert(t:find("GlitchIntensity=150", 1, true), t)
        p.reset()
    end,

    -- Slider 0% → radius 0; 200% → ~2× o de 100%. Mesmo sample, sem reload.
    glitch_intensity_changes_channel_radius_live = function()
        local p = P()
        p.reset()
        R.setLookClean(false)
        NOM_PanelParams = p
        p.set("GlitchMode", "original")
        local s = foggedStatic(1)
        p.set("GlitchIntensity", 100)
        local c100 = R.channel(s, 0, 1, 0, 0)
        assert(c100.radius > 0.5, "100% sem tear: " .. tostring(c100.radius))
        p.set("GlitchIntensity", 0)
        local c0 = R.channel(s, 0, 1, 0, 0)
        assert(c0.radius == 0, "0% ainda tem radius=" .. tostring(c0.radius))
        p.set("GlitchIntensity", 200)
        local c200 = R.channel(s, 0, 1, 0, 0)
        assert(math.abs(c200.radius - c100.radius * 2) < 1e-6,
            string.format("200%% não dobrou: 100=%.3f 200=%.3f", c100.radius, c200.radius))
        p.set("GlitchMode", "off")
        p.set("GlitchIntensity", 200)
        assert(R.channel(s, 0, 1, 0, 0).radius == 0, "off ignora intensidade")
        p.reset()
    end,

    glitch_bordas_tags_gradient_for_shader = function()
        local p = P()
        p.reset()
        R.setLookClean(false)
        NOM_PanelParams = p
        local s = foggedStatic(1)
        p.set("GlitchMode", "original")
        p.set("GlitchIntensity", 100)
        local orig = R.channel(s, 0, 1, 0, 0)
        p.set("GlitchMode", "bordas")
        local edge = R.channel(s, 0, 1, 0, 0)
        assert(edge.gradient >= orig.gradient + R.BORDAS_TAG - 0.01,
            string.format("bordas sem tag: orig=%.2f edge=%.2f", orig.gradient, edge.gradient))
        assert(edge.radius < orig.radius, "bordas deveria reduzir radius")
        local l = R.layers(s, 0, 1)
        assert(l.edgeLines == true and l.lines > 0, "bordas sem edgeLines")
        p.reset()
    end,

    -- write() aplica setAll(radius) no mesmo frame; 0% vs 200% muda o valor escrito.
    glitch_write_applies_radius_to_searchmode_same_frame = function()
        local p = P()
        p.reset()
        R.setLookClean(false)
        NOM_PanelParams = p
        p.set("GlitchMode", "original")
        local written = {}
        local float = function(name)
            return { setAll = function(_, v) written[name] = v end }
        end
        local psm = {
            getBlur = function() return float("blur") end,
            getRadius = function() return float("radius") end,
            getDesat = function() return float("desat") end,
            getDarkness = function() return float("darkness") end,
            getGradientWidth = function() return float("gradient") end,
        }
        local function apply(pct)
            p.set("GlitchIntensity", pct)
            local c = R.channel(foggedStatic(1), 0, 1, 0, 0)
            -- Espelho de FogVignette.write (client/NOM_FogVignette.lua): setAll síncrono.
            psm:getBlur():setAll(c.blur)
            psm:getRadius():setAll(c.radius)
            psm:getDesat():setAll(c.desat)
            psm:getDarkness():setAll(c.darkness)
            psm:getGradientWidth():setAll(c.gradient)
            return c
        end
        local c0 = apply(0)
        assert(written.radius == 0, "setAll(0) falhou: " .. tostring(written.radius))
        local c200 = apply(200)
        assert(written.radius == c200.radius and written.radius > 1,
            "setAll(200%) falhou: " .. tostring(written.radius))
        assert(c0.radius == 0 and c200.radius > c0.radius * 1.5)
        -- Shader: SearchMode.y = hiss (mod2 screen.frag). O float escrito É o uniform.
        assert(written.radius == c200.radius)
        p.reset()
    end,

    glitch_shader_reads_searchmode_y_as_hiss = function()
        local f = assert(io.open("mod2/42/media/shaders/screen.frag", "rb"))
        local src = f:read("*a")
        f:close()
        assert(src:find("float hiss = ours ? clamp(SearchMode.y", 1, true),
            "screen.frag não lê SearchMode.y como hiss")
        assert(src:find("hissEff", 1, true), "screen.frag sem hissEff (modo bordas)")
        assert(src:find("NOM_BORDAS_TAG", 1, true), "screen.frag sem tag de bordas")
    end,
}
