-- Opções de cliente dos efeitos de tela (sprint 0013), da tecla do painel de debug
-- (sprint 0020, só com -debug) e da densidade do sangue e da
-- erosão na névoa (sprint 0015, client/NOM_FogOverlays.lua), do dissolve e do bloom do
-- shader (sprint 0018, client/NOM_Dissolve.lua e mod2): cada jogador escolhe no
-- próprio jogo (Opções > Mods), não o servidor. PZAPI.ModOptions do B42
-- (client/PZAPI/ModOptions.lua: create, addTickBox, addSlider, getOption/getValue),
-- gravado no ModOptions.ini da máquina. A tela de opções (MainOptions:addModOptionsPanel,
-- MainOptions.lua:2795-2796) faz o load() do arquivo ao ser montada, e o MainScreen
-- do jogo nasce no OnGameStart (MainScreen.lua:2180): as opções têm de existir antes,
-- na carga deste arquivo. Os nomes passam por getText (MainOptions.lua:2805+), chaves
-- em Translate/<LANG>/UI.json. Valor lido a cada uso: o load() e o "Aplicar" trocam
-- option.value depois.
if isServer() then return end

NOM_ScreenFxOptions = { ID = "NevoaEOutroMundo", DEFAULT_INTENSITY = 1, DEFAULT_DENSITY = 1, DEFAULT_BLOOM = 1 }

local O = NOM_ScreenFxOptions
local page

if PZAPI and PZAPI.ModOptions then
    page = PZAPI.ModOptions:create(O.ID, "UI_NOM_Options")
    page:addTickBox("ScreenFx", "UI_NOM_ScreenFx", true, "UI_NOM_ScreenFx_tooltip")
    page:addSlider("ScreenFxIntensity", "UI_NOM_ScreenFxIntensity", 0, 2, 0.1, O.DEFAULT_INTENSITY,
        "UI_NOM_ScreenFxIntensity_tooltip")
    page:addSlider("FogOverlayDensity", "UI_NOM_FogOverlayDensity", 0, 2, 0.1, O.DEFAULT_DENSITY,
        "UI_NOM_FogOverlayDensity_tooltip")
    page:addTickBox("Dissolve", "UI_NOM_Dissolve", true, "UI_NOM_Dissolve_tooltip")
    page:addSlider("Bloom", "UI_NOM_Bloom", 0, 2, 0.1, O.DEFAULT_BLOOM, "UI_NOM_Bloom_tooltip")
    -- tecla do painel de debug (sprint 0020, client/NOM_DebugPanel.lua), só com -debug:
    -- addKeyBind (ModOptions.lua:182-204), o jogador troca em Opções > Mods. Insert: F7 abre o
    -- editor de veículos do vanilla em -debug (IngameState.updateInternal 547–606), F2/F8/F9
    -- também são do debug e F1–F6/F10/F11 têm bind; nenhuma das classes que leem o teclado usa Insert
    if getDebug() then
        page:addKeyBind("DebugPanel", "UI_NOM_DebugPanelKey", Keyboard.KEY_INSERT, "UI_NOM_DebugPanelKey_tooltip")
    end
end

local function value(id, default)
    local opt = page and page:getOption(id)
    if opt == nil then return default end
    local v = opt:getValue()
    if v == nil then return default end
    return v
end

function O.enabled()
    return value("ScreenFx", true) == true
end

-- 0..2; 0 com o efeito desligado.
function O.intensity()
    if not O.enabled() then return 0 end
    local v = tonumber(value("ScreenFxIntensity", O.DEFAULT_INTENSITY)) or O.DEFAULT_INTENSITY
    return math.max(0, math.min(2, v))
end

-- 0..2: quanto sangue e erosão a névoa põe em volta (1 = o padrão, já pesado).
function O.overlayDensity()
    local v = tonumber(value("FogOverlayDensity", O.DEFAULT_DENSITY)) or O.DEFAULT_DENSITY
    return math.max(0, math.min(2, v))
end

-- Dissolve das peças e da morte do Eco; desligado = peças sem shader, troca instantânea.
function O.dissolve()
    return value("Dissolve", true) == true
end

-- 0..2: bloom do screen.frag do mod do shader (sem o mod, não faz nada).
function O.bloom()
    local v = tonumber(value("Bloom", O.DEFAULT_BLOOM)) or O.DEFAULT_BLOOM
    return math.max(0, math.min(2, v))
end

-- Código da tecla do painel de debug; nil fora do -debug. Insert sem a página.
function O.debugPanelKey()
    if not getDebug() then return nil end
    return value("DebugPanel", Keyboard.KEY_INSERT)
end

return NOM_ScreenFxOptions
