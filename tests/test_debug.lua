-- Comandos de debug (client/NOM_Debug.lua → server/NOM_DebugServer.lua) contra um
-- jogo falso que imita o B42.20 onde importa (bytecode):
-- * getDebug() é o -debug do processo; o cliente só cria NOM_Debug com ele.
-- * sendClientCommand(player, module, command, args): no solo vira OnClientCommand
--   local com o jogador do índice (SinglePlayerClient.sendClientCommand manda o
--   playerIndex; a versão de 3 argumentos manda -1, sem jogador). No MP vai pro
--   servidor (aqui: guardado em G.sentClient e entregue à mão).
-- * Permissão no dedicado: player:getRole():hasCapability(Capability.UseDebugContextMenu)
--   (server/ClientCommands.lua:1280).
-- * sendServerCommand(player, ...) responde um; sem player, todos.
-- * NOM_World é o de verdade, com clima falso (hora e estação).
-- Eco, névoa e contador de noites do servidor são substituídos por registradores:
-- os testes deles moram em test_eco/test_fog.

local function setup(opts)
    opts = opts or {}
    local G = { sentClient = {}, sentServer = {}, printed = {}, zombies = {}, players = {}, spawned = {},
        debug = opts.debug ~= false, server = opts.server == true, client = opts.client == true }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    function G.player(o)
        local p = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, cap = o.cap ~= false }
        function p:getX() return self.x end
        function p:getY() return self.y end
        function p:getZ() return self.z end
        function p:getRole()
            local me = self
            return { hasCapability = function(_, c) return c == Capability.UseDebugContextMenu and me.cap end }
        end
        G.players[#G.players + 1] = p
        return p
    end
    function G.zombie(o)
        local z = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, id = o.id, dead = o.dead or false }
        function z:getX() return self.x end
        function z:getY() return self.y end
        function z:getZ() return self.z end
        function z:isDead() return self.dead end
        function z:getPersistentOutfitID() return self.id end
        G.zombies[#G.zombies + 1] = z
        return z
    end

    getDebug = function() return G.debug end
    isServer = function() return G.server end
    isClient = function() return G.client end
    print = function(s) G.printed[#G.printed + 1] = s end
    Capability = { UseDebugContextMenu = "UseDebugContextMenu" }
    getSpecificPlayer = function(i) return G.players[i + 1] end
    getCell = function()
        return { getZombieList = function()
            return { size = function() return #G.zombies end, get = function(_, i) return G.zombies[i + 1] end }
        end }
    end
    sendClientCommand = function(a, b, c, d)
        assert(d ~= nil, "3 argumentos: no solo o jogador chega nil")
        local msg = { player = a, module = b, command = c, args = d }
        G.sentClient[#G.sentClient + 1] = msg
        if not G.client then G.fire("OnClientCommand", b, c, a, d) end -- solo: local
    end
    sendServerCommand = function(a, b, c, d)
        if d == nil then
            G.sentServer[#G.sentServer + 1] = { module = a, command = b, args = c }
        else
            G.sentServer[#G.sentServer + 1] = { player = a, module = b, command = c, args = d }
        end
    end
    G.world = { tod = opts.tod or 12 }
    getGameTime = function() return { getTimeOfDay = function() return G.world.tod end } end
    getClimateManager = function()
        return { getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end }
    end
    SandboxVars = {}
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_World", "NOM_VariantRules", "NOM_DebugRules", "NOM_Debug", "NOM_DebugServer" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    -- registradores no lugar dos sistemas do servidor e do cliente
    NOM_NightCount = { current = function() return G.nightNumber end }
    NOM_Fog = { period = function() return G.fogPeriod end }
    NOM_Eco = {
        spawnAt = function(x, y, z)
            if not NOM_World.night then return false end
            G.spawned[#G.spawned + 1] = { x = x, y = y, z = z }
            return true
        end,
        loaded = function() return #G.spawned end,
    }
    NOM_NightStats = { night = false, variants = {} }
    NOM_FogState = { on = false }
    NOM_SemRosto = { nearest = function() return nil end }
    for _, m in ipairs({ "NOM_NightCount", "NOM_Fog", "NOM_Eco", "NOM_NightStats", "NOM_FogState", "NOM_SemRosto" }) do
        package.loaded[m] = _G[m]
    end
    require "NOM_World"
    if opts.loadServer ~= false then dofile("mod/42/media/lua/server/NOM_DebugServer.lua") end
    if opts.loadClient ~= false then dofile("mod/42/media/lua/client/NOM_Debug.lua") end
    return G
end

local function has(lines, pattern)
    for _, l in ipairs(lines) do if l:find(pattern) then return true end end
    return false
end

local realPrint = print

local function run(fn)
    local ok, err = pcall(fn)
    print = realPrint
    assert(ok, err)
end

return {
    debug_client_absent_without_debug = function() run(function()
        setup({ debug = false })
        assert(NOM_Debug == nil, "NOM_Debug existe sem -debug")
    end) end,
    -- cliente com -debug mandando pra um servidor sem: nada muda
    debug_server_ignores_without_debug = function() run(function()
        local G = setup({ debug = false, server = true, loadClient = false })
        local p = G.player({ x = 0, y = 0 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "night", value = true })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "variant", id = 9, kind = "corredor" })
        assert(NOM_World.forced.night == nil and NOM_VariantRules.forced[9] == nil, "mudou sem -debug")
        assert(#G.sentServer == 0)
    end) end,
    debug_server_requires_capability_on_dedicated = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local p = G.player({ x = 0, y = 0, cap = false })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "night", value = true })
        assert(NOM_World.forced.night == nil, "jogador sem permissão forçou a noite")
        local admin = G.player({ x = 0, y = 0 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", admin, { op = "night", value = true })
        assert(NOM_World.forced.night == true)
        assert(#G.sentServer == 1 and G.sentServer[1].player == admin and G.sentServer[1].command == "debugReply",
            "dedicado não respondeu a quem pediu")
    end) end,
    -- solo: o comando dá a volta pelo OnClientCommand local e a noite vale na
    -- próxima leitura do clima
    debug_sp_night_round_trip = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.night(true)
        assert(G.sentClient[1].player == G.players[1], "comando sem o jogador 0")
        NOM_World.update(0)
        assert(NOM_World.night == true, "noite forçada não pegou")
        assert(has(G.printed, "^%[NOM%] debug noite forcada=true"), table.concat(G.printed, "\n"))
        assert(#G.sentServer == 0, "solo não responde pela rede")
    end) end,
    debug_force_clears_back_to_climate = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.fog(0.9)
        NOM_World.update(0)
        assert(NOM_World.fog == true)
        NOM_Debug.fog()
        NOM_Debug.night(false)
        NOM_Debug.night()
        NOM_World.update(0)
        assert(NOM_World.fog == false and NOM_World.forced.fog == nil and NOM_World.forced.night == nil,
            "não devolveu pro clima")
    end) end,
    debug_server_rejects_bad_args = function() run(function()
        local G = setup({ loadClient = false })
        local p = G.player({ x = 0, y = 0 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "variant", id = 0, kind = "corredor" })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "night", value = "sim" })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, "lixo")
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", nil, { op = "night", value = true })
        assert(next(NOM_VariantRules.forced) == nil and NOM_World.forced.night == nil)
    end) end,
    -- MP: o cliente acha o zumbi mais perto e manda o persistentOutfitID; o servidor
    -- grava e transmite pra todos, e cada cliente grava o mesmo (o sorteio concorda)
    debug_variant_nearest_and_broadcast = function() run(function()
        local G = setup({ client = true, loadServer = false })
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 130, y = 100, id = 1 })
        G.zombie({ x = 103, y = 100, id = 2 })
        G.zombie({ x = 101, y = 100, id = 3, dead = true })
        G.zombie({ x = 102, y = 100, z = 1, id = 4 }) -- outro andar
        NOM_Debug.variant("estalador")
        local sent = G.sentClient[1]
        assert(sent.command == "debug" and sent.args.op == "variant" and sent.args.id == 2 and sent.args.kind == "estalador",
            "mandou " .. tostring(sent and sent.args.id))
        -- servidor dedicado
        G.client, G.server = false, true
        dofile("mod/42/media/lua/server/NOM_DebugServer.lua")
        G.fire("OnClientCommand", sent.module, sent.command, G.players[1], sent.args)
        assert(NOM_VariantRules.forced[2] == "estalador")
        local bc
        for _, c in ipairs(G.sentServer) do if c.command == "debugVariant" then bc = c end end
        assert(bc and bc.player == nil and bc.args.id == 2 and bc.args.kind == "estalador", "não transmitiu")
        -- outro cliente recebe
        NOM_VariantRules.forced[2] = nil
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugVariant", bc.args)
        assert(NOM_VariantRules.forced[2] == "estalador", "cliente não gravou")
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugVariant", { id = 2 })
        assert(NOM_VariantRules.forced[2] == nil, "kind nil não limpou")
    end) end,
    debug_spawn_eco_at_player_only_at_night = function() run(function()
        local G = setup()
        G.player({ x = 50, y = 60 })
        NOM_Debug.spawnEco()
        assert(#G.spawned == 0)
        G.world.tod = 23
        NOM_World.update(0)
        NOM_Debug.spawnEco()
        assert(#G.spawned == 1 and G.spawned[1].x == 50 and G.spawned[1].y == 60, "Eco fora do jogador")
        assert(has(G.printed, "eco spawn=true"))
    end) end,
    debug_status_prints_local_and_server = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.nightNumber, G.fogPeriod = 3, 2
        NOM_NightStats.night, NOM_NightStats.nightNumber = true, 3
        NOM_NightStats.variants = { a = "estalador", b = "corredor", c = "estalador" }
        NOM_World.update(0.7)
        NOM_Debug.status()
        assert(has(G.printed, "^%[NOM%] debug local .*estaladores=2"), table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug servidor .*nevoaN=2.*noiteN=3"), table.concat(G.printed, "\n"))
    end) end,
}
