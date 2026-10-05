-- Cliente de MP: o dono do zumbi é quem simula a IA (NetworkZombieManager.updateAuth),
-- então os stats noturnos são aplicados aqui (ADR-005). Quem decide se é noite é o
-- servidor (server/NOM_Night.lua); este arquivo só segue a flag.
if not isClient() then return end

require "NOM_NightStats"

local MODULE = "NevoaEOutroMundo"

NOM_NightStats.install()

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE or command ~= "night" then return end
    NOM_NightStats.setNight(args.on == true, args.night)
end)

-- Entrou no meio da noite: a borda já passou, pergunta o estado.
Events.OnCreatePlayer.Add(function(_, player)
    sendClientCommand(player, MODULE, "nightState", {})
end)
