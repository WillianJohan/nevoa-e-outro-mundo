-- client/NOM_DebugPanel.lua (sprints 0020 e 0046) contra uma ISUI falsa que imita o vanilla onde importa:
-- * ISCollapsableWindow:derive / :new(x, y, w, h); addToUIManager instancia na primeira vez
--   (ISUIElement:addToUIManager → instantiate → createChildren) e põe na lista do UIManager;
--   removeFromUIManager tira; close() do vanilla só esconde (ISCollapsableWindow.lua:134-136).
-- * Redimensionar: o ISResizeWidget só chama setWidth/setHeight da janela, sem passar do
--   minimumWidth/minimumHeight (ISResizeWidget.lua:9-34). O teste faz o mesmo e roda o update.
-- * ISPanel:new põe background/backgroundColor/borderColor (ISPanel.lua:96-115). Os painéis
--   filhos recebem onMouseDown(x, y) e onMouseWheel(del) em coordenadas locais
--   (ISScrollingListBox.lua:347, 577); getMouseX/Y local (ISUIElement.lua:339-346).
-- * getTextManager():MeasureStringX(fonte, texto) (ISButton.lua:233): aqui 7 px por letra.
-- * getSoundManager():playUISound(nome) (ISButton.lua:46).
-- * ISButton:new(x, y, w, h, título, alvo, onclick): o clique chama onclick(alvo, botão).
-- * ISLayoutManager.RegisterWindow(nome, ISCollapsableWindow, janela) devolve o leiaute salvo com
--   aquele nome: posição e, com a janela redimensionável (ISCollapsableWindow.lua:336-340), o tamanho
--   pelo ISResizeWidget:resize (ISLayoutManager.lua:26-41), que prende no mínimo e depois corta a
--   altura na borda de baixo da tela (ISResizeWidget.lua:13-27).
-- NOM é um registrador: os atalhos de verdade moram em test_debug.
local FILE = "mod/42/media/lua/client/NOM_DebugPanel.lua"

