-- NOM_NightStats contra um jogo falso que IMITA o B42.20 (bytecode) onde importa:
-- * sandbox: getOptionByName("ZombieLore.X"):getValue()/setValue(v); setValue
--   fora da faixa é ignorado (IntegerConfigOption.setValue) e não avisa ninguém.
-- * DoZombieStats(): relê sight/hearing (4 = Rand(3)+1, 5 = Rand(2)+2), mexe na
--   cognition só com sandbox 1 ou 4, NÃO mexe em strength (só com campo -1),
--   memory: campo -1 + sandbox 1..4, OU sandbox 5/6 (aleatório: re-sorteia sempre),
--   chama doZombieSpeed() com o speedType atual e re-sorteia canCrawlUnderVehicle.
-- * doZombieSpeed(t): t = -1 relê o sandbox; o sandbox manda ANTES do argumento:
--   lore 3 ou t 3 → arrastado; 2/3 de chance de "fake shambler" (speedType = t);
--   senão lore 2 ou t 2 → rápido; senão lore 1 ou t 1 → corredor.
-- * zumbi que volta do virtual é objeto novo: stats do sandbox, modData vazio.
-- * getPersistentOutfitID(): o ID do outfit (0 = sem outfit, nunca variante);
--   addZombiesInOutfit troca o ID depois do OnZombieCreate (o.id muda).
-- * ActiveOnly: a cada update o jogo chama makeInactive(isZombieInactivityPhase())
--   (IsoZombie.updateActiveState). makeInactive(b) volta cedo se nada mudou;
--   true → speedType 3 + doZombieSpeed() e nunca reafirma; false → speedType -1 +
--   DoZombieStats(). determineZombieSpeed(-1) com inactive → 3.
require "NOM_NightRules"
require "NOM_VariantRules"

local FILE = "mod/42/media/lua/shared/NOM_NightStats.lua"
local LORE_RANGE = { Speed = 4, Sight = 5, Hearing = 5, Cognition = 4, Memory = 6 }

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
    local G = { zombies = jlist(), seed = opts.seed or 0, inactivePhase = opts.inactivePhase or false, calls = { stats = 0, speedReads = 0 } }
    G.lore = { Speed = 2, Sight = 2, Hearing = 2, Cognition = 3, Memory = 2 }
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
        local z = { md = {}, speedType = -1, cognition = -1, strength = -1, memory = -1, crawling = o.crawling or false,
            remote = o.remote or false, dead = false, outfitName = o.outfit, canCrawl = true, outfitID = o.id or 0 }
        function z:getPersistentOutfitID() return self.outfitID end
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
                if self.inactive then
                    t = 3
                elseif t == 4 then
                    t = (G.rand(100) < 20) and 1 or G.rand(2) + 2
                end
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
            local r = -1
            if l.Memory == 5 then r = G.rand(4) elseif l.Memory == 6 then r = G.rand(3) + 1 end
            local unset = self.memory == -1
            if (unset and l.Memory == 1) or r == 0 then self.memory = 1250 end
            if (unset and l.Memory == 2) or r == 1 then self.memory = 800 end
            if (unset and l.Memory == 3) or r == 2 then self.memory = 500 end
            if (unset and l.Memory == 4) or r == 3 then self.memory = 25 end
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
        function z:makeInactive(b)
            if b == self.inactive then return end
            if b then
                self.inactive = true
                self.speedType = 3
                self:doZombieSpeed()
            else
                self.speedType = -1
                self.inactive = false
                self:DoZombieStats()
            end
        end
        -- createZombieOutsideWorld: inactive = isZombieInactivityPhase(), DoZombieStats antes do evento
        z.inactive = G.inactivePhase
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
    -- IsoZombie.resetForReuse: o mesmo objeto Java volta pra outro zumbi, modData
    -- zerado (getModData():wipe()), e passa de novo pelo OnZombieCreate
    function G.reuse(z, o)
        G.zombies:remove(z)
        z.md = {}
        z.outfitID = (o and o.id) or 0
        fire("OnZombieCreate", z)
        G.zombies:add(z)
    end
    -- update dos zumbis (updateActiveState) e depois o OnTick do Lua
    function G.tick(n)
        for _ = 1, n or 1 do
            for _, z in ipairs(G.zombies.items) do z:makeInactive(G.inactivePhase) end
            fire("OnTick", 0)
        end
    end
    function G.kill(z)
        z.dead = true
        fire("OnZombieDead", z)
    end
    G.fire = fire
    function G.converge() G.tick(math.ceil(G.zombies:size() / NOM_NightStats.BATCH) + 1) end

    isClient = function() return false end
    isServer = function() return false end
    getDebug = function() return false end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    getCell = function() return { getZombieList = function() return G.zombies end } end
    getGameTime = function()
        return { isZombieInactivityPhase = function() return G.inactivePhase end }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    NOM_NightStats = nil
    package.loaded["NOM_NightStats"] = nil
    NOM_FogState = nil
    package.loaded["NOM_FogState"] = nil
    dofile(FILE)
    NOM_NightStats.install()
    return G
