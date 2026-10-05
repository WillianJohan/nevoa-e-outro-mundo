-- NOM_Eco contra um jogo falso que IMITA o B42.20 (bytecode) onde importa:
-- * addZombiesInOutfit: createRealZombieAlways dispara OnZombieCreate com o ID
--   de zona ANTES de pôr o zumbi na lista da célula; só depois veste o outfit
--   pedido (dressInPersistentOutfit) e aplica a vida (1.0 na versão de 6 args).
-- * persistentOutfitID: bit 31 = feminino, índice do outfit << 16, semente 1..500;
--   outfit inexistente dá 0.
-- * zumbi que volta de chunk descarregado é objeto novo: modData vazio, só o
--   persistentOutfitID, getOutfitName() nil até alguém vestir, vida da toughness.
-- * morte: DoZombieInventory enche o inventário, OnZombieDead dispara, o corpo
--   nasce ticks depois (pode cair no square vizinho) com o modData copiado.
--   OnDeadBodySpawn não dispara no servidor dedicado: o fake nem tem.
require "NOM_EcoRules"

local ECO_FILE = "mod/42/media/lua/server/NOM_Eco.lua"
local DEFAULT_OUTFITS = { "Agent", "HospitalPatient", "NOM_Eco", "Priest" }

local function jlist(t)
    local l = { items = t or {} }
    function l:size() return #self.items end
    function l:get(i) return self.items[i + 1] end
    function l:add(o) self.items[#self.items + 1] = o end
    function l:remove(o)
        for i, v in ipairs(self.items) do
            if v == o then table.remove(self.items, i); return true end
        end
        return false
    end
    return l
end

local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
end

local function setup(opts)
    opts = opts or {}
    local G = {
        outfits = opts.outfits or DEFAULT_OUTFITS,
        squares = opts.squares or {},
        globalMD = opts.globalMD or {},
        zombies = jlist(),
        players = opts.players or { { x = 100, y = 100, z = 0 } },
        server = opts.server == true,
        sent = {},
        removedCorpses = 0,
        squareCalls = {},
        dying = {},
        seed = 0,
        nextOnline = 1,
        world = { tod = opts.tod or 23 },
    }
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end

    function G.pickOutfit(name, female)
        for i, n in ipairs(G.outfits) do
            if n == name then
                -- o jogo usa Rand.Next(500)+1: dois Ecos com o mesmo ID acontecem
                -- (~19% das noites); G.fixedSeed força isso no teste
                G.seed = G.fixedSeed or (G.seed % 500 + 1)
                local id = i * 65536 + G.seed
                if female then id = id - 2147483648 end
                return id
            end
        end
        return 0
    end
    function G.nameOf(id)
        if id == 0 then return nil end
        local k = math.floor(id / 65536)
        if k < 0 then k = k + 32768 end
        return G.outfits[k]
    end

    function G.square(x, y, z)
        local key = x .. "," .. y .. "," .. z
        local sq = G.squares[key]
        if not sq then
            sq = { x = x, y = y, z = z, bodies = jlist() }
            G.squares[key] = sq
        end
        sq.getX = function() return sq.x end
        sq.getY = function() return sq.y end
        sq.getZ = function() return sq.z end
        sq.getDeadBodys = function() return sq.bodies end
        sq.removeCorpse = function(_, body, _)
            if sq.bodies:remove(body) then
                body.square = nil
                G.removedCorpses = G.removedCorpses + 1
            end
        end
        return sq
    end
    function G.body(x, y, z, extra)
        local sq = G.square(x, y, z or 0)
        local b = { x = x, y = y, z = z or 0, md = {}, animal = false, square = sq }
        for k, v in pairs(extra or {}) do b[k] = v end
        function b:getModData() return self.md end
        function b:hasModData() return next(self.md) ~= nil end
        function b:getSquare() return self.square end
        function b:getX() return self.x end
        function b:getY() return self.y end
        function b:getZ() return self.z end
        function b:isAnimal() return self.animal end
        sq.bodies:add(b)
        return b
    end
    function G.bodiesAt(x, y, z)
        local sq = G.squares[x .. "," .. y .. "," .. (z or 0)]
        return sq and sq.bodies:size() or 0
    end

    function G.zombie(x, y, z, id)
        local zz = { x = x, y = y, z = z, md = {}, outfitID = id, health = 1.5, inv = 0,
            onlineID = G.nextOnline }
        G.nextOnline = G.nextOnline + 1
        function zz:getX() return self.x end
        function zz:getY() return self.y end
        function zz:getZ() return self.z end
        function zz:getModData() return self.md end
        function zz:getPersistentOutfitID() return self.outfitID end
        function zz:dressInPersistentOutfitID(i) self.outfitID = i; self.outfitName = G.nameOf(i) end
        function zz:getOutfitName() return self.outfitName end
        function zz:setHealth(h) self.health = h end
        function zz:getHealth() return self.health end
        function zz:isDead() return self.dead == true end
        function zz:getOnlineID() return self.onlineID end
        function zz:getInventory()
            return { removeAllItems = function() zz.inv = 0 end }
        end
        function zz:removeFromWorld() G.zombies:remove(self); self.removed = true end
        function zz:removeFromSquare() self.offSquare = true end
        return zz
    end
    -- zumbi comum já no mundo (veio do popman)
    function G.normalZombie(x, y, z)
        local zz = G.zombie(x, y, z or 0, G.pickOutfit("Agent", false))
        G.zombies:add(zz)
        return zz
    end

    function G.ecos()
        local out = {}
        for _, zz in ipairs(G.zombies.items) do
            if zz.outfitName == "NOM_Eco" or G.nameOf(zz.outfitID) == "NOM_Eco" then out[#out + 1] = zz end
        end
        return out
    end

    -- chunk descarrega: o zumbi vira virtual, sobra só o persistentOutfitID
    function G.unload(zz)
        G.zombies:remove(zz)
        return zz.outfitID
    end
    -- chunk carrega: createZombieOutsideWorld + OnZombieCreate + entra na lista
    function G.reload(x, y, z, id)
        local zz = G.zombie(x, y, z, id)
        zz.health = 1.5
        fire("OnZombieCreate", zz)
        G.zombies:add(zz)
        return zz
    end

    function G.kill(zz, o)
        o = o or {}
        zz.inv = 3 -- DoZombieInventory
        zz.dead = true
        fire("OnZombieDead", zz)
        G.dying[#G.dying + 1] = { z = zz, ticks = o.delay or 5, dx = o.dx or 0 }
    end
    function G.tick(n)
        for _ = 1, n or 1 do
            for i = #G.dying, 1, -1 do
                local d = G.dying[i]
                d.ticks = d.ticks - 1
                if d.ticks <= 0 then
                    table.remove(G.dying, i)
                    G.zombies:remove(d.z)
                    G.body(math.floor(d.z.x) + d.dx, math.floor(d.z.y), d.z.z, { md = copy(d.z.md), items = d.z.inv })
                end
            end
            fire("OnTick", 0)
        end
    end
    function G.tenMinutes() fire("EveryTenMinutes") end
    function G.setTime(tod)
        G.world.tod = tod
        NOM_World.update(0)
    end

    isClient = function() return false end
    isServer = function() return G.server end
    getDebug = function() return false end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    ModData = {
        getOrCreate = function(name)
            G.globalMD[name] = G.globalMD[name] or {}
            return G.globalMD[name]
        end,
    }
    local function player(p)
        return {
            getX = function() return p.x + 0.5 end,
            getY = function() return p.y + 0.5 end,
            getZ = function() return p.z end,
            isDead = function() return false end,
        }
    end
    getNumActivePlayers = function() return #G.players end
    getSpecificPlayer = function(i) return player(G.players[i + 1]) end
    getOnlinePlayers = function()
        local l = jlist()
        for _, p in ipairs(G.players) do l:add(player(p)) end
        return l
    end
    getCell = function()
        return {
            getGridSquare = function(_, x, y, z)
                local k = x .. "," .. y .. "," .. z
                G.squareCalls[k] = (G.squareCalls[k] or 0) + 1
                local sq = G.squares[x .. "," .. y .. "," .. z]
                return sq and G.square(x, y, z) or nil
            end,
            getZombieList = function() return G.zombies end,
        }
    end
    addZombiesInOutfit = function(x, y, z, count, outfit, femaleChance)
        local out = jlist()
        if opts.zombiesDisabled then return out end
        for i = 1, count do
            local female = (i % 2 == 0) and femaleChance > 0
            local zz = G.zombie(x + 0.5, y + 0.5, z, G.pickOutfit("Agent", female))
            fire("OnZombieCreate", zz)
            G.zombies:add(zz)
            zz:dressInPersistentOutfitID(G.pickOutfit(outfit, female))
            if zz.outfitID == 0 then zz.outfitName = nil end
            zz.health = 1.0
            out:add(zz)
        end
        return out
    end
    sendServerCommand = function(module, command, args)
        G.sent[#G.sent + 1] = { module = module, command = command, args = args }
    end
    getGameTime = function() return { getTimeOfDay = function() return G.world.tod end } end
    getClimateManager = function()
        return { getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })

    NOM_World = nil
    package.loaded["NOM_World"] = nil
    NOM_NightCount = nil
    package.loaded["NOM_NightCount"] = nil
    require "NOM_World"
    dofile(ECO_FILE)
    if not opts.noClock then NOM_World.update(0) end
    return G
end

local function bodies(G, n, x0, y0)
    local out = {}
    for i = 1, n do out[i] = G.body(x0 + (i - 1) % 10, y0 + math.floor((i - 1) / 10), 0) end
    return out
end

return {
    eco_spawns_one_per_body_at_night = function()
        local G = setup()
        local bs = bodies(G, 3, 105, 105)
        G.tenMinutes()
        assert(#G.ecos() == 3, "Ecos: " .. #G.ecos())
        for _, b in ipairs(bs) do assert(b.md.NOM_ecoReleased == true) end
        for _, e in ipairs(G.ecos()) do assert(e.md.NOM_eco == true, "Eco sem marca") end
        G.tenMinutes()
        assert(#G.ecos() == 3, "corpo soltou dois Ecos")
    end,
    eco_nothing_by_day = function()
        local G = setup({ tod = 12 })
        bodies(G, 3, 105, 105)
        G.tenMinutes()
        assert(#G.ecos() == 0)
    end,
    eco_disabled_spawns_nothing = function()
        local G = setup({ sandbox = { EcoEnabled = false } })
        bodies(G, 3, 105, 105)
        G.tenMinutes()
        assert(#G.ecos() == 0)
    end,
    eco_body_out_of_radius_ignored = function()
        local G = setup({ sandbox = { EcoRadius = 10 } })
        G.body(111, 100, 0)
        G.body(110, 100, 0)
        G.tenMinutes()
        assert(#G.ecos() == 1)
    end,
    eco_cap_respected_with_60_bodies = function()
        local G = setup()
        bodies(G, 60, 95, 95)
        G.tenMinutes()
        assert(#G.ecos() == 30, "Ecos: " .. #G.ecos())
        G.tenMinutes()
        assert(#G.ecos() == 30, "passou do teto: " .. #G.ecos())
        for i = 1, 5 do G.kill(G.ecos()[i]) end
        G.tick(10)
        G.tenMinutes()
        assert(#G.ecos() == 30, "não repôs até o teto: " .. #G.ecos())
    end,
    eco_periodic_scan_catches_new_bodies = function()
        local G = setup()
        G.tenMinutes()
        G.body(300, 300, 0)
        G.players[1].x, G.players[1].y = 298, 298
        G.tenMinutes()
        assert(#G.ecos() == 1, "jogador andou até o corpo às 2h e nada aconteceu")
    end,
    eco_ignores_animals_and_released = function()
        local G = setup()
        G.body(101, 101, 0, { animal = true })
        local b = G.body(102, 102, 0)
        b.md.NOM_ecoReleased = true
        G.tenMinutes()
        assert(#G.ecos() == 0)
    end,
    eco_released_flag_survives_restart = function()
        local G = setup()
        bodies(G, 4, 105, 105)
        G.tenMinutes()
        assert(#G.ecos() == 4)
        local G2 = setup({ squares = G.squares, globalMD = G.globalMD })
        G2.tenMinutes()
        assert(#G2.ecos() == 0, "corpo soltou Eco de novo depois de recarregar")
    end,
    eco_spawn_failure_keeps_body_unreleased = function()
        local G = setup({ zombiesDisabled = true })
        local b = G.body(105, 105, 0)
        G.tenMinutes()
        assert(b.md.NOM_ecoReleased == nil, "corpo marcado sem Eco")
    end,
    eco_outfit_missing_learns_nothing = function()
        local G = setup({ outfits = { "Agent", "Priest" } })
        G.body(105, 105, 0)
        G.tenMinutes()
        local ids = G.globalMD.NevoaEOutroMundo and G.globalMD.NevoaEOutroMundo.eco and G.globalMD.NevoaEOutroMundo.eco.ids or {}
        assert(next(ids) == nil, "guardou ID sem outfit")
        local zz = G.reload(100, 100, 0, 0)
        assert(zz.md.NOM_eco == nil, "zumbi sem outfit virou Eco")
    end,
    eco_two_players_share_bodies_once = function()
        local G = setup({ players = { { x = 100, y = 100, z = 0 }, { x = 101, y = 100, z = 0 } } })
        bodies(G, 10, 105, 105)
        G.tenMinutes()
        assert(#G.ecos() == 10, "Ecos: " .. #G.ecos())
    end,
    eco_spawned_is_weak = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local e = G.ecos()[1]
        assert(e and e.health < 1.0, "Eco com vida cheia")
    end,
    eco_outfit_xml_has_both_sexes = function()
        local f = assert(io.open("mod/42/media/clothing/clothing.xml"))
        local xml = f:read("*a")
        f:close()
        for _, tag in ipairs({ "m_MaleOutfits", "m_FemaleOutfits" }) do
            local block = xml:match("<" .. tag .. ">%s*<m_Name>NOM_Eco</m_Name>(.-)</" .. tag .. ">")
            assert(block, "sem NOM_Eco em " .. tag)
            assert(block:find("ae2071bc-0d47-4041-b0a5-28c8cfa46c05", 1, true), tag .. " sem a camisola (Gown_Hospital)")
            assert(block:find("edf2b504-261e-4baf-9440-48884d80a8bb", 1, true), tag .. " sem o véu (Hat_WeddingVeil)")
        end
    end,

    -- morte: inventário limpo já no OnZombieDead; corpo removido quando nascer
    eco_death_clears_inventory_and_removes_corpse = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local e = G.ecos()[1]
        G.kill(e, { delay = 30 })
        assert(e.inv == 0, "loot ficou no Eco")
        G.tick(40)
        assert(G.bodiesAt(105, 105) == 1, "o corpo original tem que ficar")
        assert(G.removedCorpses == 1, "cadáver do Eco ficou no chão")
    end,
    eco_corpse_on_neighbor_square_is_removed = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        G.kill(G.ecos()[1], { dx = 1 })
        G.tick(10)
        assert(G.bodiesAt(106, 105) == 0, "cadáver no square vizinho ficou")
    end,
    eco_normal_zombie_keeps_corpse = function()
        local G = setup()
        local zz = G.normalZombie(110, 110)
        G.kill(zz)
        G.tick(10)
        assert(G.bodiesAt(110, 110) == 1, "removeu cadáver de zumbi comum")
        assert(zz.inv == 3, "limpou loot de zumbi comum")
    end,
    -- remoção falhou (servidor caiu, square descarregou): a varredura limpa
    eco_corpse_is_swept_and_never_releases = function()
        local G = setup()
        local b = G.body(105, 105, 0)
        b.md.NOM_eco = true
        G.tenMinutes()
        assert(#G.ecos() == 0, "corpo de Eco soltou Eco")
        assert(G.bodiesAt(105, 105) == 0, "varredura não removeu corpo de Eco")
    end,

    eco_dawn_removes_all = function()
        local G = setup()
        bodies(G, 5, 105, 105)
        local normal = G.normalZombie(120, 120)
        G.tenMinutes()
        assert(#G.ecos() == 5)
        G.setTime(7)
        assert(#G.ecos() == 0, "Ecos sobreviveram ao amanhecer: " .. #G.ecos())
        assert(not normal.removed, "removeu zumbi comum")
        assert(#G.sent == 0, "solo não manda comando")
    end,
    eco_dawn_mp_sends_ids = function()
        local G = setup({ server = true })
        bodies(G, 2, 105, 105)
        G.tenMinutes()
        local ids = {}
        for _, e in ipairs(G.ecos()) do ids[e.onlineID] = true end
        G.setTime(7)
        assert(#G.sent == 1, "comandos: " .. #G.sent)
        local c = G.sent[1]
        assert(c.module == "NevoaEOutroMundo" and c.command == "ecoGone")
        local n = 0
        for _, id in pairs(c.args.ids) do assert(ids[id]); n = n + 1 end
        assert(n == 2)
    end,

    -- Eco descarregado à noite que volta de dia: some no tick seguinte (dentro
    -- do OnZombieCreate não dá: o jogo põe o zumbi na lista depois do evento)
    eco_reloaded_by_day_is_removed_next_tick = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        G.setTime(9)
        local back = G.reload(105, 105, 0, id)
        G.tick(1)
        assert(back.removed, "Eco recarregado de dia ficou no mundo")
    end,
    eco_reloaded_at_night_stays_weak_and_corpseless = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        local back = G.reload(105, 105, 0, id)
        G.tick(5)
        assert(not back.removed, "removeu Eco à noite")
        assert(back.md.NOM_eco == true and back.health < 1.0, "voltou como zumbi comum")
        G.kill(back)
        G.tick(10)
        assert(G.removedCorpses == 1, "Eco recarregado deixou cadáver")
    end,
    -- servidor reiniciou: as chaves vêm do ModData global
    eco_restart_recognizes_reloaded_eco = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        local G2 = setup({ squares = G.squares, globalMD = G.globalMD, tod = 12 })
        local back = G2.reload(105, 105, 0, id)
        G2.tick(1)
        assert(back.removed, "Eco não reconhecido depois de reiniciar")
    end,
    -- antes do primeiro OnClimateTick não se sabe se é dia: espera
    eco_unknown_clock_waits = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        local G2 = setup({ squares = G.squares, globalMD = G.globalMD, tod = 12, noClock = true })
        local back = G2.reload(105, 105, 0, id)
        G2.tick(3)
        assert(not back.removed, "removeu sem saber a hora")
        G2.setTime(12)
        G2.tick(1)
        assert(back.removed, "não removeu depois de saber que é dia")
    end,
    -- lista de mods mudou: o ID guardado agora veste outro outfit, que não é Eco
    eco_stale_id_is_dropped = function()
        local G = setup()
        local agent = G.pickOutfit("Agent", false)
        G.globalMD.NevoaEOutroMundo.eco.ids = { [agent] = { [G.globalMD.NevoaEOutroMundo.eco.night] = true } }
        local zz = G.reload(110, 110, 0, agent)
        G.setTime(12)
        G.tick(1)
        assert(not zz.removed and zz.md.NOM_eco == nil, "zumbi comum tratado como Eco")
        assert(next(G.globalMD.NevoaEOutroMundo.eco.ids) == nil, "ID velho ficou")
    end,
    -- zumbi de zona que sorteou o outfit NOM_Eco (fallback GetRandomOutfit) não
    -- está na lista de IDs: é zumbi comum
    eco_random_outfit_zombie_is_not_eco = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes() -- já existe um Eco de verdade com esse outfit
        local zz = G.reload(110, 110, 0, G.pickOutfit("NOM_Eco", false))
        G.setTime(12)
        G.tick(1)
        assert(not zz.removed and zz.md.NOM_eco == nil)
    end,
    -- regra do GDD: "ao amanhecer, todos os Ecos somem, onde quer que estejam"
    eco_reloaded_on_later_night_is_removed = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        G.setTime(9)
        G.setTime(22)
        local back = G.reload(105, 105, 0, id)
        G.tick(1)
        assert(back.removed, "Eco da noite anterior voltou na noite seguinte")
    end,
    eco_restart_mid_night_keeps_same_night = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        local G2 = setup({ squares = G.squares, globalMD = G.globalMD, tod = 2 })
        local back = G2.reload(105, 105, 0, id)
        G2.tick(1)
        assert(not back.removed and back.md.NOM_eco == true, "reiniciar no meio da noite abriu noite nova")
    end,
    eco_ids_of_old_nights_are_pruned = function()
        local G = setup()
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        assert(G.globalMD.NevoaEOutroMundo.eco.ids[id])
        for _ = 1, 8 do G.setTime(9); G.setTime(22) end
        assert(G.globalMD.NevoaEOutroMundo.eco.ids[id] == nil, "lista de IDs cresce pra sempre")
    end,
    -- gêmeos: mesmo ID exato. Um morre; o outro, descarregado, continua Eco
    eco_twin_death_keeps_unloaded_twin = function()
        local G = setup()
        G.fixedSeed = 7
        G.body(105, 105, 0)
        G.body(106, 105, 0)
        G.tenMinutes()
        local a, b = G.ecos()[1], G.ecos()[2]
        assert(a.outfitID == b.outfitID, "fake não forçou gêmeos")
        local id = G.unload(a)
        G.kill(b)
        G.tick(10)
        local back = G.reload(105, 105, 0, id)
        G.tick(1)
        assert(not back.removed and back.md.NOM_eco == true, "gêmeo descarregado perdeu o Eco quando o outro morreu")
    end,
    eco_twin_dawn_removal_keeps_unloaded_twin_known = function()
        local G = setup()
        G.fixedSeed = 7
        G.body(105, 105, 0)
        G.body(106, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        G.setTime(9) -- o carregado sai no amanhecer
        G.setTime(22)
        local back = G.reload(105, 105, 0, id)
        G.tick(1)
        assert(back.removed, "gêmeo de noite passada voltou como zumbi comum (ID apagado)")
    end,
    -- gêmeo nascido numa noite depois não apaga a noite do mais velho
    eco_twin_later_night_keeps_both_nights = function()
        local G = setup()
        G.fixedSeed = 7
        G.body(105, 105, 0)
        G.tenMinutes()
        local id = G.unload(G.ecos()[1])
        G.setTime(9)
        G.setTime(22)
        G.body(120, 120, 0)
        G.tenMinutes()
        local nights = G.globalMD.NevoaEOutroMundo.eco.ids[id]
        assert(type(nights) == "table" and nights[1] and nights[2], "noite do gêmeo mais velho sobrescrita")
        G.unload(G.ecos()[1])
        G.setTime(9)
        G.setTime(22) -- noite 3: nenhum dos dois é daqui
        local back = G.reload(105, 105, 0, id)
        G.tick(1)
        assert(back.removed, "gêmeo de noite passada contou como atual")
    end,
    -- onlineID -1 = ainda sem ID de rede: não viaja (o cliente casaria com outro sem ID)
    eco_dawn_mp_skips_unassigned_online_id = function()
        local G = setup({ server = true })
        bodies(G, 2, 105, 105)
        G.tenMinutes()
        G.ecos()[1].onlineID = -1
        G.setTime(7)
        assert(#G.ecos() == 0, "Eco sem ID de rede ficou no servidor")
        for _, id in pairs(G.sent[1].args.ids) do assert(id ~= -1, "mandou -1") end
    end,
    -- dois jogadores juntos: cada square é lido uma vez por varredura
    eco_overlapping_players_scan_each_square_once = function()
        local G = setup({ players = { { x = 100, y = 100, z = 0 }, { x = 102, y = 100, z = 0 } } })
        bodies(G, 10, 105, 105)
        G.tenMinutes()
        for k, n in pairs(G.squareCalls) do assert(n == 1, k .. " lido " .. n .. " vezes") end
        assert(#G.ecos() == 10, "Ecos: " .. #G.ecos())
    end,
    -- pilha no meio de dois jogadores: os Ecos perto contam no teto dos dois
    eco_overlapping_players_share_nearby_ecos_in_cap = function()
        local G = setup({ sandbox = { EcoMaxPerPlayer = 5 },
            players = { { x = 100, y = 100, z = 0 }, { x = 160, y = 100, z = 0 } } })
        bodies(G, 20, 125, 100) -- a pilha fica a até 40 dos dois
        G.tenMinutes()
        assert(#G.ecos() == 5, "Ecos: " .. #G.ecos())
    end,
    -- orçamento: a varredura escala com jogadores × raio², não com o mapa nem com a
    -- horda; zumbi comum custa 1 chamada (o modData) por varredura
    eco_scan_budget_independent_of_horde = function()
        local G = setup({ sandbox = { EcoRadius = 10 } })
        bodies(G, 5, 102, 102)
        bodies(G, 50, 300, 300) -- fora do raio: nunca lidos
        local zs = {}
        for i = 1, 2000 do zs[i] = G.normalZombie(100 + i % 50, 300 + math.floor(i / 50)) end
        local c = dofile("tests/calls.lua")(zs)
        G.tenMinutes()
        local squares = 0
        for _ in pairs(G.squareCalls) do squares = squares + 1 end
        assert(squares <= 21 * 21, "squares lidos: " .. squares)
        assert(c.n <= #zs, "chamadas em zumbi comum: " .. c.n)
        assert(#G.ecos() == 5)
    end,
    -- debug (NOM_Debug.spawnEco): Eco no lugar pedido, só à noite, contado na
    -- noite atual como os outros (some no amanhecer)
    eco_spawn_at_only_at_night = function()
        local G = setup({ tod = 12 })
        assert(NOM_Eco.spawnAt(100, 100, 0) == false, "spawnou de dia")
        assert(#G.ecos() == 0)
        G.setTime(23)
        assert(NOM_Eco.spawnAt(100, 100, 0) == true)
        local e = G.ecos()[1]
        assert(e and e.md.NOM_eco == true and e.health == 0.3, "Eco sem marca ou sem vida baixa")
        assert(NOM_Eco.loaded() == 1)
        local ids = G.globalMD.NevoaEOutroMundo.eco.ids
        assert(ids[e.outfitID] and ids[e.outfitID][G.globalMD.NevoaEOutroMundo.eco.night], "ID não guardado na noite")
        G.setTime(7)
        assert(#G.ecos() == 0 and NOM_Eco.loaded() == 0, "Eco do debug não sumiu no amanhecer")
    end,
}
