-- client/NOM_SonarFx.lua (sprint 0037 + 0048): ripples do burst na tela quando o mod3 não pega.
-- Contra o mundo falso de tests/fog_world.lua (isoToScreenX/Y e getTimestampMs do B42.21).
local W = dofile("tests/fog_world.lua")
local calls = dofile("tests/calls.lua")
local FILE = "mod/42/media/lua/client/NOM_SonarFx.lua"

local function near(a, b) return math.abs(a - b) < 1e-6 end

local function png(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    assert(s:sub(2, 4) == "PNG", path .. " não é PNG")
    local function u32(i) return s:byte(i) * 16777216 + s:byte(i + 1) * 65536 + s:byte(i + 2) * 256 + s:byte(i + 3) end
    return u32(17), u32(21), s:byte(26)
end

local function fakeElement(G)
    local el = { javaObject = {} }
    function el.javaObject:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a)
        G.java = G.java + 1
        G.draws[#G.draws + 1] = { tex = tex.path, x = x, y = y, w = w, h = h, r = r, g = g, b = b, a = a }
    end
    function el.javaObject:DrawTextureScaled(tex, x, y, w, h, a)
        G.java = G.java + 1
        G.draws[#G.draws + 1] = { tex = tex.path, x = x, y = y, w = w, h = h, a = a }
    end
    function el:drawTextureScaled(tex, x, y, w, h, a, r, g, b)
        if r == nil then self.javaObject:DrawTextureScaled(tex, x, y, w, h, a)
        else self.javaObject:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a) end
    end
    return el
end

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SonarRules", "NOM_SonarFx", "NOM_Sonar", "NOM_ScreenFx" })
    G.java, G.draws = 0, {}
    NOM_ScreenFx = { extra = {} }
    package.loaded.NOM_ScreenFx = NOM_ScreenFx
    G.clicks = {}
    NOM_Sonar = {
        onRing = function(fn) G.listener = fn end,
        playClick = function(x, y, z) G.clicks[#G.clicks + 1] = { x = x, y = y, z = z } end,
    }
    package.loaded.NOM_Sonar = NOM_Sonar
    require "NOM_FogState"
    G.menu = false
    MainScreen = { instance = { isReallyVisible = function() G.java = G.java + 1; return G.menu end } }
    G.missing, G.texCalls = false, 0
    getTexture = function(path)
        G.java = G.java + 1
        G.texCalls = G.texCalls + 1
        if G.missing then return nil end
        return { path = path }
    end
    local sp = getSpecificPlayer
    getSpecificPlayer = function(i) G.java = G.java + 1; return sp(i) end
    NOMRender_sonarRipple = opts.mod3
    NOMRender_sonar = nil
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    G.pc = calls({ G.p })
    G.el = fakeElement(G)
    function G.ring(x, y, z, burst) G.listener(x, y, z, burst) end
    function G.frame(ms)
        G.now = G.now + (ms or 16)
        G.draws = {}
        local j, pc = G.java, G.pc.n
        for _, fn in ipairs(NOM_ScreenFx.extra) do fn(G.el, G.now) end
        G.cost = G.java - j + G.pc.n - pc
    end
    return G
end

local R
local function rules()
    R = NOM_SonarRules
    return R
end

return {
    -- No meio da expansão do primeiro ripple a elipse está centrada, 2:1, frente no raio.
    sonar_fx_ring_on_floor = function()
        local G = setup()
        rules()
        G.ring(104, 98, 0)
        G.frame(R.RIPPLE_DURATION_MS / 2) -- primeiro beat em 0; meio do ripple
        assert(#G.draws >= 1, "pelo menos o primeiro ripple: " .. #G.draws)
        local d = G.draws[1]
        assert(d.tex == R.TEXTURE)
        local r = R.rippleRadius(R.RIPPLE_DURATION_MS / 2)
        local cx, cy = isoToScreenX(0, 104, 98, 0), isoToScreenY(0, 104, 98, 0)
        local o = r / math.sqrt(2)
        local right = isoToScreenX(0, 104 + o, 98 - o, 0)
        assert(near(d.x + d.w / 2, cx) and near(d.y + d.h / 2, cy), "centrado")
        assert(near(d.h, d.w / 2), "2:1")
        assert(near(cx + R.TEX_RING * d.w / 2, right), "frente na ponta da direita")
        assert(near(d.a, R.RIPPLE_ALPHA), "discreto: " .. d.a)
        local c = R.COLOR.white
        assert(d.r == c[1] and d.g == c[2] and d.b == c[3], "cor da névoa branca")
        NOM_FogState.red = true
        G.frame()
        c = R.COLOR.red
        assert(G.draws[1].r == c[1], "névoa vermelha tinge o anel")
    end,

    -- cresce com o tempo, some depois do fim e sai da lista
    sonar_fx_grows_and_fades = function()
        local G = setup()
        rules()
        G.ring(100, 100, 0)
        G.frame(120)
        local w1 = G.draws[1].w
        G.frame(200)
        assert(G.draws[1].w > w1, "cresce")
        -- avança até depois do fim do primeiro ripple (beats posteriores ainda podem viver)
        G.frame(R.RIPPLE_DURATION_MS + R.RIPPLE_FADE_MS)
        -- o primeiro (born=t0) já saiu; pode haver outros
        local alive = 0
        for _, g in ipairs(NOM_SonarFx.rings) do
            if G.now - g.born > 0 and not R.rippleDone(G.now - g.born) then alive = alive + 1 end
        end
        G.frame(R.BEAT_MS[#R.BEAT_MS] + R.RIPPLE_DURATION_MS + R.RIPPLE_FADE_MS)
        assert(#NOM_SonarFx.rings == 0, "todos os ripples saíram: " .. #NOM_SonarFx.rings)
        G.frame()
        assert(G.cost == 0, "sem anel o quadro não vai ao Java: " .. G.cost)
    end,

    -- o mod3 pega cada beat: a tela não desenha. Recusa ou erro: a tela desenha.
    sonar_fx_mod3_first = function()
        local asked = {}
        local G = setup({ mod3 = function(x, y, z) asked[#asked + 1] = { x, y, z }; return true end })
        rules()
        G.ring(101, 102, 0)
        G.frame(0)
        G.frame(R.BEAT_MS[#R.BEAT_MS] + 1)
        assert(#asked == #R.BEAT_MS, "um ripple por batida: " .. #asked)
        assert(asked[1][1] == 101 and asked[1][2] == 102 and asked[1][3] == 0)
        assert(#G.draws == 0 and NOM_SonarFx.mod3 == #R.BEAT_MS, "mod3 pegou todos")
        G = setup({ mod3 = function() return false end })
        rules()
        G.ring(101, 102, 0)
        G.frame(100)
        assert(#G.draws >= 1, "mod3 recusou: anel na tela")
        G = setup({ mod3 = function() error("java") end })
        rules()
        G.ring(101, 102, 0)
        G.frame(100)
        assert(#G.draws >= 1, "erro do mod3 não some com o anel")
    end,

    -- outro andar, longe demais, menu aberto, morto ou sem textura: nada desenhado
    sonar_fx_skips = function()
        local G = setup()
        rules()
        G.ring(100, 100, 1)
        G.ring(100 + R.VIEW + 1, 100, 0)
        G.frame(100)
        assert(#G.draws == 0, "outro andar e longe")
        G.ring(100, 100, 0)
        G.menu = true
        G.frame(100)
        assert(#G.draws == 0, "menu")
        G.menu = false
        G.p.dead = true
        G.frame(100)
        assert(#G.draws == 0, "morto")
        G = setup()
        rules()
        G.missing = true
        G.ring(100, 100, 0)
        G.frame(100)
        G.frame()
        assert(#G.draws == 0 and G.texCalls == 1, "sem textura: some e não pergunta de novo")
    end,

    -- no máximo MAX_RIPPLES vivos: o mais velho sai
    sonar_fx_cap = function()
        local G = setup()
        rules()
        local bursts = math.ceil((R.MAX_RIPPLES + 3) / #R.BEAT_MS) + 1
        for i = 1, bursts do G.ring(100 + i * 0.1, 100, 0) end
        assert(#NOM_SonarFx.rings == R.MAX_RIPPLES, "cap: " .. #NOM_SonarFx.rings)
    end,

    -- um burst agenda beatCount ripples; custo por quadro com ripples vivos
    sonar_fx_budget = function()
        local G = setup()
        rules()
        G.frame()
        assert(G.cost == 0, "sem anel: " .. G.cost)
        G.ring(100, 100, 0)
        G.frame(50) -- primeiro beat ativo
        G.frame(16)
        local one = G.cost
        assert(one > 0, "com ripple desenha")
        print(string.format("[budget] sonar na tela: 1 ripple ativo ~%d idas ao Java/quadro; beats=%d", one, #R.BEAT_MS))
        assert(one <= 6 + 4 * #R.BEAT_MS, "pior quadro com burst: " .. one)
    end,

    sonar_fx_texture_asset = function()
        local R0 = dofile("mod/42/media/lua/shared/NOM_SonarRules.lua")
        local w, h, kind = png("mod/42/" .. R0.TEXTURE)
        assert(w == 256 and h == 256 and kind == 6, "256×256 RGBA")
        local f = assert(io.open("CREDITS.md"))
        local s = f:read("*a")
        f:close()
        assert(s:find("NOM_SonarAnel.png", 1, true), "fora do CREDITS")
    end,

    -- burst agenda N ripples, um por BEAT_MS
    sonar_fx_schedules_beats = function()
        local G = setup()
        rules()
        G.ring(100, 100, 0)
        assert(#NOM_SonarFx.rings == #R.BEAT_MS)
        for i, g in ipairs(NOM_SonarFx.rings) do
            assert(g.born == G.now + R.BEAT_MS[i], "beat " .. i)
        end
    end,

    -- sprint 0056: variação B (e C) agenda ripples nos gaps próprios
    sonar_fx_schedules_pattern_b = function()
        local G = setup()
        rules()
        G.ring(100, 100, 0, 2)
        local beats = R.burstBeats(2)
        assert(#NOM_SonarFx.rings == #beats)
        for i, g in ipairs(NOM_SonarFx.rings) do
            assert(g.born == G.now + beats[i], "B beat " .. i)
            assert((g.click == true) == (beats[i] > 0), "tac atrasado só após 0")
        end
    end,
}
