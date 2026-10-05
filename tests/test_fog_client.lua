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
}
