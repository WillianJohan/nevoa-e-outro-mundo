-- Cliente de MP: o dono do zumbi é quem simula a IA (NetworkZombieManager.updateAuth),
-- então os stats noturnos são aplicados aqui (ADR-005). Quem decide se é noite é o
-- servidor (server/NOM_Night.lua); este arquivo só segue a flag.
if not isClient() then return end

require "NOM_NightStats"

local MODULE = "NevoaEOutroMundo"

NOM_NightStats.install()

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE then return end
    if command == "night" then
        NOM_NightStats.setNight(args.on == true, args.night)
    elseif command == "calm" then
        NOM_NightStats.setCalm(args.on == true)
    end
end)

-- Entrou no meio da noite (ou da calmaria): a borda já passou, pergunta o estado.
Events.OnCreatePlayer.Add(function(_, player)
    sendClientCommand(player, MODULE, "nightState", {})
end)
