-- client/NOM_ScreenFx.lua (sprint 0013) contra uma UI falsa que imita o B42
-- (bytecode do 42.21 e Lua vanilla):
-- * ISUIElement (client/ISUI/ISUIElement.lua): derive, new(x, y, w, h), instantiate
--   cria o UIElement com setConsumeMouseEvents(self.wantMouseEvents or false) (:1004),
--   addToUIManager/removeFromUIManager (:1365-1380), backMost (:1381-1386),
--   drawTextureScaled com cor → DrawTextureScaledColor (:1032-1041), drawTextureTiled
--   → DrawTextureTiled, uma chamada (:1109-1117). Cada Draw* é uma ida ao Java.
-- * UIManager.update 389–454: todo elemento com backMost (alwaysBack) vai pro índice
--   0. UIManager.render: OnPreUIDraw, depois a lista na ordem (o índice 0 primeiro,
--   por baixo de tudo), depois OnPostUIDraw.
-- * Clique (updateMouseButtons 54–206): do topo pra baixo, só quem tem o ponto dentro
--   da caixa (isOverElement); onConsumeMouseButtonDown → onMouseDown do Lua, e o
--   retorno manda (nil → consumeMouseEvents). Roda: isPointOver + onMouseWheel.
--   isForceCursorVisible: algum elemento visível com o mouse em cima.
-- * getPlayerScreenLeft/Top/Width/Height(0) e MainScreen.instance:isReallyVisible()
--   (client/ISUI/ISSleepingUI.lua:16-17, 49, 60-61); getTexture(caminho) (:14).
local W = dofile("tests/fog_world.lua")
require "NOM_Rules"
require "NOM_FogEventRules"
local FILE = "mod/42/media/lua/client/NOM_ScreenFx.lua"

