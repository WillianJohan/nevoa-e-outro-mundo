-- NOM_NightStats contra um jogo falso que IMITA o B42.20 (bytecode) onde importa:
-- * sandbox: getOptionByName("ZombieLore.X"):getValue()/setValue(v); setValue
--   fora da faixa é ignorado (IntegerConfigOption.setValue) e não avisa ninguém.
-- * DoZombieStats(): relê sight/hearing (4 = Rand(3)+1, 5 = Rand(2)+2), mexe na
--   cognition só com sandbox 1 ou 4, NÃO mexe em strength (só com campo -1),
--   chama doZombieSpeed() com o speedType atual e re-sorteia canCrawlUnderVehicle.
-- * doZombieSpeed(t): t = -1 relê o sandbox; o sandbox manda ANTES do argumento:
--   lore 3 ou t 3 → arrastado; 2/3 de chance de "fake shambler" (speedType = t);
--   senão lore 2 ou t 2 → rápido; senão lore 1 ou t 1 → corredor.
-- * zumbi que volta do virtual é objeto novo: stats do sandbox, modData vazio.
require "NOM_NightRules"

local FILE = "mod/42/media/lua/shared/NOM_NightStats.lua"
local LORE_RANGE = { Speed = 4, Sight = 5, Hearing = 5, Cognition = 4 }

