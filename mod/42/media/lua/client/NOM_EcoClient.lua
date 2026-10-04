-- Cliente de MP: apaga o Eco local que o servidor já tirou do mundo. O servidor
-- não manda o aviso de remoção de zumbi pra Lua de mod (ver server/NOM_Eco.lua).
-- Não decide nada: só limpa o que o servidor mandou limpar.
if not isClient() then return end

local function onServerCommand(module, command, args)
    if module ~= "NevoaEOutroMundo" or command ~= "ecoGone" then return end
    local gone = {}
    for _, id in pairs(args.ids) do gone[id] = true end
    local list = getCell():getZombieList()
    for i = list:size() - 1, 0, -1 do
        local z = list:get(i)
        if gone[z:getOnlineID()] then
            z:removeFromWorld()
            z:removeFromSquare()
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)
