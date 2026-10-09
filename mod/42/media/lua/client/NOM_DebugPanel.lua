-- Painel de debug (sprints 0020 e 0046): janela que chama os atalhos NOM.* (client/NOM_Console.lua),
-- só no cliente com o jogo em -debug. Abre e fecha pela tecla das opções do mod
-- (NOM_ScreenFxOptions.debugPanelKey, padrão Insert) ou por NOM.panel(). Fechado, sai do
-- UIManager: não pega clique nem tecla.
--
-- Leiaute (0046): cabeçalho com o estado (hora, dia/noite, névoa, monstros, cheats), seções na
-- lateral, a lista de ações da seção (cada ação é um cartão com título, descrição e botões) e as
-- respostas do debug no rodapé (shared/NOM_DebugLog.lua). A janela redimensiona (alças do
-- ISCollapsableWindow; o ISResizeWidget respeita minimumWidth/minimumHeight) e refaz o leiaute
-- quando o tamanho muda. Posição e tamanho ficam no layout do jogo (ISLayoutManager), com nome
-- novo (P.LAYOUT): o leiaute do painel da 0020 tinha 440 de largura e o resize do vanilla
-- (ISLayoutManager.lua:30-33) só subiria até o mínimo.
-- A lista rola por conta própria (scroll em Lua, yScroll do Java sempre 0): o clique e o mouse
-- chegam em coordenadas locais e o desenho sai em y - scroll, recortado pelo stencil.
if isServer() or not getDebug() then return end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NOM_Console"
require "NOM_Math"
require "NOM_NightStats"
require "NOM_FogState"
require "NOM_ScreenFxOptions"
require "NOM_DebugLog"
require "NOM_FlakeRules"

NOM_DebugPanel = ISCollapsableWindow:derive("NOM_DebugPanel")
local Side = ISPanel:derive("NOM_DebugPanelSide")
local List = ISPanel:derive("NOM_DebugPanelList")
local Log = ISPanel:derive("NOM_DebugPanelLog")

local P = NOM_DebugPanel
P.LAYOUT = "NOM_DebugPanel_0046"
local WIDTH, HEIGHT, MIN_W, MIN_H = 820, 620, 600, 440
local PAD, GAP, SIDE_W = 8, 8, 168
local REFRESH_MS = 1000
local SCROLL_STEP, SCROLL_W = 48, 8
local CARD_PAD, PILL_PAD, PILL_GAP = 12, 12, 6
local TRACK_H, SLIDER_GAP = 12, 8
local SMALL, MEDIUM = UIFont.Small, UIFont.Medium
local SMALL_HGT = getTextManager():getFontHeight(SMALL)
local MEDIUM_HGT = getTextManager():getFontHeight(MEDIUM)
local PILL_H = SMALL_HGT + 8
local HEADER_H = SMALL_HGT + MEDIUM_HGT + 14
local LOG_HEAD, LOG_LINE = SMALL_HGT + 10, SMALL_HGT + 1
local LOG_MIN = math.max(96, LOG_HEAD + LOG_LINE * 3 + 9)
local SIDE_ROW, SIDE_GAP = MEDIUM_HGT + 14, 4
local CLICK_SOUND = "UIActivateButton" -- ISButton.lua:521

local TEXT = { r = 0.92, g = 0.93, b = 0.95 }
local DIM = { r = 0.62, g = 0.65, b = 0.70 }
local CARD = { r = 0.12, g = 0.13, b = 0.16 }
local ON = { r = 0.22, g = 0.62, b = 0.34 }
local OFF = { r = 0.26, g = 0.27, b = 0.30 }

local function player() return getSpecificPlayer(0) end

local function cheat(getter)
    return function()
        local p = player()
        return p ~= nil and p[getter](p) == true
    end
end

local function c(key, fn) return { key = key, fn = fn } end