end

-- primeiro persistentOutfitID (formato do jogo) que dá a variante pedida
local function idFor(want, night, sandbox)
    local c = NOM_VariantRules.config(function(k)
        local v = sandbox[k]
        if v == nil then v = NOM_Config.DEFAULTS[k] end
        return v
    end)
    for seed = 1, 500 do
        local id = 5 * 65536 + seed
        if NOM_VariantRules.variant(id, night, c) == want then return id end
    end
    error("nenhum ID dá " .. tostring(want))
end

local function sameLore(G, want)
    for k, v in pairs(want) do
        if G.lore[k] ~= v then return false end
    end
    return true
end

return {
    -- calmaria (sprint 0033): o comum fica um degrau pior em velocidade, visão e audição
    stats_calm_dulls_common_by_day = function()
        local G = setup()
        local z = G.spawn()
        G.tick()
        assert(z.md.NOM_night == nil, "dia sem calmaria mexeu no zumbi")
        NOM_NightStats.setCalm(true)
        assert(NOM_NightStats.calm == true)
        G.converge()
        assert(z.speedType == 3 and z.sight == 3 and z.hearing == 3, "calmaria não aplicou")
        assert(z.md.NOM_night == "c3,3,3", "chave: " .. tostring(z.md.NOM_night))
        NOM_NightStats.setCalm(false)
        assert(NOM_NightStats.calm == false)
        G.converge()
        assert(z.md.NOM_night == nil and z.md.NOM_dayTier == nil, "cache ficou depois da calmaria")
        assert(z.sight == 2 and z.hearing == 2, "sentidos não voltaram")
    end,
    -- o zumbi já estava em dia "dormindo" (idle): a calmaria acorda o tick
    stats_calm_wakes_sleeping_tick = function()
        local G = setup()
        local z = G.spawn()
        G.tick(5) -- passada inteira sem nada a devolver: dorme
        NOM_NightStats.setCalm(true)
        G.converge()
        assert(z.md.NOM_night == "c3,3,3", "tick continuou dormindo")
    end,
    -- durante a calmaria o tick não dorme: zumbi que nasce ou volta do virtual é pego
    stats_calm_keeps_tick_awake = function()
        local G = setup()
        G.spawn()
        NOM_NightStats.setCalm(true)
        G.tick(5)
        local late = G.spawn()
        G.converge()
        assert(late.md.NOM_night == "c3,3,3" and late.speedType == 3, "zumbi novo escapou da calmaria")
    end,
    -- saiu a calmaria: o tick acorda, limpa, e só então volta a dormir
    stats_calm_end_then_sleeps = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setCalm(true)
        G.converge()
        NOM_NightStats.setCalm(false)
        G.tick(5)
        assert(z.md.NOM_night == nil)
        local s0 = G.calls.speedReads
        G.tick(5)
        assert(G.calls.speedReads == s0, "tick não voltou a dormir")
    end,
    -- à noite a calmaria vence nos comuns; a variante e o Eco seguem o próprio perfil
    stats_calm_beats_night_for_common = function()
        local G = setup()
        local z, eco = G.spawn(), G.spawn({ outfit = "NOM_Eco" })
        NOM_NightStats.setNight(true)
        NOM_NightStats.setCalm(true)
        G.converge()
        assert(z.speedType == 3 and z.sight == 3 and z.md.NOM_night == "c3,3,3")
        assert(eco.speedType == 3 and eco.md.NOM_night == "eco", "Eco: " .. tostring(eco.md.NOM_night))
        NOM_NightStats.setCalm(false)
        G.converge()
        assert(z.speedType == 1 and z.sight == 1, "noite não voltou depois da calmaria")
    end,
    -- sandbox de velocidade aleatória: a calmaria parte do degrau do zumbi
    stats_calm_from_zombie_tier = function()
        local G = setup({ lore = { Speed = 4 } })
        local z = G.spawn()
        z.speedType = 1
        NOM_NightStats.setCalm(true)
        G.converge()
        assert(z.speedType == 2, "um degrau abaixo do corredor: " .. z.speedType)
    end,
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
    -- memória aleatória (5/6) re-sorteia em todo DoZombieStats, mesmo com o campo setado
    stats_memory_not_rerolled = function()
        for _, m in ipairs({ 5, 6 }) do
            local G = setup({ lore = { Memory = m } })
            local zs = {}
            for i = 1, 10 do zs[i] = G.spawn() end
            local before = {}
            for i, z in ipairs(zs) do before[i] = z.memory end
            NOM_NightStats.setNight(true)
            G.converge()
            NOM_NightStats.setNight(false)
            G.converge()
            for i, z in ipairs(zs) do assert(z.memory == before[i], "re-sorteou memory com sandbox " .. m) end
            assert(G.lore.Memory == m, "sandbox de memória não voltou")
        end
    end,
    -- ActiveOnly: zumbi inativo pela fase vanilla continua arrastado; sentidos valem
    stats_inactive_phase_night_keeps_shamble = function()
        local G = setup({ inactivePhase = true })
        local zs = {}
        for i = 1, 5 do zs[i] = G.spawn() end
        G.tick()
        NOM_NightStats.setNight(true)
        G.converge()
        for _, z in ipairs(zs) do
            assert(z.speedType == 3 and z.inactive, "acordou zumbi inativo: " .. z.speedType)
            assert(z.sight == 1 and z.hearing == 1, "sentidos não subiram na fase inativa")
        end
        local before = G.calls.stats
        G.converge()
        assert(G.calls.stats == before, "brigou com o makeInactive")
    end,
    -- fase vira inativa no meio da noite e amanhece: o mod não devolve a velocidade do dia
    stats_inactive_phase_dawn_keeps_shamble = function()
        local G = setup()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.speedType == 1)
        G.inactivePhase = true
        G.converge()
        assert(z.speedType == 3, "promoveu zumbi inativo")
        NOM_NightStats.setNight(false)
        G.converge()
        assert(z.speedType == 3 and z.sight == 2, "amanhecer acordou zumbi inativo")
    end,
    -- fase vira ativa à noite: o jogo re-rola (DoZombieStats) e o mod reaplica tudo
    stats_phase_end_reapplies_night = function()
        local G = setup({ inactivePhase = true, sandbox = { NightFaster = false } })
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.sight == 1)
        G.inactivePhase = false
        G.converge()
        assert(not z.inactive and z.speedType == 2 and z.sight == 1, "não reaplicou os sentidos depois da fase")
    end,
    -- Speed aleatória + ActiveOnly: a 1ª passada da noite pega o zumbi inativo (3).
    -- Não pode guardar 3 como degrau do dia: no amanhecer o jogo sorteia de novo.
    stats_inactive_random_speed_not_captured = function()
        local G = setup({ lore = { Speed = 4 }, inactivePhase = true })
        local zs = {}
        for i = 1, 20 do zs[i] = G.spawn() end
        G.tick()
        NOM_NightStats.setNight(true)
        G.converge()
        for _, z in ipairs(zs) do assert(z.md.NOM_dayTier == nil, "guardou o degrau do zumbi inativo") end
        G.inactivePhase = false
        NOM_NightStats.setNight(false)
        G.converge()
        local slow = 0
        for _, z in ipairs(zs) do if z.speedType == 3 then slow = slow + 1 end end
        assert(slow < 20, "todo zumbi aleatório ficou arrastado o dia inteiro")
        assert(G.lore.Speed == 4)
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
    -- todo monstro menos o Eco só existe na névoa (Johan, 05/10): de dia na névoa o
    -- Corredor corre, e volta a comum quando a névoa baixa
    stats_corredor_sprints_in_fog_by_day_and_returns = function()
        local sb = { CorredorChance = 100, EstaladorChance = 0 }
        local G = setup({ lore = { Speed = 3 }, sandbox = sb })
        local z = G.spawn({ id = idFor("corredor", 3, sb) })
        NOM_FogState.set(true, 3)
        G.converge()
        assert(z.speedType == 1 and z.md.NOM_variant == "corredor", "corredor: " .. z.speedType)
        NOM_FogState.set(false, 3)
        G.converge()
        assert(z.speedType == 3 and z.md.NOM_variant == nil, "corredor não voltou a comum")
    end,
    -- noite sem névoa: noite agressiva, nenhum monstro
    stats_night_without_fog_has_no_variant = function()
        local sb = { EstaladorChance = 100 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("estalador", 2, sb) })
        NOM_NightStats.setNight(true, 2)
        G.converge()
        assert(z.md.NOM_variant == nil and z.speedType == 1 and z.sight == 1, "variante sem névoa")
    end,
    -- névoa de dia: Estalador cego e de ouvido apurado, sem bônus da noite
    stats_estalador_in_fog_by_day = function()
        local sb = { EstaladorChance = 100 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("estalador", 2, sb) })
        NOM_FogState.set(true, 2)
        G.converge()
        assert(z.sight == 3 and z.hearing == 1 and z.md.NOM_variant == "estalador")
        assert(z.speedType == 2, "estalador ganhou velocidade da noite de dia: " .. z.speedType)
        assert(G.lore.Sight == 2 and G.lore.Hearing == 2, "sandbox vazou")
        NOM_FogState.set(false, 2)
        G.converge()
        assert(z.sight == 2 and z.hearing == 2 and z.md.NOM_variant == nil)
    end,
    -- noite + névoa: a variante por cima dos stats da noite; a névoa baixa e a
    -- noite continua
    stats_estalador_on_top_of_night = function()
        local sb = { EstaladorChance = 100, NightSharperSenses = false }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("estalador", 2, sb) })
        NOM_NightStats.setNight(true, 9)
        NOM_FogState.set(true, 2)
        G.converge()
        assert(z.sight == 3 and z.hearing == 1 and z.md.NOM_variant == "estalador")
        assert(z.speedType == 1, "estalador perdeu a velocidade da noite")
        NOM_FogState.set(false, 2)
        G.converge()
        assert(z.md.NOM_variant == nil and z.speedType == 1 and z.sight == 2, "névoa baixou e levou a noite junto")
        assert(z.md.NOM_night ~= nil)
    end,
    -- o Sem-rosto não tem stats: no NOM_NightStats ele é zumbi comum
    stats_semrosto_has_no_profile = function()
        local sb = { EstaladorChance = 0, CorredorChance = 0, SemRostoChance = 100 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("semrosto", 1, sb) })
        NOM_FogState.set(true, 1)
        G.converge()
        assert(z.md.NOM_variant == nil and NOM_NightStats.variants[z] == nil and z.md.NOM_night == nil)
    end,
    -- addZombiesInOutfit veste depois do OnZombieCreate: a variante segue o ID atual
    stats_variant_follows_outfit_id = function()
        local sb = { CorredorChance = 50, EstaladorChance = 0 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor(nil, 6, sb) })
        NOM_FogState.set(true, 6)
        G.converge()
        assert(z.md.NOM_variant == nil)
        z.outfitID = idFor("corredor", 6, sb)
        G.converge()
        assert(z.md.NOM_variant == "corredor" and z.speedType == 1, "não seguiu o ID novo")
        -- outra névoa, outro sorteio: o mesmo zumbi pode deixar de ser
        local other = idFor(nil, 7, sb)
        z.outfitID = other
        NOM_FogState.set(true, 7)
        G.converge()
        assert(z.md.NOM_variant == nil)
    end,
    stats_eco_never_variant = function()
        local sb = { EstaladorChance = 100 }
        local G = setup({ sandbox = sb })
        local id = idFor("estalador", 1, sb)
        local eco = G.spawn({ id = id })
        eco.md.NOM_eco = true
        local ecoMP = G.spawn({ id = id, outfit = "NOM_Eco" })
        NOM_NightStats.setNight(true, 1)
        NOM_FogState.set(true, 1)
        G.converge()
        for _, e in ipairs({ eco, ecoMP }) do
            assert(e.md.NOM_variant == nil and e.speedType == 3 and e.sight == 2, "Eco virou variante")
        end
    end,
    -- cliente que ainda não sabe o número da névoa: sem variante
    stats_variant_needs_fog_period = function()
        local sb = { EstaladorChance = 100 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("estalador", 1, sb) })
        NOM_NightStats.setNight(true, 5)
        NOM_FogState.set(true, nil)
        G.converge()
        assert(z.md.NOM_variant == nil and z.speedType == 1 and z.sight == 1)
        NOM_FogState.set(true, 1)
        G.converge()
        assert(z.md.NOM_variant == "estalador" and z.sight == 3)
    end,
    stats_dead_variant_forgets = function()
        local sb = { CorredorChance = 100, EstaladorChance = 0 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("corredor", 1, sb) })
        NOM_FogState.set(true, 1)
        G.converge()
        z.md.NOM_hunting = true
        z.md.NOM_furia = 1 -- Carpideira que gritou (sprint 0011)
        G.kill(z)
        assert(z.md.NOM_variant == nil and z.md.NOM_hunting == nil, "chave de variante foi pro corpo")
        assert(z.md.NOM_furia == nil, "marca da Carpideira foi pro corpo")
    end,
    -- fim da névoa: alerta do Estalador e caça do Corredor não passam pra próxima
    stats_fog_end_clears_variant_state = function()
        local sb = { EstaladorChance = 100 }
        local G = setup({ sandbox = sb })
        local z = G.spawn({ id = idFor("estalador", 1, sb) })
        NOM_FogState.set(true, 1)
        G.converge()
        z.md.NOM_alert, z.md.NOM_hunting = true, true
        NOM_FogState.set(false, 1)
        G.converge()
        assert(z.md.NOM_alert == nil and z.md.NOM_hunting == nil, "estado da variante sobrou sem névoa")
    end,
    -- conjunto Lua das variantes locais (o OnZombieUpdate olha só ele, sem chamar Java)
    stats_variant_set_tracks_life = function()
        local sb = { EstaladorChance = 100 }
        local G = setup({ sandbox = sb })
        local id = idFor("estalador", 1, sb)
        local z, plain = G.spawn({ id = id }), G.spawn()
        NOM_FogState.set(true, 1)
        G.converge()
        assert(NOM_NightStats.variants[z] == "estalador" and NOM_NightStats.variants[plain] == nil)
        NOM_FogState.set(false, 1)
        G.converge()
        assert(NOM_NightStats.variants[z] == nil, "ficou no conjunto sem névoa")
        NOM_FogState.set(true, 1)
        G.converge()
        G.kill(z)
        assert(NOM_NightStats.variants[z] == nil, "morto ficou no conjunto")
        local r = G.spawn({ id = id })
        G.converge()
        G.reuse(r)
        assert(NOM_NightStats.variants[r] == nil, "objeto reaproveitado herdou a variante")
    end,
    -- de dia, a névoa que sobe acorda o tick que dormia
    stats_day_idle_wakes_with_fog = function()
        local sb = { CorredorChance = 100, EstaladorChance = 0 }
        local G = setup({ lore = { Speed = 3 }, sandbox = sb })
        G.spawn()
        G.converge()
        G.converge()
        local z = G.spawn({ id = idFor("corredor", 4, sb) })
        NOM_FogState.set(true, 4)
        G.converge()
        assert(z.speedType == 1, "névoa de dia não acordou o tick")
    end,

    -- orçamento: de dia, depois de devolver tudo e de uma passada limpa, o tick não
    -- toca em zumbi nenhum nem no sandbox (docs/architecture/README.md#orçamento)
    stats_day_idle_only_after_clean_pass = function()
        local G = setup()
        local zs = {}
        for i = 1, 300 do zs[i] = G.spawn() end
        NOM_NightStats.setNight(true)
        G.converge()
        NOM_NightStats.setNight(false)
        G.converge() -- passada do amanhecer: devolve todos
        for _, z in ipairs(zs) do assert(z.md.NOM_night == nil, "ficou com stat da noite") end
        G.converge() -- passada limpa
        -- makeInactive é o update do jogo (updateActiveState), não o mod
        local c = dofile("tests/calls.lua")(zs, { makeInactive = true })
        local reads = 0
        local orig = getSandboxOptions
        getSandboxOptions = function() reads = reads + 1; return orig() end
        G.tick(50)
        getSandboxOptions = orig
        assert(c.n == 0 and reads == 0, "de dia ocioso e mexeu: zumbi=" .. c.n .. " sandbox=" .. reads)
    end,
    -- ocioso de dia não pode atrasar a noite seguinte, nem pra zumbi que nasceu dormindo
    stats_day_idle_wakes_at_night = function()
        local G = setup()
        G.spawn()
        G.converge()
        G.converge()
        local z = G.spawn()
        NOM_NightStats.setNight(true)
        G.converge()
        assert(z.speedType == 1, "não acordou à noite: " .. z.speedType)
    end,
    -- variante forçada (NOM_Debug) num Eco: Eco nunca é variante
    stats_forced_variant_skips_eco = function()
        local G = setup()
        local eco = G.spawn({ id = 77, outfit = "NOM_Eco" })
        local z = G.spawn({ id = 78 })
        NOM_VariantRules.forced[77], NOM_VariantRules.forced[78] = "corredor", "corredor"
        NOM_NightStats.setNight(true, 1)
        NOM_FogState.set(true, 1)
        G.converge()
        NOM_VariantRules.forced[77], NOM_VariantRules.forced[78] = nil, nil
        assert(eco.md.NOM_variant == nil and eco.speedType == 3, "Eco virou Corredor")
        assert(z.md.NOM_variant == "corredor" and z.speedType == 1, "forçado ignorado")
    end,
    -- zumbi pulado pelo cursor (a lista mudou embaixo dele no amanhecer) fica com o
    -- stat da noite enquanto o tick dorme; a cada hora de jogo o tick acorda e
    -- devolve (Events.EveryHours, shared/Foraging/forageSystem.lua:751)
    stats_day_idle_wakes_every_hour = function()
        local G = setup()
        local zs = {}
        for i = 1, 30 do zs[i] = G.spawn() end
        NOM_NightStats.setNight(true)
        G.converge()
        local stranded = zs[7]
        local key = stranded.md.NOM_night
        NOM_NightStats.setNight(false)
        G.converge()
        G.converge()
        -- simula o pulado: continua com o perfil da noite com o tick já dormindo
        stranded.md.NOM_night = key
        stranded.speedType = 1
        G.converge()
        assert(stranded.md.NOM_night == key, "teste não prova nada: o tick não dormiu")
        G.fire("EveryHours")
        G.converge()
        assert(stranded.md.NOM_night == nil, "zumbi preso na noite depois da hora")
    end,
    -- névoa vermelha (sprint 0010): todo zumbi vira variante (Estalador/Corredor com
    -- perfil; Sem-rosto sem perfil), dividido por igual; o Eco nunca
    stats_red_fog_every_zombie_is_variant = function()
        local G = setup()
        local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
        local zs = {}
        for seed = 1, 90 do zs[#zs + 1] = G.spawn({ id = 3 * 65536 + seed }) end
        local eco = G.spawn({ id = 3 * 65536 + 1, outfit = "NOM_Eco" })
        NOM_FogState.set(true, 4, true)
        G.converge()
        local n = { estalador = 0, corredor = 0, semrosto = 0, carpideira = 0 }
        for _, z in ipairs(zs) do
            local k = z.md.NOM_variant
            if k == nil then
                assert(NOM_VariantRules.variant(z.outfitID, 4, c, true) == "semrosto", "zumbi comum na vermelha")
                k = "semrosto"
            end
            n[k] = n[k] + 1
        end
        -- 1/4 de cada (sprint 0011): ~22 de 90
        for k, v in pairs(n) do assert(v >= 10 and v <= 35, k .. " " .. v) end
        assert(eco.md.NOM_variant == nil, "Eco virou variante")
        -- a vermelha acaba (névoa normal no mesmo período): volta ao sorteio normal
        NOM_FogState.set(true, 4, false)
        G.converge()
        local still = 0
        for _, z in ipairs(zs) do if z.md.NOM_variant then still = still + 1 end end
        assert(still < 20, "continuou vermelha: " .. still)
    end,
    -- review da 0011: o useless viaja no pacote e nada no jogo o desliga; a passada do
    -- laço (inclusive no fim da névoa e de dia, na conferência de hora em hora) passa
    -- todo zumbi vivo pelo NOM_NightStats.unstick (o NOM_VariantAI instala)
    stats_pass_offers_every_zombie_to_unstick = function()
        local G = setup()
        local seen = {}
        NOM_NightStats.unstick = function(z) seen[z] = (seen[z] or 0) + 1 end
        local zs = {}
        for i = 1, 30 do zs[i] = G.spawn() end
        NOM_FogState.set(true, 1)
        G.converge()
        NOM_FogState.set(false, 1) -- névoa acaba: a passada de conferência
        seen = {}
        G.converge()
        for i, z in ipairs(zs) do assert(seen[z], "zumbi " .. i .. " fora do unstick no fim da névoa") end
        G.converge()
        G.converge()
        seen = {}
        G.fire("EveryHours")
        G.converge()
        for i, z in ipairs(zs) do assert(seen[z], "zumbi " .. i .. " fora do unstick de dia") end
        NOM_NightStats.unstick = nil
    end,
}
