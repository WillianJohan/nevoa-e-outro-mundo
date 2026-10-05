-- client/NOM_DebugPanel.lua contra uma ISUI falsa que imita o vanilla onde importa:
-- * ISCollapsableWindow:derive / :new(x, y, w, h); addToUIManager instancia na primeira
--   vez (ISUIElement:addToUIManager → instantiate → createChildren) e põe na lista do
--   UIManager; removeFromUIManager tira; close() do vanilla só esconde
--   (ISCollapsableWindow.lua:134-136). Elemento fora da lista não recebe clique nem tecla.
-- * ISButton:new(x, y, w, h, título, alvo, onclick): o clique chama onclick(alvo, botão)
--   (ISButton.lua:47, 479); setTitle troca o texto (:282).
-- * ISLayoutManager.RegisterWindow(nome, ISCollapsableWindow, janela) lembra a posição
--   (ISBBQInfoAction.lua:29).
-- * OnKeyPressed(key) com o código da tecla.
-- NOM é um registrador: os atalhos de verdade moram em test_debug.
local FILE = "mod/42/media/lua/client/NOM_DebugPanel.lua"

local function setup(opts)
    opts = opts or {}
    local G = { ui = {}, calls = {}, layouts = {}, now = 0, key = 65, debug = opts.debug ~= false, hour = 13.5 }
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
    UIFont = { Small = "small" }
    getTextManager = function() return { getFontHeight = function() return 14 end } end
    getGameTime = function() return { getTimeOfDay = function() return G.hour end } end

    local Element = {}
    Element.__index = Element
    function Element:derive(name)
        local c = setmetatable({}, { __index = self })
        c.__index = c
        c.Type = name
        return c
    end
    function Element:new(x, y, w, h)
        local o = setmetatable({ x = x, y = y, width = w, height = h, visible = true, children = {} }, self)
        return o
    end
    function Element:initialise() end
    function Element:instantiate() self.instantiated = true end
    function Element:addChild(c) self.children[#self.children + 1] = c end
    function Element:setVisible(v) self.visible = v end
    function Element:getIsVisible() return self.visible end
    function Element:getWidth() return self.width end
    function Element:setHeight(h) self.height = h end
    function Element:setTitle(t) self.title = t end
    function Element:titleBarHeight() return 16 end
    function Element:drawText(s) self.drawn = s end
    function Element:prerender() end
    function Element:render() end
    function Element:update() end
    function Element:createChildren() end
    function Element:addToUIManager()
        if not self.instantiated then
            self.instantiated = true
            self:createChildren()
        end
        G.ui[self] = true
    end
    function Element:removeFromUIManager() G.ui[self] = nil end
    function Element:close() self:setVisible(false) end
    ISCollapsableWindow = Element:derive("ISCollapsableWindow")

    ISButton = Element:derive("ISButton")
    function ISButton:new(x, y, w, h, title, target, onclick)
        local o = Element.new(self, x, y, w, h)
        o.title, o.target, o.onclick = title, target, onclick
        return o
    end
    function ISButton:click() self.onclick(self.target, self) end
    ISLayoutManager = { RegisterWindow = function(name, funcs, win)
        G.layouts[#G.layouts + 1] = { name = name, funcs = funcs, win = win }
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
    for _, n in ipairs({ "fog", "redFog", "night", "time", "spawn", "variant", "eco", "god", "noclip", "invisible" }) do
        NOM[n] = rec(n)
    end
    NOM_Debug = { night = rec("clock") }
    NOM_NightStats = { night = false, variants = {} }
    NOM_FogState = { on = false, red = false }
    NOM_ScreenFxOptions = { debugPanelKey = function() if G.debug then return G.key end end }
    for _, m in ipairs({ "NOM_Console", "NOM_NightStats", "NOM_FogState", "NOM_ScreenFxOptions", "NOM_Math",
        "ISUI/ISCollapsableWindow", "ISUI/ISButton" }) do
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

local function button(win, key)
    for _, c in ipairs(win.children) do
        if c.labelKey == key then return c end
    end
    error("sem botão " .. key)
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
    debug_panel_buttons_call_nom = function()
        local G = setup()
        NOM_DebugPanel.toggle()
        local w = NOM_DebugPanel.instance
        local expect = {
            UI_NOM_Debug_Fog = "fog()", UI_NOM_Debug_FogNow = "fog(true,true)", UI_NOM_Debug_FogEnd = "fog(false)",
            UI_NOM_Debug_RedFog = "redFog()",
            UI_NOM_Debug_Night = "night(true)", UI_NOM_Debug_Day = "night(false)", UI_NOM_Debug_Clock = "clock()",
            UI_NOM_Debug_Hour0 = "time(0)", UI_NOM_Debug_Hour6 = "time(6)", UI_NOM_Debug_Hour12 = "time(12)",
            UI_NOM_Debug_Hour18 = "time(18)", UI_NOM_Debug_Hour22 = "time(22)",
            UI_NOM_Debug_Spawn1 = "spawn(1)", UI_NOM_Debug_Spawn5 = "spawn(5)", UI_NOM_Debug_Spawn10 = "spawn(10)",
            UI_NOM_Debug_Estalador = "variant(estalador)", UI_NOM_Debug_Corredor = "variant(corredor)",
            UI_NOM_Debug_SemRosto = "variant(semrosto)", UI_NOM_Debug_Carpideira = "variant(carpideira)",
            UI_NOM_Debug_Eco = "eco()",
            UI_NOM_Debug_God = "god()", UI_NOM_Debug_NoClip = "noclip()", UI_NOM_Debug_Invisible = "invisible()",
        }
        local n = 0
        for key, call in pairs(expect) do
            G.calls = {}
            button(w, key):click()
            assert(G.calls[1] == call, key .. " chamou " .. tostring(G.calls[1]) .. ", esperado " .. call)
            n = n + 1
        end
        local buttons = 0
        for _, c in ipairs(w.children) do if c.labelKey then buttons = buttons + 1 end end
        assert(buttons == n, "botão sem teste: " .. buttons .. " vs " .. n)
    end,
    -- toggles do jogador mostram o estado; o clique já atualiza
    debug_panel_toggle_titles_show_state = function()
        local G = setup()
        NOM_DebugPanel.toggle()
        local w = NOM_DebugPanel.instance
        w:update()
        local god = button(w, "UI_NOM_Debug_God")
        assert(god.title == "UI_NOM_Debug_God: UI_NOM_Debug_No", god.title)
        G.player.god = true
        god:click()
        assert(god.title == "UI_NOM_Debug_God: UI_NOM_Debug_Yes", god.title)
    end,
    debug_panel_status_refreshes_each_second = function()
        local G = setup()
        NOM_DebugPanel.toggle()
        local w = NOM_DebugPanel.instance
        w:update()
        assert(w.status:find("UI_NOM_Debug_Night: UI_NOM_Debug_No", 1, true), w.status)
        assert(w.status:find("UI_NOM_Debug_StatusHour: 13:30", 1, true), w.status)
        NOM_NightStats.night = true
        NOM_NightStats.variants = { a = "estalador", b = "corredor" }
        NOM_FogState.on, NOM_FogState.red = true, true
        G.hour = 6.05
        G.now = 999
        w:update()
        assert(w.status:find("UI_NOM_Debug_Night: UI_NOM_Debug_No", 1, true), "atualizou antes de 1 s")
        G.now = 1000
        w:update()
        assert(w.status:find("UI_NOM_Debug_Night: UI_NOM_Debug_Yes", 1, true), w.status)
        assert(w.status:find("UI_NOM_Debug_StatusFog: UI_NOM_Debug_Yes", 1, true), w.status)
        assert(w.status:find("UI_NOM_Debug_StatusRed: UI_NOM_Debug_Yes", 1, true), w.status)
        assert(w.status:find("UI_NOM_Debug_StatusHour: 06:03", 1, true), w.status)
        assert(w.status:find("UI_NOM_Debug_StatusMonsters: 2", 1, true), w.status)
        w:render()
        assert(w.drawn == w.status, "status não desenhado")
    end,
    debug_panel_remembers_position = function()
        local G = setup()
        NOM_DebugPanel.toggle()
        NOM_DebugPanel.toggle()
        NOM_DebugPanel.toggle()
        assert(#G.layouts == 1 and G.layouts[1].win == NOM_DebugPanel.instance and G.layouts[1].funcs == ISCollapsableWindow,
            "RegisterWindow: " .. #G.layouts)
    end,
}