-- Seções da lateral e seus cartões. Chaves literais: o teste das traduções acha a chave no código.
-- Todo comando do NOM.HELP tem botão aqui (AGENTS.md; tests/test_debug_panel.lua cobra).
-- Cartão com state é um liga/desliga: um botão só, que mostra LIGADO ou DESLIGADO.
P.SECTIONS = {
    { title = "UI_NOM_Debug_Sec_Fog", desc = "UI_NOM_Debug_Sec_Fog_Desc", color = { r = 0.62, g = 0.74, b = 0.90 },
        cards = {
            { title = "UI_NOM_Debug_C_White", desc = "UI_NOM_Debug_C_White_Desc", choices = {
                c("UI_NOM_Debug_B_Omen", function() NOM.setFog() end),
                c("UI_NOM_Debug_B_OpenNow", function() NOM.setFog(true) end) } },
            { title = "UI_NOM_Debug_C_Red", desc = "UI_NOM_Debug_C_Red_Desc", choices = {
                c("UI_NOM_Debug_B_Omen", function() NOM.setRedFog() end),
                c("UI_NOM_Debug_B_OpenNow", function() NOM.setRedFog(true) end) } },
            { title = "UI_NOM_Debug_C_Black", desc = "UI_NOM_Debug_C_Black_Desc", choices = {
                c("UI_NOM_Debug_B_Omen", function() NOM.setBlackFog() end),
                c("UI_NOM_Debug_B_OpenNow", function() NOM.setBlackFog(true) end) } },
            { title = "UI_NOM_Debug_C_End", desc = "UI_NOM_Debug_C_End_Desc", choices = {
                c("UI_NOM_Debug_B_End", function() NOM.setEndFog() end) } },
            { title = "UI_NOM_Debug_C_FogLook", desc = "UI_NOM_Debug_C_FogLook_Desc", choices = {
                c("UI_NOM_Debug_B_FogLook", function() NOM.fogLook() end) } },
            { title = "UI_NOM_Debug_C_FogToggle", desc = "UI_NOM_Debug_C_FogToggle_Desc", choices = {
                c("UI_NOM_Debug_B_Toggle", function() NOM.fog() end),
                c("UI_NOM_Debug_B_OpenNow", function() NOM.fog(true, true) end),
                c("UI_NOM_Debug_B_RedToggle", function() NOM.redFog() end) } },
        } },
    { title = "UI_NOM_Debug_Sec_Time", desc = "UI_NOM_Debug_Sec_Time_Desc", color = { r = 0.96, g = 0.76, b = 0.36 },
        cards = {
            { title = "UI_NOM_Debug_C_Night", desc = "UI_NOM_Debug_C_Night_Desc", choices = {
                c("UI_NOM_Debug_Night", function() NOM.night(true) end),
                c("UI_NOM_Debug_Day", function() NOM.night(false) end),
                c("UI_NOM_Debug_Clock", function() NOM_Debug.night() end) } },
            { title = "UI_NOM_Debug_C_Hour", desc = "UI_NOM_Debug_C_Hour_Desc", choices = {
                c("UI_NOM_Debug_Hour0", function() NOM.time(0) end),
                c("UI_NOM_Debug_Hour6", function() NOM.time(6) end),
                c("UI_NOM_Debug_Hour12", function() NOM.time(12) end),
                c("UI_NOM_Debug_Hour18", function() NOM.time(18) end),
                c("UI_NOM_Debug_Hour22", function() NOM.time(22) end) } },
        } },
    { title = "UI_NOM_Debug_Sec_Monsters", desc = "UI_NOM_Debug_Sec_Monsters_Desc", color = { r = 0.88, g = 0.36, b = 0.32 },
        cards = {
            { title = "UI_NOM_Debug_C_Spawn", desc = "UI_NOM_Debug_C_Spawn_Desc", choices = {
                c("UI_NOM_Debug_Spawn1", function() NOM.spawn(1) end),
                c("UI_NOM_Debug_Spawn5", function() NOM.spawn(5) end),
                c("UI_NOM_Debug_Spawn10", function() NOM.spawn(10) end) } },
            { title = "UI_NOM_Debug_C_Variant", desc = "UI_NOM_Debug_C_Variant_Desc", choices = {
                c("UI_NOM_Debug_Estalador", function() NOM.variant("estalador") end),
                c("UI_NOM_Debug_Corredor", function() NOM.variant("corredor") end),
                c("UI_NOM_Debug_SemRosto", function() NOM.variant("semrosto") end),
                c("UI_NOM_Debug_Carpideira", function() NOM.variant("carpideira") end),
                c("UI_NOM_Debug_UndoVariant", function() NOM.turnZombie(0) end) } },
            { title = "UI_NOM_Debug_C_Pull", desc = "UI_NOM_Debug_C_Pull_Desc", choices = {
                c("UI_NOM_Debug_B_Pull", function() NOM.getZombie() end) } },
            { title = "UI_NOM_Debug_C_Eco", desc = "UI_NOM_Debug_C_Eco_Desc", choices = {
                c("UI_NOM_Debug_B_Here", function() NOM.eco() end) } },
            { title = "UI_NOM_Debug_C_Alma", desc = "UI_NOM_Debug_C_Alma_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.alma() end) } },
        } },
    { title = "UI_NOM_Debug_Sec_Storm", desc = "UI_NOM_Debug_Sec_Storm_Desc", color = { r = 0.46, g = 0.66, b = 0.98 },
        cards = {
            { title = "UI_NOM_Debug_C_Thunder", desc = "UI_NOM_Debug_C_Thunder_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.thunder() end) } },
            { title = "UI_NOM_Debug_C_Lamp", desc = "UI_NOM_Debug_C_Lamp_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.flickerLamp() end) } },
            { title = "UI_NOM_Debug_C_Rain", desc = "UI_NOM_Debug_C_Rain_Desc", choices = {
                c("UI_NOM_Debug_B_Toggle", function() NOM.rain() end) } },
            { title = "UI_NOM_Debug_C_Sonar", desc = "UI_NOM_Debug_C_Sonar_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.sonar() end) } },
            { title = "UI_NOM_Debug_C_Ambient", desc = "UI_NOM_Debug_C_Ambient_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.ambientScream() end) } },
            { title = "UI_NOM_Debug_C_Wander", desc = "UI_NOM_Debug_C_Wander_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.wander() end) } },
            { title = "UI_NOM_Debug_C_CarpWalk", desc = "UI_NOM_Debug_C_CarpWalk_Desc", choices = {
                c("UI_NOM_Debug_B_Now", function() NOM.carpWalk() end) } },
            { title = "UI_NOM_Debug_C_Wind", desc = "UI_NOM_Debug_C_Wind_Desc", choices = {
                c("UI_NOM_Debug_B_Toggle", function() NOM.wind() end) } },
        } },
    -- Cinzas (sprint 0057): knobs live dens/taxa/ar; o que o sprint toca tem slider aqui.
    { title = "UI_NOM_Debug_Sec_Ash", desc = "UI_NOM_Debug_Sec_Ash_Desc", color = { r = 0.82, g = 0.78, b = 0.70 },
        cards = {
            { title = "UI_NOM_Debug_C_Ash", desc = "UI_NOM_Debug_C_Ash_Desc",
                sliders = {
                    { key = "density", label = "UI_NOM_Debug_AshDensity", min = 0, max = 2, step = 0.1 },
                    { key = "rate", label = "UI_NOM_Debug_AshRate", min = 0, max = 2, step = 0.1 },
                    { key = "air", label = "UI_NOM_Debug_AshAir", min = 0, max = 2, step = 0.1 },
                },
                choices = {
                    c("UI_NOM_Debug_B_Show", function() NOM.ash() end),
                    c("UI_NOM_Debug_B_Reset", function() NOM.ash("reset") end) } },
        } },
    { title = "UI_NOM_Debug_Sec_Player", desc = "UI_NOM_Debug_Sec_Player_Desc", color = { r = 0.40, g = 0.82, b = 0.52 },
        cards = {
            { title = "UI_NOM_Debug_C_GodMode", desc = "UI_NOM_Debug_C_GodMode_Desc", state = cheat("isGodMod"),
                choices = { c(nil, function() NOM.godMode() end) } },
            { title = "UI_NOM_Debug_C_God", desc = "UI_NOM_Debug_C_God_Desc", state = cheat("isGodMod"),
                choices = { c(nil, function() NOM.god() end) } },
            { title = "UI_NOM_Debug_C_NoClip", desc = "UI_NOM_Debug_C_NoClip_Desc", state = cheat("isNoClip"),
                choices = { c(nil, function() NOM.noclip() end) } },
            { title = "UI_NOM_Debug_C_Invisible", desc = "UI_NOM_Debug_C_Invisible_Desc", state = cheat("isInvisible"),
                choices = { c(nil, function() NOM.invisible() end) } },
        } },
    { title = "UI_NOM_Debug_Sec_Diag", desc = "UI_NOM_Debug_Sec_Diag_Desc", color = { r = 0.72, g = 0.62, b = 0.90 },
        cards = {
            { title = "UI_NOM_Debug_C_Status", desc = "UI_NOM_Debug_C_Status_Desc", choices = {
                c("UI_NOM_Debug_B_Show", function() NOM.status() end) } },
            { title = "UI_NOM_Debug_C_Ticao", desc = "UI_NOM_Debug_C_Ticao_Desc", choices = {
                c("UI_NOM_Debug_B_Show", function() NOM.ticao() end) } },
            { title = "UI_NOM_Debug_C_BlackPressure", desc = "UI_NOM_Debug_C_BlackPressure_Desc", choices = {
                c("UI_NOM_Debug_B_Show", function() NOM.blackPressure() end) } },
            { title = "UI_NOM_Debug_C_Blind", desc = "UI_NOM_Debug_C_Blind_Desc", choices = {
                c("UI_NOM_Debug_B_Show", function() NOM.blind() end) } },
            { title = "UI_NOM_Debug_C_OwnSprites", desc = "UI_NOM_Debug_C_OwnSprites_Desc", choices = {
                c("UI_NOM_Debug_B_Show", function() NOM.ownSprites() end) } },
            { title = "UI_NOM_Debug_C_Help", desc = "UI_NOM_Debug_C_Help_Desc", choices = {
                c("UI_NOM_Debug_B_Show", function() NOM.help() end) } },
        } },
}

local function measure(font, s) return getTextManager():MeasureStringX(font, s) end

-- Quebra o texto em linhas que cabem em maxW (palavra maior que a linha fica sozinha).
local function wrap(text, font, maxW)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        local try = line == "" and word or line .. " " .. word
        if line ~= "" and measure(font, try) > maxW then
            lines[#lines + 1] = line
            line = word
        else
            line = try
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

-- Corta com "..." o que não cabe (no Kahlua a string é do Java: sub corta por caractere).
local function fit(text, font, maxW)
    if measure(font, text) <= maxW then return text end
    while #text > 1 and measure(font, text .. "...") > maxW do text = text:sub(1, -2) end
    return text .. "..."
end

local function rect(el, x, y, w, h, col, a) el:drawRect(x, y, w, h, a, col.r, col.g, col.b) end
local function border(el, x, y, w, h, col, a) el:drawRectBorder(x, y, w, h, a, col.r, col.g, col.b) end
local function text(el, s, x, y, col, a, font) el:drawText(s, x, y, col.r, col.g, col.b, a, font) end
local function mix(col, k) return { r = col.r * k, g = col.g * k, b = col.b * k } end

local function choiceLabel(card, choice)
    if card.state then
        local on = card.state()
        return getText(on and "UI_NOM_Debug_On" or "UI_NOM_Debug_Off"), on
    end
    return getText(choice.key), nil
end

-- "HH:MM" da hora do jogo (13.5 → 13:30), sem %d em número quebrado.
local function clock(h)
    local m = NOM_Math.mod(math.floor(h * 60 + 0.5), 24 * 60)
    local hh = math.floor(m / 60)
    local mm = m - hh * 60
    return (hh < 10 and "0" or "") .. hh .. ":" .. (mm < 10 and "0" or "") .. mm
end

-- Cartões do cabeçalho: o que este cliente sabe agora. weight: fatia da largura.
local function statusChips()
    local monsters = 0
    for _ in pairs(NOM_NightStats.variants) do monsters = monsters + 1 end
    local fog, fogColor = "UI_NOM_Debug_FogNone", DIM
    if NOM_FogState.on then
        if NOM_FogState.black then
            fog, fogColor = "UI_NOM_Debug_FogBlack", { r = 0.70, g = 0.55, b = 0.95 }
        elseif NOM_FogState.red then
            fog, fogColor = "UI_NOM_Debug_FogRed", { r = 0.95, g = 0.32, b = 0.28 }
        else
            fog, fogColor = "UI_NOM_Debug_FogWhite", { r = 0.90, g = 0.93, b = 0.97 }
        end
    end
    local you = {}
    if cheat("isGodMod")() then you[#you + 1] = getText("UI_NOM_Debug_YouGod") end
    if cheat("isNoClip")() then you[#you + 1] = getText("UI_NOM_Debug_YouNoClip") end
    if cheat("isInvisible")() then you[#you + 1] = getText("UI_NOM_Debug_YouInvisible") end
    local night = NOM_NightStats.night == true
    return {
        { label = getText("UI_NOM_Debug_StatusHour"), value = clock(getGameTime():getTimeOfDay()), color = TEXT, weight = 1 },
        { label = getText("UI_NOM_Debug_StatusTime"), value = getText(night and "UI_NOM_Debug_Night" or "UI_NOM_Debug_Day"),
            color = night and { r = 0.55, g = 0.65, b = 1 } or { r = 1, g = 0.85, b = 0.45 }, weight = 1 },
        { label = getText("UI_NOM_Debug_StatusFog"), value = getText(fog), color = fogColor, weight = 1.2 },
        { label = getText("UI_NOM_Debug_StatusMonsters"), value = tostring(monsters),
            color = monsters > 0 and { r = 0.95, g = 0.45, b = 0.40 } or TEXT, weight = 1 },
        { label = getText("UI_NOM_Debug_StatusYou"),
            value = #you > 0 and table.concat(you, ", ") or getText("UI_NOM_Debug_YouNormal"),
            color = #you > 0 and { r = 0.45, g = 0.90, b = 0.55 } or TEXT, weight = 1.8 },
    }
end

local function newPanel(class, window)
    local o = class:new(0, 0, 10, 10)
    o:noBackground()
    o.window = window
    o:initialise()
    o:instantiate()
    return o
end

-- Lateral: uma linha por seção, com a cor e o número de ações.
function Side:layout()
    self.rows = {}
    for i = 1, #P.SECTIONS do
        self.rows[i] = { x = 0, y = (i - 1) * (SIDE_ROW + SIDE_GAP), w = self.width, h = SIDE_ROW }
    end
end

local function sideHeight() return #P.SECTIONS * (SIDE_ROW + SIDE_GAP) - SIDE_GAP end

function Side:rowAt(x, y)
    for i, r in ipairs(self.rows or {}) do
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then return i end
    end
end

function Side:onMouseDown(x, y)
    local i = self:rowAt(x, y)
    if i and i ~= self.window.list.section then
        getSoundManager():playUISound(CLICK_SOUND)
        self.window.list:setSection(i)
    end
    return true
end

function Side:prerender()
    self.hover = self:isMouseOver() and self:rowAt(self:getMouseX(), self:getMouseY()) or nil
    local current = self.window.list.section
    for i, r in ipairs(self.rows or {}) do
        local s = P.SECTIONS[i]
        local selected = i == current
        if selected then
            rect(self, r.x, r.y, r.w, r.h, mix(s.color, 0.28), 0.95)
            rect(self, r.x, r.y, 3, r.h, s.color, 1)
        elseif i == self.hover then
            rect(self, r.x, r.y, r.w, r.h, CARD, 0.95)
        else
            rect(self, r.x, r.y, r.w, r.h, CARD, 0.55)
        end
        local count = tostring(#s.cards)
        local countW = measure(SMALL, count) + 10
        text(self, fit(getText(s.title), MEDIUM, r.w - countW - 18), r.x + 12, r.y + 7,
            selected and TEXT or (i == self.hover and TEXT or DIM), 1, MEDIUM)
        self:drawTextRight(count, r.x + r.w - 8, r.y + 7 + (MEDIUM_HGT - SMALL_HGT) / 2, s.color.r, s.color.g,
            s.color.b, 0.9, SMALL)
    end
end

function List:setSection(i)
    self.section = i
    self.scroll = 0
    self:layout()
end

function List:maxScroll() return math.max(0, (self.contentH or 0) - self.height) end

function List:setScroll(v)
    self.scroll = math.max(0, math.min(v, self:maxScroll()))
end

local function sliderValue(key)
    local d = NOM_FlakeRules.debugMul()
    return d[key] or 1
end

local function snapSlider(v, minV, maxV, step)
    v = math.floor(v / step + 0.5) * step
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    return math.floor(v * 1000 + 0.5) / 1000
end

-- Posições em coordenadas do conteúdo (y sem a rolagem). hits: botões; sliders: trilhos.
function List:layout()
    local s = P.SECTIONS[self.section]
    local cw = self.width - SCROLL_W - 4
    local inner = cw - CARD_PAD * 2
    self.cards, self.hits, self.sliders = {}, {}, {}
    local y = 2
    self.head = { y = y, desc = wrap(getText(s.desc), SMALL, cw - 4) }
    y = y + MEDIUM_HGT + 4 + #self.head.desc * SMALL_HGT + 12
    for _, card in ipairs(s.cards) do
        local item = { card = card, y = y, title = getText(card.title), desc = wrap(getText(card.desc), SMALL, inner) }
        local cy = y + CARD_PAD
        cy = cy + MEDIUM_HGT + 4 + #item.desc * SMALL_HGT + 8
        for _, sl in ipairs(card.sliders or {}) do
            local labelY = cy
            local trackY = cy + SMALL_HGT + 2
            self.sliders[#self.sliders + 1] = {
                card = card, key = sl.key, label = sl.label, min = sl.min, max = sl.max, step = sl.step,
                x = CARD_PAD, w = inner, labelY = labelY, trackY = trackY, trackH = TRACK_H,
            }
            cy = trackY + TRACK_H + SLIDER_GAP
        end
        local px = CARD_PAD
        for i, choice in ipairs(card.choices) do
            local label, on = choiceLabel(card, choice)
            local pw = math.min(inner, math.max(64, measure(SMALL, label) + PILL_PAD * 2))
            if px > CARD_PAD and px + pw > cw - CARD_PAD then
                px = CARD_PAD
                cy = cy + PILL_H + PILL_GAP
            end
            self.hits[#self.hits + 1] = { x = px, y = cy, w = pw, h = PILL_H, card = card, choice = choice,
                index = i, label = label, on = on }
            px = px + pw + PILL_GAP
        end
        cy = cy + PILL_H + CARD_PAD
        item.h = cy - y
        item.w = cw
        self.cards[#self.cards + 1] = item
        y = cy + GAP
    end
    self.contentH = y
    self:setScroll(self.scroll or 0)
end

function List:hitAt(x, cy)
    for _, h in ipairs(self.hits or {}) do
        if x >= h.x and x < h.x + h.w and cy >= h.y and cy < h.y + h.h then return h end
    end
end

function List:sliderAt(x, cy)
    for _, sl in ipairs(self.sliders or {}) do
        if x >= sl.x and x < sl.x + sl.w and cy >= sl.trackY - 2 and cy < sl.trackY + sl.trackH + 2 then
            return sl
        end
    end
end

function List:applySlider(sl, x)
    local t = (x - sl.x) / sl.w
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local v = snapSlider(sl.min + t * (sl.max - sl.min), sl.min, sl.max, sl.step)
    NOM_FlakeRules.setDebugKey(sl.key, v)
    NOM_DebugLog.echo(getText(sl.label) .. ": " .. string.format("%.1f", v))
    self.window:refresh()
end

function List:onMouseWheel(del)
    self:setScroll(self.scroll + del * SCROLL_STEP)
    return true
end

function List:onMouseDown(x, y)
    if y < 0 or y > self.height then return true end
    local cy = y + self.scroll
    local sl = self:sliderAt(x, cy)
    if sl then
        getSoundManager():playUISound(CLICK_SOUND)
        self.drag = sl
        self:applySlider(sl, x)
        return true
    end
    local h = self:hitAt(x, cy)
    if h then
        getSoundManager():playUISound(CLICK_SOUND)
        -- liga/desliga ecoa só o título: o rótulo é o estado de antes do clique
        NOM_DebugLog.echo(getText(h.card.title) .. (h.on == nil and ": " .. h.label or ""))
        h.choice.fn()
        self.window:refresh()
    end
    return true
end

function List:onMouseMove(dx, dy)
    if self.drag then self:applySlider(self.drag, self:getMouseX()) end
end

function List:onMouseUp()
    self.drag = nil
end

function List:onMouseUpOutside()
    self.drag = nil
end

function List:prerender()
    self:setStencilRect(0, 0, self.width, self.height)
    self.hover = nil
    if self:isMouseOver() then self.hover = self:hitAt(self:getMouseX(), self:getMouseY() + self.scroll) end
    local s = P.SECTIONS[self.section]
    local sy = -self.scroll
    text(self, getText(s.title), 2, self.head.y + sy, s.color, 1, MEDIUM)
    local ty = self.head.y + sy + MEDIUM_HGT + 4
    for _, line in ipairs(self.head.desc) do
        text(self, line, 2, ty, DIM, 1, SMALL)
        ty = ty + SMALL_HGT
    end
    for _, item in ipairs(self.cards) do
        local y = item.y + sy
        if y + item.h >= 0 and y <= self.height then
            local over = self.hover and self.hover.card == item.card
            rect(self, 0, y, item.w, item.h, CARD, 0.96)
            border(self, 0, y, item.w, item.h, over and s.color or mix(TEXT, 0.25), over and 0.8 or 0.5)
            rect(self, 0, y, 3, item.h, s.color, 0.9)
            text(self, item.title, CARD_PAD, y + CARD_PAD, TEXT, 1, MEDIUM)
            local dy = y + CARD_PAD + MEDIUM_HGT + 4
            for _, line in ipairs(item.desc) do
                text(self, line, CARD_PAD, dy, DIM, 1, SMALL)
                dy = dy + SMALL_HGT
            end
        end
    end
    self.sliderHover = nil
    if self:isMouseOver() then
        self.sliderHover = self:sliderAt(self:getMouseX(), self:getMouseY() + self.scroll)
    end
    for _, sl in ipairs(self.sliders or {}) do
        local ly = sl.labelY + sy
        local ty = sl.trackY + sy
        if ty + sl.trackH >= 0 and ly <= self.height then
            local v = sliderValue(sl.key)
            local span = sl.max - sl.min
            local t = span > 0 and (v - sl.min) / span or 0
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            local over = sl == self.sliderHover or sl == self.drag
            local label = getText(sl.label) .. "  " .. string.format("%.1f", v)
            text(self, label, sl.x, ly, over and TEXT or DIM, 1, SMALL)
            rect(self, sl.x, ty, sl.w, sl.trackH, mix(CARD, 0.7), 0.95)
            border(self, sl.x, ty, sl.w, sl.trackH, mix(s.color, over and 1 or 0.55), over and 0.9 or 0.5)
            local fill = math.max(2, sl.w * t)
            rect(self, sl.x, ty, fill, sl.trackH, mix(s.color, over and 0.85 or 0.55), 0.9)
            local thumbX = sl.x + fill - 3
            if thumbX < sl.x then thumbX = sl.x end
            rect(self, thumbX, ty - 1, 6, sl.trackH + 2, TEXT, 0.85)
        end
    end
    for _, h in ipairs(self.hits) do
        local y = h.y + sy
        if y + h.h >= 0 and y <= self.height then
            local over = h == self.hover
            local base = h.on == true and ON or (h.on == false and OFF or mix(s.color, 0.32))
            rect(self, h.x, y, h.w, h.h, over and mix(base, 1.35) or base, 0.95)
            border(self, h.x, y, h.w, h.h, h.on == nil and s.color or mix(base, 1.6), over and 1 or 0.6)
            self:drawTextCentre(h.label, h.x + h.w / 2, y + (h.h - SMALL_HGT) / 2, TEXT.r, TEXT.g, TEXT.b, 1, SMALL)
        end
    end
    local max = self:maxScroll()
    if max > 0 then
        local track = self.height
        local thumb = math.max(24, track * self.height / self.contentH)
        local ty2 = (track - thumb) * self.scroll / max
        rect(self, self.width - SCROLL_W + 2, 0, SCROLL_W - 4, track, CARD, 0.8)
        rect(self, self.width - SCROLL_W + 2, ty2, SCROLL_W - 4, thumb, s.color, 0.7)
    end
end

function List:render()
    self:clearStencilRect()
end

function Log:createChildren()
    local label = getText("UI_NOM_Debug_Clear")
    local bw = measure(SMALL, label) + 20
    self.clear = ISButton:new(self.width - bw - 6, 4, bw, SMALL_HGT + 2, label, self, function()
        NOM_DebugLog.clear()
    end)
    self.clear:initialise()
    self.clear:instantiate()
    self:addChild(self.clear)
end

function Log:layout()
    if self.clear then self.clear:setX(self.width - self.clear.width - 6) end
    self.cacheSeq = nil
end

-- Linhas quebradas na largura, refeitas só quando chega linha nova, limpa ou muda a largura.
function Log:wrapped()
    local seq = NOM_DebugLog.seq()
    if self.cacheSeq ~= seq or self.cacheW ~= self.width then
        local out = {}
        for _, entry in ipairs(NOM_DebugLog.lines()) do
            for _, line in ipairs(wrap(entry.text, SMALL, self.width - 34)) do
                out[#out + 1] = { text = line, kind = entry.kind }
            end
        end
        self.cache, self.cacheSeq, self.cacheW = out, seq, self.width
    end
    return self.cache
end

function Log:prerender()
    self:setStencilRect(0, 0, self.width, self.height)
    rect(self, 0, 0, self.width, self.height, { r = 0.05, g = 0.055, b = 0.065 }, 0.92)
    border(self, 0, 0, self.width, self.height, mix(TEXT, 0.25), 0.6)
    rect(self, 0, LOG_HEAD - 1, self.width, 1, mix(TEXT, 0.25), 0.6)
    text(self, getText("UI_NOM_Debug_Log"), 10, 5, TEXT, 1, SMALL)
end

function Log:render()
    local all = self:wrapped()
    local fits = math.max(0, math.floor((self.height - LOG_HEAD - 6) / LOG_LINE))
    local first = math.max(1, #all - fits + 1)
    self.shown = {}
    local y = LOG_HEAD + 3
    for i = first, #all do
        local l = all[i]
        self.shown[#self.shown + 1] = { text = l.text, kind = l.kind, y = y }
        if l.kind == "echo" then
            text(self, ">", 10, y, { r = 0.96, g = 0.80, b = 0.45 }, 1, SMALL)
            text(self, l.text, 22, y, { r = 0.96, g = 0.80, b = 0.45 }, 1, SMALL)
        else
            text(self, l.text, 22, y, { r = 0.80, g = 0.84, b = 0.88 }, 1, SMALL)
        end
        y = y + LOG_LINE
    end
    if #all == 0 then text(self, getText("UI_NOM_Debug_LogEmpty"), 10, y, DIM, 0.9, SMALL) end
    self:clearStencilRect()
end

function P:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.side = newPanel(Side, self)
    self:addChild(self.side)
    self.list = newPanel(List, self)
    self.list.section, self.list.scroll = 1, 0
    self:addChild(self.list)
    self.log = newPanel(Log, self)
    self:addChild(self.log)
    self:layout()
    self:refresh()
end

-- Recalcula tudo pelo tamanho de agora (abre, redimensiona, leiaute salvo).
function P:layout()
    local w, h = math.max(self.width, MIN_W), math.max(self.height, MIN_H)
    self.lastW, self.lastH = self.width, self.height
    local top = self:titleBarHeight() + PAD
    self.headerY = top
    local bodyY = top + HEADER_H + PAD
    local bottom = h - self:resizeWidgetHeight() - PAD
    -- a lateral inteira cabe sempre (minimumHeight conta com ela); as respostas cedem até LOG_MIN
    local logH = math.max(LOG_MIN, math.min(190, math.floor(h * 0.22), bottom - bodyY - GAP - sideHeight()))
    local logY = bottom - logH
    local bodyH = logY - GAP - bodyY
    local function place(el, x, y, ew, eh)
        el:setX(x); el:setY(y); el:setWidth(ew); el:setHeight(eh)
    end
    place(self.side, PAD, bodyY, SIDE_W, bodyH)
    place(self.list, PAD + SIDE_W + GAP, bodyY, w - PAD * 2 - SIDE_W - GAP, bodyH)
    place(self.log, PAD, logY, w - PAD * 2, logH)
    self.side:layout()
    self.list:layout()
    self.log:layout()
end

function P:refresh()
    self.chips = statusChips()
    if self.list then self.list:layout() end
end

-- Altura mínima pelas fontes de agora (a opção de tamanho de fonte do jogo muda as alturas).
function P:neededHeight()
    return self:titleBarHeight() + PAD + HEADER_H + PAD + sideHeight() + GAP + LOG_MIN + self:resizeWidgetHeight() + PAD
end

function P:update()
    ISCollapsableWindow.update(self)
    -- o ISResizeWidget corta a altura na borda de baixo da tela depois do mínimo
    -- (ISResizeWidget.lua:25-27): a janela sobe até caber
    if self.height < self.minimumHeight then
        self:setY(math.max(0, self.y - (self.minimumHeight - self.height)))
        self:setHeight(self.minimumHeight)
    end
    if self.width ~= self.lastW or self.height ~= self.lastH then self:layout() end
    local now = getTimestampMs()
    if self.nextRefresh == nil or now >= self.nextRefresh then
        self:refresh()
        self.nextRefresh = now + REFRESH_MS
    end
end

function P:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local chips = self.chips or {}
    local total = 0
    for _, ch in ipairs(chips) do total = total + ch.weight end
    local avail = self.width - PAD * 2 - GAP * (#chips - 1)
    local x = PAD
    for _, ch in ipairs(chips) do
        local cw = avail * ch.weight / total
        rect(self, x, self.headerY, cw, HEADER_H, CARD, 0.95)
        rect(self, x, self.headerY, cw, 2, ch.color, 0.8)
        text(self, fit(ch.label, SMALL, cw - 16), x + 8, self.headerY + 5, DIM, 1, SMALL)
        text(self, fit(ch.value, MEDIUM, cw - 16), x + 8, self.headerY + 7 + SMALL_HGT, ch.color, 1, MEDIUM)
        x = x + cw + GAP
    end
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
        w = P:new(100, 100, WIDTH, HEIGHT)
        w.minimumWidth = MIN_W -- ISResizeWidget.lua:13-23
        w.minimumHeight = math.max(MIN_H, w:neededHeight())
        w.backgroundColor = { r = 0.06, g = 0.065, b = 0.08, a = 0.95 }
        w:setTitle(getText("UI_NOM_Debug_Title"))
        w:initialise()
        w:addToUIManager()
        P.instance = w
        -- devolve posição e tamanho salvos (e o "visible" salvo, que o setVisible abaixo corrige)
        ISLayoutManager.RegisterWindow(P.LAYOUT, ISCollapsableWindow, w)
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
