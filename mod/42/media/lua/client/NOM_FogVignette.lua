-- Vinheta da névoa, por jogador local (solo e cliente de MP), sem shader: liga o
-- efeito de tela do modo de busca (SearchMode: vinheta, escurecimento, desfoque,
-- dessaturação) sem ligar o forrageamento, que é outra flag (ISSearchManager.
-- isSearchMode). Spike de shader, docs/sprints/spike-shader/README.md.
--
-- O ISSearchManager:updateOverlay() vanilla faz setEnabled(pn, isSearchMode or
-- isEffectOverlay) e desligaria a vinheta, a menos que manager.isOverride seja
-- true (client/Foraging/ISSearchManager.lua:1055-1056, 1089). O mod liga
-- isOverride só durante a névoa e só enquanto o jogador não forrageia.
-- setOverrideSearchManager não é usado: ele bloqueia o forrageamento (:1102).
--
-- Com o mod do shader (NevoaEOutroMundo_Shader, flag NOM_ShaderMod, sprint 0013) o
-- SearchMode vira o canal Lua → shader em vez da vinheta (ADR-013): override do
-- SearchMode ligado (PlayerSearchMode.update sai na 1ª linha e não mexe nos floats),
-- enabled nunca ligado (VarInfo.x = 0: o screen.frag do mod sabe que os floats são
-- dele pelo marcador do gradiente) e os floats reescritos todo tick com o estado do
-- NOM_ScreenFx. A vinheta de busca some; o shader faz a dele. Um dono só do
-- SearchMode: os dois modos não brigam.
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_AtmosphereRules"
require "NOM_ScreenFxRules"
require "NOM_ScreenFxOptions"
require "NOM_ScreenFx"

NOM_FogVignette = { UPDATE_TICKS = 10 }

-- [pn] = { m = manager, override = isOverride de antes, enabled = enabled de
-- antes, intensity = intensidade aplicada, channel = true no modo do shader }
local owned = {}

local function targets(pn, intensity)
    owned[pn].intensity = intensity
    local sm = getSearchMode()
    local v = NOM_AtmosphereRules.vignette(intensity)
    local psm = sm:getSearchModeForPlayer(pn)
    psm:getBlur():setTargets(v.blur, v.blur)
    psm:getDesat():setTargets(v.desat, v.desat)
    psm:getRadius():setTargets(v.radius, v.radius)
    psm:getDarkness():setTargets(v.darkness, v.darkness)
    psm:getGradientWidth():setTargets(v.gradient, v.gradient)
end

local function take(pn, m, intensity)
    local sm = getSearchMode()
    owned[pn] = { m = m, override = m.isOverride, enabled = sm:isEnabled(pn) }
    m.isOverride = true
    targets(pn, intensity)
    sm:setEnabled(pn, true) -- o SearchMode já aproxima dos alvos devagar (fade)
end

-- Devolve o override de antes. Se ele era nosso, o enabled fica como o vanilla
-- deixaria (a fórmula do updateOverlay, :1089), sem esperar o vanilla rodar; se
-- era de outro (OnOverrideSearchManager, outro mod), volta o enabled de antes.
-- Se o isOverride não é mais o true que pusemos (ISSearchManager.handleOverride
-- mudou no meio, :1449-1456), o controle é de outro: não escreve nada.
local function release(pn)
    local o = owned[pn]
    owned[pn] = nil
    local m = o.m
    if m.isOverride ~= true then return end
    m.isOverride = o.override
    if o.override then
        getSearchMode():setEnabled(pn, o.enabled)
    else
        getSearchMode():setEnabled(pn, (m.isSearchMode or m.isEffectOverlay) == true)
    end
end

-- Canal do shader ---------------------------------------------------------------

local function channelValues(now)
    return NOM_ScreenFxRules.channel(NOM_ScreenFx.sample(now), now, NOM_ScreenFxOptions.intensity())
end

local function write(pn, c)
    local psm = getSearchMode():getSearchModeForPlayer(pn)
    psm:getBlur():setAll(c.blur)
    psm:getRadius():setAll(c.radius)
    psm:getDesat():setAll(c.desat)
    psm:getDarkness():setAll(c.darkness)
    psm:getGradientWidth():setAll(c.gradient)
end

-- Com o fade do forrageamento em andamento, o override congelaria o fade
-- (isShaderEnabled preso em true, e o shader leria o círculo vanilla): espera.
local function takeChannel(pn, m)
    if getSearchMode():getSearchModeForPlayer(pn):isShaderEnabled() then return end
    owned[pn] = { m = m, override = m.isOverride, channel = true }
    m.isOverride = true
    getSearchMode():setOverride(pn, true)
    write(pn, channelValues(getTimestampMs()))
end

-- Zera o canal antes de soltar: o fade de entrada do forrageamento parte do valor atual.
local function releaseChannel(pn)
    local o = owned[pn]
    owned[pn] = nil
    write(pn, { blur = 0, radius = 0, desat = 0, darkness = 0, gradient = 0 })
    getSearchMode():setOverride(pn, false)
    if o.m.isOverride == true then o.m.isOverride = o.override end
end

local function channelWanted(now)
    if NOM_ScreenFxOptions.intensity() <= 0 then return false end
    local c = channelValues(now)
    return c.blur > 0 or c.darkness > 0
end

local function updateChannel()
    local want = channelWanted(getTimestampMs())
    local seen = {}
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() and ISSearchManager then
            local pn = p:getPlayerNum()
            seen[pn] = true
            local m = ISSearchManager.getManager(p)
            local w = want and not m.isSearchMode
            if w and not owned[pn] then
                takeChannel(pn, m)
            elseif not w and owned[pn] then
                releaseChannel(pn)
            end
        end
    end
    for pn in pairs(owned) do
        if not seen[pn] then releaseChannel(pn) end
    end
end

-- todo tick: o pulso do grito e o fade não ficam em degraus de 10 ticks
local function writeChannels()
    local c
    for pn in pairs(owned) do
        c = c or channelValues(getTimestampMs())
        write(pn, c)
    end
end

-- Vinheta ------------------------------------------------------------------------

local function update()
    if NOM_ShaderMod then return updateChannel() end
    local intensity = NOM_Config.get("FogVignetteIntensity")
    local on = NOM_FogState.on and NOM_Config.get("FogVignette") and intensity > 0
    local seen = {}
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() and ISSearchManager then
            local pn = p:getPlayerNum()
            seen[pn] = true
            local m = ISSearchManager.getManager(p)
            local want = on and not m.isSearchMode
            if want and not owned[pn] then
                take(pn, m, intensity)
            elseif want and owned[pn].intensity ~= intensity then
                targets(pn, intensity) -- sandbox mudou no meio da névoa
            elseif not want and owned[pn] then
                release(pn)
            end
        end
    end
    for pn in pairs(owned) do
        if not seen[pn] then release(pn) end -- morreu ou saiu
    end
end

local ticks = 0
Events.OnTick.Add(function()
    if NOM_ShaderMod then writeChannels() end
    ticks = ticks + 1
    if ticks < NOM_FogVignette.UPDATE_TICKS then return end
    ticks = 0
    update()
end)

return NOM_FogVignette
