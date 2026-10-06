-- Painel de debug (sprint 0020): janela de botões que chamam os atalhos NOM.*
-- (client/NOM_Console.lua), só no cliente com o jogo em -debug. Abre e fecha pela
-- tecla das opções do mod (NOM_ScreenFxOptions.debugPanelKey, padrão Insert) ou por
-- NOM.panel(). Fechado, sai do UIManager: não pega clique nem tecla. A posição fica
-- no layout do jogo (ISLayoutManager.RegisterWindow, como ISBBQInfoAction.lua:29).
-- Padrão de janela: ISCollapsableWindow com ISButton (DebugUIs/ISFilmingToolsUI.lua).
if isServer() or not getDebug() then return end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "NOM_Console"
require "NOM_Math"
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_ScreenFxOptions"

NOM_DebugPanel = ISCollapsableWindow:derive("NOM_DebugPanel")

local P = NOM_DebugPanel
local WIDTH, PAD, GAP = 440, 8, 4
local FONT_HGT = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT + 6
local REFRESH_MS = 1000

local function player() return getSpecificPlayer(0) end

local function cheat(getter)
    return function()
        local p = player()
        return p ~= nil and p[getter](p) == true
    end
end

-- chave literal: o teste das traduções acha a chave no código
local function hourButton(key, h)
    return { key, function() NOM.time(h) end }
end

-- Linhas de botões: { chave do texto, ação, estado (só nos toggles do jogador) }.
-- Todo comando do NOM.HELP tem botão aqui (AGENTS.md; tests/test_debug_panel.lua cobra).
P.ROWS = {
    { { "UI_NOM_Debug_SetFog", function() NOM.setFog() end },
        { "UI_NOM_Debug_SetFogNow", function() NOM.setFog(true) end },
        { "UI_NOM_Debug_SetRedFog", function() NOM.setRedFog() end },
        { "UI_NOM_Debug_SetRedFogNow", function() NOM.setRedFog(true) end },
        { "UI_NOM_Debug_SetBlackFog", function() NOM.setBlackFog() end } },
    { { "UI_NOM_Debug_Fog", function() NOM.fog() end },
        { "UI_NOM_Debug_FogNow", function() NOM.fog(true, true) end },
        { "UI_NOM_Debug_FogEnd", function() NOM.setEndFog() end },
        { "UI_NOM_Debug_RedFog", function() NOM.redFog() end } },
    { { "UI_NOM_Debug_Night", function() NOM.night(true) end },
        { "UI_NOM_Debug_Day", function() NOM.night(false) end },
        { "UI_NOM_Debug_Clock", function() NOM_Debug.night() end } },
    { hourButton("UI_NOM_Debug_Hour0", 0), hourButton("UI_NOM_Debug_Hour6", 6), hourButton("UI_NOM_Debug_Hour12", 12),
        hourButton("UI_NOM_Debug_Hour18", 18), hourButton("UI_NOM_Debug_Hour22", 22) },
    { { "UI_NOM_Debug_Spawn1", function() NOM.spawn(1) end },
        { "UI_NOM_Debug_Spawn5", function() NOM.spawn(5) end },
        { "UI_NOM_Debug_Spawn10", function() NOM.spawn(10) end },
        { "UI_NOM_Debug_Eco", function() NOM.eco() end },
        { "UI_NOM_Debug_GetZombie", function() NOM.getZombie() end } },
    { { "UI_NOM_Debug_Estalador", function() NOM.variant("estalador") end },
        { "UI_NOM_Debug_Corredor", function() NOM.variant("corredor") end },
        { "UI_NOM_Debug_SemRosto", function() NOM.variant("semrosto") end },
        { "UI_NOM_Debug_Carpideira", function() NOM.variant("carpideira") end },
        { "UI_NOM_Debug_UndoVariant", function() NOM.turnZombie(0) end } },
    { { "UI_NOM_Debug_God", function() NOM.god() end, cheat("isGodMod") },
        { "UI_NOM_Debug_NoClip", function() NOM.noclip() end, cheat("isNoClip") },
        { "UI_NOM_Debug_Invisible", function() NOM.invisible() end, cheat("isInvisible") },
        { "UI_NOM_Debug_GodMode", function() NOM.godMode() end, cheat("isGodMod") } },
    { { "UI_NOM_Debug_Wind", function() NOM.wind() end },
        { "UI_NOM_Debug_Status", function() NOM.status() end } },
}

