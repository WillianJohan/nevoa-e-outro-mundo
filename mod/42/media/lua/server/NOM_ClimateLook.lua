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

-- COLOR_NEW_FOG: o ClimateManager não tem o campo estático (só COLOR_GLOBAL_LIGHT
-- e COLOR_MAX); o id 1 vem do setup() 312–321 (chamado pelo <init> no 525) e de
-- client/ISUI/AdminPanel/ISAdmPanelClimate.lua:249.
local COLOR_NEW_FOG = 1

-- eventRamp: densidade da névoa do evento (0..1 de NOM_FogEventRules.DENSITY), não
-- depende de DarkEnabled: a névoa é o evento, o look é por cima (ADR-009).
-- redRamp: névoa vermelha (sprint 0010, ADR-010); a cor da névoa é do evento (não
-- depende de DarkEnabled), a luz vermelha é do look.
local state = { nightRamp = 0, fogRamp = 0, eventRamp = 0, redRamp = 0 }
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

-- Cor da névoa vermelha (ADR-010). O interno do COLOR_NEW_FOG nunca volta sozinho
-- (nada no ClimateManager escreve nele depois do setup()), e o calculate faz o lerp
-- da camada modded no PRÓPRIO interno (ClimateColor.calculate 25–60): com
-- interpolate 1 o interno vira o escrito. Desligar a camada direto deixaria a névoa
-- vermelha até recarregar; então, no fim, um minuto escrevendo o vanilla e só
-- depois desliga. A tempestade religa o override da cor todo minuto
-- (WeatherPeriod.updateCurrentStage 909–957): na vermelha, o mod desliga. A rampa
-- sai da cor que estava na tela quando a vermelha começou (getFinalValue: a do
-- minuto anterior, com o tom da tempestade se havia), senão desligar o override
-- pularia do marrom pro branco no primeiro minuto. A saída volta pra essa mesma
-- cor e, no minuto do vanilla, o override da tempestade (se ainda houver) volta.
local fogColorInfo
local fogBase -- { ext = {r,g,b,a}, int = {r,g,b,a} }

local function rgbaOf(col)
    return { col:getRedFloat(), col:getGreenFloat(), col:getBlueFloat(), col:getAlphaFloat() }
end

local function paintFogColor(c)
    local r = state.redRamp
    if r <= 0 then
        if applied.fogColor == "vanilla" then
            c:setEnableModded(false)
            applied.fogColor = nil
        end
        if not applied.fogColor then return end
    end
    if not applied.fogColor then
        local f = c:getFinalValue()
        fogBase = { ext = rgbaOf(f:getExterior()), int = rgbaOf(f:getInterior()) }
        c:setEnableModded(true)
    end
    if r > 0 and c:isEnableOverride() then c:setEnableOverride(false) end
    local red = NOM_Rules.RED_FOG_COLOR
    local x, y = {}, {}
    for i = 1, 4 do
        -- r = 0 aqui é o minuto do vanilla: o interno volta ao do jogo
        x[i] = r > 0 and NOM_Rules.blend(fogBase.ext[i], red[i], r) or NOM_Rules.FOG_COLOR[i]
        y[i] = r > 0 and NOM_Rules.blend(fogBase.int[i], red[i], r) or NOM_Rules.FOG_COLOR[i]
    end
    fogColorInfo = fogColorInfo or ClimateColorInfo.new(1, 1, 1, 1, 1, 1, 1, 1)
    fogColorInfo:setExterior(x[1], x[2], x[3], x[4])
    fogColorInfo:setInterior(y[1], y[2], y[3], y[4])
    c:setModdedValue(fogColorInfo)
    c:setModdedInterpolate(1)
    applied.fogColor = r > 0 or "vanilla"
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
local lastEdge = { nightRamp = 0, fogRamp = 0, eventRamp = 0, redRamp = 0 }
-- Devolve true quando é hora do bloco canal a canal (logChannels): borda da rampa,
-- ou hora de jogo nova à noite.
local function logDebug(w)
    if not getDebug() then return false end
    if w.night ~= lastNight or w.fog ~= lastFog then
        print(string.format("[NOM] night=%s fog=%s", tostring(w.night), tostring(w.fog)))
        lastNight, lastFog = w.night, w.fog
    end
    local edged = false
    for _, k in ipairs({ "nightRamp", "fogRamp", "eventRamp", "redRamp" }) do
        local v = state[k]
        local edge = (v == 0 or v == 1) and v or nil
        if edge and edge ~= lastEdge[k] then
            edged = true
            lastEdge[k] = edge
        end
    end
    if edged then
        print(string.format("[NOM] nightRamp=%.2f fogRamp=%.2f nevoa=%.2f vermelha=%.2f", state.nightRamp, state.fogRamp,
            NOM_FogEventRules.DENSITY * state.eventRamp, state.redRamp))
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
    -- cor da névoa (COLOR_NEW_FOG): vanilla 0.90,0.90,0.95,1.00; vermelha = RED_FOG_COLOR
    print(string.format("[NOM] clima corNevoa final=%s vermelha=%.2f",
        rgba(clim:getClimateColor(COLOR_NEW_FOG):getFinalValue():getExterior()), state.redRamp))
end

-- Roda logo depois de updateValues(): os valores internos são o vanilla limpo.
local function onClimateTick(clim)
    local enabled = NOM_Config.get("DarkEnabled")
    local w = NOM_World.update()
    -- A flag de névoa é a de agora: o evento abre no OnTick (fim da sirene) e o
    -- fim/carga acertam no OnClimateTick do NOM_FogEvent, que roda depois deste
    -- (ordem alfabética de carga). A rampa começa até 1 minuto de jogo depois da
    -- borda; com 20 minutos de rampa não se vê.
    -- A névoa sobe já na fuga (rising, sprint 0034): os 30 s reais (~12 minutos de jogo no
    -- dia padrão) deixam ela pelo meio quando os bichos soltam, e a rampa segue sem degrau.
    local fog = w.fog or w.rising
    local red = (w.fog and w.red) or (w.rising and w.risingRed)
    state.eventRamp = NOM_Rules.ramp(state.eventRamp, fog, TRANSITION_MINUTES)
    state.redRamp = NOM_Rules.ramp(state.redRamp, red, TRANSITION_MINUTES)
    state.nightRamp = NOM_Rules.ramp(state.nightRamp, enabled and w.night, TRANSITION_MINUTES)
    state.fogRamp = NOM_Rules.ramp(state.fogRamp, enabled and fog, TRANSITION_MINUTES)
    local dump = logDebug(w)
    ownFog(clim:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY))
    paintFogColor(clim:getClimateColor(COLOR_NEW_FOG))

    local look = NOM_Rules.mix(state.nightRamp, state.fogRamp, NOM_Config.get("DarkIntensity"), state.redRamp)
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
