-- client/NOM_Flakes.lua (sprint 0035): lascas de tinta e cinza sobem do chão e das paredes
-- no Outro Mundo, pelo overlay de tela (NOM_ScreenFx.extra). Contra o mundo falso de
-- tests/fog_world.lua com o NOM_FogOverlays de verdade (tests/attached_world.lua): as fontes
-- são os pisos e paredes que ele vestiu. Imita o B42.21 onde importa:
-- * isoToScreenX/Y(i, x, y, z) (LuaManager$GlobalObject 0–60, em tests/fog_world.lua): afim em
--   x, y, z por quadro (a câmera não muda dentro do quadro).
-- * ISUIElement:drawSubTexture(tex, subX, subY, subW, subH, x, y, w, h, a, r, g, b)
--   (client/ISUI/ISUIElement.lua:1043-1052): com r nil desenha a textura INTEIRA (o vanilla
--   esquece o recorte); com cor, UIElement.DrawSubTextureRGBA, recorte em pixels da textura
--   (bytecode 123–306). drawTextureScaled com cor → DrawTextureScaledColor (:1032-1041).
--   Cada Draw* é uma ida ao Java.
-- * getTexture(caminho), MainScreen.instance:isReallyVisible() (ISSleepingUI.lua:14, 49).
local W = dofile("tests/fog_world.lua")
local A = dofile("tests/attached_world.lua")
local calls = dofile("tests/calls.lua")
local FILE = "mod/42/media/lua/client/NOM_Flakes.lua"

local SHEET_W, SHEET_H -- tamanho do NOM_Lascas.png, lido do PNG

local function read(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- IHDR: largura, altura e tipo de cor (6 = RGBA)
local function png(path)
    local s = read(path)
    assert(s:sub(2, 4) == "PNG", path .. " não é PNG")
    local function u32(i) return s:byte(i) * 16777216 + s:byte(i + 1) * 65536 + s:byte(i + 2) * 256 + s:byte(i + 3) end
    return u32(17), u32(21), s:byte(26)
end

local function fakeElement(G)
    local el = { javaObject = {} }
    local j = el.javaObject
    local function rec(kind, t)
        G.java = G.java + 1
        t.kind = kind
        G.draws[#G.draws + 1] = t
    end
    function j:DrawSubTextureRGBA(tex, ...)
        local a = { ... }
        if #a == 8 then
            rec("whole", { tex = tex.path, x = a[1], y = a[2], w = a[3], h = a[4] })
        else
            rec("sub", { tex = tex.path, sx = a[1], sy = a[2], sw = a[3], sh = a[4], x = a[5], y = a[6], w = a[7],
                h = a[8], r = a[9], g = a[10], b = a[11], a = a[12] })
        end
    end
    function j:DrawTextureScaled(tex, x, y, w, h, a) rec("scaled", { tex = tex.path, x = x, y = y, w = w, h = h, a = a }) end
    function j:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a)
        rec("scaled", { tex = tex.path, x = x, y = y, w = w, h = h, r = r, g = g, b = b, a = a })
    end
    -- os wrappers do ISUIElement vanilla, como estão
    function el:drawSubTexture(tex, subX, subY, subW, subH, x, y, w, h, a, r, g, b)
        if r == nil then self.javaObject:DrawSubTextureRGBA(tex, x, y, w, h, 1, 1, 1, a)
        else self.javaObject:DrawSubTextureRGBA(tex, subX, subY, subW, subH, x, y, w, h, r, g, b, a) end
    end
    function el:drawTextureScaled(tex, x, y, w, h, a, r, g, b)
        if r == nil then self.javaObject:DrawTextureScaled(tex, x, y, w, h, a)
        else self.javaObject:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a) end
    end
    return el
end

local function walls(G, x0, y0, n)
    for x = x0, x0 + n - 1 do
        for y = y0, y0 + n - 1 do
            G.obj(x, y, 0, "N")
            G.obj(x, y, 0, "W")
        end
    end
