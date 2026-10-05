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
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_AtmosphereRules"

NOM_FogVignette = { UPDATE_TICKS = 10 }

-- [pn] = { m = manager, override = isOverride de antes, enabled = enabled de
-- antes, intensity = intensidade aplicada }
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

local function update()
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
    ticks = ticks + 1
    if ticks < NOM_FogVignette.UPDATE_TICKS then return end
    ticks = 0
    update()
end)

return NOM_FogVignette
