-- Cliente de MP: segue a flag de névoa do servidor (server/NOM_Fog.lua). No solo
-- o servidor roda no mesmo processo e põe o estado direto.
if not isClient() then return end

require "NOM_FogState"

local MODULE = "NevoaEOutroMundo"

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE then return end
    if command == "fog" then
        NOM_FogState.set(args.on == true, args.period)
    end
end)

-- Entrou no meio da névoa: a borda já passou, pergunta o estado.
Events.OnCreatePlayer.Add(function(_, player)
    sendClientCommand(player, MODULE, "fogState", {})
end)
