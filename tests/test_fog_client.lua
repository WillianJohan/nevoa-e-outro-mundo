-- client/NOM_FogClient.lua: no MP a flag de névoa vem do servidor.
local W = dofile("tests/fog_world.lua")
require "NOM_FogEventRules"
local FILE = "mod/42/media/lua/client/NOM_FogClient.lua"

local function setup(opts)
    opts = opts or {}
    if opts.client == nil then opts.client = true end
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SemRosto", "NOM_Siren", "NOM_SirenFreeze" })
    dofile(FILE)
    function G.server(command, args) G.fire("OnServerCommand", "NevoaEOutroMundo", command, args) end
    return G
end

return {
    fog_client_inert_outside_mp = function()
        local G = setup({ client = false })
        assert(next(G.handlers) == nil, "solo/servidor registrou o cliente")
    end,
    fog_client_follows_server = function()
        local G = setup()
        G.server("fog", { on = true, period = 3 })
        assert(NOM_FogState.on == true and NOM_FogState.period == 3)
        G.fire("OnServerCommand", "OutroMod", "fog", { on = false })
        assert(NOM_FogState.on == true)
        G.server("fog", { on = false, period = 3 })
        assert(NOM_FogState.on == false)
    end,
    -- sirene do evento de névoa (comando do servidor): toca local, volume cheio, sem pacote
    fog_client_plays_siren = function()
        local G = setup()
        G.server("siren", {})
        assert(G.played("NOM_Siren") == 0, "tocou sem jogador")
        G.player({ x = 0, y = 0 })
        G.server("siren", {})
        assert(G.played("NOM_Siren") == 1 and G.playing("NOM_Siren")[1].volume == 1)
        G.fire("OnServerCommand", "OutroMod", "siren", {})
        assert(G.played("NOM_Siren") == 1)
    end,
    -- sprint 0033: a sirene congela os zumbis que este cliente simula (dono), virados pra dir
    fog_client_siren_freezes_owned_zombies = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local mine = G.zombie({ x = 10, y = 10, onlineID = 5 })
        local remote = G.zombie({ x = 20, y = 20, onlineID = 6, remote = true })
        G.server("siren", { red = false, dir = 90 })
        G.tick(1)
        assert(NOM_SirenFreeze.active and mine.useless == true, "dono não congelou")
        assert(math.abs(mine.faced.y - (mine.y + NOM_SirenFreeze.FAR)) < 1e-6, "dir 90° = +y")
        assert(not remote.useless, "cópia remota é do outro cliente")
        G.fire("OnServerCommand", "OutroMod", "sirenStop", {})
        assert(mine.useless == true, "comando de outro módulo soltou")
        G.server("sirenStop", {})
        assert(mine.useless == false and not NOM_SirenFreeze.active, "sirenStop não soltou")
    end,
    fog_client_fog_on_releases_freeze = function()
        local G = setup()
        local mine = G.zombie({ x = 10, y = 10, onlineID = 5 })
        G.server("siren", { red = true, dir = 0 })
        G.tick(1)
        assert(mine.useless == true)
        G.server("fog", { on = false, period = 1 })
        assert(mine.useless == true, "fog off não devia soltar")
        G.server("fog", { on = true, period = 2 })
        assert(mine.useless == false and not NOM_SirenFreeze.active, "a névoa não soltou")
    end,
    -- sirene sem argumentos (servidor antigo): direção 0 e a mesma segurança de fim
    fog_client_siren_without_args_and_safety = function()
        local G = setup()
        local mine = G.zombie({ x = 10, y = 10, onlineID = 5 })
        G.server("siren", nil)
        G.tick(1)
        assert(mine.useless == true and math.abs(mine.faced.x - (mine.x + NOM_SirenFreeze.FAR)) < 1e-6)
        G.now = G.now + NOM_FogEventRules.SIREN_MS + NOM_SirenFreeze.SAFETY_MS + 1000
        G.tick(1)
        assert(mine.useless == false, "sem sirenStop nem fog, ficou congelado")
    end,
    fog_client_asks_state_on_join = function()
        local G = setup()
        local p = {}
        G.fire("OnCreatePlayer", 0, p)
        assert(#G.sentClient == 1 and G.sentClient[1].player == p)
        assert(G.sentClient[1].module == "NevoaEOutroMundo" and G.sentClient[1].command == "fogState")
    end,
    -- o cliente que vê avisa o servidor pelo ID de rede, com o destino
    fog_client_reports_by_online_id = function()
        local G = setup()
        G.server("fog", { on = true, period = 1 })
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 42, remote = true })
        G.zombie({ x = 100, y = 112, id = W.semRostoID(1, true), onlineID = -1 }) -- sem ID de rede
        G.players[1].face = 0.6
        G.tick(NOM_SemRosto.SCAN_TICKS)
        local seen = G.commands(G.sentClient, "semRostoSeen")
        assert(#seen == 1, "avisos: " .. #seen)
        assert(seen[1].module == "NevoaEOutroMundo" and seen[1].args.id == 42)
        assert(type(seen[1].args.x) == "number" and seen[1].args.z == 0)
        -- a cópia remota de quem viu vai junto pro destino (ADR-007): sem deslize
        assert(G.zombies[1].x == seen[1].args.x + 0.5, "cópia remota de quem viu não foi pro destino")
    end,
    -- critério (MP): só o dono move; a cópia remota recebe a posição do dono
    fog_client_only_owner_moves = function()
        local G = setup()
        local mine = G.zombie({ x = 112, y = 100, id = 1, onlineID = 5 })
        local remote = G.zombie({ x = 50, y = 50, id = 2, onlineID = 6, remote = true })
        G.server("semRostoMove", { id = 5, x = 95, y = 100, z = 0 })
        G.server("semRostoMove", { id = 6, x = 40, y = 50, z = 0 })
        G.server("semRostoMove", { id = -1, x = 1, y = 1, z = 0 })
        assert(mine.teleports == 1 and mine.x == 95.5 and mine.y == 100.5)
        assert(remote.teleports == nil, "cópia remota teleportou (o pacote do dono a puxa de volta)")
    end,
    -- quem viu não é o dono: a cópia dele (remota) vai direto pro destino; o dono
    -- (outro cliente) move quando o servidor manda, e os pacotes dele convergem ali
    fog_client_reporter_not_owner = function()
        local G = setup()
        G.server("fog", { on = true, period = 1 })
        G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 42, remote = true })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        local seen = G.commands(G.sentClient, "semRostoSeen")
        assert(#seen == 1)
        local a = seen[1].args
        assert(z.x == a.x + 0.5 and z.y == a.y + 0.5, "a cópia de quem viu ficou pra deslizar")
        assert(not z:getCurrentSquare():isCanSee(0), "continua à vista de quem viu")
        -- o eco do servidor não move de novo a cópia remota
        G.server("semRostoMove", { id = 42, x = a.x, y = a.y, z = a.z })
        assert(z.teleports == 1)
    end,
    -- o dono confere a vista dos próprios jogadores antes de mover (o servidor não sabe)
    fog_client_owner_skips_visible_destination = function()
        local G = setup()
        G.player({ x = 90, y = 100, face = 0 }) -- olhando pro destino
        local z = G.zombie({ x = 130, y = 100, id = 1, onlineID = 5 })
        G.server("semRostoMove", { id = 5, x = 95, y = 100, z = 0 })
        assert(z.teleports == nil, "dono moveu pra frente do próprio jogador")
        G.server("semRostoMove", { id = 5, x = 80, y = 100, z = 0 }) -- atrás dele
        assert(z.teleports == 1 and z.x == 80.5)
    end,
    -- névoa vermelha: a sirene própria, uma vez por comando; o red chega no FogState
    fog_client_plays_red_siren_once = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.server("siren", { red = true })
        assert(G.played("NOM_SirenRed") == 1 and G.played("NOM_Siren") == 0)
        assert(G.playing("NOM_SirenRed")[1].volume == 1)
        G.server("fog", { on = true, period = 4, red = true })
        assert(NOM_FogState.on and NOM_FogState.red == true and G.played("NOM_SirenRed") == 1)
        G.server("fog", { on = false, period = 4, red = true })
        assert(NOM_FogState.red == false, "vermelho sem névoa")
    end,

    -- sprint 0017: o destino que o servidor espalha (semRostoMove, de qualquer cliente)
    -- fica reservado aqui também: dois clientes vendo a mesma horda não a juntam
    fog_client_move_reserves_tile = function()
        local function scanOnce(move)
            local G = setup()
            G.server("fog", { on = true, period = 1 })
            G.player({ x = 100, y = 100, face = 0 })
            G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 42, remote = true })
            if move then G.server("semRostoMove", move) end
            G.tick(NOM_SemRosto.SCAN_TICKS)
            return G.commands(G.sentClient, "semRostoSeen")[1].args
        end
        local free = scanOnce()
        local got = scanOnce({ id = 77, x = free.x, y = free.y, z = 0 }) -- outro zumbi, de outro cliente
        assert(got.x ~= free.x or got.y ~= free.y, "escolheu o tile que o servidor acabou de usar")
    end,
}
