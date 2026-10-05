-- Visual dark aplicado no clima, só do lado do servidor (no solo o servidor
-- roda no mesmo processo). Cliente de MP recebe o resultado pela sincronização
-- de clima do próprio jogo e nunca escreve aqui.
if isClient() then return end

require "NOM_World"
require "NOM_Config"
require "NOM_FogEventRules"

-- Em minutos de jogo: cobre pelo menos 2 pacotes de clima do MP (1 a cada 10).
local TRANSITION_MINUTES = 20

-- FLOAT_AMBIENT: client/DebugUIs/DebugMenu/Climate/PopupColorEdit.lua:64. Por que
-- estes canais e não a "intensidade da luz global": NOM_Rules.LOOKS.
local FLOATS = {
    desaturation = ClimateManager.FLOAT_DESATURATION,
    ambient = ClimateManager.FLOAT_AMBIENT,
}

-- eventRamp: densidade da névoa do evento (0..1 de NOM_FogEventRules.DENSITY), não
-- depende de DarkEnabled: a névoa é o evento, o look é por cima (ADR-009).
local state = { nightRamp = 0, fogRamp = 0, eventRamp = 0 }
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

-- O mod é dono do canal de névoa (ADR-009): fora do evento 0, no evento a
-- densidade com rampa, sempre com valor absoluto e interpolate 1. Quem passa por
-- cima do interno é o override, e o jogo religa ele todo minuto ANTES deste
-- evento (ClimateManager.update 363–402: updateSandboxOverrides, updateValues,
-- WeatherPeriod.update, depois OnClimateTick, depois calculate):
-- * sandbox FogCycle "sem névoa"/"névoa eterna" e ClimateCycle "nevasca eterna":
--   override de valor (o final ignora o interno), ligado na troca e, na névoa
--   eterna, de novo a cada hora por setOverride (updateSandboxOverrides 555–672);
-- * WeatherPeriod.updateCurrentStage: setOverride(0, t) ou setOverride(névoa do
--   estágio, t) a cada minuto de chuva/tempestade (895–906, 1259–1270).
-- setEnableOverride(false) só zera isOverride (ClimateFloat.setEnableOverride 0–5)
-- e não vai pro save (ClimateManager.save grava só o admin). Admin passa por cima
-- de tudo (calculate 0–21) e fica: é escolha explícita de quem administra.
local function ownFog(f)
    if not applied.fog then
        f:setEnableModded(true)
        applied.fog = true
    end
    if f:isEnableOverride() then f:setEnableOverride(false) end
    f:setModdedValue(NOM_FogEventRules.DENSITY * state.eventRamp)
    f:setModdedInterpolate(1)
end

-- rgba[4] = alfa: a força da cor no render (blendIntensity), é o que escurece.
local function blendColor(c, rgba, w)
    return NOM_Rules.blend(c:getRedFloat(), rgba[1], w),
        NOM_Rules.blend(c:getGreenFloat(), rgba[2], w),
        NOM_Rules.blend(c:getBlueFloat(), rgba[3], w),
        NOM_Rules.blend(c:getAlphaFloat(), rgba[4], w)
end

local lastNight, lastFog, lastHour
-- As rampas nascem em 0: save carregado de noite também loga a borda do 1.
local lastEdge = { nightRamp = 0, fogRamp = 0, eventRamp = 0 }
-- Devolve true quando é hora do bloco canal a canal (logChannels): borda da rampa,
-- ou hora de jogo nova à noite.
local function logDebug(w)
    if not getDebug() then return false end
    if w.night ~= lastNight or w.fog ~= lastFog then
        print(string.format("[NOM] night=%s fog=%s", tostring(w.night), tostring(w.fog)))
        lastNight, lastFog = w.night, w.fog
    end
    local edged = false
    for _, k in ipairs({ "nightRamp", "fogRamp", "eventRamp" }) do
        local v = state[k]
        local edge = (v == 0 or v == 1) and v or nil
        if edge and edge ~= lastEdge[k] then
            edged = true
            lastEdge[k] = edge
        end
    end
    if edged then
        print(string.format("[NOM] nightRamp=%.2f fogRamp=%.2f nevoa=%.2f", state.nightRamp, state.fogRamp,
            NOM_FogEventRules.DENSITY * state.eventRamp))
    end
    local hour = math.floor(w.tod)
    local hourly = w.night and lastHour ~= nil and hour ~= lastHour
    lastHour = hour
    return edged or hourly
end

local function rgba(c)
    return string.format("%.2f,%.2f,%.2f,%.2f", c:getRedFloat(), c:getGreenFloat(), c:getBlueFloat(), c:getAlphaFloat())
end

-- Diagnóstico (só -debug): por canal, o vanilla (interno limpo, logo depois do
-- updateValues), o valor escrito na camada modded e o getFinalValue(). O final é
-- o do frame anterior, ou seja o do minuto passado: com a rampa parada, tem que
-- bater com o escrito. Se não bate, outra camada (admin, override de clima, outro
-- mod) está por cima. luz = multiplicador da luz do céu por canal (NOM_Rules.skyMod).
local function logChannels(clim, look)
    for _, ch in ipairs({ "desaturation", "ambient" }) do
        local f, l = clim:getClimateFloat(FLOATS[ch]), look[ch]
        local vanilla = f:getInternalValue()
        local written = l.weight > 0 and string.format("%.2f", NOM_Rules.blend(vanilla, l.value, l.weight)) or "-"
        print(string.format("[NOM] clima %s vanilla=%.2f escrito=%s final=%.2f peso=%.2f",
            ch, vanilla, written, f:getFinalValue(), l.weight))
    end
    -- névoa: vanilla = a natural que o jogo calculou (e que o mod apaga)
    local f = clim:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY)
    print(string.format("[NOM] clima fog vanilla=%.2f escrito=%.2f final=%.2f",
        f:getInternalValue(), NOM_FogEventRules.DENSITY * state.eventRamp, f:getFinalValue()))
    local c, t = clim:getClimateColor(ClimateManager.COLOR_GLOBAL_LIGHT), look.tint
    local final = c:getFinalValue():getExterior()
    local mr, mg, mb = NOM_Rules.skyMod(final:getRedFloat(), final:getGreenFloat(), final:getBlueFloat(), final:getAlphaFloat())
    print(string.format("[NOM] clima tint vanilla=%s escrito=%s final=%s luz=%.2f,%.2f,%.2f peso=%.2f",
        rgba(c:getInternalValue():getExterior()), t.weight > 0 and tintInfo and rgba(tintInfo:getExterior()) or "-",
        rgba(final), mr, mg, mb, t.weight))
end

-- Roda logo depois de updateValues(): os valores internos são o vanilla limpo.
local function onClimateTick(clim)
    local enabled = NOM_Config.get("DarkEnabled")
    local w = NOM_World.update()
    state.eventRamp = NOM_Rules.ramp(state.eventRamp, w.fog, TRANSITION_MINUTES)
    state.nightRamp = NOM_Rules.ramp(state.nightRamp, enabled and w.night, TRANSITION_MINUTES)
    state.fogRamp = NOM_Rules.ramp(state.fogRamp, enabled and w.fog, TRANSITION_MINUTES)
    local dump = logDebug(w)
    ownFog(clim:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY))

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
    if dump then logChannels(clim, look) end
end

Events.OnClimateTick.Add(onClimateTick)
