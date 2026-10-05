-- client/NOM_FogClient.lua: no MP a flag de névoa vem do servidor.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogClient.lua"

local function setup(opts)
    opts = opts or {}
    if opts.client == nil then opts.client = true end
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SemRosto" })
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
        assert(G.zombies[1].teleports == nil, "cliente moveu sem o servidor")
    end,
    -- critério (MP): só o dono move; a cópia remota recebe a posição do dono
    fog_client_only_owner_moves = function()
        local G = setup()
        local mine = G.zombie({ x = 112, y = 100, id = 1, onlineID = 5 })
        local remote = G.zombie({ x = 50, y = 50, id = 2, onlineID = 6, remote = true })
        G.server("semRostoMove", { id = 5, x = 95, y = 100, z = 0 })
        G.server("semRostoMove", { id = 6, x = 40, y = 50, z = 0 })
        G.server("semRostoMove", { id = -1, x = 1, y = 1, z = 0 })
        assert(mine.teleports == 1 and mine.x == 95 and mine.y == 100)
        assert(remote.teleports == nil, "cópia remota teleportou (o pacote do dono a puxa de volta)")
    end,
}
