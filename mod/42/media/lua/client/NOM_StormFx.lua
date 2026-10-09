-- Clarão vermelho na névoa preta (sprint 0053). O ThunderStorm vanilla pinta o clarão
-- com PlayerLightningInfo.lightningColor (branco no construtor; pz-api-notes §34). Com o
-- mod3, NOMRender_setLightningColor pinta esse campo; sem ele, um overlay vermelho curto
-- na ScreenFx cobre o clarão branco. Vermelha e branca ficam brancas (tint vanilla).
-- O som do trovão não tem cor.
if isServer() then return end

require "NOM_FogState"
require "NOM_StormRules"
require "NOM_ScreenFxRules"
require "NOM_ScreenFx"

NOM_StormFx = { flashAt = nil, tintBlack = nil }
local F = NOM_StormFx
local R = NOM_StormRules
local MODULE = "NevoaEOutroMundo"

local function wantBlack()
    return NOM_FogState.on and NOM_FogState.black == true
end

-- Empurra a cor do clarão pro mod3 quando a névoa preta liga/desliga (e no primeiro tick).
local function syncTint()
    local fn = NOMRender_setLightningColor
    if fn == nil then return end
    local black = wantBlack()
    if F.tintBlack == black then return end
    F.tintBlack = black
    local r, g, b = R.lightningTint(black)
    pcall(fn, r, g, b)
end

-- Overlay de tela (fallback sem mod3, ou reforço): pico vermelho curto.
function F.flash()
    if not wantBlack() then return end
    F.flashAt = getTimestampMs()
end

local function draw(el, now)
    syncTint()
    local a = R.stormFlash(now, F.flashAt)
    if a <= 0 then return end
    if MainScreen and MainScreen.instance and MainScreen.instance:isReallyVisible() then return end
    local t = getTexture(NOM_ScreenFxRules.TEXTURES.white)
    if not t then return end
    local c = R.LIGHTNING_BLACK
    local x, y = getPlayerScreenLeft(0), getPlayerScreenTop(0)
    local w, h = getPlayerScreenWidth(0), getPlayerScreenHeight(0)
    el:drawTextureScaled(t, x, y, w, h, a * 0.55, c.r, c.g, c.b)
end

NOM_ScreenFx.extra[#NOM_ScreenFx.extra + 1] = draw

Events.OnTick.Add(syncTint)

Events.OnServerCommand.Add(function(module, command, args)
    if module == MODULE and command == "thunderFlash" then F.flash() end
end)

return NOM_StormFx
