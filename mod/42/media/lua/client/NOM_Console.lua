-- Atalhos curtos do debug (sprint 0020): a tabela global NOM, só no cliente com o jogo
-- em -debug (a mesma porta do NOM_Debug). O autocomplete do console do debug é Java
-- (UIDebugConsole.InitSuggestionEngine lista só os métodos Java do GlobalObject), então
-- função Lua nunca aparece lá: NOM.help() lista tudo. Toggle chamado sem argumento
-- inverte o estado atual. O que mexe no mundo vai pro servidor pelo NOM_Debug
-- (server/NOM_DebugServer.lua confere -debug e a permissão); god, noclip e invisível são
-- do jogador local, como no painel de admin do vanilla. NOM_Debug.* continuam valendo.
if isServer() or not getDebug() then return end

require "NOM_Debug"
require "NOM_DebugRules"
require "NOM_Math"
require "NOM_NightStats"

NOM = {}

local SPAWN_AHEAD = 3 -- tiles na frente do jogador

local function player() return getSpecificPlayer(0) end

-- on nil: inverte. skip: com a névoa nova, sem esperar a sirene.
-- Sem argumento quem decide é o servidor (sabe se a sirene está contando).
function NOM.fog(on, skip)
    if on == nil then return NOM_Debug.send({ op = "fog", toggle = true }) end
    NOM_Debug.fog(on, skip)
end

-- Sem argumento quem decide é o servidor (sabe da sirene vermelha contando).
function NOM.redFog(on)
    if on == nil then return NOM_Debug.send({ op = "redFog", toggle = true }) end
    NOM_Debug.redFog(on)
end

-- Noite forçada (true) ou dia forçado (false); NOM_Debug.night() devolve pro relógio.
function NOM.night(on)
    if on == nil then on = not NOM_NightStats.night end
    NOM_Debug.night(on)
end

-- Hora do relógio do jogo; 25 vira 1, -1 vira 23. Sempre pra frente: hora que já
-- passou hoje é a de amanhã (server/NOM_DebugServer.lua).
function NOM.time(hour)
    if type(hour) ~= "number" or hour ~= hour or hour == math.huge or hour == -math.huge then
        print("[NOM] debug uso: NOM.time(hora), ex.: NOM.time(22)")
        return
    end
    NOM_Debug.send({ op = "time", hour = NOM_Math.mod(hour, 24) })
end

-- n zumbis (1 a 50) com o outfit (nil: sorteado) espalhados em 3×3 a 3 tiles na frente do jogador.
function NOM.spawn(n, outfit)
    local p = player()
    if not p then return end
    local count = NOM_DebugRules.clampSpawn(n == nil and 1 or n)
    if not count then
        print("[NOM] debug uso: NOM.spawn(quantos, outfit), ex.: NOM.spawn(5)")
        return
    end
    local a = p:getForwardDirection():getDirection() -- radianos (FishingRod.lua:286)
    NOM_Debug.send({ op = "spawn", n = count, outfit = outfit,
        x = p:getX() + math.cos(a) * SPAWN_AHEAD, y = p:getY() + math.sin(a) * SPAWN_AHEAD, z = p:getZ() })
end

function NOM.variant(kind) NOM_Debug.variant(kind) end
function NOM.eco() NOM_Debug.spawnEco() end
function NOM.status() NOM_Debug.status() end

-- Truques do jogador local (ISAdminPowerUI.lua:31-53): muda e manda pro servidor
-- (sendPlayerExtraInfo, :403); no MP o servidor aplica as regras dele.
local function cheat(name, getter, setter)
    return function(on)
        local p = player()
        if not p then return end
        if on == nil then on = not p[getter](p) end
        p[setter](p, on == true)
        sendPlayerExtraInfo(p)
        print("[NOM] debug " .. name .. "=" .. tostring(on == true))
    end
end

NOM.god = cheat("god", "isGodMod", "setGodMod")
NOM.noclip = cheat("noclip", "isNoClip", "setNoClip")
NOM.invisible = cheat("invisible", "isInvisible", "setInvisible")

function NOM.panel()
    if NOM_DebugPanel then NOM_DebugPanel.toggle() end
end

NOM.HELP = {
    { "NOM.fog(on, skip)", "névoa: true sirene e névoa em 30 s, (true, true) já, false termina; sem argumento inverte (e cancela a sirene)" },
    { "NOM.redFog(on)", "névoa vermelha: true força (com névoa aberta vira na hora), false desfaz; sem argumento inverte" },
    { "NOM.night(on)", "noite forçada (true) ou dia forçado (false); sem argumento inverte; NOM_Debug.night() volta pro relógio" },
    { "NOM.time(hora)", "muda a hora do relógio do jogo, sempre pra frente (hora que já passou é a de amanhã), ex.: NOM.time(22)" },
    { "NOM.spawn(n, outfit)", "n zumbis (até 50) espalhados 3 tiles na sua frente; outfit opcional, ex.: NOM.spawn(5, \"Police\")" },
    { "NOM.variant(tipo)", "zumbi mais perto vira \"estalador\", \"corredor\", \"semrosto\" ou \"carpideira\" (só na névoa); sem tipo desfaz" },
    { "NOM.eco()", "um Eco nos seus pés (só à noite)" },
    { "NOM.god(on)", "modo deus; sem argumento inverte" },
    { "NOM.noclip(on)", "atravessa paredes; sem argumento inverte" },
    { "NOM.invisible(on)", "zumbis não te veem; sem argumento inverte" },
    { "NOM.status()", "estado do mod, local e do servidor" },
    { "NOM.panel()", "abre ou fecha o painel de debug (tecla nas opções do mod, padrão Insert)" },
    { "NOM.help()", "esta lista" },
}

function NOM.help()
    for _, h in ipairs(NOM.HELP) do print("[NOM] " .. h[1] .. " - " .. h[2]) end
end

return NOM
