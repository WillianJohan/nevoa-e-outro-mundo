-- server/NOM_Fog.lua contra o mundo falso de tests/fog_world.lua: período de
-- névoa (ModData global, conta por estado como as noites), flag pros clientes
-- e o Sem-rosto do lado do servidor.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/server/NOM_Fog.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_World", "NOM_FogState", "NOM_Fog", "NOM_SemRosto" })
    dofile(FILE)
    function G.setFog(v) NOM_World.update(v) end
    function G.clientCommand(module, command, p, args) G.fire("OnClientCommand", module, command, p, args) end
    G.setFog(opts.fog or 0)
    return G
end

return {
    -- solo: o mesmo processo é cliente, a flag vai direto pro estado local
    fog_sp_sets_state = function()
        local G = setup()
        local seen = {}
        NOM_FogState.onChange(function(on) seen[#seen + 1] = on end)
        assert(NOM_FogState.on == false)
        G.setFog(0.9)
        G.setFog(0.9)
        assert(NOM_FogState.on == true and NOM_FogState.period == 1)
        G.setFog(0)
        assert(NOM_FogState.on == false)
        assert(#seen == 2 and seen[1] == true and seen[2] == false, "bordas: " .. #seen)
        assert(#G.sentServer == 0, "solo mandou comando de rede")
    end,
    -- dedicado: avisa todo mundo na borda, com o número do período
    fog_mp_broadcasts_edge_with_period = function()
        local G = setup({ server = true })
        G.setFog(0.9)
        G.setFog(0.95)
        G.setFog(0)
        G.setFog(0.9)
        local fog = G.commands(G.sentServer, "fog")
        assert(#fog == 3, "avisos: " .. #fog)
        assert(fog[1].module == "NevoaEOutroMundo" and fog[1].args.on == true and fog[1].args.period == 1)
        assert(fog[2].args.on == false)
        assert(fog[3].args.on == true and fog[3].args.period == 2)
        assert(NOM_FogState.on == false, "dedicado mexeu no estado de cliente")
    end,
    -- reiniciar no meio da névoa não abre período novo (sorteio do Sem-rosto igual)
    fog_period_counts_once_per_fog = function()
        local G = setup({ fog = 0.9 })
        assert(NOM_FogState.period == 1)
        setup({ fog = 0.9, globalMD = G.globalMD })
        assert(NOM_FogState.period == 1, "reinício abriu névoa nova")
        assert(G.globalMD.NevoaEOutroMundo.fog.night == 1)
    end,
    -- cliente que entra no meio da névoa pergunta e recebe só pra ele
    fog_answers_state = function()
        local G = setup({ server = true, fog = 0.9 })
        G.sentServer = {}
        local who = {}
        G.clientCommand("NevoaEOutroMundo", "fogState", who, {})
        G.clientCommand("OutroMod", "fogState", who, {})
        assert(#G.sentServer == 1 and G.sentServer[1].player == who)
        assert(G.sentServer[1].command == "fog" and G.sentServer[1].args.on == true and G.sentServer[1].args.period == 1)
    end,
}