end

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_DressingRules", "NOM_ScreenFxOptions", "NOM_FogOverlays", "NOM_FlakeRules",
        "NOM_Flakes", "NOM_ScreenFx" })
    PZAPI = nil
    G.java, G.draws = 0, {}
    G.optInt, G.optDensity = opts.intensity or 1, opts.density or 1
    NOM_ScreenFxOptions = {
        intensity = function() return G.optInt end,
        overlayDensity = function() return G.optDensity end,
    }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    NOM_ScreenFx = { extra = {} } -- o overlay da 0013 (testado em test_screen_fx.lua)
    package.loaded.NOM_ScreenFx = NOM_ScreenFx
    require "NOM_FogState"
    A.install(G)
    G.menu = false
    MainScreen = { instance = { isReallyVisible = function() G.java = G.java + 1; return G.menu end } }
    G.missing, G.texCalls = {}, 0
    getTexture = function(path)
        G.java = G.java + 1
        G.texCalls = G.texCalls + 1
        if G.missing[path] then return nil end
        return { path = path }
    end
    local sp = getSpecificPlayer
    getSpecificPlayer = function(i) G.java = G.java + 1; return sp(i) end
    dofile("mod/42/media/lua/client/NOM_FogOverlays.lua")
    package.loaded.NOM_FogOverlays = NOM_FogOverlays -- o dofile não registra: o require carregaria de novo
    -- A ordem do pairs no registro muda a cada processo no luajit (e não é contrato no Kahlua):
    -- as fontes vão em ordem fixa, pro mesmo sorteio dar sempre as mesmas lascas no mesmo lugar.
    local targets = NOM_FogOverlays.targets
    G.targetsAsked = {}
    NOM_FogOverlays.targets = function(...)
        G.targetsAsked[#G.targetsAsked + 1] = { ... }
        local out = targets(...)
        table.sort(out, function(a, b) return a.k < b.k end)
        return out
    end
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    G.pc = calls({ G.p })
    G.el = fakeElement(G)
    walls(G, 92, 92, 16)
    -- um quadro: tick do jogo e o desenho do overlay; G.cost = idas ao Java do desenho
    function G.frame(n)
        for _ = 1, n or 1 do
            G.tick(1)
            G.draws = {}
            local j, pc = G.java, G.pc.n
            for _, fn in ipairs(NOM_ScreenFx.extra) do fn(G.el, G.now) end
            G.cost = G.java - j + G.pc.n - pc
        end
    end
    function G.secs(s) G.frame(math.floor(s * 1000 / 16 + 0.5)) end
    return G
end

local F = function() return NOM_Flakes end
local R = function() return NOM_FlakeRules end

local function byKind(draws, kind)
    local n = 0
    for _, d in ipairs(draws) do if d.kind == kind then n = n + 1 end end
    return n
end

return {
    -- liga com a névoa (Outro Mundo): lascas pelo recorte do sprite sheet e cinza pela textura
    -- própria, as duas com cor
    flakes_on_with_fog = function()
        local G = setup()
        NOM_FogState.set(true, 3)
        G.secs(3)
        assert(F().count() > 10, "poucas lascas: " .. F().count())
        assert(byKind(G.draws, "whole") == 0, "drawSubTexture sem cor desenhou o sheet inteiro")
        local sub, ash = 0, 0
        for _, d in ipairs(G.draws) do
            assert(d.r and d.g and d.b and d.a, "desenho sem cor")
            if d.kind == "sub" then
                sub = sub + 1
                assert(d.tex == R().TEXTURES.lasca)
            else
                ash = ash + 1
                assert(d.kind == "scaled" and d.tex == R().TEXTURES.cinza)
            end
        end
        assert(sub > 0 and ash > 0, "lasca " .. sub .. " cinza " .. ash)
    end,

    -- review final da 0035: as fontes relidas a cada segundo pedem só o andar e o raio das
    -- lascas, não a cópia do registro inteiro
    flakes_sources_ask_only_their_radius = function()
        local G = setup()
        NOM_FogState.set(true, 3)
        G.secs(3)
        assert(#G.targetsAsked >= 2, "fontes relidas " .. #G.targetsAsked .. " vezes")
        for _, a in ipairs(G.targetsAsked) do
            assert(a[1] == 100 and a[2] == 100 and a[3] == 0 and a[4] == R().RADIUS,
                "pediu " .. table.concat({ tostring(a[1]), tostring(a[2]), tostring(a[3]), tostring(a[4]) }, ","))
        end
    end,

    -- o recorte é sempre uma célula inteira do sheet (quadro × formato), dentro do PNG
    flakes_sub_rect_is_a_cell = function()
        local G = setup()
        SHEET_W, SHEET_H = png("mod/42/" .. R().TEXTURES.lasca)
        NOM_FogState.set(true, 3)
        local cells = {}
        for _ = 1, 240 do
            G.frame(1)
            for _, d in ipairs(G.draws) do
                if d.kind == "sub" then
                    local C = R().CELL
                    assert(d.sw == C and d.sh == C, "célula " .. d.sw .. "x" .. d.sh)
                    assert(d.sx % C == 0 and d.sy % C == 0, "recorte fora da grade")
                    assert(d.sx + C <= SHEET_W and d.sy + C <= SHEET_H, "recorte fora do PNG")
                    cells[d.sx .. "," .. d.sy] = true
                end
            end
        end
        local n = 0
        for _ in pairs(cells) do n = n + 1 end
        assert(n >= R().FRAMES * R().SHAPES / 2, "poucas células usadas: " .. n)
    end,

    -- na subida da fuga (rising) não; só com a névoa de jogo
    flakes_not_while_rising = function()
        local G = setup()
        NOM_FogState.setRising(true, false)
        G.secs(3)
        assert(F().count() == 0 and #G.draws == 0, "lasca na fuga")
    end,

    -- fim da névoa: o ritmo para (só nascem as poucas que a retirada pede, Tarefa 2), as vivas
    -- terminam o fade e somem
    flakes_stop_at_end_with_fade = function()
        local G = setup()
        NOM_FogState.set(true, 3)
        G.secs(4)
        local before = F().count()
        assert(before > 0)
        local real, burst = F().burst, 0
        F().burst = function(...)
            local n = real(...)
            burst = burst + n
            return n
        end
        NOM_FogState.set(false)
        local last = before
        for _ = 1, 60 do
            local b = burst
            G.frame(1)
            assert(F().count() <= last + burst - b, "nasceu depois do fim fora da retirada")
            last = F().count()
        end
        assert(last > 0 and #G.draws > 0, "sumiram de golpe")
        G.secs(R().LIFE_MAX_MS / 1000 + NOM_FogOverlays.UNREVEAL_MS / 1000)
        assert(F().count() == 0, "sobrou " .. F().count())
        G.frame(1)
        assert(#G.draws == 0 and G.cost == 0, "custo sem lasca: " .. G.cost)
    end,

    -- toggle FogOverlays do sandbox desligado: nada
    flakes_respect_overlays_toggle = function()
        local G = setup({ sandbox = { FogOverlays = false } })
        NOM_FogState.set(true, 3)
        G.secs(3)
        assert(F().count() == 0, "lasca com o Outro Mundo desligado")
    end,

    -- desligado no meio: param de nascer
    flakes_toggle_off_mid_fog = function()
        local G = setup()
        NOM_FogState.set(true, 3)
        G.secs(3)
        SandboxVars.NevoaEOutroMundo.FogOverlays = false
        local last = F().count()
        for _ = 1, 30 do
            G.frame(1)
            assert(F().count() <= last, "nasceu com o toggle desligado")
            last = F().count()
        end
    end,

    -- efeitos de tela desligados (intensidade 0) ou densidade 0: nada
    flakes_respect_screen_fx_option = function()
        local G = setup({ intensity = 0 })
        NOM_FogState.set(true, 3)
        G.secs(3)
        assert(F().count() == 0, "lasca com os efeitos de tela desligados")
        local G2 = setup({ density = 0 })
        NOM_FogState.set(true, 3)
        G2.secs(3)
        assert(F().count() == 0, "lasca com densidade 0")
    end,

    -- mais intensidade e densidade, mais lascas
    flakes_scale_with_options = function()
        local function alive(int, den)
            local G = setup({ intensity = int, density = den })
            NOM_FogState.set(true, 3)
            G.secs(6)
            return F().count()
        end
        local low, high = alive(0.5, 1), alive(2, 2)
        assert(high > low * 1.5, "baixa " .. low .. " alta " .. high)
        assert(high <= R().MAX)
    end,

    -- review da 0039: a preta veste o Outro Mundo ×1,4 e as lascas do chão/parede acompanham
    -- (0057: a cinza no ar é igual nas cores; contar só F/N/W, e antes do teto MAX)
    flakes_black_denser = function()
        local function alive(black)
            local G = setup()
            NOM_FogState.set(true, 3, false, black)
            G.secs(2)
            local n = 0
            for _, p in ipairs(F().parts()) do
                if p.from ~= "A" then n = n + 1 end
            end
            return n
        end
        local white, black = alive(false), alive(true)
        assert(black > white * 1.2, "branca " .. white .. " preta " .. black)
    end,

    -- cinza no ar (0040 na vermelha; 0057 em toda névoa ativa): em volta do jogador, a meia
    -- altura, cor da paleta da névoa; some com os efeitos de tela desligados
    flakes_air_all_fog_colors = function()
        local function air(red, black, opts)
            local G = setup(opts)
            NOM_FogState.set(true, 3, red, black)
            G.secs(6)
            local n = 0
            for _, p in ipairs(F().parts()) do
                if p.from == "A" then
                    n = n + 1
                    local dx, dy = p.x - 100.5, p.y - 100.5 -- o meio do square do jogador
                    assert(dx * dx + dy * dy <= R().AIR_RADIUS ^ 2 + 1e-6, "longe do jogador")
                    assert(p.z > 0, "no chão")
                end
            end
            return n, G
        end
        local n, G = air(true, false)
        assert(n > 10 and n <= R().AIR_MAX, "vermelha sem cinza no ar: " .. n)
        local red = R().palette("red").cinza
        local seen = 0
        for _, d in ipairs(G.draws) do
            if d.kind == "scaled" then
                seen = seen + 1
                assert(d.r == red[1] and d.g == red[2] and d.b == red[3], "cor da cinza")
            end
        end
        assert(seen > 0, "cinza não desenhada")
        assert(air(false, false) > 5, "cinza no ar na branca")
        assert(air(false, true) > 5, "cinza no ar na preta")
        assert(air(true, false, { intensity = 0 }) == 0, "cinza no ar com os efeitos desligados")
    end,

    -- sem névoa e sem lasca, o desenho não vai ao Java
    flakes_off_costs_nothing = function()
        local G = setup()
        G.secs(2)
        assert(G.cost == 0 and #G.draws == 0, "custo fora da névoa: " .. G.cost)
    end,

    -- teto de idas ao Java por quadro, medido no pior caso (vermelha, densidade e intensidade 2)
    flakes_budget = function()
        local G = setup({ intensity = 2, density = 2 })
        NOM_FogState.set(true, 3, true)
        local worst, peak = 0, 0
        for _ = 1, 600 do
            G.frame(1)
            worst = math.max(worst, G.cost)
            peak = math.max(peak, F().count())
        end
        assert(peak <= R().MAX, "vivas " .. peak)
        assert(peak >= R().MAX * 0.8, "não chegou perto do teto: " .. peak)
        assert(worst <= R().MAX + F().FIXED_CALLS, "quadro com " .. worst .. " idas ao Java")
        print(string.format("[budget] lascas: até %d vivas, pior quadro %d idas ao Java (%d de base + 1 por lasca na tela)",
            peak, worst, F().FIXED_CALLS))
    end,

    -- a posição desenhada é a projeção do jogo no ponto da lasca mais o movimento / zoom, com
    -- zoom, câmera fora do centro e o ajuste fino da câmera
    flakes_projection_matches_game = function()
        for _, c in ipairs({ { zoom = 1 }, { zoom = 2, panX = 140, panY = -60 }, { zoom = 0.5, jiggle = 0.37 } }) do
            local G = setup({ zoom = c.zoom })
            G.camera.panX, G.camera.panY = c.panX or 0, c.panY or 0
            G.camera.jiggleX, G.camera.jiggleY = c.jiggle or 0, -(c.jiggle or 0)
            assert(F().burst(102, 98, 0, "N", 1) == 1)
            assert(F().burst(98, 102, 0, "F", 1) == 1)
            G.secs(1)
            local parts = F().parts()
            assert(#parts == 2 and #G.draws == 2, "desenhos: " .. #G.draws)
            for i, p in ipairs(parts) do
                local dx, dy, _, _, size = R().at(p, F().state().t - p.born)
                local s = size / c.zoom
                local x = isoToScreenX(0, p.x, p.y, p.z) + dx / c.zoom
                local y = isoToScreenY(0, p.x, p.y, p.z) + dy / c.zoom
                local d = G.draws[i]
                assert(math.abs(d.x + d.w / 2 - x) < 0.01 and math.abs(d.y + d.h / 2 - y) < 0.01,
                    string.format("zoom %.1f: desenhou em %.2f,%.2f, o jogo põe em %.2f,%.2f", c.zoom, d.x + d.w / 2, d.y + d.h / 2, x, y))
                assert(math.abs(d.w - s) < 1e-6, "tamanho sem zoom")
            end
        end
    end,

    -- fora da tela: não vai ao Java
    flakes_offscreen_not_drawn = function()
        local G = setup()
        F().burst(100 + 40, 100 - 40, 0, "F", 5) -- 40 tiles pra direita na tela
        G.frame(2)
        assert(F().count() == 5 and #G.draws == 0, "desenhou fora da tela: " .. #G.draws)
    end,

    -- as fontes são o que o Outro Mundo vestiu: chão e paredes do registro, perto do jogador
    flakes_spawn_on_dressed_squares = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3)
        G.secs(5)
        local dressed = {}
        for _, o in pairs(G.objs) do
            if #G.attachedNames(o, "mod") > 0 then dressed[o.x .. "," .. o.y .. "," .. o.kind] = true end
        end
        local walls, ground = 0, 0
        for _, p in ipairs(F().parts()) do
            if p.from == "A" then
                -- cinza no ar (0057): solta, sem anexo
            else
                local x, y = math.floor(p.x), math.floor(p.y)
                assert(dressed[x .. "," .. y .. "," .. p.from], "nasceu em " .. x .. "," .. y .. " " .. p.from .. " sem anexo")
                assert(math.sqrt((x - 100) ^ 2 + (y - 100) ^ 2) <= R().RADIUS + 1, "longe demais")
                if p.from ~= "F" then walls = walls + 1 else ground = ground + 1 end
            end
        end
        assert(walls > 0 and ground > 0, "nenhuma lasca de parede/chão")
    end,

    -- vermelha: a cor do desenho é a da paleta vermelha
    flakes_red_palette = function()
        local G = setup()
        NOM_FogState.set(true, 3, true)
        G.secs(3)
        local pal = R().palette("red")
        local n = 0
        for _, d in ipairs(G.draws) do
            local want = d.kind == "sub" and pal.lasca or pal.cinza
            assert(d.r == want[1] and d.g == want[2] and d.b == want[3], "cor fora da paleta vermelha")
            n = n + 1
        end
        assert(n > 0)
    end,

    -- rajada pedida de fora (Tarefa 2): respeita o teto
    flakes_burst_cap = function()
        local G = setup()
        assert(F().burst(100, 100, 0, "N", R().MAX + 50) == R().MAX)
        assert(F().burst(100, 100, 0, "F", 3) == 0)
        G.frame(1)
        assert(F().count() == R().MAX)
    end,

    -- menu aberto: não desenha nem anda; volta sem pular
    flakes_menu_pauses = function()
        local G = setup()
        F().burst(100, 100, 0, "F", 4)
        G.frame(2)
        G.menu = true
        G.secs(R().LIFE_MAX_MS / 1000 + 1)
        assert(#G.draws == 0, "desenhou com o menu")
        G.menu = false
        G.frame(1)
        assert(F().count() == 4 and #G.draws == 4, "o menu matou as lascas")
    end,

    -- morte: some tudo
    flakes_death_clears = function()
        local G = setup()
        NOM_FogState.set(true, 3)
        G.secs(2)
        assert(F().count() > 0)
        G.p.dead = true
        G.frame(1)
        assert(F().count() == 0 and #G.draws == 0)
    end,

    -- textura que não carrega: a camada some, sem erro e sem ir ao Java todo quadro
    flakes_missing_texture = function()
        local G = setup()
        G.missing[R().TEXTURES.lasca] = true
        G.missing[R().TEXTURES.cinza] = true
        F().burst(100, 100, 0, "F", 3)
        F().burst(100, 100, 0, "N", 3)
        G.frame(1)
        local n = G.texCalls
        G.frame(10)
        assert(#G.draws == 0)
        assert(G.texCalls == n, "getTexture todo quadro: " .. (G.texCalls - n))
    end,

    -- TRANSIÇÃO DESCASCANDO (sprint 0035, Tarefa 2) -----------------------------------------

    -- a névoa abre ao vivo: o square revelado pede rajada (NOM_FogOverlays → NOM_Flakes.burst),
    -- nunca além do teto; sem a rajada, no primeiro segundo quase nada nasceria (as fontes são
    -- relidas 1 vez por segundo e o Outro Mundo ainda está vazio)
    flakes_burst_on_live_reveal = function()
        local G = setup({ density = 2 })
        local spy = { calls = 0, asked = 0 }
        local real = F().burst
        F().burst = function(x, y, z, kind, n)
            spy.calls, spy.asked = spy.calls + 1, spy.asked + n
            return real(x, y, z, kind, n)
        end
        NOM_FogState.setRising(true)
        NOM_FogState.set(true, 3)
        NOM_FogState.setRising(false)
        local peak = 0
        for _ = 1, math.floor(NOM_FogOverlays.REVEAL_MS / 16) do
            G.frame(1)
            assert(F().count() <= R().MAX, "passou do teto: " .. F().count())
            peak = math.max(peak, F().count())
        end
        assert(spy.calls > 50, "rajadas: " .. spy.calls)
        assert(peak > R().MAX * 0.5, "a rajada não apareceu: pico " .. peak)
    end,

    -- só na janela: quem entra no meio não ganha rajada, nem quem anda depois da janela
    flakes_burst_only_in_window = function()
        for _, live in ipairs({ false, true }) do
            local G = setup({ density = 2 })
            local calls = 0
            local real = F().burst
            if live then
                NOM_FogState.setRising(true)
                NOM_FogState.set(true, 3)
                NOM_FogState.setRising(false)
                G.secs((NOM_FogOverlays.REVEAL_MS + NOM_FogOverlays.REVEAL_TAIL_MS) / 1000 + 1)
            else
                NOM_FogState.set(true, 3)
            end
            F().burst = function(...) calls = calls + 1; return real(...) end
            G.secs(3)
            for _ = 1, 40 do G.p.x = G.p.x + 0.5; G.frame(4) end -- 20 tiles: anel novo vestido
            G.secs(3)
            assert(calls == 0, (live and "depois da janela" or "entrada no meio") .. ": " .. calls .. " rajadas")
        end
    end,

    -- efeitos de tela desligados (intensidade 0): nenhuma rajada
    flakes_burst_off_with_effects_off = function()
        local G = setup({ density = 2, intensity = 0 })
        NOM_FogState.setRising(true)
        NOM_FogState.set(true, 3)
        NOM_FogState.setRising(false)
        G.secs(4)
        assert(F().count() == 0, "lascas com os efeitos desligados: " .. F().count())
    end,

    -- fim da névoa: poucas lascas na retirada (no máximo OUT_FLAKES por atualização)
    flakes_few_on_unreveal = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3)
        G.secs(5)
        local asked, updates = 0, 0
        local real = F().burst
        F().burst = function(x, y, z, kind, n) asked = asked + n; return real(x, y, z, kind, n) end
        NOM_FogState.set(false)
        G.secs(NOM_FogOverlays.UNREVEAL_MS / 1000 + 1)
        updates = math.ceil((NOM_FogOverlays.UNREVEAL_MS + 1000) / (16 * NOM_FogOverlays.UPDATE_TICKS))
        assert(asked > 0, "a retirada não soltou lasca")
        assert(asked <= updates * NOM_FogOverlays.OUT_FLAKES, "muitas: " .. asked)
    end,

    -- menu principal: esquece
    flakes_main_menu_forgets = function()
        local G = setup()
        F().burst(100, 100, 0, "F", 6)
        G.fire("OnMainMenuEnter")
        assert(F().count() == 0)
    end,

    -- texturas: geradas pelo scripts/gen_textures.py, RGBA, no CREDITS.md
    flakes_textures_exist = function()
        local credits = read("CREDITS.md")
        require "NOM_FlakeRules"
        for kind, path in pairs(NOM_FlakeRules.TEXTURES) do
            local w, h, color = png("mod/42/" .. path)
            assert(color == 6, path .. " sem alfa")
            if kind == "lasca" then
                assert(w == NOM_FlakeRules.CELL * NOM_FlakeRules.FRAMES and h == NOM_FlakeRules.CELL * NOM_FlakeRules.SHAPES,
                    "sheet " .. w .. "x" .. h)
            end
            assert(credits:find("mod/42/" .. path, 1, true), "CREDITS.md não cita " .. path)
        end
    end,
}
