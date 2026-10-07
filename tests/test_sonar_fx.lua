-- client/NOM_SonarFx.lua (sprint 0037): o anel do sonar na tela quando o mod3 não pega.
-- Contra o mundo falso de tests/fog_world.lua (isoToScreenX/Y e getTimestampMs do B42.21).
-- ISUIElement:drawTextureScaled(tex, x, y, w, h, a, r, g, b) com cor →
-- javaObject:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a)
-- (client/ISUI/ISUIElement.lua:1032-1041). getTexture e MainScreen.instance:isReallyVisible()
-- (ISSleepingUI.lua:14, 49). Cada um é uma ida ao Java, contada em G.java.
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
    -- o NOM_Sonar de verdade é testado em test_sonar.lua; aqui só o registro do desenho
    NOM_Sonar = { onRing = function(fn) G.listener = fn end }
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
    NOMRender_sonar = opts.mod3
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    G.pc = calls({ G.p })
    G.el = fakeElement(G)
    -- o anel como chega: NOM_Sonar.ring chama os ouvintes com (x, y, z)
    function G.ring(x, y, z) G.listener(x, y, z) end
    -- avança ms reais e desenha um quadro; G.cost = idas ao Java do desenho
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
    -- No meio da expansão a elipse está centrada no Estalador, 2:1, com a frente no raio
    -- projetado: a ponta da direita e a de cima do círculo de raio r caem na frente da textura.
    sonar_fx_ring_on_floor = function()
        local G = setup()
        rules()
        G.ring(104, 98, 0)
        G.frame(750)
        assert(#G.draws == 1, "um anel, um desenho: " .. #G.draws)
        local d = G.draws[1]
        assert(d.tex == R.TEXTURE)
        local r = R.radius(750)
        local cx, cy = isoToScreenX(0, 104, 98, 0), isoToScreenY(0, 104, 98, 0)
        local o = r / math.sqrt(2)
        local right = isoToScreenX(0, 104 + o, 98 - o, 0)
        local top = isoToScreenY(0, 104 - o, 98 - o, 0)
        assert(near(d.x + d.w / 2, cx) and near(d.y + d.h / 2, cy), "centrado")
        assert(near(d.h, d.w / 2), "2:1")
        assert(near(cx + R.TEX_RING * d.w / 2, right), "frente na ponta da direita")
        assert(near(cy - R.TEX_RING * d.h / 2, top), "frente na ponta de cima")
        assert(near(d.a, R.ALPHA), "discreto: " .. d.a)
        local c = R.COLOR.white
        assert(d.r == c[1] and d.g == c[2] and d.b == c[3], "cor da névoa branca")
        NOM_FogState.red = true
        G.frame()
        c = R.COLOR.red
        assert(G.draws[1].r == c[1], "névoa vermelha tinge o anel")
    end,

    -- cresce com o tempo, some em FADE_MS depois do fim e sai da lista
    sonar_fx_grows_and_fades = function()
        local G = setup()
        rules()
        G.ring(100, 100, 0)
        G.frame(300)
        local w1 = G.draws[1].w
        G.frame(900)
        assert(G.draws[1].w > w1, "cresce")
        G.frame(R.DURATION_MS - 1200 + R.FADE_MS / 2)
        assert(#G.draws == 1 and G.draws[1].a < R.ALPHA, "esmaecendo")
        G.frame(R.FADE_MS)
        assert(#G.draws == 0 and #NOM_SonarFx.rings == 0, "acabou e saiu da lista")
        G.frame()
        assert(G.cost == 0, "sem anel o quadro não vai ao Java: " .. G.cost)
    end,

    -- o mod3 pega o anel: a tela não desenha. Recusa ou erro do mod3: a tela desenha.
    sonar_fx_mod3_first = function()
        local asked = {}
        local G = setup({ mod3 = function(x, y, z) asked[#asked + 1] = { x, y, z }; return true end })
        G.ring(101, 102, 0)
        G.frame(500)
        assert(#asked == 1 and asked[1][1] == 101 and asked[1][2] == 102 and asked[1][3] == 0)
        assert(#G.draws == 0 and G.cost == 0 and NOM_SonarFx.mod3 == 1, "mod3 pegou")
        G = setup({ mod3 = function() return false end })
        G.ring(101, 102, 0)
        G.frame(500)
        assert(#G.draws == 1, "mod3 recusou: anel na tela")
        G = setup({ mod3 = function() error("java") end })
        G.ring(101, 102, 0)
        G.frame(500)
        assert(#G.draws == 1, "erro do mod3 não some com o anel")
    end,

    -- outro andar, longe demais, menu aberto, morto ou sem textura: nada desenhado
    sonar_fx_skips = function()
        local G = setup()
        rules()
        G.ring(100, 100, 1)
        G.ring(100 + R.VIEW + 1, 100, 0)
        G.frame(500)
        assert(#G.draws == 0, "outro andar e longe")
        G.ring(100, 100, 0)
        G.menu = true
        G.frame()
        assert(#G.draws == 0, "menu")
        G.menu = false
        G.p.dead = true
        G.frame()
        assert(#G.draws == 0, "morto")
        G = setup()
        G.missing = true
        G.ring(100, 100, 0)
        G.frame(500)
        G.frame()
        assert(#G.draws == 0 and G.texCalls == 1, "sem textura: some e não pergunta de novo")
    end,

    -- no máximo MAX_RINGS vivos: o mais velho sai
    sonar_fx_cap = function()
        local G = setup()
        rules()
        for i = 1, R.MAX_RINGS + 3 do G.ring(100 + i * 0.1, 100, 0) end
        assert(#NOM_SonarFx.rings == R.MAX_RINGS)
        assert(near(NOM_SonarFx.rings[1].x, 100.4), "o mais velho saiu")
    end,

    -- custo por quadro travado: 0 sem anel; base fixa + 4 por anel (3 projeções e 1 desenho)
    sonar_fx_budget = function()
        local G = setup()
        rules()
        G.frame()
        assert(G.cost == 0, "sem anel: " .. G.cost)
        G.ring(100, 100, 0)
        G.frame(500)
        G.frame(16) -- o primeiro quadro também pede a textura, uma vez só
        local one = G.cost
        for i = 1, R.MAX_RINGS - 1 do G.ring(100 + i, 100, 0) end
        G.frame(16)
        G.frame(16)
        local full = G.cost
        print(string.format("[budget] sonar na tela: 1 anel %d idas ao Java/quadro; %d anéis %d", one, R.MAX_RINGS, full))
        assert(full - one == 4 * (R.MAX_RINGS - 1), "4 por anel: " .. one .. " → " .. full)
        assert(full <= 6 + 4 * R.MAX_RINGS, "pior quadro: " .. full)
    end,

    -- a textura existe, é RGBA e está no CREDITS (test_credits.lua cobra todo asset)
    sonar_fx_texture_asset = function()
        local R0 = dofile("mod/42/media/lua/shared/NOM_SonarRules.lua")
        local w, h, kind = png("mod/42/" .. R0.TEXTURE)
        assert(w == 256 and h == 256 and kind == 6, "256×256 RGBA")
        local f = assert(io.open("CREDITS.md"))
        local s = f:read("*a")
        f:close()
        assert(s:find("NOM_SonarAnel.png", 1, true), "fora do CREDITS")
    end,
}
