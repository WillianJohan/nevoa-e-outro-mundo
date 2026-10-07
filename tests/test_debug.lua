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
        local p = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, cap = o.cap ~= false, dir = o.dir or 0,
            god = false, noclip = false, invisible = false, dontAttack = false }
        -- Vector2.getDirection(): ângulo em radianos (FishingRod.lua:286)
        function p:getForwardDirection()
            local me = self
            return { getDirection = function() return me.dir end }
        end
        -- ISAdminPowerUI.lua:31-53
        function p:isGodMod() return self.god end
        function p:setGodMod(v) self.god = v end
        function p:isNoClip() return self.noclip end
        function p:setNoClip(v) self.noclip = v end
        function p:isInvisible() return self.invisible end
        function p:setInvisible(v) self.invisible = v end
        -- ISAdminPowerUI.lua:175, 178
        function p:isZombiesDontAttack() return self.dontAttack end
        function p:setZombiesDontAttack(v) self.dontAttack = v end
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
        -- online: ID de rede (dedicado); sem ele é -1, como no solo e em zumbi sem ID (NOM_Fog.lua:153)
        local z = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, id = o.id, dead = o.dead or false,
            online = o.online or -1, remote = o.remote == true }
        function z:getOnlineID() return self.online end
        function z:isLocal() return (not isClient() and not isServer()) or not self.remote end
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
    -- Relógio do GameTime: setTimeOfDay só grava o campo (bytecode 0–5); o update seguinte
    -- (GameTime.update 938–972) vê hora ≥ 24, tira 24, chama advanceOneDay e, no servidor,
    -- marca o sync do relógio. Hora pra trás não passa por ali: os clientes do dedicado
    -- dessincronizam a data (SyncClockPacket) e o getWorldAgeHours volta (timers do mod).
    G.world = { tod = opts.tod or 12, day = 0 }
    function G.tick()
        if G.world.tod >= 24 then
            G.world.tod = G.world.tod - 24
            G.world.day = G.world.day + 1
            G.world.synced = true
        end
    end
    getGameTime = function()
        return { getTimeOfDay = function() return G.world.tod end,
            getWorldAgeHours = function() return G.world.day * 24 + G.world.tod end,
            setTimeOfDay = function(_, h) G.world.tod = h end }
    end
    -- getAllOutfits(feminino) → ArrayList<String> (ISSpawnHordeUI.lua:71-72)
    local function jlist(t)
        return { contains = function(_, v) for _, x in ipairs(t) do if x == v then return true end end return false end }
    end
    getAllOutfits = function(female) return jlist(female and { "Nurse", "Doctor" } or { "Police", "Doctor" }) end
    -- addZombiesInOutfitArea(x1, y1, x2, y2, z, n, outfit, femaleChance) → ArrayList: n vezes
    -- addZombiesInOutfit num tile sorteado com Rand.Next(x1, x2) (fim exclusivo) (bytecode
    -- 0–54). Cada um volta vazio com square nil, outfit desconhecido ou zumbis desligados.
    G.spawnCalls, G.made = {}, {}
    local KNOWN = { Police = true, Doctor = true, Nurse = true }
    addZombiesInOutfitArea = function(x1, y1, x2, y2, z, n, outfit, female)
        G.spawnCalls[#G.spawnCalls + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z, n = n, outfit = outfit, female = female }
        local made = 0
        for i = 1, n do
            local x = x1 + (i - 1) % (x2 - x1)
            local y = y1 + math.floor((i - 1) / (x2 - x1)) % (y2 - y1)
            local ok = not G.zombiesDisabled and (outfit == nil or KNOWN[outfit])
                and not (G.noSquare and G.noSquare(x, y, z))
            if ok then
                made = made + 1
                G.made[#G.made + 1] = { x = x, y = y, z = z }
            end
        end
        return { size = function() return made end }
    end
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
    -- sendPlayerExtraInfo(player): o vanilla chama depois de mudar god/noclip/invisível (ISAdminPowerUI.lua:403)
    G.extraInfo = {}
    sendPlayerExtraInfo = function(p) G.extraInfo[#G.extraInfo + 1] = p end
    for _, m in ipairs({ "NOM_World", "NOM_VariantRules", "NOM_DebugRules", "NOM_Debug", "NOM_DebugServer", "NOM_Console", "NOM" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    -- NOM_NightCount de verdade: o contador de noites salvo no ModData global
    G.globalMD = {}
    ModData = { getOrCreate = function(name)
        G.globalMD[name] = G.globalMD[name] or {}
        return G.globalMD[name]
    end }
    NOM_NightCount = nil
    package.loaded["NOM_NightCount"] = nil
    -- registradores no lugar dos outros sistemas do servidor e do cliente
    NOM_Fog = { period = function() return G.fogPeriod end }
    -- evento de névoa: o de verdade mora em test_fog_event; aqui registra o pedido
    G.fogCalls = {}
    -- a sirene conta (sirenMs) até a névoa abrir; stop cancela a contagem
    NOM_FogEvent = {
        siren = function(skip)
            G.fogCalls[#G.fogCalls + 1] = "siren:" .. tostring(skip)
            G.sirenMs = skip and 0 or 30000
            return true
        end,
        stop = function() G.fogCalls[#G.fogCalls + 1] = "stop"; G.sirenMs = nil; return true end,
        status = function() return { next = 136, endAt = nil, sirenMs = G.sirenMs, sirenRed = G.sirenMs ~= nil and G.sirenRed == true } end,
        setRed = function(on) G.fogCalls[#G.fogCalls + 1] = "red:" .. tostring(on); return true end,
        force = function(red, skip, black)
            G.fogCalls[#G.fogCalls + 1] = "force:" .. tostring(red) .. ":" .. tostring(skip == true) ..
                (black and ":preta" or "")
            return true
        end,
    }
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
    -- move: o de verdade teleporta o zumbi (NOM_SemRosto.move); aqui registra quem foi pra onde
    G.moves = {}
    NOM_SemRosto = {
        nearest = function() return nil end,
        move = function(z, x, y, zz) G.moves[#G.moves + 1] = { z = z, x = x, y = y, zz = zz } end,
    }
    for _, m in ipairs({ "NOM_Fog", "NOM_FogEvent", "NOM_Eco", "NOM_NightStats", "NOM_FogState", "NOM_SemRosto" }) do
        package.loaded[m] = _G[m]
    end
    require "NOM_World"
    if opts.loadServer ~= false then dofile("mod/42/media/lua/server/NOM_DebugServer.lua") end
    if opts.loadClient ~= false then
        dofile("mod/42/media/lua/client/NOM_Debug.lua")
        package.loaded["NOM_Debug"] = true -- o jogo carrega cada arquivo uma vez
        dofile("mod/42/media/lua/client/NOM_Console.lua")
    end
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
        NOM_World.update()
        assert(NOM_World.night == true, "noite forçada não pegou")
        assert(has(G.printed, "^%[NOM%] debug noite forcada=true"), table.concat(G.printed, "\n"))
        assert(#G.sentServer == 0, "solo não responde pela rede")
    end) end,
    debug_night_clears_back_to_clock = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.night(false)
        NOM_Debug.night()
        NOM_World.update()
        assert(NOM_World.forced.night == nil, "não devolveu pro relógio")
    end) end,
    -- NOM_Debug.fog começa um evento de verdade (com sirene, ou sem a espera) e termina
    debug_fog_starts_and_stops_event = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.fog(true)
        NOM_Debug.fog(true, true)
        NOM_Debug.fog(false)
        NOM_Debug.fog()
        assert(table.concat(G.fogCalls, ",") == "siren:false,siren:true,stop,stop", table.concat(G.fogCalls, ","))
        assert(has(G.printed, "^%[NOM%] debug nevoa sirene=true"), table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug nevoa fim=true"), table.concat(G.printed, "\n"))
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
        NOM_World.update()
        NOM_Debug.spawnEco()
        assert(#G.spawned == 1 and G.spawned[1].x == 50 and G.spawned[1].y == 60, "Eco fora do jogador")
        assert(has(G.printed, "eco spawn=true"))
    end) end,
    debug_status_prints_local_and_server = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.fogPeriod = 2
        G.globalMD.NevoaEOutroMundo = { eco = { night = 2, inNight = false } }
        G.world.tod = 23
        NOM_World.update() -- noite 3 abre
        NOM_NightStats.night, NOM_NightStats.nightNumber = true, 3
        NOM_NightStats.variants = { a = "estalador", b = "corredor", c = "estalador", d = "carpideira" }
        G.sirenMs = 12000
        NOM_Debug.status()
        assert(has(G.printed, "^%[NOM%] debug local .*estaladores=2"), table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug local carpideiras=1 "), table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug servidor .*nevoaN=2.*noiteN=3"), table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug servidor .*fim=%- .*proxima=136.00 sirene=12000"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0012: quantos zumbis estão com o visual da variante nesta tela
    debug_status_counts_looks = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.status()
        assert(has(G.printed, "^%[NOM%] debug local .* visuais=0"), table.concat(G.printed, "\n"))
        NOM_VariantLook = { count = function() return 3 end }
        NOM_Debug.status()
        NOM_VariantLook = nil
        assert(has(G.printed, "^%[NOM%] debug local .* visuais=3"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0015: quanto sangue e quantas paredes do Outro Mundo nesta tela
    debug_status_counts_overlays = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_FogOverlays = { count = function() return 312, 47 end }
        NOM_Debug.status()
        NOM_FogOverlays = nil
        assert(has(G.printed, "^%[NOM%] debug local .*chao=312 .*paredes=47"), table.concat(G.printed, "\n"))
        NOM_Debug.status()
        assert(has(G.printed, "^%[NOM%] debug local .*chao=0 .*paredes=0"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0018: efeitos de dissolve rodando nesta tela
    debug_status_counts_dissolve = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local saved = NOM_Dissolve
        NOM_Dissolve = { count = function() return 5 end }
        NOM_Debug.status()
        NOM_Dissolve = saved
        assert(has(G.printed, "^%[NOM%] debug local .*dissolve=5"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0022: cascas de brasa queimando nesta tela
    debug_status_counts_shells = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.status()
        assert(has(G.printed, "^%[NOM%] debug local .*cascas=0"), table.concat(G.printed, "\n"))
        NOM_EmberShell = { count = function() return 4 end }
        NOM_Debug.status()
        NOM_EmberShell = nil
        assert(has(G.printed, "^%[NOM%] debug local .*cascas=4"), table.concat(G.printed, "\n"))
    end) end,
    -- a noite forçada não é só memória: ela avança o contador de noites salvo
    -- (NOM_NightCount → ModData global), e com ele o sorteio das variantes e a
    -- noite dos Ecos. Por isso o roteiro manda usar um save descartável.
    debug_forced_night_advances_saved_counter = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_World.update()
        assert(NOM_NightCount.current() == 0)
        NOM_Debug.night(true)
        NOM_World.update()
        assert(NOM_NightCount.current() == 1 and G.globalMD.NevoaEOutroMundo.eco.night == 1, "contador não andou")
        NOM_Debug.night()
        NOM_World.update()
        NOM_NightCount.current() -- no jogo o Eco e a Noite leem na borda
        NOM_Debug.night(true)
        NOM_World.update()
        assert(NOM_NightCount.current() == 2, "segunda noite forçada não contou")
        NOM_Debug.night()
        NOM_World.update()
        assert(G.globalMD.NevoaEOutroMundo.eco.night == 2, "devolver pro relógio desfez o contador")
    end) end,
    -- cliente que entra depois (pergunta nightState) recebe o que já foi forçado
    debug_late_join_gets_forced_variants = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local admin = G.player({ x = 0, y = 0 })
        local late = G.player({ x = 5, y = 5, cap = false })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "nightState", late, {})
        assert(#G.sentServer == 0, "mandou forçado vazio")
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", admin, { op = "variant", id = 42, kind = "corredor" })
        G.sentServer = {}
        G.fire("OnClientCommand", "NevoaEOutroMundo", "nightState", late, {})
        local c = G.sentServer[1]
        assert(c and c.player == late and c.command == "debugForced", "não mandou o forçado pro novo")
        assert(#c.args.list == 1 and c.args.list[1].id == 42 and c.args.list[1].kind == "corredor")
        -- o cliente novo grava
        G.server, G.client = false, true
        dofile("mod/42/media/lua/client/NOM_Debug.lua")
        NOM_VariantRules.forced[42] = nil
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugForced", c.args)
        assert(NOM_VariantRules.forced[42] == "corredor", "cliente não gravou")
    end) end,
    debug_denied_prints_under_debug = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local p = G.player({ x = 0, y = 0, cap = false })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "night", value = true })
        assert(has(G.printed, "^%[NOM%] debug negado"), table.concat(G.printed, "\n"))
    end) end,
    -- névoa vermelha: o pedido vai pro evento, com a mesma porta dos outros comandos
    debug_red_fog_forwards_to_event = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.redFog(true)
        NOM_Debug.redFog(false)
        NOM_Debug.redFog()
        assert(table.concat(G.fogCalls, ",") == "red:true,red:false,red:false", table.concat(G.fogCalls, ","))
        assert(has(G.printed, "^%[NOM%] debug nevoa vermelha=true"), table.concat(G.printed, "\n"))
        local G2 = setup({ server = true, loadClient = false })
        local p = G2.player({ x = 0, y = 0, cap = false })
        G2.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "redFog", value = true })
        assert(#G2.fogCalls == 0, "sem permissão forçou a vermelha")
    end) end,
    debug_status_shows_red = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_FogState.red = true
        NOM_World.red = true
        NOM_Debug.status()
        assert(has(G.printed, "^%[NOM%] debug local .*vermelha=true"), table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug servidor .*vermelha=true"), table.concat(G.printed, "\n"))
    end) end,

    -- sprint 0017: o forçado vai pelo ID sem o bit do chapéu (o sorteio tira o bit)
    debug_variant_sends_base_id = function() run(function()
        local G = setup({ client = true, loadServer = false })
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 101, y = 100, id = 2 + 32768 })
        NOM_Debug.variant("corredor")
        assert(G.sentClient[1].args.id == 2, "mandou " .. tostring(G.sentClient[1].args.id))
    end) end,

    -- sprint 0020: NOM.time → hora do relógio, no servidor (no MP o relógio é dele)
    debug_time_sets_clock = function() run(function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        NOM_Debug.send({ op = "time", hour = 13.5 })
        G.tick()
        assert(G.world.tod == 13.5 and G.world.day == 0, "hora não mudou")
        assert(has(G.printed, "^%[NOM%] debug hora=13.50"), table.concat(G.printed, "\n"))
        local G2 = setup({ server = true, loadClient = false })
        local q = G2.player({ x = 0, y = 0, cap = false })
        G2.fire("OnClientCommand", "NevoaEOutroMundo", "debug", q, { op = "time", hour = 3 })
        assert(G2.world.tod == 12, "sem permissão mudou a hora")
        local G3 = setup({ debug = false, loadClient = false })
        G3.fire("OnClientCommand", "NevoaEOutroMundo", "debug", G3.player({ x = 0, y = 0 }), { op = "time", hour = 3 })
        assert(G3.world.tod == 12, "sem -debug mudou a hora")
    end) end,
    -- hora pra trás vira a mesma hora do dia seguinte: o relógio só anda pra frente
    debug_time_never_goes_back = function() run(function()
        local G = setup({ loadClient = false, tod = 20 })
        local p = G.player({ x = 0, y = 0 })
        local age = G.world.day * 24 + G.world.tod
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "time", hour = 6 })
        G.tick()
        assert(G.world.tod == 6 and G.world.day == 1 and G.world.synced, "não foi pro dia seguinte")
        assert(G.world.day * 24 + G.world.tod > age, "idade do mundo voltou")
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "time", hour = 6 })
        G.tick()
        assert(G.world.tod == 6 and G.world.day == 1, "mesma hora pulou um dia")
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "time", hour = 22 })
        G.tick()
        assert(G.world.tod == 22 and G.world.day == 1, "pra frente no mesmo dia")
        assert(has(G.printed, "^%[NOM%] debug hora=6.00"), table.concat(G.printed, "\n"))
    end) end,
    -- 3×3 em volta do tile pedido (Rand.Next com fim exclusivo: x-1..x+1)
    debug_server_spawn_in_front = function() run(function()
        local G = setup({ loadClient = false })
        local p = G.player({ x = 100, y = 100 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 9, x = 103.7, y = 100.2, z = 0 })
        local c = G.spawnCalls[1]
        assert(c and c.x1 == 102 and c.y1 == 99 and c.x2 == 105 and c.y2 == 102 and c.z == 0 and c.n == 9
            and c.outfit == nil and c.female == nil, "área errada")
        local tiles = {}
        for _, z in ipairs(G.made) do tiles[z.x .. "," .. z.y] = true end
        local n = 0
        for _ in pairs(tiles) do n = n + 1 end
        assert(n == 9, "não espalhou: " .. n .. " tiles")
        assert(has(G.printed, "^%[NOM%] debug spawn n=9 criados=9 outfit=%-"), table.concat(G.printed, "\n"))
        G.noSquare = function(x) return x == 102 end -- parede/fora do mapa
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 3, outfit = "Police", x = 103, y = 100, z = 0 })
        assert(has(G.printed, "spawn n=3 criados=2 outfit=Police"), table.concat(G.printed, "\n"))
    end) end,
    debug_server_spawn_rejects_unknown_outfit = function() run(function()
        local G = setup({ loadClient = false })
        local p = G.player({ x = 100, y = 100 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 2, outfit = "Polcie", x = 101, y = 100, z = 0 })
        assert(#G.spawnCalls == 0, "spawnou outfit desconhecido")
        assert(has(G.printed, "^%[NOM%] debug spawn outfit desconhecido=Polcie"), table.concat(G.printed, "\n"))
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 1, outfit = "Nurse", x = 101, y = 100, z = 0 })
        assert(#G.spawnCalls == 1, "outfit só feminino recusado")
    end) end,
    -- quem pede não spawna longe de si (nem com o pedido montado à mão)
    debug_server_spawn_rejects_far = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local p = G.player({ x = 100, y = 100 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 5, x = 120, y = 100, z = 0 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 5, x = math.huge, y = 100, z = 0 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "spawn", n = 5, x = 101, y = 100, z = 3 })
        assert(#G.spawnCalls == 0, "spawnou longe")
        assert(has(G.printed, "^%[NOM%] debug spawn longe"), table.concat(G.printed, "\n"))
        local weak = G.player({ x = 100, y = 100, cap = false })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", weak, { op = "spawn", n = 5, x = 101, y = 100, z = 0 })
        assert(#G.spawnCalls == 0, "sem permissão spawnou")
    end) end,
    -- toggle: nada → sirene; sirene contando → cancela; névoa aberta → termina
    debug_fog_toggle_cancels_siren = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Debug.send({ op = "fog", toggle = true })
        NOM_Debug.send({ op = "fog", toggle = true })
        NOM_World.fog = true
        NOM_Debug.send({ op = "fog", toggle = true })
        assert(table.concat(G.fogCalls, ",") == "siren:false,stop,stop", table.concat(G.fogCalls, ","))
    end) end,

    -- sprint 0020: a tabela NOM tem a mesma porta do NOM_Debug
    nom_absent_without_debug = function() run(function()
        setup({ debug = false })
        assert(NOM == nil, "NOM existe sem -debug")
    end) end,
    nom_absent_on_server = function() run(function()
        local G = setup({ loadClient = false, server = true })
        dofile("mod/42/media/lua/client/NOM_Console.lua")
        assert(NOM == nil, "NOM existe no servidor dedicado")
    end) end,
    -- sem argumento, o servidor decide (cancela a sirene que está contando)
    nom_fog_toggle_goes_to_server = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.fog()
        NOM.fog()
        assert(G.sentClient[1].args.toggle == true)
        assert(table.concat(G.fogCalls, ",") == "siren:false,stop", table.concat(G.fogCalls, ","))
    end) end,
    nom_fog_explicit_is_old_fog = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.fog(true, true)
        NOM.fog(false)
        assert(table.concat(G.fogCalls, ",") == "siren:true,stop", table.concat(G.fogCalls, ","))
    end) end,
    nom_red_and_night_flip_local_state = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.redFog()
        NOM_World.red = true -- névoa vermelha aberta
        NOM.redFog()
        NOM_World.red = false
        G.sirenMs, G.sirenRed = 30000, true -- sirene vermelha contando
        NOM.redFog()
        NOM.redFog(true)
        assert(G.sentClient[1].args.toggle == true, "toggle não foi pro servidor")
        assert(table.concat(G.fogCalls, ",") == "red:true,red:false,red:false,red:true", table.concat(G.fogCalls, ","))
        NOM.night()
        assert(NOM_World.forced.night == true)
        NOM_NightStats.night = true
        NOM.night()
        assert(NOM_World.forced.night == false, "não inverteu a noite")
        NOM.night(true)
        assert(NOM_World.forced.night == true)
    end) end,
    nom_time_wraps_hour = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.time(22)
        G.tick()
        assert(G.world.tod == 22)
        NOM.time(25)
        G.tick()
        assert(G.world.tod == 1, "25 não virou 1")
        NOM.time(-1)
        G.tick()
        assert(G.world.tod == 23, "-1 não virou 23")
        local n = #G.sentClient
        NOM.time("meia-noite")
        NOM.time()
        NOM.time(math.huge)
        NOM.time(-math.huge)
        NOM.time(0 / 0)
        assert(#G.sentClient == n, "mandou hora inválida")
        assert(has(G.printed, "^%[NOM%] debug uso: NOM.time"), table.concat(G.printed, "\n"))
    end) end,
    nom_spawn_clamps_and_aims_ahead = function() run(function()
        local G = setup()
        G.player({ x = 100, y = 100, dir = math.pi / 2 }) -- olhando pra +y
        NOM.spawn()
        NOM.spawn(1000, "Police")
        NOM.spawn(-3)
        local a, b, c = G.spawnCalls[1], G.spawnCalls[2], G.spawnCalls[3]
        assert(a.n == 1 and a.x1 == 99 and a.y1 == 102 and a.outfit == nil, "não spawnou 3 tiles na frente")
        assert(b.n == 50 and b.outfit == "Police", "não limitou a 50")
        assert(c.n == 1, "negativo não virou 1")
        local n = #G.sentClient
        NOM.spawn("x")
        assert(#G.sentClient == n, "mandou quantidade inválida")
    end) end,
    nom_variant_eco_status_alias = function() run(function()
        local G = setup()
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 101, y = 100, id = 7 })
        NOM.variant("corredor")
        assert(NOM_VariantRules.forced[7] == "corredor")
        G.world.tod = 23
        NOM_World.update()
        NOM.eco()
        assert(#G.spawned == 1)
        NOM.status()
        assert(has(G.printed, "^%[NOM%] debug local") and has(G.printed, "^%[NOM%] debug servidor"))
    end) end,
    nom_cheats_toggle_and_sync = function() run(function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        NOM.god()
        assert(p.god == true and #G.extraInfo == 1 and G.extraInfo[1] == p)
        NOM.god()
        assert(p.god == false)
        NOM.noclip(true)
        NOM.noclip(true)
        assert(p.noclip == true)
        NOM.invisible()
        assert(p.invisible == true and #G.extraInfo == 5)
        assert(has(G.printed, "^%[NOM%] debug god=false") and has(G.printed, "^%[NOM%] debug invisible=true"))
    end) end,
    -- todo NOM.<f> está no help, e todo item do help existe
    nom_help_lists_every_command = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.help()
        local all = table.concat(G.printed, "\n")
        for k, v in pairs(NOM) do
            if type(v) == "function" then assert(all:find("NOM." .. k .. "(", 1, true), "help sem NOM." .. k) end
        end
        for _, h in ipairs(NOM.HELP) do
            assert(type(NOM[h[1]:match("^NOM%.([%w_]+)")]) == "function", "help cita o que não existe: " .. h[1])
        end
    end) end,

    -- sprint 0033, tarefa 7: atalhos novos em cima do que já existe
    -- um único pedido: o servidor desfaz o que estiver aberto e força a cor (NOM_FogEvent.force)
    nom_set_fog_sends_single_white_request = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.setFog()
        assert(#G.sentClient == 1, "esperava um pedido só")
        local a = G.sentClient[1].args
        assert(a.op == "setFog" and a.red == false and not a.skip, "pedido errado")
        assert(table.concat(G.fogCalls, ",") == "force:false:false", table.concat(G.fogCalls, ","))
        NOM.setFog(true)
        assert(#G.sentClient == 2 and G.sentClient[2].args.skip == true and G.sentClient[2].args.red == false)
        assert(G.fogCalls[2] == "force:false:true", G.fogCalls[2])
        -- névoa aberta no cliente: o mesmo pedido (quem reabre é o servidor)
        NOM_FogState.on = true
        NOM.setFog(true)
        assert(#G.sentClient == 3 and G.sentClient[3].args.op == "setFog")
    end) end,
    nom_set_red_fog = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.setRedFog()
        assert(#G.sentClient == 1, "esperava um pedido só")
        local a = G.sentClient[1].args
        assert(a.op == "setFog" and a.red == true and not a.skip, "pedido errado")
        NOM.setRedFog(true)
        assert(#G.sentClient == 2 and G.sentClient[2].args.red == true and G.sentClient[2].args.skip == true)
        assert(table.concat(G.fogCalls, ",") == "force:true:false,force:true:true", table.concat(G.fogCalls, ","))
    end) end,
    -- o servidor confere o pedido e não aceita sem permissão
    debug_set_fog_op_needs_permission = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local weak = G.player({ x = 0, y = 0, cap = false })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", weak, { op = "setFog", red = true, skip = true })
        assert(#G.fogCalls == 0, "sem permissão forçou a névoa")
        local admin = G.player({ x = 0, y = 0 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", admin, { op = "setFog", red = "sim" })
        assert(#G.fogCalls == 0, "aceitou red inválido")
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", admin, { op = "setFog", red = true, skip = true })
        assert(table.concat(G.fogCalls, ",") == "force:true:true", table.concat(G.fogCalls, ","))
        assert(has(G.printed, "^%[NOM%] debug nevoa forcada vermelha=true"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0038: a preta é o mesmo pedido, com black (e o red nunca junto)
    nom_set_black_fog = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.setBlackFog()
        assert(#G.sentClient == 1, "esperava um pedido só")
        local a = G.sentClient[1].args
        assert(a.op == "setFog" and a.black == true and not a.red and not a.skip, "pedido errado")
        NOM.setBlackFog(true)
        assert(#G.sentClient == 2 and G.sentClient[2].args.black == true and G.sentClient[2].args.skip == true)
        assert(table.concat(G.fogCalls, ",") == "force:false:false:preta,force:false:true:preta", table.concat(G.fogCalls, ","))
        assert(has(G.printed, "^%[NOM%] debug nevoa forcada preta=true"), table.concat(G.printed, "\n"))
    end) end,
    nom_set_end_fog = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM.setEndFog()
        assert(#G.sentClient == 1 and G.sentClient[1].args.op == "fog" and G.sentClient[1].args.value == false)
        assert(table.concat(G.fogCalls, ",") == "stop", table.concat(G.fogCalls, ","))
    end) end,
    nom_turn_zombie_by_number = function() run(function()
        local G = setup()
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 101, y = 100, id = 7 })
        NOM_FogState.on = true
        NOM.turnZombie(2)
        assert(G.sentClient[1].args.op == "variant" and G.sentClient[1].args.kind == "corredor")
        assert(NOM_VariantRules.forced[7] == "corredor")
        NOM.turnZombie(4)
        assert(NOM_VariantRules.forced[7] == "carpideira", "4 é carpideira")
        NOM.turnZombie(3)
        assert(NOM_VariantRules.forced[7] == "semrosto", "3 é semrosto")
        NOM.turnZombie(1)
        assert(NOM_VariantRules.forced[7] == "estalador", "1 é estalador")
        NOM.turnZombie(0)
        assert(G.sentClient[#G.sentClient].args.kind == nil and NOM_VariantRules.forced[7] == nil, "0 não desfez")
        NOM.turnZombie()
        assert(G.sentClient[#G.sentClient].args.kind == nil)
        local n = #G.sentClient
        NOM.turnZombie(9)
        NOM.turnZombie(-1)
        NOM.turnZombie(1.5)
        NOM.turnZombie("x")
        assert(#G.sentClient == n, "mandou número fora da faixa")
        assert(has(G.printed, "^%[NOM%] debug uso: NOM.turnZombie%(i%).*1 estalador.*2 corredor.*3 semrosto.*4 carpideira"),
            table.concat(G.printed, "\n"))
    end) end,
    -- sem névoa aberta o forçado só vale quando ela abrir: avisa, mas manda
    nom_turn_zombie_warns_without_fog = function() run(function()
        local G = setup()
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 101, y = 100, id = 7 })
        NOM.turnZombie(1)
        assert(has(G.printed, "^%[NOM%] debug variante só aparece com névoa %(NOM.setFog%(true%)%)"), table.concat(G.printed, "\n"))
        assert(#G.sentClient == 1 and NOM_VariantRules.forced[7] == "estalador", "não mandou mesmo assim")
        G.printed = {}
        NOM_FogState.on = true
        NOM.turnZombie(1)
        assert(not has(G.printed, "só aparece com névoa"), "avisou com névoa aberta")
    end) end,
    nom_god_mode_sets_all_three = function() run(function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        NOM.godMode(true)
        assert(p.god and p.invisible and p.dontAttack, "não ligou os três")
        assert(#G.extraInfo == 1 and G.extraInfo[1] == p)
        assert(has(G.printed, "^%[NOM%] debug godMode=true"), table.concat(G.printed, "\n"))
        NOM.godMode() -- inverte pelo isGodMod
        assert(not p.god and not p.invisible and not p.dontAttack, "não desligou os três")
        assert(#G.extraInfo == 2 and has(G.printed, "^%[NOM%] debug godMode=false"))
        NOM.godMode()
        assert(p.god and p.invisible and p.dontAttack)
        NOM.godMode(false)
        assert(not p.god and not p.invisible and not p.dontAttack)
    end) end,
    nom_get_zombie_pulls_nearest = function() run(function()
        local G = setup()
        local p = G.player({ x = 100, y = 100 })
        G.zombie({ x = 130, y = 100, id = 1, online = 11 })
        G.zombie({ x = 103, y = 100, id = 2, online = 12 })
        G.zombie({ x = 101, y = 100, id = 3, online = 13, dead = true })
        NOM.getZombie()
        local a = G.sentClient[1].args
        assert(a.op == "pull" and a.id == 12 and a.x == 100 and a.y == 100 and a.z == 0, "pedido errado")
        -- solo: o servidor local move o zumbi pro jogador
        assert(#G.moves == 1 and G.moves[1].z == G.zombies[2] and G.moves[1].x == 100 and G.moves[1].y == 100
            and G.moves[1].zz == 0, "não moveu")
        assert(has(G.printed, "^%[NOM%] debug zumbi puxado x=100 y=100"), table.concat(G.printed, "\n"))
    end) end,
    nom_get_zombie_none_near = function() run(function()
        local G = setup()
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 101, y = 100, z = 1, id = 1 }) -- outro andar
        NOM.getZombie()
        assert(#G.sentClient == 0, "pediu sem zumbi")
        assert(has(G.printed, "^%[NOM%] debug nenhum zumbi perto"), table.concat(G.printed, "\n"))
    end) end,
    -- solo: sem ID de rede (-1) o servidor usa o mais perto de quem pediu
    debug_pull_solo_without_online_id_uses_nearest = function() run(function()
        local G = setup()
        local p = G.player({ x = 100, y = 100, z = 0 })
        G.zombie({ x = 120, y = 100, id = 1 })
        local near = G.zombie({ x = 102, y = 100, id = 2 })
        G.zombie({ x = 101, y = 100, z = 1, id = 3 }) -- outro andar
        NOM_Debug.send({ op = "pull", id = -1, x = 100, y = 100, z = 0 })
        assert(#G.moves == 1 and G.moves[1].z == near and G.moves[1].x == 100 and G.moves[1].y == 100, "não moveu o mais perto")
        assert(has(G.printed, "^%[NOM%] debug zumbi puxado x=100 y=100"), table.concat(G.printed, "\n"))
    end) end,
    debug_pull_solo_by_online_id = function() run(function()
        local G = setup()
        G.player({ x = 100, y = 100 })
        G.zombie({ x = 101, y = 100, id = 1, online = 5 })
        local far = G.zombie({ x = 110, y = 100, id = 2, online = 6 })
        NOM_Debug.send({ op = "pull", id = 6, x = 100, y = 100, z = 0 })
        assert(#G.moves == 1 and G.moves[1].z == far, "achou pelo ID de rede")
        NOM_Debug.send({ op = "pull", id = 99, x = 100, y = 100, z = 0 })
        assert(#G.moves == 1, "moveu zumbi que não existe")
        assert(has(G.printed, "^%[NOM%] debug zumbi não achado"), table.concat(G.printed, "\n"))
    end) end,
    -- dedicado: o servidor não move a cópia dele; manda debugMove a todos e o dono move
    debug_pull_dedicated_broadcasts = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local p = G.player({ x = 100, y = 100 })
        G.zombie({ x = 105, y = 100, id = 1, online = 8 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "pull", id = 8, x = 100, y = 100, z = 0 })
        assert(#G.moves == 0, "servidor moveu a cópia dele")
        local c = G.sentServer[#G.sentServer - 1]
        assert(c and c.player == nil and c.module == "NevoaEOutroMundo" and c.command == "debugMove"
            and c.args.id == 8 and c.args.x == 100 and c.args.y == 100 and c.args.z == 0, "não mandou debugMove a todos")
        -- sem permissão, nada
        local weak = G.player({ x = 100, y = 100, cap = false })
        local n = #G.sentServer
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", weak, { op = "pull", id = 8, x = 100, y = 100, z = 0 })
        assert(#G.sentServer == n, "sem permissão puxou")
        -- destino longe de quem pediu (pedido montado à mão) é recusado
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "pull", id = 8, x = 140, y = 100, z = 0 })
        for _, s in ipairs(G.sentServer) do
            assert(not (s.command == "debugMove" and s.args.x == 140), "puxou pra longe do jogador")
        end
    end) end,
    -- review final da 0033 (M4): sem ID de rede ninguém acharia o zumbi; o dedicado avisa
    debug_pull_dedicated_without_online_id_fails = function() run(function()
        local G = setup({ server = true, loadClient = false })
        local p = G.player({ x = 100, y = 100 })
        G.zombie({ x = 105, y = 100, id = 1 })
        G.fire("OnClientCommand", "NevoaEOutroMundo", "debug", p, { op = "pull", id = -1, x = 100, y = 100, z = 0 })
        for _, s in ipairs(G.sentServer) do assert(s.command ~= "debugMove", "mandou debugMove sem ID de rede") end
        local r = G.sentServer[#G.sentServer]
        assert(r and r.player == p and r.command == "debugReply" and r.args.msg:find("sem ID de rede", 1, true),
            "resposta: " .. tostring(r and r.args.msg))
    end) end,
    -- o servidor já conferiu a permissão: o dono move mesmo sem -debug no cliente dele
    debug_move_owner_without_debug_moves = function() run(function()
        local G = setup({ client = true, debug = false, loadServer = false })
        G.player({ x = 100, y = 100 })
        local mine = G.zombie({ x = 105, y = 100, id = 1, online = 8 })
        assert(NOM_Debug == nil)
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugMove", { id = 8, x = 100, y = 100, z = 0 })
        assert(#G.moves == 1 and G.moves[1].z == mine, "dono sem -debug não moveu")
    end) end,
    debug_move_only_owner_moves = function() run(function()
        local G = setup({ client = true, loadServer = false })
        G.player({ x = 100, y = 100 })
        local mine = G.zombie({ x = 105, y = 100, id = 1, online = 8 })
        G.zombie({ x = 106, y = 100, id = 2, online = 9, remote = true })
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugMove", { id = 9, x = 100, y = 100, z = 0 })
        assert(#G.moves == 0, "cópia remota moveu")
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugMove", { id = 8, x = 100, y = 100, z = 0 })
        assert(#G.moves == 1 and G.moves[1].z == mine and G.moves[1].x == 100, "dono não moveu")
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugMove", { id = 8, x = "a", y = 1, z = 0 })
        G.fire("OnServerCommand", "NevoaEOutroMundo", "debugMove", { id = -1, x = 1, y = 1, z = 0 })
        assert(#G.moves == 1, "aceitou lixo")
    end) end,
    nom_wind_calls_render_param = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local calls = {}
        NOMRender_setParam = function(i, v) calls[#calls + 1] = i .. "=" .. v end
        NOM.wind(true)
        NOM.wind(false)
        NOM.wind() -- inverte o último mandado (false → true)
        NOM.wind()
        NOMRender_setParam = nil
        assert(table.concat(calls, ",") == "11=1,11=0,11=1,11=0", table.concat(calls, ","))
    end) end,
    nom_wind_without_mod3 = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOMRender_setParam = nil
        NOM.wind(true)
        assert(has(G.printed, "^%[NOM%] debug vento precisa do mod Volumétrica %(mod3%)"), table.concat(G.printed, "\n"))
    end) end,
    nom_help_has_new_commands_on_top_and_30s = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local order = { "setFog", "setRedFog", "setBlackFog", "setEndFog", "getZombie", "turnZombie", "godMode", "wind" }
        for i, name in ipairs(order) do
            assert(NOM[name] and NOM.HELP[i][1]:find("^NOM%." .. name .. "%("), "help fora de ordem: " .. name)
        end
        local fogLine
        for _, h in ipairs(NOM.HELP) do if h[1]:find("^NOM%.fog%(") then fogLine = h[2] end end
        assert(fogLine:find("sobe", 1, true) and fogLine:find("30 s", 1, true) and not fogLine:find("15 s", 1, true), fogLine)
        local setFogLine = NOM.HELP[1][2]
        assert(setFogLine:find("sobe", 1, true) and setFogLine:find("30 s", 1, true), setFogLine)
        local all = {}
        for _, h in ipairs(NOM.HELP) do all[#all + 1] = h[2] end
        assert(table.concat(all, "\n"):find("1 estalador", 1, true), "help sem a numeração do turnZombie")
    end) end,
    -- sprint 0035, Tarefa 4b: quantos sprites próprios do Outro Mundo estão registrados (e quais
    -- PNG faltam); registra de novo se o mundo mudou (o ensure é barato na mesma sessão)
    nom_own_sprites_reports_count = function() run(function()
        local G = setup()
        local ensured = 0
        NOM_OwnSprites = {
            ensure = function() ensured = ensured + 1; return 48 end,
            total = function() return 50 end,
            missing = function() return { "media/textures/NOM/OutroMundo/a.png", "media/textures/NOM/OutroMundo/b.png" } end,
        }
        NOM.ownSprites()
        NOM_OwnSprites = nil
        assert(ensured == 1, "não chamou o ensure")
        assert(has(G.printed, "^%[NOM%] debug sprites próprios: 48 de 50"), table.concat(G.printed, "\n"))
        assert(has(G.printed, "sem textura: media/textures/NOM/OutroMundo/b%.png"), table.concat(G.printed, "\n"))
        G.printed = {}
        NOM.ownSprites()
        assert(has(G.printed, "^%[NOM%] debug sprites próprios: NOM_OwnSprites não carregou"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0036: uma onda de perambular agora; quem decide é o servidor (névoa aberta)
    nom_wander_asks_server = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local waves = {}
        NOM_WanderServer = { wave = function(why) waves[#waves + 1] = why; return 77 end }
        NOM.wander()
        assert(#waves == 0 and has(G.printed, "^%[NOM%] debug perambular precisa de névoa aberta"),
            table.concat(G.printed, "\n"))
        NOM_World.fog = true
        G.printed = {}
        NOM.wander()
        NOM_WanderServer = nil
        assert(#waves == 1 and waves[1] == "debug", "ondas: " .. #waves)
        assert(has(G.printed, "^%[NOM%] debug perambular onda semente=77"), table.concat(G.printed, "\n"))
    end) end,
    -- review final da 0036: com a opção FogWander desligada, a onda não sai; diz por quê
    nom_wander_refuses_when_option_off = function() run(function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local waves = {}
        NOM_WanderServer = { wave = function(why) waves[#waves + 1] = why; return 77 end }
        NOM_World.fog = true
        SandboxVars.NevoaEOutroMundo = { FogWander = false }
        NOM.wander()
        NOM_WanderServer = nil
        assert(#waves == 0, "mandou onda com o perambular desligado")
        assert(has(G.printed, "^%[NOM%] debug perambular desligado na opção FogWander"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0037: um estalo do sonar agora; quem decide é o servidor (o Estalador mais perto
    -- de quem pediu, ou o anel no próprio jogador)
    nom_sonar_asks_server = function() run(function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        local asked = {}
        NOM_SonarServer = { force = function(who) asked[#asked + 1] = who; return "sonar estalador x=3 y=4 dist=5" end }
        NOM.sonar()
        NOM_SonarServer = nil
        assert(#asked == 1 and asked[1] == p, "não pediu pelo jogador")
        assert(has(G.printed, "^%[NOM%] debug sonar estalador x=3 y=4 dist=5"), table.concat(G.printed, "\n"))
        G.printed = {}
        NOM.sonar()
        assert(has(G.printed, "^%[NOM%] debug sonar não carregou"), table.concat(G.printed, "\n"))
    end) end,
    -- sprint 0036: cegos da visão curta e a última onda, neste processo (quem simula)
    nom_blind_reports_counts = function() run(function()
        local G = setup()
        NOM_VariantAI = { counts = function() return { common = 5, estalador = 1, watched = 2, on = true } end }
        NOM_Wander = { last = { groups = { 1, 2 }, candidates = 9, players = 1, size = 300 } }
        NOM.blind()
        NOM_VariantAI, NOM_Wander = nil, nil
        assert(has(G.printed, "^%[NOM%] debug visão curta ligada=true raio=4 cegos=5 vigiados=2 estaladores=1"),
            table.concat(G.printed, "\n"))
        assert(has(G.printed, "^%[NOM%] debug perambular última zumbis=2 candidatos=9 jogadores=1 lista=300"),
            table.concat(G.printed, "\n"))
        G.printed = {}
        NOM.blind()
        assert(has(G.printed, "^%[NOM%] debug visão curta: NOM_VariantAI não carregou"), table.concat(G.printed, "\n"))
    end) end,
    nom_panel_calls_panel_toggle = function() run(function()
        local G = setup()
        local n = 0
        NOM_DebugPanel = { toggle = function() n = n + 1 end }
        NOM.panel()
        NOM_DebugPanel = nil
        NOM.panel()
        assert(n == 1)
    end) end,
}
