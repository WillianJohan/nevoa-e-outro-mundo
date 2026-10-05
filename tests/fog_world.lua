-- Mundo falso pros testes da névoa (servidor, Sem-rosto, cliente). Imita o
-- B42.20 onde importa (bytecode):
-- * Visão do jogador por square, calculada no cliente (LightingJNI): isCouldSee(pn)
--   = linha de visão no cone (aqui: até 30 tiles, ±60° da frente, ou colado);
--   isCanSee(pn) = isCouldSee e luz (no escuro só o square iluminado, ou a até 10
--   tiles da lanterna do jogador). O jogo usa isCanSee do square do zumbi como
--   "o jogador vê o zumbi" (IsoZombie.checkZombieEntersPlayerBuilding 26–44).
-- * getForwardDirection():getDirection() em radianos (shared/Fishing/FishingRod.lua:286).
-- * square:isFree(false) (client/ISUI/ISWorldObjectContextMenu.lua:2199).
-- * teleportTo(x, y, z): setX/Y/Z com o int (canto do tile), setLastX/Y, sem rede
--   (IsoGameCharacter.teleportTo(III)); setX/setY/setLastX/setLastY públicos (IsoMovingObject).
-- * Água: square:getProperties():has(IsoFlagType.water) (server/Fishing/BuildingObjects/FishingNet.lua:31).
-- * Andar: o jogador pode estar em z quebrado (escada); o square é do math.floor(z).
-- * MP: o servidor aplica a posição que o dono manda (NetworkZombiePacker.applyZombie);
--   G.ownerPacket(z) simula o pacote do dono que não aplicou o movimento.
-- * addZombiesInOutfit dispara OnZombieCreate e volta uma lista Java (Steps.lua:830).
-- * Square: qualquer método além dos de leitura listados explode (nada de mexer no mapa).
--   getFloor() e getWall(north) (o objeto com cutN/cutW, IsoGridSquare.getWall(Z)) vêm de
--   tests/attached_world.lua (G.floorOf, G.wallOf), que modela os anexos (sprint 0023); sem
--   ele, nil. G.sqCalls conta toda chamada de método em square (cada uma é uma ida ao Java).
-- * Prédios (sprint 0021): square:isOutside() (server/Farming/SFarmingSystem.lua:295) é falso
--   sob telhado; square:getBuilding() é o prédio do cômodo, nil fora (server/ClientCommands.lua:676);
--   player:getBuilding() é o do square dele (client/ISUI/ISWorldObjectContextMenu.lua:1679).
--   G.interior[k] = prédio (mesma tabela = mesmo prédio, como o objeto Java); G.roofed[k] =
--   telhado sem cômodo (varanda): fora de prédio e não é "de fora".
-- * Zumbi (sprint 0011): playSoundLocal no emitter dele (IsoGameCharacter.playSoundLocal),
--   getEmitter() com isPlaying/stopSoundLocal (BaseCharacterSoundEmitter); setUseless,
--   setTarget, spotted(p, forçado) (IsoZombie, públicos). removeFromWorld não para o
--   som do emitter (só stopOrTriggerSoundByName): o som fica tocando até alguém parar.
-- * Jogador: getActiveLightItem() = item aceso ou nil (pz-api-notes §2.4).
-- * Som: player:playSoundLocal(nome) = getEmitter():playSoundImpl(nome, nil), sem
--   pacote (IsoGameCharacter.playSoundLocal; client/ISUI/Maps/ISMap.lua:210);
--   emitter:setVolume(id, v), isPlaying(id), stopSoundLocal(id) são locais. Já
--   emitter:playSound e stopSound mandam pacote no cliente de MP
--   (FMODSoundEmitter.playSound 0–104, stopSound → sendStopSound): aqui explodem.
local W = {}

local function jlist(items)
    local l = { items = items or {} }
    function l:size() return #self.items end
    function l:get(i) return self.items[i + 1] end
    return l
end

