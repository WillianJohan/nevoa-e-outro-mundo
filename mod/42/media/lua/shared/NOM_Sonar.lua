-- Sonar do Estalador (sprint 0037), o lado de quem toca, desenha e aplica. Quem decide é o
-- server/NOM_SonarServer.lua: no solo ele chama ring/found direto; no dedicado manda
-- "sonar" { x, y, z, id } a quem está perto e "sonarFound" { id, pl } a todos, e o cliente
-- passa por command (client/NOM_VariantsClient.lua), que confere a mensagem antes
-- (NOM_SonarRules.valid) e descarta anel longe de todo jogador local.
require "NOM_SonarRules"
require "NOM_VariantAI"

NOM_Sonar = { CLICK_SOUND = "NOM_EstaladorClick" } -- media/scripts/NOM_sounds.txt (tac curto)
local R = NOM_SonarRules

-- fn(x, y, z, burst) a cada anel que este processo recebe (o desenho, client/NOM_SonarFx.lua).
-- Em pcall: um erro de quem desenha não para o estalo (no solo quem chama é o servidor).
local listeners = {}
function NOM_Sonar.onRing(fn)
    listeners[#listeners + 1] = fn
end

-- Tac no ponto (um clique). O burst agenda vários via client/NOM_SonarFx.lua.
function NOM_Sonar.playClick(x, y, z)
    getWorld():getFreeEmitter(x, y, z):playSoundImpl(NOM_Sonar.CLICK_SOUND, false, nil)
end

-- O estalo no ponto e o anel. Toca o primeiro tac já (beat 0); os demais e os ripples ficam
-- com o Fx no ritmo da variação `burst` (1=A, 2=B, 3=C). Som local sem pacote (pz-api-notes §22).
function NOM_Sonar.ring(x, y, z, burst)
    burst = R.clampBurst(burst or 1)
    NOM_Sonar.playClick(x, y, z)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, x, y, z, burst)
        if not ok and getDebug() then print("[NOM] sonar: erro de quem desenha: " .. tostring(err)) end
    end
end

-- O anel achou o jogador p: o dono do Estalador z aplica (NOM_VariantAI.sonarFound).
function NOM_Sonar.found(z, p)
    return NOM_VariantAI.sonarFound(z, p)
end

-- Estalador local com esse onlineID (a mensagem vai a todos; só o dono aplica). pid: o
-- persistentOutfitID que o servidor viu (o onlineID se reaproveita pra outro zumbi).
local function localById(id, pid)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == id then
            if z:isLocal() and (pid == nil or z:getPersistentOutfitID() == pid) then return z end
            return nil
        end
    end
    return nil
end

-- Algum jogador local (getNumActivePlayers/getSpecificPlayer, como o NOM_VariantAI) a até
-- SEND_RANGE do anel. O servidor já manda só pra quem está perto; isto segura o resto.
local function heard(x, y)
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p ~= nil and R.hears(x, y, p:getX(), p:getY()) then return true end
    end
    return false
end

-- Comando do servidor no cliente de MP. getPlayerByOnlineID: client/ServerCommands.lua:10
-- (nil se este cliente não conhece o jogador).
function NOM_Sonar.command(command, args)
    if command == "sonar" then
        local m = R.valid(args)
        if m and heard(m.x, m.y) then NOM_Sonar.ring(m.x, m.y, m.z, m.b) end
    elseif command == "sonarFound" then
        local m = R.validFound(args)
        if not m then return end
        local p = getPlayerByOnlineID(m.pl)
        if p == nil then return end
        local z = localById(m.id, m.pid)
        if z then NOM_Sonar.found(z, p) end
    end
end

return NOM_Sonar
