-- Perambular (sprint 0036): shared/NOM_Wander.lua (quem simula) e server/NOM_WanderServer.lua
-- (quem decide) contra um jogo falso.
-- * z:pathToLocationF(x, y, z): IsoZombie.pathToLocationF (bytecode 0–47) recusa só com
--   allowRepathDelay > 0 em quem já anda; senão IsoGameCharacter.pathToLocationF (0–17) +
--   pathToAux (0–274) ligam bPathfind ou bMoving: o zumbi passa a andar (isMoving).
-- * getCell():getGridSquare(x, y, z) nil fora do carregado; square:isFree(false)
--   (client/ISUI/ISWorldObjectContextMenu.lua:2199); getProperties():has(IsoFlagType.water)
--   (server/Fishing/BuildingObjects/FishingNet.lua:31).
-- * getNumActivePlayers/getSpecificPlayer: jogadores locais (NOM_SirenFreeze).
-- * sendServerCommand(module, command, args) sem jogador vai a todos (pz-api-notes §7).
-- * Toda chamada de método no zumbi e na lista conta em G.calls (custo Java da onda).
local function setup(opts)
    opts = opts or {}
    local G = { zombies = {}, players = {}, sent = {}, calls = 0, blocked = {}, water = {}, rand = 0 }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    function G.player(x, y, z)
        local p = { x = x, y = y, z = z or 0, dead = false }
        function p:getX() return self.x end
        function p:getY() return self.y end
        function p:getZ() return self.z end
        function p:isDead() return self.dead end
        G.players[#G.players + 1] = p
        return p
    end
    -- jogador de outro cliente (só na lista online)
    function G.remote(x, y, z)
        local p = G.player(x, y, z)
        table.remove(G.players)
        G.remotes[#G.remotes + 1] = p
        return p
    end
    function G.zombie(o)
        local z = { x = o.x, y = o.y, z = o.z or 0, md = {}, target = o.target, useless = o.useless == true,
            remote = o.remote == true, dead = o.dead == true, moving = o.moving == true, outfit = o.outfit,
            id = o.id or 0, fakeDead = o.fakeDead == true, sitting = o.sitting == true }
        local function def(name, fn)
            z[name] = function(...) G.calls = G.calls + 1; return fn(...) end
        end
        def("getX", function(self) return self.x end)
        def("getY", function(self) return self.y end)
        def("getZ", function(self) return self.z end)
        def("getTarget", function(self) return self.target end)
        def("isLocal", function(self) return not self.remote end)
        def("isDead", function(self) return self.dead end)
        def("isUseless", function(self) return self.useless end)
        def("isMoving", function(self) return self.moving end)
        def("getModData", function(self) return self.md end)
        def("getOutfitName", function(self) return self.outfit end)
        def("hasModData", function(self) return next(self.md) ~= nil end)
        def("isFakeDead", function(self) return self.fakeDead end)
        def("isSitOnGround", function(self) return self.sitting end)
        -- ID 0: zumbi sem outfit, nunca variante (NOM_VariantRules.variant)
        def("getPersistentOutfitID", function(self) return self.id end)
        def("pathToLocationF", function(self, x, y, zz)
            self.goal = { x = x, y = y, z = zz }
            self.moving = true
        end)
        G.zombies[#G.zombies + 1] = z
        return z
    end
    G.sandbox = opts.sandbox or {}
    SandboxVars = { NevoaEOutroMundo = G.sandbox }
    IsoFlagType = { water = "water" }
    isClient = function() return opts.client == true end
    isServer = function() return opts.server == true end
    getDebug = function() return false end
    instanceof = function(o, cls) return o.class == cls end
    ZombRand = function(n) return G.rand % n end
    getCore = function() return { getGameMode = function() return "Sandbox" end } end
    getTimestampMs = function() return 0 end
    sendServerCommand = function(module, command, args)
        G.sent[#G.sent + 1] = { module = module, command = command, args = args }
    end
    getNumActivePlayers = function() return #G.players end
    getSpecificPlayer = function(i) return G.players[i + 1] end
    -- getOnlinePlayers: no cliente, os jogadores que ele conhece (o local também); no solo,
    -- lista vazia (pz-api-notes, NOM_SirenFreeze)
    G.remotes = {}
    getOnlinePlayers = function()
        local all = {}
        if isClient() then
            for _, p in ipairs(G.players) do all[#all + 1] = p end
            for _, p in ipairs(G.remotes) do all[#all + 1] = p end
        end
        return { size = function() return #all end, get = function(_, i) return all[i + 1] end }
    end
    getCell = function()
        return {
            getZombieList = function()
                return { size = function() G.calls = G.calls + 1; return #G.zombies end,
                    get = function(_, i) G.calls = G.calls + 1; return G.zombies[i + 1] end }
            end,
            getGridSquare = function(_, x, y, zz)
                if G.blocked[x .. "," .. y] == "unloaded" then return nil end
                return {
                    isFree = function() return G.blocked[x .. "," .. y] == nil end,
                    getProperties = function()
                        return { has = function(_, f) return f == "water" and G.water[x .. "," .. y] == true end }
                    end,
                }
            end,
        }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_FogState", "NOM_NightStats", "NOM_VariantAI", "NOM_Carpideira", "NOM_SirenFreeze",
        "NOM_Wander", "NOM_WanderRules", "NOM_WanderServer", "NOM_World", "NOM_SemRosto" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_Wander"
    NOM_FogState.set(opts.fog ~= false, 1)
    return G
end

-- zumbis parados espalhados a 8–20 tiles do jogador em (0, 0)
local function ring(G, n, extra)
    for i = 1, n do
        local o = { x = 8 + (i % 13), y = (i % 7) - 3 }
        for k, v in pairs(extra or {}) do o[k] = v end
        G.zombie(o)
    end
end

local function walkers(G)
    local out = {}
    for _, z in ipairs(G.zombies) do
        if z.goal then out[#out + 1] = z end
    end
    return out
end

return {
    -- critério: uma onda manda 1 a 3 zumbis parados andarem, pra longe do jogador
    wander_wave_sends_idle_group = function()
        local G = setup()
        G.player(0, 0)
        ring(G, 20)
        local sizes = {}
        for seed = 1, 40 do
            for _, z in ipairs(G.zombies) do z.goal, z.moving = nil, false end
            NOM_Wander.wave(seed)
            local w = walkers(G)
            assert(#w <= NOM_WanderRules.GROUP_MAX, "grupo grande: " .. #w)
            sizes[#w] = true
            for _, z in ipairs(w) do
                local d = math.sqrt(z.goal.x * z.goal.x + z.goal.y * z.goal.y)
                assert(d >= NOM_WanderRules.DEST_MIN, "destino perto do jogador: " .. d)
                assert(z.goal.x ~= math.floor(z.goal.x), "destino fora do centro do tile")
            end
        end
        assert(sizes[1] or sizes[2] or sizes[3], "ninguém andou")
    end,
    -- quem tem regra ou não está livre nunca sai
    wander_skips_busy_and_ruled = function()
        local G = setup()
        local p = G.player(0, 0)
        local busy = {
            G.zombie({ x = 10, y = 0, target = p }),
            G.zombie({ x = 10, y = 1, moving = true }),
            G.zombie({ x = 10, y = 2, useless = true }),
            G.zombie({ x = 10, y = 3, remote = true }),
            G.zombie({ x = 10, y = -1, dead = true }),
        }
        local eco = G.zombie({ x = 11, y = 0 })
        eco.md.NOM_eco = true
        busy[#busy + 1] = eco
        local ruled = {}
        for i = 1, 5 do ruled[i] = G.zombie({ x = 12, y = i - 3 }) end
        NOM_NightStats.variants[ruled[1]] = "corredor"
        NOM_VariantAI.blinded[ruled[2]] = { common = true, n = 0 }
        NOM_VariantAI.watched[ruled[3]] = 0
        NOM_Carpideira.still[ruled[4]] = true
        NOM_SirenFreeze.frozen[ruled[5]] = true
        -- Sem-rosto de verdade: o ID sorteia no período, fora de variants (review final da 0036)
        local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
        for seed = 1, 5000 do
            local id = 11 * 65536 + seed
            if NOM_VariantRules.semRosto(id, 1, c) then
                busy[#busy + 1] = G.zombie({ x = 11, y = #busy - 3, id = id })
                if #busy >= 9 then break end
            end
        end
        local before = G.calls
        for seed = 1, 60 do NOM_Wander.wave(seed) end
        for _, z in ipairs(busy) do assert(z.goal == nil, "andou quem estava ocupado") end
        for _, z in ipairs(ruled) do assert(z.goal == nil, "andou quem tem regra") end
        -- os com regra não custam nada: só o get da lista
        assert(G.calls > before)
    end,
    -- review final da 0036: deitado fingindo de morto e sentado no chão ficam onde estão
    -- (z:isFakeDead(), z:isSitOnGround(): NOM_NightStats, log do -debug)
    wander_skips_fake_dead_and_sitting = function()
        local G = setup()
        G.player(0, 0)
        ring(G, 10, { fakeDead = true })
        ring(G, 10, { sitting = true })
        for seed = 1, 40 do NOM_Wander.wave(seed) end
        assert(#walkers(G) == 0, "levantou quem fingia de morto ou estava sentado")
    end,
    -- sem névoa, na sirene, opção desligada, vermelha ou preta: nada (0049: só branca)
    wander_needs_fog_and_option = function()
        for _, case in ipairs({
            { fog = false }, { siren = true }, { sandbox = { FogWander = false } },
            { red = true }, { black = true },
        }) do
            local G = setup(case)
            if case.siren then NOM_SirenFreeze.active = true end
            if case.red then NOM_FogState.red = true end
            if case.black then NOM_FogState.black = true end
            G.player(0, 0)
            ring(G, 20)
            for seed = 1, 20 do assert(NOM_Wander.wave(seed) == nil) end
            assert(#walkers(G) == 0, "andou sem poder")
        end
    end,
    -- sprint 0049: na branca o Estalador pode perambular (100% variantes)
    wander_allows_estalador_on_white = function()
        local G = setup()
        G.player(0, 0)
        local z = G.zombie({ x = 10, y = 0 })
        NOM_NightStats.variants[z] = "estalador"
        local moved = false
        for seed = 1, 80 do
            NOM_Wander.wave(seed)
            if z.goal then moved = true break end
        end
        assert(moved, "Estalador na branca não perambulou")
    end,
    -- destino em parede, água ou fora do carregado não serve
    wander_respects_floor = function()
        local G = setup()
        G.player(0, 0)
        ring(G, 20)
        for x = -60, 60 do
            for y = -60, 60 do G.blocked[x .. "," .. y] = (x + y) % 2 == 0 and "unloaded" or "wall" end
        end
        for seed = 1, 30 do NOM_Wander.wave(seed) end
        assert(#walkers(G) == 0, "foi pra parede")
        G.blocked = {}
        for x = -60, 60 do
            for y = -60, 60 do G.water[x .. "," .. y] = true end
        end
        for seed = 1, 30 do NOM_Wander.wave(seed) end
        assert(#walkers(G) == 0, "foi pra água")
    end,
    -- review final da 0036: no cliente de MP o destino respeita o jogador de outro cliente
    -- (getOnlinePlayers), e só o local puxa grupo
    wander_respects_remote_player = function()
        local G = setup({ client = true })
        G.player(0, 0)
        local other = G.remote(18, 0)
        ring(G, 30)
        local n = 0
        for seed = 1, 60 do
            for _, z in ipairs(G.zombies) do z.goal, z.moving = nil, false end
            NOM_Wander.wave(seed)
            for _, z in ipairs(walkers(G)) do
                n = n + 1
                local dx, dy = z.goal.x - other.x, z.goal.y - other.y
                assert(math.sqrt(dx * dx + dy * dy) >= NOM_WanderRules.DEST_MIN, "destino em cima do jogador remoto")
            end
        end
        assert(n > 0, "ninguém andou: teste não prova nada")
        local G2 = setup({ client = true })
        G2.remote(0, 0)
        ring(G2, 20)
        for seed = 1, 20 do NOM_Wander.wave(seed) end
        assert(#walkers(G2) == 0, "o jogador remoto puxou grupo")
    end,
    -- cliente de MP: o Eco vem sem o modData do servidor, só com o outfit (NOM_NightStats.isEco)
    wander_skips_eco_by_outfit_on_mp = function()
        local G = setup({ client = true })
        G.player(0, 0)
        ring(G, 20, { outfit = "NOM_Eco" })
        for seed = 1, 40 do NOM_Wander.wave(seed) end
        assert(#walkers(G) == 0, "Eco perambulou no cliente de MP")
    end,
    -- custo da onda com 300 zumbis (review final da 0036): fatiada em ticks de até ~600
    -- chamadas, terminando em no máximo 3 ticks. Perto (para em SCAN_MAX candidatos), longe
    -- (a lista inteira) e misturado (o pior: muitos olhados e muitos candidatos)
    wander_wave_cost_300 = function()
        local report = {}
        for _, kind in ipairs({ "perto", "longe", "misturado" }) do
            local G = setup()
            G.player(0, 0)
            for i = 1, 300 do
                local near = kind == "perto" or (kind == "misturado" and i % 4 == 0)
                local r = near and 8 + (i % 20) or 50 + (i % 20)
                G.zombie({ x = r, y = (i % 11) - 5 })
            end
            local worst, ticks, total = 0, 0, 0
            for seed = 1, 20 do
                for _, z in ipairs(G.zombies) do z.goal, z.moving = nil, false end
                local before = G.calls
                NOM_Wander.wave(seed)
                local n = 1
                worst = math.max(worst, G.calls - before)
                total = total + G.calls - before
                while NOM_Wander.pending() do
                    before = G.calls
                    G.fire("OnTick")
                    n = n + 1
                    worst = math.max(worst, G.calls - before)
                    total = total + G.calls - before
                    assert(n <= 3, kind .. ": a onda passou de 3 ticks")
                end
                ticks = math.max(ticks, n)
            end
            report[#report + 1] = string.format("%s pior tick %d, %d ticks, %.0f por onda", kind, worst, ticks, total / 20)
            assert(worst <= 650, kind .. ": pior tick " .. worst)
        end
        print("[budget] perambular (300 zumbis): " .. table.concat(report, "; "))
    end,
    -- a onda fatiada não termina sem névoa: a névoa que fecha no meio cancela
    wander_sliced_wave_stops_without_fog = function()
        local G = setup()
        G.player(0, 0)
        for i = 1, 300 do G.zombie({ x = 50 + (i % 20), y = (i % 11) - 5 }) end
        ring(G, 10)
        NOM_Wander.wave(7)
        assert(NOM_Wander.pending(), "300 zumbis longe deviam fatiar a onda")
        NOM_FogState.set(false, 1)
        for _ = 1, 5 do G.fire("OnTick") end
        assert(not NOM_Wander.pending() and #walkers(G) == 0, "a onda seguiu sem névoa")
    end,
    -- servidor: a cada gap minutos com névoa, uma onda; no solo aplica aqui, no dedicado manda
    wander_server_solo_applies = function()
        local G = setup()
        dofile("mod/42/media/lua/server/NOM_WanderServer.lua")
        NOM_World.fog = true
        G.player(0, 0)
        ring(G, 20)
        for _ = 1, NOM_WanderRules.MAX_GAP * 3 do G.fire("EveryOneMinute") end
        assert(NOM_WanderServer.waves >= 3, "ondas: " .. NOM_WanderServer.waves)
        assert(#walkers(G) > 0, "a onda do solo não andou ninguém")
        assert(#G.sent == 0, "solo mandou comando")
    end,
    wander_server_dedicated_sends_seed = function()
        local G = setup({ server = true })
        dofile("mod/42/media/lua/server/NOM_WanderServer.lua")
        NOM_World.fog = true
        G.rand = 1234
        -- o sorteio do intervalo dá o mínimo com ZombRand fixo: uma onda em MIN_GAP minutos
        for _ = 1, NOM_WanderRules.MIN_GAP do G.fire("EveryOneMinute") end
        assert(#G.sent == 1 and G.sent[1].command == "wander" and type(G.sent[1].args.seed) == "number",
            "comandos: " .. #G.sent)
        assert(NOM_WanderServer.waves == 1 and #walkers(G) == 0, "o dedicado aplicou em vez de mandar")
    end,
    wander_server_waits_for_fog_and_option = function()
        local G = setup({ server = true })
        dofile("mod/42/media/lua/server/NOM_WanderServer.lua")
        NOM_World.fog = false
        for _ = 1, 40 do G.fire("EveryOneMinute") end
        assert(#G.sent == 0, "onda sem névoa")
        NOM_World.fog = true
        G.sandbox.FogWander = false
        for _ = 1, 40 do G.fire("EveryOneMinute") end
        assert(#G.sent == 0, "onda com a opção desligada")
        G.sandbox.FogWander = true
        NOM_World.red = true
        for _ = 1, 40 do G.fire("EveryOneMinute") end
        assert(#G.sent == 0, "onda na vermelha")
        NOM_World.red = false
        NOM_World.black = true
        for _ = 1, 40 do G.fire("EveryOneMinute") end
        assert(#G.sent == 0, "onda na preta")
    end,
}