local function setup(opts)
    opts = opts or {}
    local G = { ui = {}, calls = {}, layouts = {}, sounds = {}, now = 0, key = 65, debug = opts.debug ~= false,
        hour = 13.5, saved = opts.saved or {} }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    getDebug = function() return G.debug end
    isServer = function() return false end
    getText = function(k) return k end
    getTimestampMs = function() return G.now end
    UIFont = { Small = "small", Medium = "medium" }
    getTextManager = function()
        return {
            getFontHeight = function(_, f) return f == "medium" and (opts.medium or 18) or (opts.small or 14) end,
            MeasureStringX = function(_, _, s) return #s * 7 end,
        }
    end
    getSoundManager = function() return { playUISound = function(_, name) G.sounds[#G.sounds + 1] = name end } end
    getGameTime = function() return { getTimeOfDay = function() return G.hour end } end
    getCore = function() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end

    local Element = {}
    Element.__index = Element
    function Element:derive(name)
        local c = setmetatable({}, { __index = self })
        c.__index = c
        c.Type = name
        return c
    end
    function Element:new(x, y, w, h)
        return setmetatable({ x = x, y = y, width = w, height = h, visible = true, children = {}, draws = {},
            stencil = 0, mouseX = -1, mouseY = -1 }, self)
    end
    function Element:initialise() end
    -- ISUIElement.lua:993-1007: instantiate cria o objeto Java e chama createChildren
    function Element:instantiate()
        self.instantiated = true
        self:createChildren()
    end
    function Element:addChild(c) self.children[#self.children + 1] = c; c.parent = self end
    function Element:setVisible(v) self.visible = v end
    function Element:getIsVisible() return self.visible end
    function Element:getWidth() return self.width end
    function Element:getHeight() return self.height end
    function Element:setWidth(w) self.width = w end
    function Element:setHeight(h) self.height = h end
    function Element:setX(x) self.x = x end
    function Element:setY(y) self.y = y end
    function Element:getX() return self.x end
    function Element:getY() return self.y end
    function Element:setTitle(t) self.title = t end
    function Element:titleBarHeight() return 16 end
    function Element:resizeWidgetHeight() return 12 end
    function Element:getMouseX() return self.mouseX end
    function Element:getMouseY() return self.mouseY end
    function Element:isMouseOver() return self.mouseX >= 0 and self.mouseY >= 0 end
    local function draw(kind)
        return function(self, ...) self.draws[#self.draws + 1] = { kind, ... } end
    end
    Element.drawRect = draw("rect")
    Element.drawRectBorder = draw("border")
    Element.drawText = draw("text")
    Element.drawTextRight = draw("textRight")
    Element.drawTextCentre = draw("textCentre")
    function Element:setStencilRect() self.stencil = self.stencil + 1 end
    function Element:clearStencilRect() self.stencil = self.stencil - 1 end
    function Element:prerender() end
    function Element:render() end
    function Element:update() end
    function Element:createChildren() end
    function Element:bringToTop() end
    function Element:addToUIManager() -- ISUIElement.lua:1365-1371
        if not self.instantiated then self:instantiate() end
        G.ui[self] = true
    end
    function Element:removeFromUIManager() G.ui[self] = nil end
    function Element:close() self:setVisible(false) end
    ISCollapsableWindow = Element:derive("ISCollapsableWindow")
    function ISCollapsableWindow:new(x, y, w, h)
        local o = Element.new(self, x, y, w, h)
        o.resizable = true -- ISCollapsableWindow.lua:395
        o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
        o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        return o
    end
    ISPanel = Element:derive("ISPanel")
    function ISPanel:new(x, y, w, h)
        local o = Element.new(self, x, y, w, h)
        o.background = true
        o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
        o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        return o
    end
    function ISPanel:noBackground() self.background = false; return self end

    ISButton = Element:derive("ISButton")
    function ISButton:new(x, y, w, h, title, target, onclick)
        local o = Element.new(self, x, y, w, h)
        o.title, o.target, o.onclick = title, target, onclick
        return o
    end
    function ISButton:click() self.onclick(self.target, self) end
    function ISButton:setFont() end
    function ISButton:setBackgroundRGBA() end
    function ISButton:setBorderRGBA() end
    ISLayoutManager = { RegisterWindow = function(name, funcs, win)
        G.layouts[#G.layouts + 1] = { name = name, funcs = funcs, win = win }
        local l = G.saved[name]
        if not l then return end
        win:setX(l.x); win:setY(l.y)
        if win.resizable then
            local w = math.max(l.width, win.minimumWidth or 0)
            local h = math.max(l.height, win.minimumHeight or 0)
            if win.y + h > 1080 then h = 1080 - win.y end
            win:setWidth(w); win:setHeight(h)
        end
    end }

    G.player = { god = false, noclip = false, invisible = false }
    function G.player:isGodMod() return self.god end
    function G.player:isNoClip() return self.noclip end
    function G.player:isInvisible() return self.invisible end
    getSpecificPlayer = function(i) if i == 0 then return G.player end end

    local function rec(name)
        return function(...) G.calls[#G.calls + 1] = name .. "(" .. table.concat((function(...)
            local t = {}
            for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
            return t
        end)(...), ",") .. ")" end
    end
    NOM = {}
    for _, n in ipairs({ "fog", "redFog", "night", "time", "spawn", "variant", "lookCycle", "lookInspect", "lookVariant", "lookGroup", "lookClean",
        "glitch", "glitchIntensity", "eco", "alma", "almaStatus", "almaReset",
        "almaCfg", "arrasto", "rastejaToggle", "rastejaToggle2", "rastejaLevanta",
        "ash", "god", "noclip", "invisible",
        "setFog", "setRedFog", "setBlackFog", "setEndFog", "getZombie", "turnZombie", "godMode", "fogLook", "wind", "status",
        "ownSprites", "wander", "carpWalk", "blind", "sonar", "sonarBurst", "sonarGaps", "ambientScream", "ticao",
        "blackPressure", "thunder", "flickerLamp", "rain", "help", "params", "param", "copyParams" }) do
        NOM[n] = rec(n)
    end
    NOM_Debug = { night = rec("clock") }
    NOM_NightStats = { night = false, variants = {} }
    NOM_FogState = { on = false, red = false }
    NOM_ScreenFxOptions = { debugPanelKey = function() if G.debug then return G.key end end }
    require "NOM_Math"
    package.loaded["NOM_FlakeRules"] = nil
    package.loaded["NOM_AlmaRules"] = nil
    package.loaded["NOM_PanelParams"] = nil
    dofile("mod/42/media/lua/shared/NOM_FlakeRules.lua")
    dofile("mod/42/media/lua/shared/NOM_AlmaRules.lua")
    dofile("mod/42/media/lua/shared/NOM_PanelParams.lua")
    NOM_AlmaRules.reset()
    NOM_FlakeRules.resetDebug()
    NOM_PanelParams.reset()
    NOM_DebugLog = nil
    package.loaded["NOM_DebugLog"] = nil
    require "NOM_DebugLog"
    for _, m in ipairs({ "NOM_Console", "NOM_NightStats", "NOM_FogState", "NOM_ScreenFxOptions", "NOM_Math",
        "NOM_AlmaRules", "NOM_FlakeRules", "NOM_PanelParams",
        "ISUI/ISCollapsableWindow", "ISUI/ISButton", "ISUI/ISPanel" }) do
        package.loaded[m] = true
    end
    NOM_DebugPanel = nil
    dofile(FILE)
    return G
end

local function inUI(G)
    local n = 0
    for _ in pairs(G.ui) do n = n + 1 end
    return n
end

local function open()
    NOM_DebugPanel.toggle()
    local w = NOM_DebugPanel.instance
    w:update()
    return w
end

-- Clica na seção i da lateral, onde ela está desenhada.
local function selectSection(w, i)
    local r = w.side.rows[i]
    assert(r, "sem seção " .. i)
    w.side:onMouseDown(r.x + 4, r.y + 4)
    assert(w.list.section == i, "clique na lateral não trocou pra seção " .. i)
end

-- Rola até o botão aparecer e clica no meio dele, na posição desenhada.
local function clickHit(w, h)
    w.list:setScroll(h.y - 4)
    local x, y = h.x + h.w / 2, h.y - w.list.scroll + h.h / 2
    assert(y >= 0 and y <= w.list.height, "botão fora da lista depois de rolar")
    w.list:onMouseDown(x, y)
end

-- Todas as escolhas de todas as seções: { seção, cartão, índice, chave }.
local function eachChoice(w, fn)
    for i = 1, #NOM_DebugPanel.SECTIONS do
        selectSection(w, i)
        local hits = {}
        for _, h in ipairs(w.list.hits) do hits[#hits + 1] = h end
        for _, h in ipairs(hits) do fn(i, h) end
    end
end

local function findHit(w, title, n)
    for _, h in ipairs(w.list.hits) do
        if h.card.title == title and h.index == (n or 1) then return h end
    end
    error("sem botão " .. title .. " #" .. tostring(n))
end

local function sectionOf(title)
    for i, s in ipairs(NOM_DebugPanel.SECTIONS) do
        for _, c in ipairs(s.cards) do if c.title == title then return i end end
    end
    error("cartão fora das seções: " .. title)
end

local function inside(c, w)
    return c.x >= 0 and c.y >= 0 and c.x + c.width <= w.width + 0.01 and c.y + c.height <= w.height + 0.01
end

return {
    debug_panel_absent_without_debug = function()
        local G = setup({ debug = false })
        assert(NOM_DebugPanel == nil, "painel sem -debug")
        G.fire("OnKeyPressed", 65)
        assert(inUI(G) == 0)
    end,
    debug_panel_key_toggles = function()
        local G = setup()
        G.fire("OnKeyPressed", 30)
        assert(NOM_DebugPanel.instance == nil, "outra tecla abriu")
        G.fire("OnKeyPressed", 65)
        local w = NOM_DebugPanel.instance
        assert(w and w.visible and G.ui[w], "tecla não abriu")
        G.fire("OnKeyPressed", 65)
        assert(not w.visible and not G.ui[w], "tecla não fechou")
        G.key = 88 -- trocada nas opções
        G.fire("OnKeyPressed", 65)
        assert(not G.ui[w])
        G.fire("OnKeyPressed", 88)
        assert(w.visible and G.ui[w] and NOM_DebugPanel.instance == w, "não reabriu a mesma janela")
        G.key = 0 -- sem tecla (KEY_NONE)
        G.fire("OnKeyPressed", 0)
        assert(G.ui[w], "KEY_NONE fechou")
    end,
    -- fechado não pega clique: sai da lista do UIManager (o close do vanilla só esconde)
    debug_panel_close_removes_from_ui = function()
        local G = setup()
        NOM_DebugPanel.toggle()
        local w = NOM_DebugPanel.instance
        w:close()
        assert(not w.visible and inUI(G) == 0, "fechado continua no UIManager")
    end,
    debug_panel_needs_player = function()
        local G = setup()
        getSpecificPlayer = function() return nil end
        NOM_DebugPanel.toggle()
        assert(NOM_DebugPanel.instance == nil and inUI(G) == 0, "abriu sem jogador (menu)")
    end,
    -- 0046: janela grande, redimensionável, com mínimo; o leiaute salvo guarda o tamanho
    debug_panel_big_and_resizable = function()
        local G = setup()
        local w = open()
        assert(w.resizable ~= false, "não redimensiona")
        assert(w.width >= 800 and w.height >= 600, "pequena: " .. w.width .. "x" .. w.height)
        -- 0058: mais seções (Almas/Estalador/Cinzas/Look) sobem o mínimo pela altura da lateral
        assert(w.minimumWidth and w.minimumHeight and w.minimumWidth <= 640 and w.minimumHeight <= 720,
            "sem mínimo razoável: " .. tostring(w.minimumWidth) .. "x" .. tostring(w.minimumHeight))
        assert(#G.layouts == 1 and G.layouts[1].funcs == ISCollapsableWindow and G.layouts[1].win == w)
    end,
    -- o leiaute salvo pelo painel da 0020 (nome NOM_DebugPanel, 440 de largura) não vale pro novo:
    -- o resize do vanilla prenderia no mínimo e o painel abriria espremido
    debug_panel_old_layout_ignored = function()
        local G = setup({ saved = { NOM_DebugPanel = { x = 50, y = 60, width = 440, height = 350 } } })
        local w = open()
        assert(G.layouts[1].name ~= "NOM_DebugPanel", "registrou com o nome do painel antigo")
        assert(w.width == 820 and w.height == 620, "ficou " .. w.width .. "x" .. w.height)
        G.saved[G.layouts[1].name] = { x = 10, y = 20, width = 1000, height = 700 }
        setup({ saved = G.saved })
        w = open()
        assert(w.width == 1000 and w.height == 700, "não voltou no tamanho salvo")
    end,
    -- perto da borda de baixo o resize corta a altura abaixo do mínimo: a janela sobe até caber
    debug_panel_below_minimum_moves_up = function()
        setup()
        setup({ saved = { [NOM_DebugPanel.LAYOUT] = { x = 10, y = 900, width = 820, height = 620 } } })
        local w = open()
        assert(w.height >= w.minimumHeight, "altura " .. w.height)
        assert(w.y + w.height <= 1080, "passou da tela: y=" .. w.y)
        for _, c in ipairs({ w.side, w.list, w.log }) do assert(inside(c, w), c.Type .. " fora da janela") end
    end,
    -- fonte grande (opção do jogo): no mínimo a lateral inteira cabe e as respostas não somem
    debug_panel_big_fonts_fit_at_minimum = function()
        setup({ small = 24, medium = 30 })
        local w = open()
        w:setWidth(w.minimumWidth)
        w:setHeight(w.minimumHeight)
        w:update()
        local last = w.side.rows[#w.side.rows]
        assert(last.y + last.h <= w.side.height, "a lateral não cabe: " .. (last.y + last.h) .. " > " .. w.side.height)
        assert(w.log.height >= 24 * 3, "respostas espremidas")
        for _, c in ipairs({ w.side, w.list, w.log }) do assert(inside(c, w), c.Type .. " fora da janela") end
    end,
    debug_panel_resize_relayouts = function()
        setup()
        local w = open()
        local listW = w.list.width
        w:setWidth(1300)
        w:setHeight(950)
        w:update()
        assert(w.list.width > listW + 400, "lista não cresceu com a janela: " .. w.list.width)
        for _, c in ipairs({ w.side, w.list, w.log }) do assert(inside(c, w), c.Type .. " fora da janela") end
        assert(w.log.y > w.list.y + w.list.height - 1, "respostas por cima da lista")
        -- no mínimo, os botões ainda cabem na largura da lista
        w:setWidth(w.minimumWidth)
        w:setHeight(w.minimumHeight)
        w:update()
        for _, c in ipairs({ w.side, w.list, w.log }) do assert(inside(c, w), c.Type .. " fora da janela no mínimo") end
        eachChoice(w, function(_, h)
            assert(h.x >= 0 and h.x + h.w <= w.list.width, "botão vaza da lista: " .. h.card.title)
        end)
    end,
    -- cada seção e cada cartão têm título e descrição (as chaves existem: test_translations)
    debug_panel_sections_are_descriptive = function()
        setup()
        local n = 0
        assert(#NOM_DebugPanel.SECTIONS >= 5, "poucas seções")
        for _, s in ipairs(NOM_DebugPanel.SECTIONS) do
            assert(s.title and s.desc and s.color, "seção sem título, descrição ou cor")
            assert(#s.cards > 0, s.title .. " vazia")
            for _, c in ipairs(s.cards) do
                assert(c.title and c.desc == c.title .. "_Desc", "cartão sem descrição: " .. tostring(c.title))
                assert(#c.choices > 0, c.title .. " sem botão")
                n = n + 1
            end
        end
        assert(n >= 20, "cartões: " .. n)
    end,
    debug_panel_buttons_call_nom = function()
        local G = setup()
        local w = open()
        local expect = {
            UI_NOM_Debug_C_White = { "setFog()", "setFog(true)" },
            UI_NOM_Debug_C_Red = { "setRedFog()", "setRedFog(true)" },
            UI_NOM_Debug_C_Black = { "setBlackFog()", "setBlackFog(true)" },
            UI_NOM_Debug_C_End = { "setEndFog()" },
            UI_NOM_Debug_C_FogLook = { "fogLook()" },
            UI_NOM_Debug_C_FogToggle = { "fog()", "fog(true,true)", "redFog()" },
            UI_NOM_Debug_C_Night = { "night(true)", "night(false)", "clock()" },
            UI_NOM_Debug_C_Hour = { "time(0)", "time(6)", "time(12)", "time(18)", "time(22)" },
            UI_NOM_Debug_C_Spawn = { "spawn(1)", "spawn(5)", "spawn(10)" },
            UI_NOM_Debug_C_Eco = { "eco()" },
            UI_NOM_Debug_C_Alma = { "alma()", "almaStatus()", "almaReset()", "almaCfg(white)" },
            UI_NOM_Debug_C_Arrasto = { "arrasto()" },
            UI_NOM_Debug_C_RastejaSpike = { "rastejaToggle()", "rastejaToggle2()", "rastejaLevanta()" },
            UI_NOM_Debug_C_Ash = { "ash()", "ash(reset)" },
            UI_NOM_Debug_C_Pull = { "getZombie()" },
            UI_NOM_Debug_C_Variant = { "variant(estalador)", "variant(corredor)", "variant(semrosto)",
                "variant(carpideira)", "lookVariant(carpideira,1)", "lookVariant(carpideira,2)",
                "lookVariant(carpideira,3)", "lookCycle()", "lookInspect()",
                "lookVariant()", "lookGroup()", "lookClean()", "turnZombie(0)" },
            UI_NOM_Debug_C_Thunder = { "thunder()" },
            UI_NOM_Debug_C_Lamp = { "flickerLamp()" },
            UI_NOM_Debug_C_Rain = { "rain()" },
            UI_NOM_Debug_C_Sonar = { "sonar()", "sonarBurst(auto)", "sonarBurst(A)", "sonarBurst(B)",
                "sonarBurst(C)", "sonarGaps(-50)", "sonarGaps(50)", "sonarGaps(reset)" },
            UI_NOM_Debug_C_Ambient = { "ambientScream()" },
            UI_NOM_Debug_C_Wander = { "wander()" },
            UI_NOM_Debug_C_CarpWalk = { "carpWalk()" },
            UI_NOM_Debug_C_Wind = { "wind()" },
            UI_NOM_Debug_C_God = { "god()" },
            UI_NOM_Debug_C_NoClip = { "noclip()" },
            UI_NOM_Debug_C_Invisible = { "invisible()" },
            UI_NOM_Debug_C_GodMode = { "godMode()" },
            UI_NOM_Debug_C_Status = { "status()" },
            UI_NOM_Debug_C_Ticao = { "ticao()" },
            UI_NOM_Debug_C_BlackPressure = { "blackPressure()" },
            UI_NOM_Debug_C_Blind = { "blind()" },
            UI_NOM_Debug_C_OwnSprites = { "ownSprites()" },
            UI_NOM_Debug_C_Params = { "params()", "param(reset)", "copyParams()" },
            UI_NOM_Debug_C_GlitchAct = { "glitch()", "glitchIntensity()" },
            UI_NOM_Debug_C_Help = { "help()" },
        }
        local n, want = 0, 0
        for _, calls in pairs(expect) do want = want + #calls end
        eachChoice(w, function(_, h)
            -- 0058: knobs live chamam NOM.param (slider/toggle/enum); não entram no mapa fixo
            if h.card.slider or h.card.param or (h.card.compact and h.card.state) then
                G.calls = {}
                clickHit(w, h)
                assert(G.calls[1] and G.calls[1]:match("^param%("),
                    h.card.title .. " #" .. h.index .. " chamou " .. tostring(G.calls[1]))
                n = n + 1
                return
            end
            local calls = expect[h.card.title]
            assert(calls, "cartão sem teste: " .. h.card.title)
            G.calls = {}
            clickHit(w, h)
            assert(G.calls[1] == calls[h.index] and #G.calls == 1,
                h.card.title .. " #" .. h.index .. " chamou " .. tostring(G.calls[1]) .. ", esperado " .. tostring(calls[h.index]))
            n = n + 1
        end)
        -- want = só os cartões do mapa; n inclui também os knobs live
        assert(n >= want, "botões " .. n .. ", esperados >= " .. want)
        -- cada botão e cada troca de seção (a primeira já abre escolhida) toca o clique
        assert(#G.sounds == n + #NOM_DebugPanel.SECTIONS - 1 and G.sounds[1] == "UIActivateButton",
            "cliques com som: " .. #G.sounds)
    end,
    -- Regra do AGENTS.md: todo comando do NOM.HELP (menos o próprio panel) tem botão. O console
    -- de verdade dá o HELP; cada NOM.* vira espião e o teste aperta todos os botões.
    debug_panel_every_help_command_has_button = function()
        setup()
        local deps = { "NOM_Debug", "NOM_DebugRules", "NOM_VariantRules" }
        local saved = {}
        for _, m in ipairs(deps) do saved[m] = package.loaded[m]; package.loaded[m] = true end
        dofile("mod/42/media/lua/client/NOM_Console.lua")
        for _, m in ipairs(deps) do package.loaded[m] = saved[m] end
        local called = {}
        for name, f in pairs(NOM) do
            if type(f) == "function" then NOM[name] = function() called[name] = true end end
        end
        local w = open()
        eachChoice(w, function(_, h) clickHit(w, h) end)
        local checked = 0
        for _, h in ipairs(NOM.HELP) do
            local name = h[1]:match("^NOM%.(%w+)%(")
            assert(name, "linha do HELP sem NOM.x(: " .. h[1])
            if name ~= "panel" then
                assert(called[name], "comando sem botão no NOM.panel(): NOM." .. name .. " (regra do AGENTS.md)")
                checked = checked + 1
            end
        end
        assert(checked >= 21, "HELP encolheu? " .. checked)
    end,
    debug_panel_sidebar_switches_and_resets_scroll = function()
        setup()
        local w = open()
        w:setHeight(w.minimumHeight)
        w:update()
        local busiest, most = 1, 0
        for i, s in ipairs(NOM_DebugPanel.SECTIONS) do
            if #s.cards > most then busiest, most = i, #s.cards end
        end
        selectSection(w, busiest)
        assert(w.list:maxScroll() > 0, "a seção maior cabe sem rolar no mínimo? teste não prova nada")
        w.list:onMouseWheel(1)
        assert(w.list.scroll > 0)
        selectSection(w, busiest == 1 and 2 or 1)
        assert(w.list.scroll == 0, "trocar de seção não voltou pro topo")
        for _, h in ipairs(w.list.hits) do
            assert(sectionOf(h.card.title) == w.list.section, "botão de outra seção na lista")
        end
    end,
    -- a roda rola sem passar do fim nem do começo; o clique acerta o botão rolado
    debug_panel_scroll_clamps_and_clicks_follow = function()
        local G = setup()
        local w = open()
        w:setHeight(w.minimumHeight)
        w:update()
        selectSection(w, sectionOf("UI_NOM_Debug_C_Wind"))
        local max = w.list:maxScroll()
        assert(max > 0, "Tempestade e luz cabe sem rolar no mínimo")
        assert(w.list:onMouseWheel(-1) == true, "a roda não é da lista")
        assert(w.list.scroll == 0, "rolou pra cima do começo")
        for _ = 1, 100 do w.list:onMouseWheel(1) end
        assert(w.list.scroll == max, "passou do fim: " .. w.list.scroll .. " > " .. max)
        local h = findHit(w, "UI_NOM_Debug_C_Wind")
        local y = h.y - w.list.scroll + h.h / 2
        assert(y > 0 and y < w.list.height, "o último cartão não aparece no fim da rolagem")
        G.calls = {}
        w.list:onMouseDown(h.x + 2, y)
        assert(G.calls[1] == "wind()", "clique rolado errou: " .. tostring(G.calls[1]))
        -- clique fora de botão não faz nada
        G.calls = {}
        w.list:onMouseDown(w.list.width - 1, 1)
        assert(#G.calls == 0)
    end,
    -- toggles do jogador: o botão diz LIGADO/DESLIGADO; o clique já atualiza
    debug_panel_toggles_show_state = function()
        local G = setup()
        local w = open()
        selectSection(w, sectionOf("UI_NOM_Debug_C_God"))
        local god = findHit(w, "UI_NOM_Debug_C_God")
        assert(god.label == "UI_NOM_Debug_Off" and god.on == false, tostring(god.label))
        G.player.god = true
        clickHit(w, god)
        god = findHit(w, "UI_NOM_Debug_C_God")
        assert(god.label == "UI_NOM_Debug_On" and god.on == true, tostring(god.label))
        local godMode = findHit(w, "UI_NOM_Debug_C_GodMode")
        assert(godMode.on == true, "modo deus segue o isGodMod")
        assert(findHit(w, "UI_NOM_Debug_C_NoClip").on == false)
        local l = NOM_DebugLog.lines()
        assert(l[#l].text == "UI_NOM_Debug_C_God", "liga/desliga ecoa o estado velho: " .. l[#l].text)
    end,
    -- cabeçalho: hora, dia/noite, névoa (qual), monstros aqui, cheats; atualiza a cada segundo
    debug_panel_header_refreshes_each_second = function()
        local G = setup()
        local w = open()
        local function chip(label)
            for _, c in ipairs(w.chips) do if c.label == label then return c.value end end
            error("sem cartão " .. label)
        end
        assert(chip("UI_NOM_Debug_StatusHour") == "13:30", chip("UI_NOM_Debug_StatusHour"))
        assert(chip("UI_NOM_Debug_StatusTime") == "UI_NOM_Debug_Day")
        assert(chip("UI_NOM_Debug_StatusFog") == "UI_NOM_Debug_FogNone")
        assert(chip("UI_NOM_Debug_StatusMonsters") == "0")
        assert(chip("UI_NOM_Debug_StatusYou") == "UI_NOM_Debug_YouNormal")
        NOM_NightStats.night = true
        NOM_NightStats.variants = { a = "estalador", b = "corredor" }
        NOM_FogState.on, NOM_FogState.red = true, true
        G.player.god, G.player.invisible = true, true
        G.hour = 6.05
        G.now = 999
        w:update()
        assert(chip("UI_NOM_Debug_StatusTime") == "UI_NOM_Debug_Day", "atualizou antes de 1 s")
        G.now = 1000
        w:update()
        assert(chip("UI_NOM_Debug_StatusTime") == "UI_NOM_Debug_Night")
        assert(chip("UI_NOM_Debug_StatusFog") == "UI_NOM_Debug_FogRed")
        assert(chip("UI_NOM_Debug_StatusHour") == "06:03")
        assert(chip("UI_NOM_Debug_StatusMonsters") == "2")
        assert(chip("UI_NOM_Debug_StatusYou") == "UI_NOM_Debug_YouGod, UI_NOM_Debug_YouInvisible", chip("UI_NOM_Debug_StatusYou"))
        NOM_FogState.black = true
        G.now = 2000
        w:update()
        assert(chip("UI_NOM_Debug_StatusFog") == "UI_NOM_Debug_FogBlack", "preta ganha da vermelha")
        w.draws = {}
        w:render()
        local seen = false
        for _, d in ipairs(w.draws) do if d[2] == "06:03" then seen = true end end
        assert(seen, "hora não desenhada no cabeçalho")
    end,
    -- respostas: o clique ecoa, o que o debug responde aparece, Limpar apaga
    debug_panel_log_shows_replies = function()
        setup()
        local realPrint = print
        print = function() end
        local ok, err = pcall(function()
            local w = open()
            selectSection(w, sectionOf("UI_NOM_Debug_C_Thunder"))
            clickHit(w, findHit(w, "UI_NOM_Debug_C_Thunder"))
            NOM_DebugLog.say("[NOM] debug relâmpago em x=10 y=20")
            w.log:prerender()
            w.log:render()
            local shown = w.log.shown
            assert(#shown == 2, "linhas: " .. #shown)
            assert(shown[1].text == "UI_NOM_Debug_C_Thunder: UI_NOM_Debug_B_Now" and shown[1].kind == "echo", shown[1].text)
            assert(shown[2].text == "relâmpago em x=10 y=20" and shown[2].kind == "reply", shown[2].text)
            assert(w.log.stencil == 0, "stencil das respostas sem fechar")
            -- muitas linhas: mostra as mais novas, sem passar da altura
            for i = 1, 50 do NOM_DebugLog.say("[NOM] debug linha " .. i) end
            w.log:render()
            shown = w.log.shown
            assert(shown[#shown].text == "linha 50", "a mais nova não aparece: " .. shown[#shown].text)
            assert(#shown < 50, "não coube tudo e mostrou tudo")
            local last = shown[#shown]
            assert(last.y + 14 <= w.log.height, "linha passou do rodapé")
            local clear
            for _, c in ipairs(w.log.children) do if c.title == "UI_NOM_Debug_Clear" then clear = c end end
            assert(clear, "sem botão Limpar")
            clear:click()
            w.log:render()
            assert(#w.log.shown == 0 and #NOM_DebugLog.lines() == 0, "Limpar não apagou")
        end)
        print = realPrint
        assert(ok, err)
    end,
    -- desenho: passa o mouse num botão, desenha sem erro e fecha todo stencil
    debug_panel_renders_with_hover = function()
        setup()
        local w = open()
        local h = w.list.hits[1]
        w.list.mouseX, w.list.mouseY = h.x + 2, h.y - w.list.scroll + 2
        w.side.mouseX, w.side.mouseY = w.side.rows[2].x + 2, w.side.rows[2].y + 2
        for _, c in ipairs({ w, w.side, w.list, w.log }) do
            c.draws = {}
            c:prerender()
            c:render()
            assert(c.stencil == 0, c.Type .. ": stencil sem fechar")
            assert(#c.draws > 0, c.Type .. " não desenhou nada")
        end
        assert(w.list.hover == h, "hover não achou o botão sob o mouse")
        assert(w.side.hover == 2, "hover da lateral")
    end,
    -- sprint 0058: seção Cinzas (PanelParams) com trilhos; clique no trilho grava via NOM.param
    debug_panel_cinzas_sliders = function()
        local G = setup()
        local w = open()
        local ashI
        for i, s in ipairs(NOM_DebugPanel.SECTIONS) do
            if s.title == "UI_NOM_Debug_Sec_Cinzas" then ashI = i break end
        end
        assert(ashI, "sem seção Cinzas")
        selectSection(w, ashI)
        assert(#w.list.sliders >= 2, "sliders: " .. #w.list.sliders)
        NOM_PanelParams.reset()
        local rate = w.list.sliders[1]
        assert(rate.key == "CinzaRateMult", tostring(rate.key))
        w.list:setScroll(math.max(0, rate.y - 4))
        local y = rate.y - w.list.scroll + rate.h / 2
        G.calls = {}
        w.list:onMouseDown(rate.x + rate.w - 1, y)
        assert(G.calls[1] and G.calls[1]:match("^param%(CinzaRateMult,"),
            "clique no trilho: " .. tostring(G.calls[1]))
        NOM_PanelParams.reset()
    end,
}
