require "NOM_World"

local TRANSITION_SECONDS = 30

local FLOATS = {
    desaturation = ClimateManager.FLOAT_DESATURATION,
    light = ClimateManager.FLOAT_GLOBAL_LIGHT_INTENSITY,
    fog = ClimateManager.FLOAT_FOG_INTENSITY,
}

local state = { nightRamp = 0, fogRamp = 0, lastMs = nil, fogWeight = 0 }
local applied = {} -- canal -> true enquanto a camada modded dele está ligada por nós
local tintInfo = nil

-- Só desliga o que nós ligamos, uma vez: outros mods podem usar a mesma camada.
local function apply(ch, target, weight, setValue)
    if weight <= 0 then
        if applied[ch] then
            target:setEnableModded(false)
            applied[ch] = false
        end
        return
    end
    if not applied[ch] then
        target:setEnableModded(true)
        applied[ch] = true
    end
    setValue()
    target:setModdedInterpolate(weight)
end

local function onTick()
    local now = getTimestampMs()
    local dt = state.lastMs and (now - state.lastMs) / 1000 or 0
    state.lastMs = now

    local enabled = NOM_Config.get("DarkEnabled")
    local w = NOM_World.update(state.fogWeight)
    state.nightRamp = NOM_Rules.ramp(state.nightRamp, enabled and w.night, dt, TRANSITION_SECONDS)
    state.fogRamp = NOM_Rules.ramp(state.fogRamp, enabled and w.fog, dt, TRANSITION_SECONDS)

    local look = NOM_Rules.mix(state.nightRamp, state.fogRamp, NOM_Config.get("DarkIntensity"))
    local clim = getClimateManager()
    for ch, id in pairs(FLOATS) do
        local f = clim:getClimateFloat(id)
        apply(ch, f, look[ch].weight, function() f:setModdedValue(look[ch].value) end)
    end
    state.fogWeight = applied.fog and look.fog.weight or 0

    local c = clim:getClimateColor(ClimateManager.COLOR_GLOBAL_LIGHT)
    apply("tint", c, look.tint.weight, function()
        local rgb = look.tint.value
        tintInfo = tintInfo or ClimateColorInfo.new(rgb[1], rgb[2], rgb[3], 1, rgb[1], rgb[2], rgb[3], 1)
        tintInfo:setExterior(rgb[1], rgb[2], rgb[3], 1)
        tintInfo:setInterior(rgb[1], rgb[2], rgb[3], 1)
        c:setModdedValue(tintInfo)
    end)
end

Events.OnTick.Add(onTick)
