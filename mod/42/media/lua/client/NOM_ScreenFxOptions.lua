-- Opções de cliente dos efeitos de tela (sprint 0013; a tontura, sprint 0035), da tecla do painel de debug
-- (sprint 0020, só com -debug) e da densidade do sangue e da
-- erosão na névoa (sprint 0015, client/NOM_FogOverlays.lua), do dissolve e do bloom do
-- shader (sprint 0018, client/NOM_Dissolve.lua e mod2), da brasa no corpo (sprint 0022): cada jogador escolhe no
-- próprio jogo (Opções > Mods), não o servidor. PZAPI.ModOptions do B42
-- (client/PZAPI/ModOptions.lua: create, addTickBox, addSlider, getOption/getValue),
-- gravado no ModOptions.ini da máquina. A tela de opções (MainOptions:addModOptionsPanel,
-- MainOptions.lua:2795-2796) faz o load() do arquivo ao ser montada, e o MainScreen
-- do jogo nasce no OnGameStart (MainScreen.lua:2180): as opções têm de existir antes,
-- na carga deste arquivo. Os nomes passam por getText (MainOptions.lua:2805+), chaves
-- em Translate/<LANG>/UI.json. Valor lido a cada uso: o load() e o "Aplicar" trocam
-- option.value depois.
if isServer() then return end

NOM_ScreenFxOptions = { ID = "NevoaEOutroMundo", DEFAULT_INTENSITY = 1, DEFAULT_DENSITY = 1, DEFAULT_BLOOM = 1,
    DEFAULT_FOG_QUALITY = 2, DEFAULT_FLOW_RESOLUTION = 3 }

local O = NOM_ScreenFxOptions
local page

if PZAPI and PZAPI.ModOptions then
    page = PZAPI.ModOptions:create(O.ID, "UI_NOM_Options")
    page:addTickBox("ScreenFx", "UI_NOM_ScreenFx", true, "UI_NOM_ScreenFx_tooltip")
    page:addSlider("ScreenFxIntensity", "UI_NOM_ScreenFxIntensity", 0, 2, 0.1, O.DEFAULT_INTENSITY,
        "UI_NOM_ScreenFxIntensity_tooltip")
    -- tontura na revelação do Outro Mundo (sprint 0035, client/NOM_ScreenFx.lua)
    page:addTickBox("Dizzy", "UI_NOM_Dizzy", true, "UI_NOM_Dizzy_tooltip")
    page:addSlider("FogOverlayDensity", "UI_NOM_FogOverlayDensity", 0, 2, 0.1, O.DEFAULT_DENSITY,
        "UI_NOM_FogOverlayDensity_tooltip")
    page:addTickBox("Dissolve", "UI_NOM_Dissolve", true, "UI_NOM_Dissolve_tooltip")
    page:addTickBox("BodyEmbers", "UI_NOM_BodyEmbers", true, "UI_NOM_BodyEmbers_tooltip")
    page:addSlider("Bloom", "UI_NOM_Bloom", 0, 2, 0.1, O.DEFAULT_BLOOM, "UI_NOM_Bloom_tooltip")
    -- qualidade da névoa do mod Java opcional (sprint 0026, client/NOM_FogQualitySync.lua)
    page:addSlider("FogQuality", "UI_NOM_FogQuality", 0, 2, 1, O.DEFAULT_FOG_QUALITY, "UI_NOM_FogQuality_tooltip")
    -- resolução da névoa fluida do mesmo mod (sprint 0030): células por tile
    page:addSlider("FlowResolution", "UI_NOM_FlowResolution", 1, 3, 1, O.DEFAULT_FLOW_RESOLUTION,
        "UI_NOM_FlowResolution_tooltip")
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

-- Tontura quando o Outro Mundo se espalha: sub-opção dos efeitos de tela, sem eles não há.
function O.dizzy()
    return O.enabled() and value("Dizzy", true) == true
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

-- Casca de brasa no corpo inteiro na mutação (sprint 0022, client/NOM_EmberShell.lua):
-- sub-opção do dissolve, sem ele não há casca.
function O.bodyEmbers()
    return O.dissolve() and value("BodyEmbers", true) == true
end

-- 0..2: bloom do screen.frag do mod do shader (sem o mod, não faz nada).
function O.bloom()
    local v = tonumber(value("Bloom", O.DEFAULT_BLOOM)) or O.DEFAULT_BLOOM
    return math.max(0, math.min(2, v))
end

-- 0 baixa, 1 média, 2 alta: qualidade da névoa do mod Java opcional (sem ele, não faz nada).
function O.fogQuality()
    local v = tonumber(value("FogQuality", O.DEFAULT_FOG_QUALITY)) or O.DEFAULT_FOG_QUALITY
    return math.max(0, math.min(2, math.floor(v + 0.5)))
end

-- 1 a 3 células por tile na névoa fluida do mod Java opcional (sem ele, não faz nada).
function O.flowResolution()
    local v = tonumber(value("FlowResolution", O.DEFAULT_FLOW_RESOLUTION)) or O.DEFAULT_FLOW_RESOLUTION
    return math.max(1, math.min(3, math.floor(v + 0.5)))
end

-- Código da tecla do painel de debug; nil fora do -debug. Insert sem a página.
function O.debugPanelKey()
    if not getDebug() then return nil end
    return value("DebugPanel", Keyboard.KEY_INSERT)
end

return NOM_ScreenFxOptions
