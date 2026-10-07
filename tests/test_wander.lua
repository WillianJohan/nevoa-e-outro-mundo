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
    function G.zombie(o)
        local z = { x = o.x, y = o.y, z = o.z or 0, md = {}, target = o.target, useless = o.useless == true,
            remote = o.remote == true, dead = o.dead == true, moving = o.moving == true, outfit = o.outfit }
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
        for i = 1, 6 do ruled[i] = G.zombie({ x = 12, y = i - 3 }) end
        NOM_NightStats.variants[ruled[1]] = "corredor"
        NOM_VariantAI.blinded[ruled[2]] = { common = true, n = 0 }
        NOM_VariantAI.watched[ruled[3]] = 0
        NOM_Carpideira.still[ruled[4]] = true
        NOM_SirenFreeze.frozen[ruled[5]] = true
        NOM_NightStats.variants[ruled[6]] = "semrosto"
        local before = G.calls
        for seed = 1, 60 do NOM_Wander.wave(seed) end
        for _, z in ipairs(busy) do assert(z.goal == nil, "andou quem estava ocupado") end
        for _, z in ipairs(ruled) do assert(z.goal == nil, "andou quem tem regra") end
        -- os com regra não custam nada: só o get da lista
        assert(G.calls > before)
    end,
    -- sem névoa, na sirene ou com a opção desligada, nada
    wander_needs_fog_and_option = function()
        for _, case in ipairs({ { fog = false }, { siren = true }, { sandbox = { FogWander = false } } }) do
            local G = setup(case)
            if case.siren then NOM_SirenFreeze.active = true end
            G.player(0, 0)
            ring(G, 20)
            for seed = 1, 20 do assert(NOM_Wander.wave(seed) == nil) end
            assert(#walkers(G) == 0, "andou sem poder")
        end
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
    -- cliente de MP: o Eco vem sem o modData do servidor, só com o outfit (NOM_NightStats.isEco)
    wander_skips_eco_by_outfit_on_mp = function()
        local G = setup({ client = true })
        G.player(0, 0)
        ring(G, 20, { outfit = "NOM_Eco" })
        for seed = 1, 40 do NOM_Wander.wave(seed) end
        assert(#walkers(G) == 0, "Eco perambulou no cliente de MP")
    end,
    -- custo da onda com 300 zumbis: abaixo do teto de 2500 por atualização, mesmo com
    -- todos perto e parados (para em SCAN_MAX candidatos)
    wander_wave_cost_300 = function()
        for _, near in ipairs({ true, false }) do
            local G = setup()
            G.player(0, 0)
            for i = 1, 300 do
                local r = near and 8 + (i % 20) or 50 + (i % 20)
                G.zombie({ x = r, y = (i % 11) - 5 })
            end
            local worst = 0
            for seed = 1, 20 do
                for _, z in ipairs(G.zombies) do z.goal, z.moving = nil, false end
                local before = G.calls
                NOM_Wander.wave(seed)
                worst = math.max(worst, G.calls - before)
            end
            -- medido na sprint: 404 perto (para em SCAN_MAX), 1201 longe (a lista inteira)
            assert(worst <= 4 * 300 + 8 * NOM_WanderRules.SCAN_MAX, (near and "perto" or "longe") .. ": " .. worst)
        end
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
    end,
}
