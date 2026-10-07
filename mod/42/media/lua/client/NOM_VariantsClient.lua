-- Cliente de MP: o dono do zumbi roda a IA (ADR-005), então é aqui que o
-- Estalador fica cego, estala, o Corredor é visto pegando um jogador de alvo e a
-- Carpideira fica parada e soluça. Quem decide os gritos é o servidor
-- (server/NOM_Variants.lua): o cliente só avisa e aplica o que ele decidiu.
if not isClient() then return end

require "NOM_VariantAI"
require "NOM_VariantRules"
require "NOM_Carpideira"
require "NOM_Wander"

local MODULE = "NevoaEOutroMundo"

NOM_VariantAI.install(function(z)
    local id = z:getOnlineID()
    if id == -1 then return end -- sem ID de rede: o servidor não acharia
    sendClientCommand(MODULE, "corredorSaw", { id = id })
end)

-- Com o jogador na frente: o servidor confere a distância dele (tela dividida).
NOM_Carpideira.install(function(z, p, why)
    local id = z:getOnlineID()
    if id == -1 then return end
    sendClientCommand(p, MODULE, "carpideiraWoke", { id = id, why = why })
end)

-- O servidor decidiu o grito: { pid, id = onlineID dela, pl = onlineID de quem a
-- acordou }. A marca vale por ID (outro objeto com o mesmo ID, ou ela voltando do
-- virtual, fica furioso); o grito e o spot vão no zumbi com esse onlineID.
-- getPlayerByOnlineID: client/ServerCommands.lua:10 (nil se não estiver carregado).
local function screamed(args)
    NOM_Carpideira.screamed[args.pid] = true
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if NOM_VariantRules.baseId(z:getPersistentOutfitID()) == args.pid and z:getOnlineID() == args.id then
            NOM_Carpideira.scream(z, type(args.pl) == "number" and getPlayerByOnlineID(args.pl) or nil)
            return
        end
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE or type(args) ~= "table" then return end
    if command == "carpideiraScream" and type(args.pid) == "number" then
        screamed(args)
    elseif command == "carpideiraList" and type(args.pids) == "table" then -- entrou no meio da névoa
        for _, pid in pairs(args.pids) do NOM_Carpideira.screamed[pid] = true end
    elseif command == "wander" and type(args.seed) == "number" then
        NOM_Wander.wave(args.seed) -- o servidor decidiu a onda; os zumbis daqui andam (sprint 0036)
    end
end)
