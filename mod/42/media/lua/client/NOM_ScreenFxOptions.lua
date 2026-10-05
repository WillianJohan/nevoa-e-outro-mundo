-- Opções de cliente dos efeitos de tela (sprint 0013): cada jogador escolhe no
-- próprio jogo (Opções > Mods), não o servidor. PZAPI.ModOptions do B42
-- (client/PZAPI/ModOptions.lua: create, addTickBox, addSlider, getOption/getValue),
-- gravado no ModOptions.ini da máquina. A tela de opções (MainOptions:addModOptionsPanel,
-- MainOptions.lua:2795-2796) faz o load() do arquivo ao ser montada, e o MainScreen
-- do jogo nasce no OnGameStart (MainScreen.lua:2180): as opções têm de existir antes,
-- na carga deste arquivo. Os nomes passam por getText (MainOptions.lua:2805+), chaves
-- em Translate/<LANG>/UI.json. Valor lido a cada uso: o load() e o "Aplicar" trocam
-- option.value depois.
if isServer() then return end

NOM_ScreenFxOptions = { ID = "NevoaEOutroMundo", DEFAULT_INTENSITY = 1 }

local O = NOM_ScreenFxOptions
local page

if PZAPI and PZAPI.ModOptions then
    page = PZAPI.ModOptions:create(O.ID, "UI_NOM_Options")
    page:addTickBox("ScreenFx", "UI_NOM_ScreenFx", true, "UI_NOM_ScreenFx_tooltip")
    page:addSlider("ScreenFxIntensity", "UI_NOM_ScreenFxIntensity", 0, 2, 0.1, O.DEFAULT_INTENSITY,
        "UI_NOM_ScreenFxIntensity_tooltip")
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

return NOM_ScreenFxOptions
