-- Visual dark aplicado no clima, só do lado do servidor (no solo o servidor
-- roda no mesmo processo). Cliente de MP recebe o resultado pela sincronização
-- de clima do próprio jogo e nunca escreve aqui.
if isClient() then return end

require "NOM_World"

local TRANSITION_SECONDS = 30

local FLOATS = {
    desaturation = ClimateManager.FLOAT_DESATURATION,
    light = ClimateManager.FLOAT_GLOBAL_LIGHT_INTENSITY,
    fog = ClimateManager.FLOAT_FOG_INTENSITY,
}

local state = { nightRamp = 0, fogRamp = 0, lastMs = nil }
local applied = {} -- canal -> true enquanto a camada modded dele está ligada por nós
local tintInfo = nil

-- O jogo faz internal = lerp(interpolate, internal, modded) a cada frame, em cima
-- do próprio interno, e só volta pro vanilla uma vez por minuto de jogo. Com
-- interpolate 1 e o valor já misturado, todo frame dá o mesmo resultado.
-- Liga/desliga só na borda: a camada modded é compartilhada com outros mods.
-- ponytail: o jogo não expõe isEnableModded(); se outro mod desligar a camada
-- enquanto estamos ativos, ela só volta no próximo ciclo (peso 0 e de novo > 0).
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
    target:setModdedInterpolate(1)
end

-- FogCycle do sandbox liga um override de valor: aí o efetivo é o final, e a
-- nossa camada modded não chega na tela.
local function vanillaFog(f)
    if f:isEnableOverride() then
        return f:getFinalValue()
    end
    return f:getInternalValue()
end

local function blendColor(c, rgb, w)
    return NOM_Rules.blend(c:getRedFloat(), rgb[1], w),
        NOM_Rules.blend(c:getGreenFloat(), rgb[2], w),
        NOM_Rules.blend(c:getBlueFloat(), rgb[3], w),
        c:getAlphaFloat()
end

local lastNight, lastFog
local lastEdge = {}
local function logDebug(w)
    if not getDebug() then return end
    if w.night ~= lastNight or w.fog ~= lastFog then
        print(string.format("[NOM] night=%s fog=%s fogI=%.2f", tostring(w.night), tostring(w.fog), w.fogIntensity))
        lastNight, lastFog = w.night, w.fog
    end
    local edged = false
    for _, k in ipairs({ "nightRamp", "fogRamp" }) do
        local v = state[k]
        local edge = (v == 0 or v == 1) and v or nil
        if edge and edge ~= lastEdge[k] then
            edged = edged or lastEdge[k] ~= nil
            lastEdge[k] = edge
        end
    end
    if edged then
        print(string.format("[NOM] nightRamp=%.2f fogRamp=%.2f", state.nightRamp, state.fogRamp))
    end
end

-- Roda logo depois de updateValues(): os valores internos são o vanilla limpo.
local function onClimateTick(clim)
    local now = getTimestampMs()
    local dt = state.lastMs and (now - state.lastMs) / 1000 or 0
    state.lastMs = now

    local fogFloat = clim:getClimateFloat(FLOATS.fog)
    local enabled = NOM_Config.get("DarkEnabled")
    local w = NOM_World.update(vanillaFog(fogFloat))
    state.nightRamp = NOM_Rules.ramp(state.nightRamp, enabled and w.night, dt, TRANSITION_SECONDS)
    state.fogRamp = NOM_Rules.ramp(state.fogRamp, enabled and w.fog, dt, TRANSITION_SECONDS)
    logDebug(w)

    local look = NOM_Rules.mix(state.nightRamp, state.fogRamp, NOM_Config.get("DarkIntensity"))
    for ch, id in pairs(FLOATS) do
        local f = clim:getClimateFloat(id)
        local l = look[ch]
        apply(ch, f, l.weight, function()
            f:setModdedValue(NOM_Rules.blend(f:getInternalValue(), l.value, l.weight))
        end)
    end

    local c = clim:getClimateColor(ClimateManager.COLOR_GLOBAL_LIGHT)
    local tint = look.tint
    apply("tint", c, tint.weight, function()
        local vanilla = c:getInternalValue()
        tintInfo = tintInfo or ClimateColorInfo.new(1, 1, 1, 1, 1, 1, 1, 1)
        tintInfo:setExterior(blendColor(vanilla:getExterior(), tint.value, tint.weight))
        tintInfo:setInterior(blendColor(vanilla:getInterior(), tint.value, tint.weight))
        c:setModdedValue(tintInfo)
    end)
end

Events.OnClimateTick.Add(onClimateTick)
