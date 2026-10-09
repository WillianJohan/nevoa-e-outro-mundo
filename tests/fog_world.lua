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
-- * Sirene (sprint 0033): z:faceLocationF(x, y) = IsoGameCharacter.faceLocationF(FF)Z
--   (javap; uso vanilla client/BuildingObjects/TimedActions/ISBuildAction.lua:248): vira o
--   zumbi pro ponto, sem rede, e devolve true; o fake guarda em z.faced. getX/getY: IsoMovingObject.
-- * Tela e câmera do jogador 0 (sprint 0034, bytecode B42.21, pz-api-notes §16.6):
--   getPlayerScreenWidth/Height(i) = IsoCamera.getScreenWidth/Height(i) (LuaManager$GlobalObject);
--   getCore():getZoom(i) = displayZoom · T/2 (Core.getZoom(I), T = Core.tileScale, 2 no Tiles2x);
--   a câmera centra no jogador (PlayerCamera.center 0–147): offX = XToScreen(x + deferedX,
--   y + deferedY, zCam, 0) − offscreenW/2 + playerOffsetX (0), offY = YToScreen(...) − offscreenH/2
--   − offsetY · 1,5 (0 aqui) + playerOffsetY (−56 / (2 / T), IsoCamera.<clinit>), com zCam = getZ() a pé
--   (FrameState.calculateCameraZ) e offscreenW = int(w · zoom) (MultiTextureFBO2.getWidth(I));
--   IsoCamera.getOffX(i) = int(offX + rightClickX) (PlayerCamera.getOffX). IsoUtils.XToIso(i, sx,
--   sy, z) = (sx + offX + 2(sy + offY)) / (64T) + 3z; YToIso = (sx + offX − 2(sy + offY)) / (−64T)
--   + 3z (IsoUtils.XToIso(IFFF) 0–36, YToIso(IFFF) 0–36). G.camera.deferX/deferY (o carro olha
--   pra frente) e panX/panY (rightClick, mirar) tiram a câmera do centro.
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
            -- luz fixa (sprint 0039): rede (hasGridPower), gerador (haveElectricity) e cômodo
            hasGridPower = function() return G.gridPower == true end,
            haveElectricity = function() return G.generator[k] == true end,
            getRoom = function() return G.rooms[k] end,
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

    -- Emitter do pool (sprint 0034, pz-api-notes §22): getWorld():getFreeEmitter(x, y, z)
    -- devolve um emitter já posicionado (IsoWorld.getFreeEmitter(FFF) 0–16), que fica onde
    -- foi posto. O pool devolve o que ficou vazio e outro sistema pode pegá-lo (aqui o mesmo
    -- objeto volta). playSoundImpl(nome, false, nil) → id, isPlaying(id), stopSoundLocal(id),
    -- setVolume(id, v): locais. playSound/stopSound mandam pacote e stopAll mata o som dos
    -- outros: explodem. G.sounds[id].at é onde o emitter estava ao tocar.
    -- FMODSoundEmitter tem playSoundImpl(String, IsoGridSquare) e (String, IsoObject): com
    -- nil o Kahlua escolhe o do square, que lê square.x e dá NPE (bytecode 1208–1235; visto
    -- no console.txt). (String, boolean, IsoObject) (1245–1250) cai no do IsoObject com nil.
    function G.newEmitter(where)
        local e = { x = where.x, y = where.y, z = where.z, vehicle = where.vehicle }
        function e:playSoundImpl(name, flag, obj)
            if type(flag) ~= "boolean" then
                error('Cannot read field "x" because "square" is null (playSoundImpl(nome, nil))', 2)
            end
            assert(obj == nil, "playSoundImpl com objeto")
            local id = #G.sounds + 1
            G.sounds[id] = { name = name, volume = 1, pitch = 1, playing = true, emitter = self,
                at = { x = self.x, y = self.y, z = self.z }, vehicle = self.vehicle, startedAt = G.now }
            self.claimed = G.ticks
            return id
        end
        function e:isPlaying(id) return G.sounds[id] ~= nil and G.sounds[id].emitter == self and G.sounds[id].playing end
        function e:stopSoundLocal(id)
            if G.sounds[id] and G.sounds[id].emitter == self then G.sounds[id].playing = false end
        end
        function e:setVolume(id, v)
            if G.sounds[id] and G.sounds[id].emitter == self then G.sounds[id].volume = v end
        end
        -- FMODSoundEmitter.setPitch(long, float), 0–112: o id só decide o DebugLog; a afinação vai
        -- pra TODO som do emitter (toStart e instances). Local, sem pacote.
        function e:setPitch(id, pitch)
            assert(type(id) == "number" and type(pitch) == "number", "setPitch(long, float)")
            for _, s in pairs(G.sounds) do
                if s.emitter == self and s.playing then s.pitch = pitch end
            end
        end
        e.playSound = function() error("emitter:playSound manda pacote no cliente de MP", 2) end
        e.stopSound = function() error("emitter:stopSound manda sendStopSound", 2) end
        e.stopAll = function() error("stopAll num emitter do pool mata o som de outro sistema", 2) end
        function e:empty()
            for _, s in pairs(G.sounds) do
                if s.emitter == self and s.playing then return false end
            end
            return true
        end
        return e
    end
    G.pool = {}
    G.freeCalls = 0
    getWorld = function()
        return { getFreeEmitter = function(_, x, y, z)
            G.freeCalls = G.freeCalls + 1
            for _, e in ipairs(G.pool) do
                if e.claimed ~= G.ticks and e:empty() then
                    e.x, e.y, e.z, e.claimed = x, y, z, G.ticks
                    return e
                end
            end
            local e = G.newEmitter({ x = x, y = y, z = z })
            e.claimed = G.ticks
            G.pool[#G.pool + 1] = e
            return e
        end }
    end

    G.byNum = {}
    G.remotes = {}
    -- o.remote: jogador de outro cliente, que este cliente só conhece pelo getOnlinePlayers()
    function G.player(o)
        local p = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, face = o.face or 0, pn = o.remote and -1 or #G.players,
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
        -- Luz na mão (sprint 0038): o.light = true (HandTorch: cone, 15, 0,5) ou
        -- { cone, distance, dot }. InventoryItem.isTorchCone/getLightDistance/getTorchDot (javap);
        -- getActiveLightItem só devolve item aceso. setActivated é local (sem sync).
        if o.light then
            local l = type(o.light) == "table" and o.light or {}
            local inv = {}
            p.inventory = inv
            local item = { lit = true, on = true, cone = l.cone ~= false, distance = l.distance or 15, dot = l.dot or 0.5 }
            function item:isTorchCone() return self.cone end
            function item:getLightDistance() return self.distance end
            function item:getTorchDot() return self.dot end
            function item:isActivated() return self.on end
            function item:setActivated(b) self.on = b end
            function item:getContainer() return inv end
            p.item = item
        end
        function p:getInventory() return self.inventory end
        function p:getActiveLightItem()
            if self.item and self.item.on then return self.item end
            return nil
        end
        -- IsoGameCharacter.getForwardDirectionX/Y()F (javap): a direção unitária pra onde olha
        function p:getForwardDirectionX() return math.cos(self.face) end
        function p:getForwardDirectionY() return math.sin(self.face) end
        -- IsoGameCharacter.getVehicle(); BaseVehicle.getHeadlightsOn()Z (server/Vehicles/Vehicles.lua:565)
        p.vehicle = o.vehicle
        function p:getVehicle() return self.vehicle end
        function p:playSoundLocal(name)
            local id = #G.sounds + 1
            G.sounds[id] = { name = name, volume = 1, playing = true }
            return id
        end
        if o.remote then
            G.remotes[#G.remotes + 1] = p
            return p
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
        function z:isLocal() return (not isClient() and not isServer()) or not self.remote end
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
        function z:faceLocationF(x, y) self.faced = { x = x, y = y }; return true end
        -- Andando (PathFindState): o useless não para, o PathFindState.execute nem olha
        -- (bytecode). Para quando bPathfind e bMoving caem e o caminho some (o fim do
        -- execute 128–149). o.walking: o zumbi já nasce indo pra algum lugar.
        z.vars = { bPathfind = o.walking == true, bMoving = o.walking == true }
        z.path = o.walking and {} or nil
        function z:setVariable(k, v) self.vars[k] = v end
        function z:setPath2(p) self.path = p end
        function z:getPathFindBehavior2()
            local zz = self
            return { cancel = function() zz.pathCancelled = true end }
        end
        function z:isMoving() return self.vars.bMoving == true or self.vars.bPathfind == true end
        -- Sprint 0052 / 0036: IsoZombie.pathToLocationF → PathFindBehavior2 (pz-api-notes §27).
        function z:pathToLocationF(x, y, zz)
            self.goal = { x = x, y = y, z = zz }
            self.vars.bPathfind, self.vars.bMoving = true, true
            self.path = self.path or {}
        end
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
    -- getCore():getGameMode() == "Tutorial": shared/TimedActions/ISGrabCorpseAction.lua:140
    G.screenW, G.screenH, G.zoom, G.tileScale = opts.screenW or 1920, opts.screenH or 1080, opts.zoom or 1, 2
    G.camera = { deferX = 0, deferY = 0, panX = 0, panY = 0 }
    local function java() G.java = (G.java or 0) + 1 end
    getCore = function()
        return { getGameMode = function() return opts.gameMode or "Sandbox" end,
            getZoom = function(_, i) java(); assert(i == 0, "zoom de outro jogador"); return G.zoom end }
    end
    getPlayerScreenWidth = function(i) java(); assert(i == 0); return G.screenW end
    getPlayerScreenHeight = function(i) java(); assert(i == 0); return G.screenH end
    local function trunc(v) return v >= 0 and math.floor(v) or math.ceil(v) end
    local function cameraOff()
        local p, T, c = G.players[1], G.tileScale, G.camera
        local x, y = p.x + c.deferX, p.y + c.deferY
        local offX = 32 * T * (x - y) - trunc(G.screenW * G.zoom) / 2
        local offY = 16 * T * (x + y) - 96 * T * p.z - trunc(G.screenH * G.zoom) / 2 + trunc(-56 / trunc(2 / T))
        return trunc(offX + c.panX), trunc(offY + c.panY)
    end
    IsoUtils = {
        XToIso = function(i, sx, sy, z)
            java()
            assert(i == 0 and z ~= nil, "XToIso(int, F, F, F)")
            local ox, oy = cameraOff()
            return (sx + ox + 2 * (sy + oy)) / (64 * G.tileScale) + 3 * z
        end,
        YToIso = function(i, sx, sy, z)
            java()
            assert(i == 0 and z ~= nil, "YToIso(int, F, F, F)")
            local ox, oy = cameraOff()
            return (sx + ox - 2 * (sy + oy)) / (-64 * G.tileScale) + 3 * z
        end,
    }
    -- LuaManager$GlobalObject.isoToScreenX/Y(IFFF) 0–60 (sprint 0035): (IsoUtils.XToScreen(x + fjx,
    -- y + fjy, z, 0) − PlayerCamera.getOffX()) / zoom + IsoCamera.getScreenLeft(i), com XToScreen =
    -- 32T(x − y) e YToScreen = 16T(x + y) − 96Tz (IsoUtils 0–33, 0–50). G.camera.jiggleX/Y é o
    -- PlayerCamera.fixJigglyModelsSquareX/Y; a tela do jogador 0 começa em (0, 0).
    getPlayerScreenLeft = function(i) java(); assert(i == 0); return 0 end
    getPlayerScreenTop = function(i) java(); assert(i == 0); return 0 end
    isoToScreenX = function(i, x, y, z)
        java()
        assert(i == 0 and z ~= nil, "isoToScreenX(int, F, F, F)")
        local ox = cameraOff()
        local c = G.camera
        return (32 * G.tileScale * ((x + (c.jiggleX or 0)) - (y + (c.jiggleY or 0))) - ox) / G.zoom
    end
    isoToScreenY = function(i, x, y, z)
        java()
        assert(i == 0 and z ~= nil, "isoToScreenY(int, F, F, F)")
        local _, oy = cameraOff()
        local c = G.camera
        return (16 * G.tileScale * ((x + (c.jiggleX or 0)) + (y + (c.jiggleY or 0))) - 96 * G.tileScale * z - oy) / G.zoom
    end
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
    -- addSound do mundo (caça, lanterna, gritos; sprint 0051: caça no piscar da preta).
    -- G.sounds já guarda emitters de personagem — estes vão em G.worldSounds.
    G.worldSounds = {}
    addSound = function(src, x, y, z, radius, volume)
        G.worldSounds[#G.worldSounds + 1] = { src = src, x = x, y = y, z = z, radius = radius, volume = volume }
    end
    -- Lore do zumbi (NOM_NightStats quando NOM_Night carrega com a caça no piscar da 0051).
    G.lore = { speed = 2, sight = 2, hearing = 2 }
    getSandboxOptions = function()
        return {
            getOptionByName = function(_, name)
                local key = (name:match("ZombieLore%.(%w+)$") or name):lower()
                return { getValue = function() return G.lore[key] or 2 end }
            end,
        }
    end
    G.rand = opts.rand or 0
    ZombRand = function(n) return G.rand % n end
    getNumActivePlayers = function() return #G.players end
    getSpecificPlayer = function(i) return G.players[i + 1] end
    -- getPlayer() é o jogador em foco (tela dividida); o mod usa getSpecificPlayer(0)
    getPlayer = function() error("use getSpecificPlayer(0)", 2) end
    -- batentes: as do sprite de porta/janela somam nas propriedades do square
    -- (ISBuildIsoEntity.lua:195-198); G.flags[k] = { DoorWallN = true, ... }
    IsoFlagType = { water = "water", DoorWallN = "DoorWallN", DoorWallW = "DoorWallW", WindowN = "WindowN",
        WindowW = "WindowW", windowN = "windowN", windowW = "windowW", doorN = "doorN", doorW = "doorW",
        -- flags do sprite próprio (sprint 0035; enum IsoFlagType do bytecode)
        FloorOverlay = "FloorOverlay", WallOverlay = "WallOverlay", attachedN = "attachedN", attachedW = "attachedW" }
    -- LuaManager$GlobalObject.getOnlinePlayers 0–30: servidor = GameServer.getPlayers, cliente
    -- = GameClient.getPlayers (o IDToPlayerMap: os locais e os remotos que ele conhece), solo =
    -- ArrayList vazia
    getOnlinePlayers = function()
        if not opts.client and not opts.server then return jlist({}) end
        local all = {}
        for _, p in ipairs(G.players) do all[#all + 1] = p end
        for _, p in ipairs(G.remotes) do all[#all + 1] = p end
        return jlist(all)
    end
    getCell = function()
        return {
            getGridSquare = function(_, x, y, z) return G.square(x, y, z) end,
            getZombieList = function() return jlist(G.zombies) end,
            getLamppostPositions = function() G.lampListCalls = G.lampListCalls + 1 return jlist(G.lamps) end,
        }
    end
    -- Luz fixa (sprint 0039): IsoLightSource da lista de postes (getX/Y/Z, getRadius, isActive,
    -- isHydroPowered; javap) e cômodo com interruptor (IsoRoom.getLightSwitches, IsoLightSwitch
    -- isActivated/hasLightBulb/getUseBattery/getHasBattery/getPower/getSquare). G.lampCalls conta.
    G.lamps, G.rooms, G.generator, G.lampCalls, G.lampListCalls = {}, {}, {}, 0, 0
    function G.lamp(o)
        local l = { x = o.x, y = o.y, z = o.z or 0, radius = o.radius or 8, on = o.on ~= false, hydro = o.hydro == true }
        local function c(f) return function() G.lampCalls = G.lampCalls + 1 return f() end end
        l.getX, l.getY, l.getZ = c(function() return l.x end), c(function() return l.y end), c(function() return l.z end)
        l.getRadius = c(function() return l.radius end)
        l.isActive = c(function() return l.on end)
        l.isHydroPowered = c(function() return l.hydro end)
        -- Poste que pisca (sprint 0045, §34): luz de dentro de prédio tem getLocalToBuilding() e o
        -- update() do jogo reescreve a cor dela; a de fora guarda o setR/G/B.
        l.building = o.building
        l.r, l.g, l.b = 1, 0.9, 0.7
        l.getLocalToBuilding = function() return l.building end
        l.getR, l.getG, l.getB = function() return l.r end, function() return l.g end, function() return l.b end
        l.setR = function(_, v) l.r = v end
        l.setG = function(_, v) l.g = v end
        l.setB = function(_, v) l.b = v end
        G.lamps[#G.lamps + 1] = l
        return l
    end
    -- Cômodo retangular x0..x1, y0..y1 no andar z, com um interruptor.
    function G.room(o)
        local sw = { on = o.on ~= false, bulb = o.bulb ~= false, battery = o.battery == true, charge = o.charge or 0 }
        sw.isActivated = function() return sw.on end
        sw.hasLightBulb = function() return sw.bulb end
        sw.getUseBattery = function() return sw.battery end
        sw.getHasBattery = function() return sw.charge > 0 end
        sw.getPower = function() return sw.charge end
        sw.getSquare = function() return G.square(o.x0, o.y0, o.z or 0) end
        local room = { switch = sw }
        room.getLightSwitches = function() G.roomCalls = (G.roomCalls or 0) + 1 return jlist({ sw }) end
        for x = o.x0, o.x1 do
            for y = o.y0, o.y1 do G.rooms[key(x, y, o.z or 0)] = room end
        end
        return room
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
            getWorldAgeHours = function() return G.world.hours or G.world.tod end,
            isZombieInactivityPhase = function() return false end }
    end
    -- ThunderStorm.triggerThunderEvent(x, y, strike, lightning, rumble) (sprint 0045, §34): no servidor
    -- o jogo transmite sozinho; G.thunders guarda as chamadas.
    G.thunders = {}
    local thunder = {
        triggerThunderEvent = function(_, x, y, strike, lightning, rumble)
            G.thunders[#G.thunders + 1] = { x = x, y = y, strike = strike, lightning = lightning, rumble = rumble }
        end,
    }
    getClimateManager = function()
        return { getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end,
            getThunderStorm = function() return thunder end }
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
    -- sprint 0049: branca 100%. Comum (want false) = ID 0.
    -- redOnly: não é Sem-rosto na branca (pesos), mas é na vermelha (split 1/4).
    if not want and not redOnly then return 0 end
    for seed = 1, 20000 do
        local id = 7 * 65536 + seed
        local v = NOM_VariantRules.variant(id, period, c)
        if redOnly then
            if v ~= "semrosto" and NOM_VariantRules.variant(id, period, c, true) == "semrosto" then
                return id
            end
        elseif want and v == "semrosto" then
            return id
        end
    end
    error("nenhum ID")
end

return W
