-- Sonar do Estalador (sprint 0037), o lado de quem toca, desenha e aplica. Quem decide é o
-- server/NOM_SonarServer.lua: no solo ele chama ring/found direto; no dedicado manda
-- "sonar" { x, y, z, id } e "sonarFound" { id, pl } a todos, e o cliente passa por command
-- (client/NOM_VariantsClient.lua), que confere a mensagem antes (NOM_SonarRules.valid).
require "NOM_SonarRules"
require "NOM_VariantAI"

NOM_Sonar = { CLICK_SOUND = "NOM_EstaladorClick" } -- media/scripts/NOM_sounds.txt
local R = NOM_SonarRules

-- fn(x, y, z) a cada anel que este processo recebe (o desenho, client/NOM_SonarFx.lua). Em
-- pcall: um erro de quem desenha não para o estalo (no solo quem chama é o servidor).
local listeners = {}
function NOM_Sonar.onRing(fn)
    listeners[#listeners + 1] = fn
end

-- O estalo no ponto e o anel. Som local num emitter do pool, sem pacote (pz-api-notes §22):
-- cada cliente toca o seu, como o estalo de antes (playSoundLocal no zumbi); o
-- playSoundImpl(nome, false, nil) cai na versão do IsoObject com nil (a do square dá NPE).
function NOM_Sonar.ring(x, y, z)
    getWorld():getFreeEmitter(x, y, z):playSoundImpl(NOM_Sonar.CLICK_SOUND, false, nil)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, x, y, z)
        if not ok and getDebug() then print("[NOM] sonar: erro de quem desenha: " .. tostring(err)) end
    end
end

-- O anel achou o jogador p: o dono do Estalador z aplica (NOM_VariantAI.sonarFound).
function NOM_Sonar.found(z, p)
    return NOM_VariantAI.sonarFound(z, p)
end

-- Estalador local com esse onlineID (a mensagem vai a todos; só o dono aplica).
local function localById(id)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then
            if z:isLocal() then return z end
            return nil
        end
    end
    return nil
end

-- Comando do servidor no cliente de MP. getPlayerByOnlineID: client/ServerCommands.lua:10
-- (nil se este cliente não conhece o jogador).
function NOM_Sonar.command(command, args)
    if command == "sonar" then
        local m = R.valid(args)
        if m then NOM_Sonar.ring(m.x, m.y, m.z) end
    elseif command == "sonarFound" then
        local m = R.validFound(args)
        if not m then return end
        local p = getPlayerByOnlineID(m.pl)
        if p == nil then return end
        local z = localById(m.id)
        if z then NOM_Sonar.found(z, p) end
    end
end

return NOM_Sonar
