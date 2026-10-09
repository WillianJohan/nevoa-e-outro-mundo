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

    -- FogVignette de verdade: slider → channel → setAll(radius) no mesmo tick; lastChannel
    -- guarda mode/intensity (log "[NOM] glitch apply …"). Sem reload.
    glitch_write_applies_radius_to_searchmode_same_frame = function()
        local W = dofile("tests/fog_world.lua")
        local G = W.new({ shader = true })
        G.reload({
            "NOM_FogState", "NOM_FogVignette", "NOM_ScreenFx", "NOM_ScreenFxOptions",
            "NOM_ScreenFxRules", "NOM_SemRosto", "NOM_Carpideira", "NOM_NightStats",
            "NOM_DressingRules", "NOM_PanelParams",
        })
        NOM_ShaderMod = true
        require "NOM_FogState"
        require "NOM_ScreenFxOptions"
        if NOM_ScreenFxOptions then NOM_ScreenFxOptions.bloom = function() return 0 end end
        local p = P()
        p.reset()
        NOM_PanelParams = p
        package.loaded["NOM_PanelParams"] = p
        R.setLookClean(false)
        p.set("GlitchMode", "original")

        G.enabled, G.targets, G.managers, G.override, G.fading, G.all = {}, {}, {}, {}, {}, {}
        G.FADE_TICKS = 30
        local function float(pn, name)
            return {
                setAll = function(_, v)
                    G.all[pn] = G.all[pn] or {}
                    G.all[pn][name] = v
                end,
                setTargets = function(_, ext, int)
                    G.targets[pn] = G.targets[pn] or {}
                    G.targets[pn][name] = { ext, int }
                end,
            }
        end
        getSearchMode = function()
            return {
                setEnabled = function(_, pn, b)
                    if not b and G.enabled[pn] then G.fading[pn] = G.FADE_TICKS end
                    G.enabled[pn] = b
                end,
                setOverride = function(_, pn, b) G.override[pn] = b end,
                isOverride = function(_, pn) return G.override[pn] == true end,
                isEnabled = function(_, pn) return G.enabled[pn] == true end,
                getSearchModeForPlayer = function(_, pn)
                    return {
                        isShaderEnabled = function()
                            return G.enabled[pn] == true or G.fading[pn] ~= nil
                        end,
                        getBlur = function() return float(pn, "blur") end,
                        getDesat = function() return float(pn, "desat") end,
                        getRadius = function() return float(pn, "radius") end,
                        getDarkness = function() return float(pn, "darkness") end,
                        getGradientWidth = function() return float(pn, "gradient") end,
                    }
                end,
            }
        end
        ISSearchManager = {
            getManager = function(pl)
                if not G.managers[pl] then
                    G.managers[pl] = {
                        isOverride = false, isSearchMode = false, isEffectOverlay = false,
                        pn = pl:getPlayerNum(),
                        updateOverlay = function() end,
                    }
                end
                return G.managers[pl]
            end,
        }
        dofile("mod/42/media/lua/client/NOM_FogVignette.lua")
        G.p = G.player({ x = 100, y = 100 })

        -- sampleSeen devolve fog+static=1; o que importa é write→setAll→lastChannel
        -- (updateStatic zeraria sem Sem-rosto no mundo falso).
        require "NOM_ScreenFx"
        NOM_ScreenFx.sampleSeen = function()
            return foggedStatic(1)
        end
        NOM_FogState.set(true, 1)

        p.set("GlitchIntensity", 0)
        G.seconds(2)
        assert(G.override[0] == true, "não tomou canal com static+fog")
        assert(G.all[0] and G.all[0].radius == 0, "0%: radius=" .. tostring(G.all[0] and G.all[0].radius))
        local lc0 = NOM_FogVignette.lastChannel()
        assert(lc0 and lc0.intensity == 0 and lc0.mode == "original", "lastChannel 0%")

        p.set("GlitchIntensity", 200)
        G.tick(1) -- writeChannels todo tick com shader — mesmo frame seguinte
        assert(G.all[0].radius == 2, "200%: radius=" .. tostring(G.all[0].radius) .. " (quer 2)")
        local lc200 = NOM_FogVignette.lastChannel()
        assert(lc200 and lc200.intensity == 2 and lc200.radius == 2,
            string.format("lastChannel 200%%: int=%s r=%s",
                tostring(lc200 and lc200.intensity), tostring(lc200 and lc200.radius)))
        p.reset()
        R.setLookClean(false)
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