local function yesNo(v) return getText(v and "UI_NOM_Debug_Yes" or "UI_NOM_Debug_No") end

-- "HH:MM" da hora do jogo (13.5 → 13:30), sem %d em número quebrado.
local function clock(h)
    local m = NOM_Math.mod(math.floor(h * 60 + 0.5), 24 * 60)
    local hh = math.floor(m / 60)
    local mm = m - hh * 60
    return (hh < 10 and "0" or "") .. hh .. ":" .. (mm < 10 and "0" or "") .. mm
end

-- Linha de estado: o que este cliente sabe (noite, névoa, vermelha, hora, monstros aqui).
local function statusText()
    local monsters = 0
    for _ in pairs(NOM_NightStats.variants) do monsters = monsters + 1 end
    local parts = {
        getText("UI_NOM_Debug_Night") .. ": " .. yesNo(NOM_NightStats.night),
        getText("UI_NOM_Debug_StatusFog") .. ": " .. yesNo(NOM_FogState.on),
        getText("UI_NOM_Debug_StatusRed") .. ": " .. yesNo(NOM_FogState.red),
        getText("UI_NOM_Debug_StatusHour") .. ": " .. clock(getGameTime():getTimeOfDay()),
        getText("UI_NOM_Debug_StatusMonsters") .. ": " .. monsters,
    }
    return table.concat(parts, "   ")
end

function P:createChildren()
    -- altura antes do createChildren do vanilla: ele põe as alças pela altura de agora
    local top = self:titleBarHeight() + PAD
    self.statusY = top + #P.ROWS * (BUTTON_HGT + GAP) + GAP
    self:setHeight(self.statusY + FONT_HGT + PAD)
    ISCollapsableWindow.createChildren(self)
    self.toggles = {}
    local y = top
    for _, row in ipairs(P.ROWS) do
        local w = (WIDTH - PAD * 2 - GAP * (#row - 1)) / #row
        for i, b in ipairs(row) do
            local action, state = b[2], b[3]
            local btn = ISButton:new(PAD + (i - 1) * (w + GAP), y, w, BUTTON_HGT, getText(b[1]), self,
                function(panel)
                    action()
                    panel:refresh()
                end)
            btn.labelKey = b[1]
            btn:initialise()
            btn:instantiate()
            self:addChild(btn)
            if state then self.toggles[#self.toggles + 1] = { btn = btn, key = b[1], state = state } end
        end
        y = y + BUTTON_HGT + GAP
    end
    self:refresh()
end

function P:refresh()
    self.status = statusText()
    for _, t in ipairs(self.toggles) do t.btn:setTitle(getText(t.key) .. ": " .. yesNo(t.state())) end
end

function P:update()
    ISCollapsableWindow.update(self)
    local now = getTimestampMs()
    if self.nextRefresh == nil or now >= self.nextRefresh then
        self:refresh()
        self.nextRefresh = now + REFRESH_MS
    end
end

function P:render()
    ISCollapsableWindow.render(self)
    self:drawText(self.status or "", PAD, self.statusY or 0, 1, 1, 1, 1, UIFont.Small)
end

-- O close do vanilla só esconde; fora do UIManager o painel não pega nada.
function P:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function P.toggle()
    local w = P.instance
    if w and w:getIsVisible() then
        w:close()
        return
    end
    if not player() then return end -- menu principal
    if not w then
        w = P:new(100, 100, WIDTH, 200) -- altura certa no createChildren
        w.resizable = false -- grade fixa de botões (ISCollapsableWindow:new liga)
        w:setTitle(getText("UI_NOM_Debug_Title"))
        w:initialise()
        w:addToUIManager()
        P.instance = w
        -- devolve a posição salva (e o "visible" salvo, que o setVisible abaixo corrige)
        ISLayoutManager.RegisterWindow("NOM_DebugPanel", ISCollapsableWindow, w)
    else
        w:addToUIManager()
    end
    w:setVisible(true)
end

Events.OnKeyPressed.Add(function(key)
    local k = NOM_ScreenFxOptions.debugPanelKey()
    if k and k ~= 0 and key == k then P.toggle() end
end)

return NOM_DebugPanel
