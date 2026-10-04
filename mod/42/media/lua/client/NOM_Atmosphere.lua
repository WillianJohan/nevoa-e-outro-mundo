require "NOM_World"

local TRANSITION_SECONDS = 30

-- Ids numéricos como fallback: os mesmos do painel de admin vanilla (ISAdmPanelClimate.lua).
local FLOATS = {
    desaturation = ClimateManager.FLOAT_DESATURATION or 0,
    light = ClimateManager.FLOAT_GLOBAL_LIGHT_INTENSITY or 1,
    fog = ClimateManager.FLOAT_FOG_INTENSITY or 5,
}
local COLOR_GLOBAL_LIGHT = ClimateManager.COLOR_GLOBAL_LIGHT or 0

local state = { nightRamp = 0, fogRamp = 0, lastMs = nil }
local tintInfo = {} -- cache: tabela de cor do NOM_Rules -> ClimateColorInfo

local function applyFloat(clim, id, ch)
    local f = clim:getClimateFloat(id)
    if ch.weight <= 0 then
        f:setEnableModded(false)
        return
    end
    f:setEnableModded(true)
    f:setModdedValue(ch.value)
    f:setModdedInterpolate(ch.weight)
end

local function colorInfo(c, rgb)
    if tintInfo[rgb] then return tintInfo[rgb] end
    local ok, info = pcall(ClimateColorInfo.new, rgb[1], rgb[2], rgb[3], 1, rgb[1], rgb[2], rgb[3], 1)
    if not ok then
        -- ponytail: fallback reusa o objeto modded do jogo; só serve com uma cor ativa por vez
        info = c:getModdedValue()
        info:setExterior(rgb[1], rgb[2], rgb[3], 1)
        info:setInterior(rgb[1], rgb[2], rgb[3], 1)
        print("[NOM] ClimateColorInfo.new indisponível, usando fallback setExterior/setInterior")
        return info
    end
    tintInfo[rgb] = info
    return info
end

local function applyTint(clim, ch)
    local c = clim:getClimateColor(COLOR_GLOBAL_LIGHT)
    if ch.weight <= 0 then
        c:setEnableModded(false)
        return
    end
    c:setEnableModded(true)
    c:setModdedValue(colorInfo(c, ch.value))
    c:setModdedInterpolate(ch.weight)
end

local function onTick()
    local now = getTimestampMs()
    local dt = state.lastMs and (now - state.lastMs) / 1000 or 0
    state.lastMs = now

    local enabled = NOM_Config.get("DarkEnabled")
    local w = NOM_World.update()
    state.nightRamp = NOM_Rules.ramp(state.nightRamp, enabled and w.night, dt, TRANSITION_SECONDS)
    state.fogRamp = NOM_Rules.ramp(state.fogRamp, enabled and w.fog, dt, TRANSITION_SECONDS)

    local look = NOM_Rules.mix(state.nightRamp, state.fogRamp, NOM_Config.get("DarkIntensity"))
    local clim = getClimateManager()
    for ch, id in pairs(FLOATS) do
        applyFloat(clim, id, look[ch])
    end
    applyTint(clim, look.tint)
end

Events.OnTick.Add(onTick)
