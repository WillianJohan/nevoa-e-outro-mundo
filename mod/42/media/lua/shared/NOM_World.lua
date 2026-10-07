require "NOM_Rules"

-- Flags night/fog do mundo. A noite vem do relógio (NOM_World.update, no
-- OnClimateTick do servidor); a névoa é um evento do mod (server/NOM_FogEvent.lua,
-- ADR-009), ligada por NOM_World.setFog.
-- red: a névoa aberta é vermelha (sprint 0010); sempre false sem névoa.
-- calm: calmaria depois da névoa (sprint 0033), ligada por NOM_World.setCalm.
-- rising: a névoa visual subindo na fuga (sprint 0034), da sirene até a névoa abrir; só o
-- visual (NOM_ClimateLook) segue ela, a regra de jogo espera o fog. risingRed só com rising.
-- black/risingBlack: a névoa preta (sprint 0038), como red/risingRed; nunca junto do red.
NOM_World = { night = false, fog = false, red = false, black = false, calm = false, rising = false,
    risingRed = false, risingBlack = false }

-- Noite forçada pelo NOM_Debug (só em -debug, server/NOM_DebugServer.lua):
-- night = true/false; nil = do relógio. Só em memória. A névoa forçada é um
-- evento de verdade (NOM_FogEvent).
NOM_World.forced = {}

local listeners = {}

-- fn(flag, value) é chamada só na borda: flag "night", "fog", "red", "black", "calm" ou "rising".
-- As bordas "red" e "black" só saem com a névoa já aberta (debug): na borda "fog" a cor já é a nova.
function NOM_World.onChange(fn)
    listeners[#listeners + 1] = fn
end

local function notify(flag, was)
    if NOM_World[flag] == was then return end
    for _, fn in ipairs(listeners) do
        fn(flag, NOM_World[flag])
    end
end

function NOM_World.update()
    local season = getClimateManager():getSeason()
    local wasNight = NOM_World.night
    NOM_World.tod = getGameTime():getTimeOfDay()
    NOM_World.dawn = season:getDawn()
    NOM_World.dusk = season:getDusk()
    NOM_World.night = NOM_Rules.isNight(NOM_World.tod, NOM_World.dawn, NOM_World.dusk)
    if NOM_World.forced.night ~= nil then NOM_World.night = NOM_World.forced.night end
    notify("night", wasNight)
    return NOM_World
end

function NOM_World.setFog(on, red, black)
    local was, wasRed, wasBlack = NOM_World.fog, NOM_World.red, NOM_World.black
    NOM_World.fog = on == true
    NOM_World.black = NOM_World.fog and black == true
    NOM_World.red = NOM_World.fog and red == true and not NOM_World.black
    notify("fog", was)
    if NOM_World.fog == was then
        notify("red", wasRed)
        notify("black", wasBlack)
    end
end

-- Calmaria (sprint 0033): o servidor liga depois do fim da névoa e desliga no prazo.
function NOM_World.setCalm(on)
    local was = NOM_World.calm
    NOM_World.calm = on == true
    notify("calm", was)
end

-- Fuga (sprint 0034): o NOM_FogEvent liga na sirene e desliga quando a névoa abre ou a
-- sirene é cancelada.
function NOM_World.setRising(on, red, black)
    local was = NOM_World.rising
    NOM_World.rising = on == true
    NOM_World.risingBlack = NOM_World.rising and black == true
    NOM_World.risingRed = NOM_World.rising and red == true and not NOM_World.risingBlack
    notify("rising", was)
end

return NOM_World
