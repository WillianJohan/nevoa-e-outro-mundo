-- Cliente de MP: segue a flag de névoa do servidor (server/NOM_Fog.lua), toca a
-- sirene do evento (server/NOM_FogEvent.lua) e faz a
-- parte do Sem-rosto que é do cliente (ADR-007): ver (luz e visão são calculadas
-- aqui) e, se for dono do zumbi, mover. Quem decide é o servidor. No solo o
-- servidor roda no mesmo processo e faz tudo direto.
if not isClient() then return end

require "NOM_FogState"
require "NOM_SemRosto"
require "NOM_Siren"
require "NOM_SirenFreeze"
require "NOM_FogEventRules"

local MODULE = "NevoaEOutroMundo"

-- Sirene: o cliente dono congela os zumbis dele (shared/NOM_SirenFreeze, ADR-005).
NOM_SirenFreeze.install()

-- Avisa o servidor pelo ID de rede (-1 = sem ID: o servidor não acharia). Se a
-- cópia daqui é remota (o dono é outro cliente), ela vai direto pro destino: o
-- dono move quando o servidor mandar, e os pacotes dele trazem a mesma posição,
-- então ninguém desliza na tela de quem viu. Se o servidor recusar, os pacotes
-- do dono trazem a cópia de volta. A cópia do dono espera o servidor: posição
-- do dono vale como verdade (applyZombie) e não pode pular sem conferência.
NOM_SemRosto.install(function(z, x, y, zz)
    local id = z:getOnlineID()
    if id == -1 then return end
    sendClientCommand(MODULE, "semRostoSeen", { id = id, x = x, y = y, z = zz })
    if z:isRemoteZombie() then NOM_SemRosto.move(z, x, y, zz) end
end)

-- Só o dono move: o servidor aceita a posição do dono (NetworkZombiePacker.parseZombie
-- descarta pacote de quem não é dono; applyZombie aplica realX/realY), e as cópias
-- remotas andam até ela (NetworkZombieAI.parse → targetX/targetY). Antes, o dono
-- confere que nenhum jogador dele vê o destino (o servidor não sabe a vista de
-- ninguém); se algum vê, não move, e o fallback do servidor cuida se for preciso.
local function moveIfOwner(args)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getOnlineID() == args.id then
            if z:isRemoteZombie() then return end
            local sq = getCell():getGridSquare(args.x, args.y, args.z)
            if sq and NOM_SemRosto.hidden(sq) then NOM_SemRosto.move(z, args.x, args.y, args.z) end
            return
        end
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE then return end
    if command == "fog" then
        NOM_FogState.set(args.on == true, args.period, args.red == true)
        -- a névoa abre: a fuga acabou (o servidor não manda sirenStop nesse caso). O fog off
        -- não desce a subida: quem entra na fuga recebe fog (off) e depois siren.
        if args.on == true then
            NOM_FogState.setRising(false)
            NOM_SirenFreeze.stop()
        end
    elseif command == "siren" then -- evento de névoa: começa a fuga de 30 s (NOM_FogEvent)
        local red = type(args) == "table" and args.red == true
        NOM_Siren.play(red)
        NOM_FogState.setRising(true, red)
        NOM_SirenFreeze.start(type(args) == "table" and args.dir or 0, NOM_FogEventRules.GRACE_MS)
    elseif command == "sirenStop" then -- sirene cancelada (NOM_FogEvent.stop)
        NOM_FogState.setRising(false)
        NOM_SirenFreeze.stop()
    elseif command == "semRostoMove" and args.id ~= -1 then
        -- o tile fica reservado aqui também (sprint 0017): o próximo Sem-rosto que este
        -- cliente vir vai pra outro, mesmo que o sumiço tenha sido visto por outro cliente
        NOM_SemRosto.reserve(args.x, args.y, args.z)
        moveIfOwner(args)
    end
end)

-- Entrou no meio da névoa: a borda já passou, pergunta o estado.
Events.OnCreatePlayer.Add(function(_, player)
    sendClientCommand(player, MODULE, "fogState", {})
end)
