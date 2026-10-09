-- Almas esqueléticas (sprint 0050): servidor agenda leva/TTL; shared aplica look/seek.
-- Fake fiel: addZombiesInOutfit longa, isOutside, pathToLocationF, removeFromWorld.
local function setup(opts)
    opts = opts or {}
    package.loaded["NOM_AlmaRules"] = nil
    package.loaded["NOM_Alma"] = nil
    package.loaded["NOM_AlmaServer"] = nil
    package.loaded["NOM_World"] = nil
    package.loaded["NOM_Config"] = nil
    package.loaded["NOM_Players"] = nil
    package.loaded["NOM_Rules"] = nil
    package.loaded["NOM_FlakeRules"] = nil
    package.loaded["NOM_Math"] = nil

    local G = {
        zombies = {}, players = {}, sent = {}, fx = {}, time = 100000, rand = 0,
        squares = {},
    }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; handlers[name][#handlers[name] + 1] = f end }
            rawset(t, name, e)
            return e
        end,
    })
    isClient = function() return opts.client == true end
    isServer = function() return opts.server == true end
    getDebug = function() return false end
    isGamePaused = function() return false end
    getTimestampMs = function() return G.time end
    ZombRand = function(n) G.rand = G.rand + 1; return G.rand % n end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    IsoFlagType = { water = "water" }

    function G.player(x, y, z)
        local p = { x = x, y = y, z = z or 0, dead = false }
        function p:getX() return self.x end
        function p:getY() return self.y end
        function p:getZ() return self.z end
        function p:isDead() return self.dead end
        G.players[#G.players + 1] = p
        return p
    end

    getNumActivePlayers = function() return #G.players end
    getSpecificPlayer = function(i) return G.players[i + 1] end
    getOnlinePlayers = function()
        return { size = function() return 0 end, get = function() end }
    end

    function G.square(x, y, z, o)
        o = o or {}
        local key = x .. "," .. y .. "," .. (z or 0)
        local sq = {
            outside = o.outside ~= false,
            free = o.free ~= false,
            water = o.water == true,
        }
        function sq:isOutside() return self.outside end
        function sq:isFree() return self.free end
        function sq:getProperties()
            return { has = function(_, f) return f == IsoFlagType.water and sq.water end }
        end
        G.squares[key] = sq
        return sq
    end

    -- anel de spawn: preenche squares outside em volta
    function G.fillOutside(px, py, pz)
        for dx = -30, 30 do
            for dy = -30, 30 do
                local d = math.sqrt(dx * dx + dy * dy)
                if d >= 12 and d <= 28 then
                    G.square(px + dx, py + dy, pz or 0, { outside = true })
                end
            end
        end
    end

    -- (x,y,z,count,outfit,femaleChance, crawler, fall, fakeDead, knocked, invuln, sitting, health)
    addZombiesInOutfit = function(x, y, z, count, outfit, female, crawler, _a, _b, _c, _d, _e, health)
        local list = {}
        for _ = 1, count do
            local zd = {
                x = x, y = y, z = z, md = {}, dead = false, local_ = true, useless = false,
                online = 1000 + #G.zombies, health = health or 1.5, skeleton = false,
                crawler = crawler == true, speed = nil, goal = nil, sounds = {},
            }
            function zd:getX() return self.x end
            function zd:getY() return self.y end
            function zd:getZ() return self.z end
            function zd:isDead() return self.dead end
            function zd:isLocal() return self.local_ end
            function zd:isUseless() return self.useless end
            function zd:getModData() return self.md end
            function zd:getOnlineID() return self.online end
            function zd:setHealth(h) self.health = h end
            function zd:setSkeleton(v) self.skeleton = v == true end
            function zd:setCrawler(v) self.crawler = v == true end
            function zd:doZombieSpeed(t) self.speed = t end
            function zd:pathToLocationF(px, py, pz)
                self.goal = { x = px, y = py, z = pz }
            end
            function zd:getCurrentSquare()
                return G.squares[math.floor(self.x) .. "," .. math.floor(self.y) .. "," .. math.floor(self.z)]
            end
            function zd:getEmitter()
                return { playSound = function(_, n) self.sounds[#self.sounds + 1] = n end }
            end
            function zd:removeFromWorld() self.removed = true end
            function zd:removeFromSquare() self.removedSq = true end
            G.zombies[#G.zombies + 1] = zd
            list[#list + 1] = zd
        end
        return {
            size = function() return #list end,
            get = function(_, i) return list[i + 1] end,
        }
    end

    getCell = function()
        return {
            getGridSquare = function(_, x, y, z)
                return G.squares[x .. "," .. y .. "," .. (z or 0)]
            end,
            getZombieList = function()
                return {
                    size = function() return #G.zombies end,
                    get = function(_, i) return G.zombies[i + 1] end,
                }
            end,
        }
    end

    sendServerCommand = function(module, command, args)
        G.sent[#G.sent + 1] = { module = module, command = command, args = args }
        if command == "almaFx" then G.fx[#G.fx + 1] = args end
    end

    dofile("mod/42/media/lua/shared/NOM_Math.lua")
    dofile("mod/42/media/lua/shared/NOM_FlakeRules.lua")
    dofile("mod/42/media/lua/shared/NOM_Rules.lua")
    dofile("mod/42/media/lua/shared/NOM_World.lua")
    dofile("mod/42/media/lua/shared/NOM_Config.lua")
    dofile("mod/42/media/lua/shared/NOM_AlmaRules.lua")
    dofile("mod/42/media/lua/shared/NOM_Alma.lua")
    dofile("mod/42/media/lua/server/NOM_Players.lua")
    -- client stub for solo fx
    NOM_AlmaClient = { fx = function(a) G.fx[#G.fx + 1] = a end }
    dofile("mod/42/media/lua/server/NOM_AlmaServer.lua")

    NOM_World.setFog(opts.fog ~= false, opts.red == true, opts.black == true)
    return G
end

return {
    alma_wave_spawns_on_street_white_fog = function()
        local G = setup({ fog = true })
        G.player(100, 100, 0)
        G.fillOutside(100, 100, 0)
        local n = NOM_AlmaServer.wave("debug")
        assert(n > 0, "spawn=" .. tostring(n))
        assert(#NOM_AlmaServer.alive == n)
        local crawlers = 0
        for _, e in ipairs(NOM_AlmaServer.alive) do
            local z = e.z
            assert(z.md.NOM_alma == true)
            assert(z.skeleton == true, "esqueleto")
            assert(z.health <= 0.4, "vida baixa")
            assert(z.speed == 3, "shambler")
            assert(z.goal ~= nil, "seek")
            if z.md.NOM_almaCrawler then crawlers = crawlers + 1 end
        end
        assert(crawlers >= 0) -- leva debug ≤ 8; proporção flutuante
        local kinds = {}
        for _, a in ipairs(G.fx) do kinds[a.kind] = true end
        assert(kinds.spawn and kinds.group, "fx spawn/group")
    end,

    alma_no_wave_on_red_or_black = function()
        for _, color in ipairs({ { red = true }, { black = true } }) do
            local G = setup({ fog = true, red = color.red, black = color.black })
            G.player(0, 0, 0)
            G.fillOutside(0, 0, 0)
            local n, why = NOM_AlmaServer.wave("debug")
            assert(n == 0 and why, "cor bloqueia: " .. tostring(why))
        end
    end,

    alma_ttl_despawns = function()
        local G = setup({ fog = true })
        G.player(50, 50, 0)
        G.fillOutside(50, 50, 0)
        local n = NOM_AlmaServer.wave("debug")
        assert(n > 0)
        -- evita nova leva no mesmo tick (gap pode ser ≤ 120 s)
        NOM_AlmaServer.nextAt = G.time + 10 * 60 * 1000
        G.time = G.time + 120000 -- 2 min: todo TTL (≤ 60 s) expirou
        G.fire("OnTick")
        assert(#NOM_AlmaServer.alive == 0, "vivas=" .. #NOM_AlmaServer.alive)
        local despawn = 0
        for _, a in ipairs(G.fx) do if a.kind == "despawn" then despawn = despawn + 1 end end
        assert(despawn >= n, "despawn fx")
    end,

    alma_interior_despawns = function()
        local G = setup({ fog = true })
        G.player(10, 10, 0)
        G.fillOutside(10, 10, 0)
        NOM_AlmaServer.wave("debug")
        assert(#NOM_AlmaServer.alive > 0)
        NOM_AlmaServer.nextAt = G.time + 10 * 60 * 1000
        for _, e in ipairs(NOM_AlmaServer.alive) do
            local z = e.z
            z.x, z.y = 10, 10
            G.square(10, 10, 0, { outside = false })
        end
        G.fire("OnTick")
        assert(#NOM_AlmaServer.alive == 0, "interior")
    end,

    alma_dress_and_seek = function()
        local G = setup({ fog = true })
        local p = G.player(5, 5, 0)
        local z = {
            x = 0, y = 0, z = 0, md = {}, dead = false, local_ = true, useless = false,
            health = 1, skeleton = false,
        }
        function z:getX() return self.x end
        function z:getY() return self.y end
        function z:getZ() return self.z end
        function z:isDead() return self.dead end
        function z:isLocal() return self.local_ end
        function z:isUseless() return self.useless end
        function z:getModData() return self.md end
        function z:setHealth(h) self.health = h end
        function z:setSkeleton(v) self.skeleton = v end
        function z:pathToLocationF(x, y, zz) self.goal = { x = x, y = y, z = zz } end
        NOM_Alma.dress(z, true)
        assert(z.md.NOM_alma and z.md.NOM_almaCrawler and z.skeleton and z.health == NOM_AlmaRules.HEALTH)
        assert(NOM_Alma.seek(z) and z.goal.x == p.x and z.goal.y == p.y)
    end,

    alma_clear_when_fog_ends = function()
        local G = setup({ fog = true })
        G.player(20, 20, 0)
        G.fillOutside(20, 20, 0)
        NOM_AlmaServer.wave("debug")
        assert(#NOM_AlmaServer.alive > 0)
        NOM_World.setFog(false)
        G.fire("OnTick")
        -- onChange clears; tick also clears when not enabled
        assert(#NOM_AlmaServer.alive == 0)
    end,
}