local function fakeUI(G)
    G.ui, G.draws, G.java = {}, {}, 0
    local function java() G.java = G.java + 1 end
    ISUIElement = {}
    ISUIElement.__index = ISUIElement
    function ISUIElement:derive(name)
        local c = setmetatable({ Type = name }, { __index = self })
        c.__index = c
        return c
    end
    function ISUIElement.new(class, x, y, w, h)
        -- o vanilla nasce consumindo mouse (ISUIElement:new: wantMouseEvents = true)
        local o = setmetatable({ x = x, y = y, width = w, height = h, wantMouseEvents = true }, class)
        return o
    end
    function ISUIElement:instantiate()
        local me = self
        self.javaObject = { table = self, x = self.x, y = self.y, w = self.width, h = self.height,
            visible = true, consume = self.wantMouseEvents or false, alwaysBack = false, onTop = false }
        local j = self.javaObject
        function j:setConsumeMouseEvents(b) java(); self.consume = b end
        function j:backMost() java(); self.alwaysBack = true end
        function j:setAlwaysOnTop(b) java(); self.onTop = b end
        local function draw(kind)
            return function(_, tex, x, y, w, h, ...)
                java()
                G.draws[#G.draws + 1] = { kind = kind, tex = tex and tex.path, x = x, y = y, w = w, h = h, args = { ... }, owner = me }
            end
        end
        j.DrawTextureScaled = draw("scaled")
        j.DrawTextureScaledColor = draw("scaled")
        j.DrawTextureTiled = draw("tiled")
    end
    function ISUIElement:backMost()
        if not self.javaObject then self:instantiate() end
        self.javaObject:backMost()
    end
    function ISUIElement:addToUIManager()
        if not self.javaObject then self:instantiate() end
        UIManager.AddUI(self.javaObject)
    end
    function ISUIElement:removeFromUIManager()
        if not self.javaObject then return end
        UIManager.RemoveElement(self.javaObject)
        self.removed = true
    end
    function ISUIElement:drawTextureScaled(tex, x, y, w, h, a, r, g, b)
        if r == nil then self.javaObject:DrawTextureScaled(tex, x, y, w, h, a)
        else self.javaObject:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a) end
    end
    function ISUIElement:drawTextureTiled(tex, x, y, w, h, r, g, b, a)
        self.javaObject:DrawTextureTiled(tex, x, y, w, h, r or 1, g or 1, b or 1, a or 1)
    end

    UIManager = {
        AddUI = function(j) G.ui[#G.ui + 1] = j end,
        RemoveElement = function(j)
            for i, v in ipairs(G.ui) do if v == j then table.remove(G.ui, i) break end end
        end,
    }
    function G.uiUpdate()
        for i = 1, #G.ui do
            if G.ui[i].alwaysBack then
                local j = table.remove(G.ui, i)
                table.insert(G.ui, 1, j)
            end
        end
    end
    -- um quadro do jogo: tick + update da UI + render da UI
    function G.frame(n)
        for _ = 1, n or 1 do
            G.tick(1)
            G.uiUpdate()
            G.fire("OnPreUIDraw")
            for _, j in ipairs(G.ui) do
                if j.visible and j.table.render then j.table:render() end
            end
            G.fire("OnPostUIDraw")
        end
    end
    function G.frameDraws()
        G.draws = {}
        G.frame(1)
        return G.draws
    end
    local function inside(j, x, y) return x >= j.x and y >= j.y and x < j.x + j.w and y < j.y + j.h end
    -- clique: devolve quem consumiu (nil = o jogo, o mundo)
    function G.click(x, y)
        for i = #G.ui, 1, -1 do
            local j = G.ui[i]
            if j.visible and inside(j, x, y) then
                local consumed
                if j.table.onMouseDown then
                    local r = j.table:onMouseDown(x - j.x, y - j.y)
                    if r == nil then consumed = j.consume else consumed = r end
                else
                    consumed = false
                end
                if consumed then return j end
            end
        end
        return nil
    end
    function G.wheel(x, y)
        for i = #G.ui, 1, -1 do
            local j = G.ui[i]
            if inside(j, x, y) and j.table.onMouseWheel and j.table:onMouseWheel(1) then return j end
        end
        return nil
    end
    function G.cursorForced(x, y)
        for _, j in ipairs(G.ui) do if j.visible and inside(j, x, y) then return true end end
        return false
    end

    G.screen = { [0] = { 0, 0, 1920, 1080 } }
    getPlayerScreenLeft = function(i) java(); return G.screen[i][1] end
    getPlayerScreenTop = function(i) java(); return G.screen[i][2] end
    getPlayerScreenWidth = function(i) java(); return G.screen[i][3] end
    getPlayerScreenHeight = function(i) java(); return G.screen[i][4] end
    G.menu = false
    MainScreen = { instance = { inGame = true, isReallyVisible = function() java(); return G.menu end } }
    G.textures = {}
    getTexture = function(path) java(); return { path = path } end
    local now = getTimestampMs
    getTimestampMs = function() java(); return now() end
    local sp = getSpecificPlayer
    getSpecificPlayer = function(i) java(); return sp(i) end
end

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SemRosto", "NOM_NightStats", "NOM_Carpideira", "NOM_ScreenFx",
        "NOM_ScreenFxOptions", "NOM_ScreenFxRules" })
    NOM_ShaderMod = opts.shader
    G.optOn, G.optInt = true, 1
    NOM_ScreenFxOptions = {
        enabled = function() return G.optOn end,
        intensity = function() return G.optOn and G.optInt or 0 end,
    }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    require "NOM_SemRosto"
    require "NOM_Carpideira"
    NOM_SemRosto.install(function() end) -- no solo o server/NOM_Fog.lua instala
    fakeUI(G)
    -- o HUD vanilla já está na lista quando o jogo começa
    G.hud = { table = { render = function() G.draws[#G.draws + 1] = { kind = "hud" } end },
        x = 0, y = 0, w = 300, h = 300, visible = true, consume = true }
    G.ui[1] = G.hud
    dofile(FILE)
    if opts.embers then -- sprint 0018: brasas do Eco pelo mesmo overlay
        _G.NOM_Embers = nil
        package.loaded.NOM_Embers = nil
        package.loaded.NOM_ScreenFx = NOM_ScreenFx -- o dofile não registra: o require carregaria de novo
        G.zoom = 1
        isoToScreenX = function(pn, x, y, z) G.java = G.java + 1; assert(pn == 0); return (x - y) * 32 + 960 end
        isoToScreenY = function(pn, x, y, z) G.java = G.java + 1; assert(pn == 0); return (x + y) * 16 - z * 96 + 100 end
        getCore = function() return { getZoom = function(_, pn) G.java = G.java + 1; return G.zoom end } end
        dofile("mod/42/media/lua/client/NOM_Embers.lua")
    end
    G.p = G.player({ x = 100, y = 100, face = 0 })
    if not opts.noStart then G.fire("OnGameStart") end
    return G
end

local function byTex(draws, path)
    for _, d in ipairs(draws) do if d.tex == path then return d end end
    return nil
end

local function mine(draws)
    local out = {}
    for _, d in ipairs(draws) do if d.owner then out[#out + 1] = d end end
    return out
end

local function alpha(d)
    if d.kind == "tiled" then return d.args[4] end
    return d.args[4]
end

local function fogOn(G, red)
    NOM_FogState.set(true, 1, red)
    G.frame(math.ceil(NOM_ScreenFxRules.FADE_MS / 16) + 2)
end

local R -- NOM_ScreenFxRules depois do setup
local function T() R = NOM_ScreenFxRules; return R.TEXTURES end

return {
    screenfx_inert_on_dedicated = function()
        local G = setup({ server = true, noStart = true })
        G.fire("OnGameStart")
        assert(#G.ui == 1, "servidor dedicado criou overlay")
    end,

    -- critério: por cima do mundo, por baixo do HUD; 1 px, não consome nada
    screenfx_created_behind_hud = function()
        local G = setup()
        assert(#G.ui == 2)
        G.frame(1)
        assert(G.ui[1].table == NOM_ScreenFx.ui, "não está no fundo da lista")
        local j = G.ui[1]
        assert(j.alwaysBack and not j.onTop and j.consume == false)
        assert(j.w == 1 and j.h == 1, "elemento maior que 1 px: " .. j.w .. "x" .. j.h)
        fogOn(G)
        local d = G.frameDraws()
        assert(d[1].owner and d[#d].kind == "hud", "o HUD não ficou por cima")
    end,

    -- Review Focus 1: clique, roda e cursor no canto (0,0) passam pro jogo
    screenfx_corner_click_passes = function()
        local G = setup()
        G.hud.x, G.hud.y = 500, 500 -- HUD longe do canto
        fogOn(G)
        assert(G.click(0, 0) == nil, "clique no canto consumido")
        assert(G.wheel(0, 0) == nil, "roda no canto consumida")
        assert(G.click(960, 540) == nil, "clique no meio da tela consumido")
        assert(not G.cursorForced(960, 540), "força o cursor no meio da tela")
        local ui = NOM_ScreenFx.ui
        assert(ui:onMouseUp(0, 0) == false and ui:onMouseMove(1, 1) == false and ui:onRightMouseDown(0, 0) == false)
    end,

    screenfx_nothing_outside_fog_cheap = function()
        local G = setup()
        G.frame(60)
        G.java = 0
        local d = G.frameDraws()
        assert(#mine(d) == 0, "desenhou sem névoa")
        assert(G.java <= 1, "chamadas Java fora da névoa: " .. G.java)
    end,

    -- sprint 0034: os efeitos do Outro Mundo esperam a fuga; na subida só a estática sutil,
    -- na cor da névoa que vem
    screenfx_only_static_while_rising = function()
        local G = setup()
        local tex = T()
        NOM_FogState.setRising(true, true)
        G.frame(60)
        local m = mine(G.frameDraws())
        assert(#m == 1 and m[1].tex == tex.static, "na fuga desenhou além da estática: " .. #m)
        assert(m[1].kind == "tiled", "a estática não é em mosaico")
        assert(math.abs(alpha(m[1]) - R.STATIC_SUBTLE) < 1e-9, "não é o sutil: " .. alpha(m[1]))
        local C = NOM_Rules.RED_FOG_COLOR
        assert(m[1].args[1] == C[1] and m[1].args[2] == C[2] and m[1].args[3] == C[3], "não é a cor da vermelha")
    end,

    -- presságio: fora de qualquer névoa, a estática cresce 3 s e ganha destaque; cobre a tela
    -- e chia (anda a cada quadro); a sirene leva ao sutil
    screenfx_static_presage_grows = function()
        local G = setup()
        local tex = T()
        NOM_FogState.setOmen(false)
        local first = byTex(G.frameDraws(), tex.static)
        assert(first and alpha(first) < R.STATIC_PEAK / 4, "o presságio não começou sutil")
        assert(#mine(G.draws) == 1, "o presságio ligou o Outro Mundo")
        local F = NOM_Rules.FOG_COLOR
        assert(first.args[1] == F[1] and first.args[2] == F[2] and first.args[3] == F[3], "não é a cor da branca")
        assert(first.x <= 0 and first.y <= 0 and first.x + first.w >= 1920 and first.y + first.h >= 1080, "não cobre")
        local pos = {}
        for _ = 1, 10 do
            local d = byTex(G.frameDraws(), tex.static)
            pos[d.x .. "," .. d.y] = true
        end
        local n = 0
        for _ in pairs(pos) do n = n + 1 end
        assert(n >= 3, "a estática está parada")
        G.frame(math.ceil(NOM_FogEventRules.PRESAGE_MS / 16))
        local peak = byTex(G.frameDraws(), tex.static)
        assert(math.abs(alpha(peak) - R.STATIC_PEAK) < 1e-9, "sem destaque no fim: " .. alpha(peak))
        NOM_FogState.setRising(true, false)
        G.frame(math.ceil(R.STATIC_SETTLE_MS / 16) + 2)
        assert(math.abs(alpha(byTex(G.frameDraws(), tex.static)) - R.STATIC_SUBTLE) < 1e-9, "não desceu ao sutil")
    end,

    -- na névoa: a estática sutil junto com o resto; acabou, some em ~3 s
    screenfx_static_in_fog_and_fades = function()
        local G = setup()
        local tex = T()
        fogOn(G)
        local d = byTex(G.frameDraws(), tex.static)
        assert(d and math.abs(alpha(d) - R.STATIC_SUBTLE) < 1e-9, "sem estática na névoa")
        NOM_FogState.set(false, 1)
        G.frame(math.ceil(R.STATIC_FADE_MS / 32))
        local mid = byTex(G.frameDraws(), tex.static)
        assert(mid and alpha(mid) > 0 and alpha(mid) < R.STATIC_SUBTLE, "não desceu aos poucos")
        G.frame(math.ceil(R.STATIC_FADE_MS / 16) + 2)
        assert(byTex(G.frameDraws(), tex.static) == nil, "ficou depois do fim")
    end,

    -- a opção ScreenFx (acessibilidade) desliga e o slider escala a estática também
    screenfx_static_follows_options = function()
        local G = setup()
        local tex = T()
        NOM_FogState.setRising(true, false)
        G.frame(5)
        G.optInt = 2
        assert(math.abs(alpha(byTex(G.frameDraws(), tex.static)) - 2 * R.STATIC_SUBTLE) < 1e-9, "não escala")
        G.optOn = false
        assert(#mine(G.frameDraws()) == 0, "desligado desenha a estática")
        G.optOn = true
        NOM_FogState.setRising(false)
        NOM_FogState.setOmen(true)
        G.optInt = 0
        assert(#mine(G.frameDraws()) == 0, "intensidade 0 desenha o presságio")
    end,
    screenfx_fog_draws_grain_and_vignette = function()
        local G = setup()
        local tex = T()
        NOM_FogState.set(true, 1)
        G.frame(30)
        local v1 = alpha(byTex(G.frameDraws(), tex.vignette))
        fogOn(G)
        G.java = 0
        local d = G.frameDraws()
        local m = mine(d)
        assert(#m >= 2 and #m <= 4, "desenhos: " .. #m)
        local grain = m[1]
        assert(grain.kind == "tiled" and grain.tex:find("NOM_Grain"), "grão")
        assert(grain.x <= 0 and grain.y <= 0 and grain.x + grain.w >= 1920 and grain.y + grain.h >= 1080, "grão não cobre")
        local v = byTex(d, tex.vignette)
        assert(v and v.x == 0 and v.y == 0 and v.w == 1920 and v.h == 1080)
        assert(alpha(v) > v1, "sem fade de entrada")
        assert(v.args[1] == 0 and v.args[2] == 0 and v.args[3] == 0, "vinheta normal não é preta")
        assert(G.java <= 12, "chamadas Java por quadro: " .. G.java)
        -- quadros de grão mudam com o tempo
        local frames = {}
        for _ = 1, 30 do frames[mine(G.frameDraws())[1].tex] = true end
        local n = 0
        for _ in pairs(frames) do n = n + 1 end
        assert(n >= 2, "grão parado")
        NOM_FogState.set(false, 1)
        G.frame(math.ceil(R.FADE_MS / 16) + 2)
        assert(#mine(G.frameDraws()) == 0, "ficou depois da névoa")
    end,

    screenfx_red_fog_red_and_stronger = function()
        local G = setup()
        local tex = T()
        fogOn(G)
        local normal = alpha(byTex(G.frameDraws(), tex.vignette))
        NOM_FogState.set(false, 1)
        G.frame(math.ceil(R.FADE_MS / 16) + 2)
        fogOn(G, true)
        local v = byTex(G.frameDraws(), tex.vignette)
        assert(v.args[1] > 0 and v.args[2] == 0 and v.args[3] == 0, "vinheta vermelha sem vermelho")
        assert(alpha(v) > normal * 1.2, "vermelha não é mais forte")
    end,

    -- linhas pela distância do Sem-rosto mais perto (o mesmo do rádio, sprint 0005)
    screenfx_lines_with_semrosto_distance = function()
        local G = setup()
        local tex = T()
        fogOn(G)
        assert(byTex(G.frameDraws(), tex.lines) == nil, "linhas sem Sem-rosto")
        local z = G.zombie({ x = 125, y = 100, id = W.semRostoID(1, true) })
        G.frame(30)
        local far = byTex(G.frameDraws(), tex.lines)
        assert(far and alpha(far) > 0, "Sem-rosto a 25 tiles sem linhas")
        z.x = 105.5
        G.frame(30)
        local near = byTex(G.frameDraws(), tex.lines)
        assert(alpha(near) > alpha(far), "perto não é mais forte")
        assert(near.x <= 0 and near.x + near.w >= 1920 and near.y <= 0 and near.y + near.h >= 1080)
        SandboxVars.NevoaEOutroMundo.SemRostoEnabled = false
        G.frame(30)
        assert(byTex(G.frameDraws(), tex.lines) == nil, "linhas com o Sem-rosto desligado")
    end,

    screenfx_carpideira_scream_flash = function()
        local G = setup()
        local tex = T()
        fogOn(G)
        local z = G.zombie({ x = 104, y = 100, id = 77 })
        NOM_Carpideira.scream(z, G.p)
        local f = byTex(G.frameDraws(), tex.white)
        assert(f and alpha(f) > 0 and f.args[1] > f.args[2], "sem pulso vermelho")
        G.frame(math.ceil(R.FLASH_MS / 16) + 1)
        assert(byTex(G.frameDraws(), tex.white) == nil, "pulso não acabou")
        local far = G.zombie({ x = 160, y = 100, id = 78 })
        NOM_Carpideira.scream(far, nil)
        assert(byTex(G.frameDraws(), tex.white) == nil, "grito longe pulsou")
    end,

    -- uma falha no efeito não pode quebrar o grito (no solo é o servidor que chama)
    screenfx_scream_listener_error_does_not_break_scream = function()
        local G = setup()
        NOM_Carpideira.onScream(function() error("quebrou") end)
        local z = G.zombie({ x = 104, y = 100, id = 77 })
        NOM_Carpideira.scream(z, G.p)
        assert(#G.playing(NOM_Carpideira.SCREAM) == 1, "o grito não tocou")
    end,

    screenfx_menu_and_death_hide = function()
        local G = setup()
        fogOn(G)
        G.menu = true
        assert(#mine(G.frameDraws()) == 0, "desenhou com o menu aberto")
        G.menu = false
        assert(#mine(G.frameDraws()) > 0)
        G.p.dead = true
        assert(#mine(G.frameDraws()) == 0, "desenhou morto")
        G.p.dead = false
        local d = byTex(G.frameDraws(), NOM_ScreenFxRules.TEXTURES.vignette)
        assert(d == nil or alpha(d) < 0.1, "não recomeçou do zero depois da morte")
    end,

    -- Review Focus 2: voltar ao menu tira o elemento; outro jogo cria um só
    screenfx_main_menu_removes_and_new_game_recreates = function()
        local G = setup()
        G.fire("OnMainMenuEnter")
        assert(#G.ui == 1, "ficou na UI no menu principal")
        G.fire("OnGameStart")
        G.fire("OnGameStart")
        local n = 0
        for _, j in ipairs(G.ui) do if j.table == NOM_ScreenFx.ui then n = n + 1 end end
        assert(#G.ui == 2 and n == 1, "duplicou")
    end,

    -- Review Focus 3: resolução nova e tela dividida (jogador 0) no quadro seguinte
    screenfx_follows_resolution_change = function()
        local G = setup()
        fogOn(G)
        G.screen[0] = { 0, 0, 2560, 1440 }
        local v = byTex(G.frameDraws(), NOM_ScreenFxRules.TEXTURES.vignette)
        assert(v.w == 2560 and v.h == 1440)
        G.screen[0] = { 0, 0, 1280, 720 } -- tela dividida: a metade de cima é do jogador 0
        v = byTex(G.frameDraws(), NOM_ScreenFxRules.TEXTURES.vignette)
        assert(v.x == 0 and v.y == 0 and v.w == 1280 and v.h == 720)
    end,

    -- Review Focus 5: desligar ou zerar no meio da névoa some no quadro seguinte
    screenfx_option_off_mid_fog = function()
        local G = setup()
        fogOn(G)
        G.optInt = 0
        assert(#mine(G.frameDraws()) == 0, "intensidade 0 desenha")
        G.optInt = 2
        assert(#mine(G.frameDraws()) > 0)
        G.optOn = false
        assert(#mine(G.frameDraws()) == 0, "desligado desenha")
    end,

    screenfx_intensity_scales = function()
        local G = setup()
        fogOn(G)
        G.optInt = 0.5
        local lo = alpha(byTex(G.frameDraws(), NOM_ScreenFxRules.TEXTURES.vignette))
        G.optInt = 1.5
        local hi = alpha(byTex(G.frameDraws(), NOM_ScreenFxRules.TEXTURES.vignette))
        assert(hi > lo * 2, lo .. " " .. hi)
    end,

    -- com o mod do shader o grão é dele (real, no screen.frag): o overlay não desenha
    screenfx_shader_mod_skips_grain = function()
        local G = setup({ shader = true })
        fogOn(G)
        local m = mine(G.frameDraws())
        assert(#m >= 1)
        for _, d in ipairs(m) do assert(not d.tex:find("NOM_Grain"), "grão com o shader") end
    end,

    -- textura que o jogo não achar: a camada some, nada quebra
    screenfx_missing_texture_skips_layer = function()
        local G = setup()
        getTexture = function() return nil end
        fogOn(G)
        assert(#mine(G.frameDraws()) == 0)
    end,

    -- Sprint 0018: brasas da morte do Eco, pelo overlay, com ou sem névoa ---------------

    embers_drawn_outside_fog_near_the_eco = function()
        local G = setup({ embers = true })
        G.frame(5)
        assert(NOM_Embers.burst(10.5, 20.5, 0))
        G.frame(3)
        local d = mine(G.frameDraws())
        assert(#d > 0 and #d <= NOM_EmberRules.COUNT, "brasas: " .. #d)
        local sx, sy = isoToScreenX(0, 10.5, 20.5, 0), isoToScreenY(0, 10.5, 20.5, 0)
        for _, e in ipairs(d) do
            assert(e.tex == NOM_Embers.TEXTURE, "textura " .. tostring(e.tex))
            assert(math.abs(e.x - sx) < 60 and e.y < sy + 10 and e.y > sy - 120, "brasa longe do Eco")
            assert(e.w >= 1 and e.w <= 5)
        end
        -- zoom afastado (2): o rastro encolhe pela metade
        G.zoom = 2
        local far = mine(G.frameDraws())
        assert(far[1].w <= d[1].w and math.abs(far[1].x - sx) <= math.abs(d[1].x - sx) + 1)
    end,

    embers_end_and_menu = function()
        local G = setup({ embers = true })
        NOM_Embers.burst(10.5, 20.5, 0)
        G.menu = true
        assert(#mine(G.frameDraws()) == 0, "brasa com o menu aberto")
        G.menu = false
        G.frame(math.ceil(NOM_EmberRules.LIFE_MS / 16) + 2)
        assert(NOM_Embers.count() == 0 and #mine(G.frameDraws()) == 0, "brasa depois da vida")
    end,

    embers_cap_and_budget = function()
        local G = setup({ embers = true })
        for _ = 1, NOM_EmberRules.CAP do assert(NOM_Embers.burst(1, 1, 0)) end
        assert(not NOM_Embers.burst(1, 1, 0), "passou do teto")
        G.frame(8) -- fora do tick da distância do Sem-rosto (a cada 10)
        G.java = 0
        local d = mine(G.frameDraws())
        local B = NOM_EmberRules.CAP
        assert(G.java <= 4 + 2 * B + #d, "custou " .. G.java .. " com " .. #d .. " desenhos")
        G.fire("OnMainMenuEnter")
        assert(NOM_Embers.count() == 0)
    end,

    -- sem brasa, o quadro fora da névoa continua 1 chamada
    embers_idle_cheap = function()
        local G = setup({ embers = true })
        G.frame(60) -- fora do tick da distância do Sem-rosto (a cada 10)
        G.java = 0
        assert(#mine(G.frameDraws()) == 0 and G.java <= 1, "custou " .. G.java)
    end,

    -- review da 0018: as brasas por cima do grão e da vinheta
    embers_over_fog_layers = function()
        local G = setup({ embers = true })
        fogOn(G)
        NOM_Embers.burst(10.5, 20.5, 0)
        G.frame(3)
        local d = mine(G.frameDraws())
        local vig, firstEmber
        for i, e in ipairs(d) do
            if e.tex == NOM_ScreenFxRules.TEXTURES.vignette then vig = i end
            if e.tex == NOM_Embers.TEXTURE and not firstEmber then firstEmber = i end
        end
        assert(vig and firstEmber and firstEmber > vig, "brasa por baixo da vinheta")
    end,
}