local function jlist()
    local l = { items = {} }
    function l:size() return #self.items end
    function l:get(i) return self.items[i + 1] end
    function l:add(o) self.items[#self.items + 1] = o end
    function l:remove(o)
        for i, v in ipairs(self.items) do
            if v == o then table.remove(self.items, i); return end
        end
    end
    return l
end

local function setup(opts)
    opts = opts or {}
    local G = { zombies = jlist(), seed = opts.seed or 0, calls = { stats = 0, speedReads = 0 } }
    G.lore = { Speed = 2, Sight = 2, Hearing = 2, Cognition = 3 }
    for k, v in pairs(opts.lore or {}) do G.lore[k] = v end
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    -- Rand determinístico: o teste não depende da sorte
    function G.rand(n)
        G.seed = (G.seed * 1103515245 + 12345) % 2147483648
        return math.floor(G.seed / 65536) % n -- bits altos: o bit baixo do LCG alterna
    end

    local function option(short)
        return {
            getValue = function() return G.lore[short] end,
            setValue = function(_, v)
                if v < 1 or v > LORE_RANGE[short] then return end
                G.lore[short] = v
            end,
        }
    end
    getSandboxOptions = function()
        return {
            getOptionByName = function(_, name)
                local short = name:match("^ZombieLore%.(%w+)$")
                assert(short and LORE_RANGE[short], "opção inesperada: " .. name)
                return option(short)
            end,
        }
    end

    function G.zombie(o)
        o = o or {}
        local z = { md = {}, speedType = -1, cognition = -1, strength = -1, crawling = o.crawling or false,
            remote = o.remote or false, dead = false, outfitName = o.outfit, canCrawl = true }
        function z:getModData() return self.md end
        function z:hasModData() return next(self.md) ~= nil end
        function z:isDead() return self.dead end
        function z:isCrawling() return self.crawling end
        function z:isRemoteZombie() return self.remote end
        function z:getOutfitName() return self.outfitName end
        function z:isCanCrawlUnderVehicle() return self.canCrawl end
        function z:setCanCrawlUnderVehicle(b) self.canCrawl = b end
        function z:getSpeedType()
            G.calls.speedReads = G.calls.speedReads + 1
            return self.speedType
        end
        function z:doZombieSpeed(t)
            if t == nil then t = self.speedType end
            if t == -1 then
                t = G.lore.Speed
                if t == 4 then t = (G.rand(100) < 20) and 1 or G.rand(2) + 2 end
            end
            if self.crawling then return end
            if G.lore.Speed == 3 or t == 3 then
                self.speedType = 3
            elseif G.rand(3) ~= 0 then
                self.speedType = t -- doFakeShambler(t) → doZombieSpeedInternal2(t)
            elseif G.lore.Speed == 2 or t == 2 then
                self.speedType = 2
            elseif G.lore.Speed == 1 or t == 1 then
                self.speedType = 1
            end
        end
        function z:DoZombieStats()
            G.calls.stats = G.calls.stats + 1
            if G.throwInStats then error("boom") end
            local l = G.lore
            if l.Cognition == 1 then self.cognition = 1 end
            if l.Cognition == 4 then self.cognition = (G.rand(2) == 0) and 1 or 0 end
            if self.strength == -1 then self.strength = 3 end
            local function sense(v)
                if v == 4 then return G.rand(3) + 1 end
                if v == 5 then return G.rand(2) + 2 end
                return v
            end
            self.sight = sense(l.Sight)
            self.hearing = sense(l.Hearing)
            self:doZombieSpeed()
            self.canCrawl = G.rand(2) == 0
        end
        -- createZombieOutsideWorld: DoZombieStats antes do evento
        z:DoZombieStats()
        return z
    end
    -- chunk carrega: objeto novo, OnZombieCreate, entra na lista
    function G.spawn(o)
        local z = G.zombie(o)
        fire("OnZombieCreate", z)
        G.zombies:add(z)
        return z
    end
    function G.unload(z) G.zombies:remove(z) end
    function G.tick(n)
        for _ = 1, n or 1 do fire("OnTick", 0) end
    end
    function G.kill(z)
        z.dead = true
        fire("OnZombieDead", z)
    end
    function G.converge() G.tick(math.ceil(G.zombies:size() / NOM_NightStats.BATCH) + 1) end

    isClient = function() return false end
    isServer = function() return false end
    getDebug = function() return false end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    getCell = function() return { getZombieList = function() return G.zombies end } end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    NOM_NightStats = nil
    package.loaded["NOM_NightStats"] = nil
    dofile(FILE)
    NOM_NightStats.install()
    return G
end

local function sameLore(G, want)
    for k, v in pairs(want) do
        if G.lore[k] ~= v then return false end
    end
    return true
end

return {
    stats_night_boosts_speed_and_senses = function()
        local G = setup()
        local zs = {}
        for i = 1, 5 do zs[i] = G.spawn() end
        G.tick()
        NOM_NightStats.setNight(true)
        G.converge()
        for _, z in ipairs(zs) do
            assert(z.speedType == 1, "velocidade: " .. z.speedType)
            assert(z.sight == 1 and z.hearing == 1, "sentidos não subiram")
        end
    end,
    stats_dawn_restores_day = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.speedType == 1)
        NOM_NightStats.setNight(false)
        G.converge()
        assert(z.speedType == 2 and z.sight == 2 and z.hearing == 2, "ficou com stat noturno")
        assert(z.md.NOM_night == nil and z.md.NOM_dayTier == nil, "cache ficou no zumbi")
    end,
    -- a troca nunca vaza: o sandbox (que o jogo salva) volta igual
    stats_sandbox_restored_after_apply = function()
        local G = setup({ lore = { Speed = 4, Sight = 5, Hearing = 4, Cognition = 1 } })
        for _ = 1, 30 do G.spawn() end
        NOM_NightStats.setNight(true)
        G.converge()
        NOM_NightStats.setNight(false)
        G.converge()
        assert(sameLore(G, { Speed = 4, Sight = 5, Hearing = 4, Cognition = 1 }))
    end,
    stats_sandbox_restored_when_stats_throw = function()
        local G = setup()
        G.spawn()
        local savedPrint = print
        print = function() end
        G.throwInStats = true
        NOM_NightStats.setNight(true)
        local ok = pcall(G.tick)
        print = savedPrint
        assert(ok, "erro escapou do OnTick")
        assert(sameLore(G, { Speed = 2, Sight = 2, Hearing = 2, Cognition = 3 }), "sandbox ficou trocado")
    end,
    -- sandbox "Arrastados": lore.speed == 3 vence o argumento; sem a troca não sobe
    stats_shambler_sandbox_still_promotes = function()
        local G = setup({ lore = { Speed = 3 } })
        local zs = {}
        for i = 1, 10 do zs[i] = G.spawn() end
        NOM_NightStats.setNight(true)
        G.converge()
        for _, z in ipairs(zs) do assert(z.speedType == 2, "arrastado não subiu: " .. z.speedType) end
    end,
    stats_eco_slow_and_unboosted = function()
        local G = setup({ sandbox = { NightSpeedMult = 3 } })
        local eco = G.spawn()
        eco.md.NOM_eco = true
        local normal = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        assert(eco.speedType == 3 and eco.sight == 2 and eco.hearing == 2, "Eco não ficou lento")
        assert(normal.speedType == 1)
    end,
    -- cliente de MP: o modData do servidor não chega, o outfit sim
    stats_eco_by_outfit_name = function()
        local G = setup()
        local eco = G.spawn({ outfit = "NOM_Eco" })
        NOM_NightStats.setNight(true)
        G.converge()
        assert(eco.speedType == 3)
    end,
    stats_toggles_respected = function()
        local G = setup({ sandbox = { NightFaster = false } })
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.speedType == 2 and z.sight == 1, "velocidade desligada mudou")
        local G2 = setup({ sandbox = { NightSharperSenses = false } })
        local z2 = G2.spawn()
        NOM_NightStats.setNight(true)
        G2.converge()
        assert(z2.speedType == 1 and z2.sight == 2 and z2.hearing == 2, "sentidos desligados mudaram")
        local G3 = setup({ sandbox = { NightFaster = false, NightSharperSenses = false } })
        G3.spawn()
        NOM_NightStats.setNight(true)
        local before = G3.calls.stats
        G3.converge()
        assert(G3.calls.stats == before, "tudo desligado e mexeu no zumbi")
    end,
    -- critério de FPS: trabalho por tick limitado ao lote, horda inteira converge
    stats_batch_bounded_with_200 = function()
        local G = setup()
        local zs = {}
        for i = 1, 200 do zs[i] = G.spawn() end
        G.tick(10) -- esvazia a fila do OnZombieCreate (de dia: nada a aplicar)
        NOM_NightStats.setNight(true)
        local ticks = 0
        repeat
            local s0, r0 = G.calls.stats, G.calls.speedReads
            G.tick()
            ticks = ticks + 1
            assert(G.calls.stats - s0 <= NOM_NightStats.BATCH, "aplicou demais num tick")
            assert(G.calls.speedReads - r0 <= 2 * NOM_NightStats.BATCH, "leu demais num tick")
            local done = 0
            for _, z in ipairs(zs) do if z.speedType == 1 then done = done + 1 end end
        until done == 200 or ticks > 50
        assert(ticks <= math.ceil(200 / NOM_NightStats.BATCH), "demorou " .. ticks .. " ticks")
        local s0 = G.calls.stats
        G.tick(20)
        assert(G.calls.stats == s0, "reaplicou sem motivo")
    end,
    stats_reload_at_night_reapplies = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        G.unload(z)
        local back = G.spawn() -- objeto novo, stats do sandbox
        assert(back.speedType == 2)
        G.tick()
        assert(back.speedType == 1 and back.sight == 1, "não reaplicou no OnZombieCreate")
    end,
    -- salvar à noite e carregar de dia: o jogo re-sorteia do sandbox, que voltou intacto
    stats_reload_by_day_is_untouched = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        G.unload(z)
        NOM_NightStats.setNight(false)
        local back = G.spawn()
        local before = G.calls.stats
        G.converge()
        assert(back.speedType == 2 and back.sight == 2, "voltou com stat noturno")
        assert(G.calls.stats == before, "mexeu em zumbi de dia")
    end,
    -- o jogo re-rola (addZombiesInOutfit, makeInactive): o laço percebe pela velocidade
    stats_game_reroll_is_detected = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        z.speedType = -1
        z:DoZombieStats()
        assert(z.speedType == 2)
        G.converge()
        assert(z.speedType == 1 and z.sight == 1)
    end,
    -- remoto: o pacote do dono manda no walkType; o laço não briga
    stats_remote_speed_not_fought = function()
        local G = setup()
        local z = G.spawn({ remote = true })
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.sight == 1, "remoto não recebeu os sentidos")
        z.speedType = 3 -- pacote do dono
        local before = G.calls.stats
        G.converge()
        assert(G.calls.stats == before and z.speedType == 3)
    end,
    stats_keeps_crawl_under_vehicle = function()
        local G = setup()
        local zs = {}
        for i = 1, 10 do zs[i] = G.spawn() end
        local before = {}
        for i, z in ipairs(zs) do before[i] = z.canCrawl end
        NOM_NightStats.setNight(true)
        G.converge()
        for i, z in ipairs(zs) do assert(z.canCrawl == before[i], "re-sorteou canCrawlUnderVehicle") end
    end,
    stats_cognition_not_rerolled = function()
        local G = setup({ lore = { Cognition = 4 } })
        local zs = {}
        for i = 1, 10 do zs[i] = G.spawn() end
        local before = {}
        for i, z in ipairs(zs) do before[i] = z.cognition end
        NOM_NightStats.setNight(true)
        G.converge()
        for i, z in ipairs(zs) do assert(z.cognition == before[i], "re-sorteou cognition") end
    end,
    -- velocidade aleatória no sandbox: a base é a do zumbi e volta igual
    stats_random_speed_keeps_own_tier = function()
        local G = setup({ lore = { Speed = 4 } })
        local zs = {}
        for i = 1, 20 do zs[i] = G.spawn() end
        local before = {}
        for i, z in ipairs(zs) do before[i] = z.speedType end
        NOM_NightStats.setNight(true)
        G.converge()
        for i, z in ipairs(zs) do assert(z.speedType == math.max(1, before[i] - 1)) end
        NOM_NightStats.setNight(false)
        G.converge()
        for i, z in ipairs(zs) do assert(z.speedType == before[i], "não voltou ao degrau do dia") end
    end,
    stats_day_writes_nothing = function()
        local G = setup()
        local zs = {}
        for i = 1, 10 do zs[i] = G.spawn() end
        G.converge()
        for _, z in ipairs(zs) do assert(next(z.md) == nil, "escreveu no modData de dia") end
        assert(G.calls.stats == 10, "mexeu nos stats de dia")
    end,
    -- o corpo copia o modData do zumbi: a chave sai na morte
    stats_dead_forgets = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        G.kill(z)
        assert(z.md.NOM_night == nil and z.md.NOM_dayTier == nil)
    end,
}