function W.new(opts)
    opts = opts or {}
    local G = { players = {}, zombies = {}, sentServer = {}, sentClient = {}, now = 0, ticks = 0,
        holes = {}, blocked = {}, interior = {}, roofed = {}, lit = {}, water = {}, flags = {}, sqCalls = 0, dark = opts.dark or false, nextID = 1000, spawned = {} }
    local handlers = {}
    G.handlers = handlers
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    local function key(x, y, z) return x .. "," .. y .. "," .. (z or 0) end

    local function angleOk(p, x, y)
        local dx, dy = x + 0.5 - p.x, y + 0.5 - p.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 1.5 then return true end
        local a = math.atan2(dy, dx) - p.face
        a = math.abs((a + math.pi) % (2 * math.pi) - math.pi)
        return a <= math.rad(60)
    end
    local function couldSee(pn, x, y, z)
        local p = G.byNum[pn]
        if not p or math.floor(p.z) ~= z or G.blocked[key(x, y, z)] then return false end
        local dx, dy = x + 0.5 - p.x, y + 0.5 - p.y
        return math.sqrt(dx * dx + dy * dy) <= 30 and angleOk(p, x, y)
    end

    local squares = {}
    function G.square(x, y, z)
        z = z or 0
        local k = key(x, y, z)
        if G.holes[k] then return nil end
        if squares[k] then return squares[k] end
        local sq = { x = x, y = y, z = z, free = true, kind = "square" }
        local api = {
            getX = function() return x end,
            getY = function() return y end,
            getZ = function() return z end,
            isFree = function(_, _) return sq.free and not G.noFree end,
            getProperties = function()
                return { has = function(_, flag)
                    if flag == IsoFlagType.water then return G.water[k] == true end
                    return G.flags[k] ~= nil and G.flags[k][flag] == true
                end }
            end,
            isCouldSee = function(_, pn) return couldSee(pn, x, y, z) end,
            isOutside = function() return G.interior[k] == nil and not G.roofed[k] end,
            getBuilding = function() return G.interior[k] end,
            getFloor = function() return G.floorOf and G.floorOf(x, y, z) or nil end,
            getWall = function(_, north) return G.wallOf and G.wallOf(x, y, z, north) or nil end,
            isCanSee = function(_, pn)
                if not couldSee(pn, x, y, z) then return false end
                if not G.dark or G.lit[k] then return true end
                local p = G.byNum[pn]
                local dx, dy = x + 0.5 - p.x, y + 0.5 - p.y
                return p.light == true and math.sqrt(dx * dx + dy * dy) <= 10
            end,
        }
        setmetatable(sq, { __index = function(_, name)
            if api[name] then
                G.sqCalls = G.sqCalls + 1
                return api[name]
            end
            error("square:" .. tostring(name) .. " não devia ser chamado (mexe no mapa?)", 2)
        end })
        squares[k] = sq
        return sq
    end

    G.sounds = {} -- id -> { name, volume, playing }
    local emitter = {
        isPlaying = function(_, id) return G.sounds[id] ~= nil and G.sounds[id].playing end,
        setVolume = function(_, id, v) G.sounds[id].volume = v end,
        stopSoundLocal = function(_, id) G.sounds[id].playing = false end,
        playSound = function() error("emitter:playSound manda pacote PlaySound no cliente de MP", 2) end,
        stopSound = function() error("emitter:stopSound manda sendStopSound", 2) end,
    }
    function G.playing(name)
        local out = {}
        for id, snd in pairs(G.sounds) do
            if snd.name == name and snd.playing then out[#out + 1] = snd end
        end
        return out
    end
    function G.played(name)
        local n = 0
        for _, snd in pairs(G.sounds) do if snd.name == name then n = n + 1 end end
        return n
    end

    G.byNum = {}
    function G.player(o)
        local p = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, face = o.face or 0, pn = #G.players,
            dead = false, light = o.light }
        function p:getX() return self.x end
        function p:getY() return self.y end
        function p:getZ() return self.z end
        function p:getPlayerNum() return self.pn end
        function p:isDead() return self.dead end
        function p:getForwardDirection()
            local me = self
            return { getDirection = function() return me.face end }
        end
        function p:getCurrentSquare() return G.square(math.floor(self.x), math.floor(self.y), self.z) end
        function p:getBuilding() return G.interior[key(math.floor(self.x), math.floor(self.y), math.floor(self.z))] end
        function p:DistTo(x, y) return math.sqrt((self.x - x) ^ 2 + (self.y - y) ^ 2) end
        function p:getEmitter() return emitter end
        function p:getActiveLightItem() if self.light then return { lit = true } end return nil end
        function p:playSoundLocal(name)
            local id = #G.sounds + 1
            G.sounds[id] = { name = name, volume = 1, playing = true }
            return id
        end
        G.players[#G.players + 1] = p
        G.byNum[p.pn] = p
        return p
    end

    function G.zombie(o)
        local z = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, id = o.id, onlineID = o.onlineID or -1,
            remote = o.remote or false, md = {}, outfitName = o.outfit or "Generic01", dead = false, female = o.female }
        if o.eco then z.md.NOM_eco = true end
        function z:getX() return self.x end
        function z:getY() return self.y end
        function z:getZ() return self.z end
        function z:getPersistentOutfitID() return self.id end
        function z:getOnlineID() return self.onlineID end
        function z:isRemoteZombie() return self.remote end
        function z:getModData() return self.md end
        function z:hasModData() return next(self.md) ~= nil end
        function z:getOutfitName() return self.outfitName end
        function z:isDead() return self.dead end
        function z:isFemale() return self.female == true end
        function z:getCurrentSquare() return G.square(math.floor(self.x), math.floor(self.y), self.z) end
        function z:teleportTo(x, y, zz)
            self.x, self.y, self.z = math.floor(x), math.floor(y), math.floor(zz)
            self.lastX, self.lastY = self.x, self.y
            self.teleports = (self.teleports or 0) + 1
        end
        function z:setX(v) self.x = v; return v end
        function z:setY(v) self.y = v; return v end
        function z:setLastX(v) self.lastX = v; return v end
        function z:setLastY(v) self.lastY = v; return v end
        function z:dressInPersistentOutfitID(id) self.id = id end
        function z:removeFromWorld()
            self.removed = true
            for i, v in ipairs(G.zombies) do
                if v == self then table.remove(G.zombies, i) break end
            end
        end
        function z:removeFromSquare() self.offSquare = true end
        function z:getEmitter() return emitter end
        function z:playSoundLocal(name)
            local id = #G.sounds + 1
            G.sounds[id] = { name = name, volume = 1, playing = true, src = self }
            return id
        end
        function z:isUseless() return self.useless == true end
        function z:setUseless(b) self.useless = b end
        function z:setTarget(t) self.target = t end
        function z:getTarget() return self.target end
        function z:spotted(p, forced)
            if self.useless then self.target = nil return end
            self.target = p
            self.forcedSpot = forced
        end
        G.zombies[#G.zombies + 1] = z
        return z
    end
    -- pacote do dono com a posição antiga: o servidor aplica (applyZombie)
    function G.ownerPacket(z, x, y)
        z.x, z.y = x + 0.5, y + 0.5
    end

    isClient = function() return opts.client == true end
    isServer = function() return opts.server == true end
    getDebug = function() return opts.debug == true end -- -debug do processo
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    G.globalMD = opts.globalMD or {}
    ModData = {
        getOrCreate = function(name)
            G.globalMD[name] = G.globalMD[name] or {}
            return G.globalMD[name]
        end,
    }
    getTimestampMs = function() return G.now end
    -- GameTime.isGamePaused: solo = velocidade 0; dedicado = vazio com PauseEmpty
    isGamePaused = function() return G.paused == true end
    G.rand = opts.rand or 0
    ZombRand = function(n) return G.rand % n end
    getNumActivePlayers = function() return #G.players end
    getSpecificPlayer = function(i) return G.players[i + 1] end
    -- getPlayer() é o jogador em foco (tela dividida); o mod usa getSpecificPlayer(0)
    getPlayer = function() error("use getSpecificPlayer(0)", 2) end
    -- batentes: as do sprite de porta/janela somam nas propriedades do square
    -- (ISBuildIsoEntity.lua:195-198); G.flags[k] = { DoorWallN = true, ... }
    IsoFlagType = { water = "water", DoorWallN = "DoorWallN", DoorWallW = "DoorWallW", WindowN = "WindowN",
        WindowW = "WindowW", windowN = "windowN", windowW = "windowW", doorN = "doorN", doorW = "doorW" }
    getOnlinePlayers = function() return jlist(G.players) end
    getCell = function()
        return {
            getGridSquare = function(_, x, y, z) return G.square(x, y, z) end,
            getZombieList = function() return jlist(G.zombies) end,
        }
    end
    addZombiesInOutfit = function(x, y, z, n, outfit, female)
        local zz = G.zombie({ x = x, y = y, z = z, id = G.nextID, outfit = outfit, onlineID = G.nextID })
        G.nextID = G.nextID + 1
        zz.x, zz.y = x, y
        zz.femaleChance = female
        G.spawned[#G.spawned + 1] = zz
        G.fire("OnZombieCreate", zz)
        return jlist({ zz })
    end
    sendServerCommand = function(a, b, c, d)
        if d == nil then
            G.sentServer[#G.sentServer + 1] = { module = a, command = b, args = c }
        else
            G.sentServer[#G.sentServer + 1] = { player = a, module = b, command = c, args = d }
        end
    end
    sendClientCommand = function(a, b, c, d)
        if d == nil then
            G.sentClient[#G.sentClient + 1] = { module = a, command = b, args = c }
        else
            G.sentClient[#G.sentClient + 1] = { player = a, module = b, command = c, args = d }
        end
    end
    G.world = { tod = opts.tod or 12 }
    getGameTime = function()
        -- horas de mundo: G.world.hours quando o teste usa (evento de névoa), senão a hora do dia
        return { getTimeOfDay = function() return G.world.tod end,
            getWorldAgeHours = function() return G.world.hours or G.world.tod end }
    end
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
    function G.reload(mods)
        for _, m in ipairs(mods) do
            _G[m] = nil
            package.loaded[m] = nil
        end
    end
    -- n ticks do jogo, avançando o relógio real (60 FPS)
    function G.tick(n)
        for _ = 1, n or 1 do
            G.now = G.now + 16
            G.ticks = G.ticks + 1
            G.fire("OnTick", G.ticks)
        end
    end
    function G.seconds(s) G.tick(math.floor(s * 1000 / 16 + 0.5)) end
    function G.commands(list, command)
        local out = {}
        for _, c in ipairs(list) do if c.command == command then out[#out + 1] = c end end
        return out
    end
    return G
end

-- persistentOutfitID no formato do jogo; acha um ID que é Sem-rosto no período
-- (want true) ou zumbi comum, sem variante nenhuma (want false), com o sandbox
-- padrão (a chance do Sem-rosto pode ser trocada). redOnly: Sem-rosto só na névoa
-- vermelha (comum na névoa normal).
function W.semRostoID(period, want, chance, redOnly)
    require "NOM_VariantRules"
    require "NOM_Config"
    local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
    c.semRostoChance = chance or c.semRostoChance
    for seed = 1, 500 do
        local id = 7 * 65536 + seed
        local v = NOM_VariantRules.variant(id, period, c)
        if redOnly then
            if v == nil and NOM_VariantRules.variant(id, period, c, true) == "semrosto" then return id end
        elseif (want and v == "semrosto") or (not want and v == nil) then
            return id
        end
    end
    error("nenhum ID")
end

return W
