-- Anexos de sprite nos objetos de piso e parede (sprint 0023), por cima do mundo falso de
-- tests/fog_world.lua. Imita o B42.21 onde importa (bytecode, pz-api-notes §16.6):
-- * obj:getAttachedAnimSprite(): a ArrayList do objeto, nil até o 1º anexo (o campo nasce nulo;
--   addAttachedAnimSpriteInstance cria). Viva: size()/get(i) leem a lista na hora.
-- * obj:addAttachedAnimSpriteByName(nome): nome vazio ou sem sprite (namedMap) não faz nada,
--   nem cria sprite vazio; com sprite, uma IsoSpriteInstance do POOL vai pro fim da lista e o
--   nível do chunk é invalidado (G.invalidations). O namedMap do fake: os nomes medidos no
--   pack (tests/floor_sprites.lua, tests/wall_sprites.lua), menos G.unknown.
-- * obj:RemoveAttachedAnim(i): índice fora não faz nada; tira o i (os de trás andam um) e a
--   instância VOLTA PRO POOL: o próximo anexo de qualquer um reusa a mesma tabela (Lua) — o
--   mesmo objeto Java (IsoSpriteInstance.add / get).
-- * inst:getParentSprite():getName(), inst:SetAlpha(f), inst:SetTargetAlpha(f), inst:getAlpha().
-- * Proibidos pro mod (salvam ou mandam pacote, ou apagam o vanilla): RemoveAttachedAnims,
--   AttachExistingAnim, clearAttachedAnimSprite, setAttachedAnimSprite, transmit*: explodem.
--   O vanilla que limpa tudo (pá, ISShovelGround.lua:63) é G.wipe(obj), por fora.
-- * IsoObject.save grava a lista inteira, sem filtro: G.saveSnapshot() dispara OnSave (o
--   GameWindow.save dispara antes do IsoCell.save) e lê a lista de todo objeto carregado.
-- * IsoChunk.doLoadGridsquare dispara LoadGridsquare(square): G.loadSquare.
-- * instanceof(o, classe) com a hierarquia do jogo (IsoThumpable, IsoDoor, IsoWindow e
--   IsoMovingObject são IsoObject; IsoPlayer e IsoZombie são IsoMovingObject).
-- * ISTimedActionQueue.queues[jogador].queue[1] = ação atual (client/TimedActions/
--   ISTimedActionQueue.lua:138-155).
-- * Sprite próprio em runtime (sprint 0035, spike-sprite-proprio §1b, §2, §5):
--   - getSprite(nome) = IsoSpriteManager.getSprite: o do namedMap; senão AddSprite cria um
--     sprite SEM nome, SEM flags, ID 20000000, com a textura do getTexture(nome) (nil: sprite
--     vazio, que desenha nada) e o põe no namedMap (G.sprites). Os nomes do pack (KNOWN) já
--     estão no namedMap com nome (tiledef).
--   - sprite:setName(nome) só grava o nome; getName() devolve nil sem ele; getProperties():
--     set(flag)/has(flag).
--   - addAttachedAnimSpriteByName só acha o que está no namedMap (não cria); o
--     getParentSprite() da instância é o sprite (o getName() dele, nil se esqueceram o setName).
--   - Sprite de runtime anexado sem a flag do lado (piso: FloorOverlay; parede N/W:
--     WallOverlay + attachedN/W) cai na profundidade genérica (§2): vai pra G.badFlags.
--     Sprite vazio anexado vai pra G.emptyAttached.
--   - IsoObject.load: anexo de ID fora do intMap (20000000) é descartado (§5).
--   - getTexture(caminho em media/textures/NOM/OutroMundo/): o PNG existe em mod/42/ (nil se
--     não; G.missingTex[caminho] = true tira um). Outro caminho: o getTexture que o teste já
--     tinha (ou textura, se é nome do pack).
-- * obj:getTextureName() = o nome do sprite do objeto, nil sem sprite (IsoObject.getTextureName
--   0–16: sprite.name; uso vanilla shared/Foraging/forageSystem.lua:1681 no getFloor()). O piso
--   nasce com o sprite de G.floorSprite (hotfix do chão, nomes de newtiledefinitions.tiles.txt):
--   dentro, floors_interior_tilesandwood_01_0; fora, quadras de 8 tiles em xadrez de grama
--   (blends_natural_01_16, natural) e asfalto (blends_street_01_0). G.floorName[k] troca um
--   (false = sem sprite).
local A = {}
-- os getTexture falsos já postos (global: tem teste que dá dofile neste arquivo a cada setup)
NOM_TestTextureFakes = NOM_TestTextureFakes or setmetatable({}, { __mode = "k" })

local OWN_DIR = "media/textures/NOM/OutroMundo/"
local RUNTIME_ID = 20000000 -- IsoSprite.<init>(IsoSpriteManager) 50–53

local PARENT = { IsoThumpable = "IsoObject", IsoDoor = "IsoObject", IsoWindow = "IsoObject",
    IsoMovingObject = "IsoObject", IsoPlayer = "IsoMovingObject", IsoZombie = "IsoMovingObject" }

local KNOWN = {}
for _, file in ipairs({ "tests/floor_sprites.lua", "tests/wall_sprites.lua" }) do
    for name in pairs(dofile(file)) do KNOWN[name] = true end
end

function A.install(G)
    -- mundo novo: o namedMap começa vazio (IsoWorld.init 2182–2185) e o NOM_OwnSprites também
    _G.NOM_OwnSprites, package.loaded.NOM_OwnSprites = nil, nil
    G.objs, G.unknown, G.invalidations, G.java = {}, {}, 0, G.java or 0
    G.floorName, G.textureNames = {}, 0
    G.blends = true -- todo piso nasce com um blend de grama anexado (vanilla)
    G.sprites, G.badFlags, G.emptyAttached, G.missingTex = {}, {}, {}, {}
    local pool = {}

    local function key(x, y, z) return x .. "," .. y .. "," .. (z or 0) end

    local spriteMeta = { __index = {
        getName = function(self) G.java = G.java + 1; return self.name end,
        setName = function(self, n)
            G.java = G.java + 1
            if not G.ignoreSetName then self.name = n end
        end,
        getID = function(self) G.java = G.java + 1; return self.id end,
        getProperties = function(self)
            G.java = G.java + 1
            local flags = self.flags
            return {
                set = function(_, f)
                    G.java = G.java + 1
                    assert(f ~= nil, "props:set(nil): IsoFlagType sem o campo")
                    flags[f] = true
                end,
                has = function(_, f) G.java = G.java + 1; return flags[f] == true end,
            }
        end,
    } }

    -- sprite do pack (tiledef): nome e ID do intMap
    local packSprites = {}
    local function vanillaSprite(name)
        local s = packSprites[name]
        if not s then
            s = setmetatable({ name = name, id = 1, flags = {}, texture = true }, spriteMeta)
            packSprites[name] = s
        end
        return s
    end

    -- IsoSprite.getSprite(manager, nome, 0): só o namedMap, nunca cria
    local function lookup(name)
        if name == nil or name == "" then return nil end
        if G.sprites[name] then return G.sprites[name] end
        if KNOWN[name] and not G.unknown[name] then return vanillaSprite(name) end
        return nil
    end

    -- o getTexture do teste (não o de um mundo falso anterior: a cadeia cresceria a cada setup)
    local prevTexture = getTexture
    if NOM_TestTextureFakes[prevTexture] then prevTexture = NOM_TestTextureFakes[prevTexture].prev end
    local files = {}
    local function fake(path)
        G.java = G.java + 1
        if type(path) == "string" and path:sub(1, #OWN_DIR) == OWN_DIR then
            if G.missingTex[path] then return nil end
            if files[path] == nil then
                local f = io.open("mod/42/" .. path, "rb")
                files[path] = f ~= nil
                if f then f:close() end
            end
            return files[path] and { path = path } or nil
        end
        if prevTexture then return prevTexture(path) end
        return KNOWN[path] and { path = path } or nil
    end
    NOM_TestTextureFakes[fake] = { prev = prevTexture }
    getTexture = fake

    getSprite = function(name)
        G.java = G.java + 1
        local s = lookup(name)
        if s then return s end
        -- AddSprite: new IsoSprite (ID 20000000), LoadSingleTexture, namedMap.put; sem setName
        s = setmetatable({ name = nil, id = RUNTIME_ID, flags = {}, runtime = true,
            texture = getTexture(name) ~= nil }, spriteMeta)
        G.java = G.java - 1 -- o LoadSingleTexture é dentro da mesma ida ao Java
        G.sprites[name] = s
        return s
    end

    -- o sprite de runtime tem a flag do lado do objeto? (§2: senão, profundidade genérica)
    local function sideOk(s, kind)
        local f = s.flags
        if kind == "F" then return f[IsoFlagType.FloorOverlay] == true and not f[IsoFlagType.WallOverlay] end
        if not f[IsoFlagType.WallOverlay] or f[IsoFlagType.FloorOverlay] then return false end
        if kind == "N" then return f[IsoFlagType.attachedN] == true and not f[IsoFlagType.attachedW] end
        return f[IsoFlagType.attachedW] == true and not f[IsoFlagType.attachedN]
    end

    local instMeta = { __index = {
        getParentSprite = function(self)
            G.java = G.java + 1
            return self.sprite
        end,
        SetAlpha = function(self, v) G.java = G.java + 1; self.alpha = v end,
        SetTargetAlpha = function(self, v) G.java = G.java + 1; self.target = v end,
        getAlpha = function(self) return self.alpha end,
    } }

    -- uma instância do pool (reusa a tabela devolvida, como IsoSpriteInstance.get)
    -- sprite: o do namedMap (anexo pelo nome); sem ele, o do pack (mapa, erosão, save)
    local function newInst(name, vanilla, sprite)
        local inst = table.remove(pool) or setmetatable({}, instMeta)
        inst.name, inst.alpha, inst.target, inst.vanilla = name, 1, 1, vanilla
        inst.sprite = sprite or vanillaSprite(name)
        return inst
    end

    local FORBIDDEN = { RemoveAttachedAnims = true, AttachExistingAnim = true, clearAttachedAnimSprite = true,
        setAttachedAnimSprite = true, transmitUpdatedSpriteToClients = true, transmitUpdatedSpriteToServer = true,
        transmitCompleteItemToServer = true, transmitCompleteItemToClients = true }

    -- nome do sprite do piso que nasce em (x, y, z), ou nil
    function G.floorSprite(x, y, z)
        local k = key(x, y, z)
        if G.floorName[k] ~= nil then return G.floorName[k] or nil end
        if G.interior[k] or G.roofed[k] then return "floors_interior_tilesandwood_01_0" end
        if (math.floor(x / 8) + math.floor(y / 8)) % 2 == 0 then return "blends_natural_01_16" end
        return "blends_street_01_0"
    end

    function G.obj(x, y, z, kind, opts)
        opts = opts or {}
        -- list = false: o campo existe (nulo no Java), sem cair no __index que explode
        local o = { class = opts.class or "IsoObject", x = x, y = y, z = z or 0, kind = kind, list = false,
            sprite = opts.sprite or (kind == "F" and G.floorSprite(x, y, z)) or false }
        local api = {
            getTextureName = function()
                G.textureNames = G.textureNames + 1
                return o.sprite or nil
            end,
            getAttachedAnimSprite = function()
                if not o.list then return nil end
                return { size = function() return #o.list end, get = function(_, i) return o.list[i + 1] end }
            end,
            addAttachedAnimSpriteByName = function(_, name)
                local s = lookup(name)
                if not s then return end
                if s.runtime then
                    if not sideOk(s, kind) then G.badFlags[#G.badFlags + 1] = name .. " em " .. kind end
                    if not s.texture then G.emptyAttached[#G.emptyAttached + 1] = name end
                end
                o.list = o.list or {}
                o.list[#o.list + 1] = newInst(name, false, s)
                G.invalidations = G.invalidations + 1
            end,
            RemoveAttachedAnim = function(_, i)
                if not o.list or i < 0 or i >= #o.list then return end
                pool[#pool + 1] = table.remove(o.list, i + 1)
                G.invalidations = G.invalidations + 1
            end,
            getSquare = function() return G.square(x, y, z) end,
        }
        setmetatable(o, { __index = function(_, m)
            if api[m] then
                G.java = G.java + 1
                return api[m]
            end
            if FORBIDDEN[m] then error("obj:" .. m .. " proibido (save, rede ou apaga o vanilla)", 2) end
            error("obj:" .. tostring(m) .. " não devia ser chamado", 2)
        end })
        for _, n in ipairs(opts.attached or {}) do
            o.list = o.list or {}
            o.list[#o.list + 1] = newInst(n, true)
        end
        G.objs[key(x, y, z) .. kind] = o
        return o
    end

    function G.floorOf(x, y, z)
        local k = key(x, y, z) .. "F"
        if G.objs[k] == nil and G.noFloor ~= true then
            G.obj(x, y, z, "F", { attached = G.blends and { "blends_natural_01_" .. ((x + y) % 8) } or nil })
        end
        return G.objs[k]
    end

    function G.wallOf(x, y, z, north)
        return G.objs[key(x, y, z) .. (north and "N" or "W")]
    end

    -- anexo vanilla (erosão, mapa) num objeto que já existe: reusa o pool como o jogo
    function G.vanillaAttach(o, name)
        o.list = rawget(o, "list") or {}
        o.list[#o.list + 1] = newInst(name, true)
    end

    -- o vanilla limpando tudo (RemoveAttachedAnims da pá, ISShovelGround.lua:63)
    function G.wipe(o)
        for _, inst in ipairs(rawget(o, "list") or {}) do pool[#pool + 1] = inst end
        o.list = {}
    end

    -- nomes na lista do objeto; vanillaOnly: só os que não são do mod
    function G.attachedNames(o, which)
        local out = {}
        for _, inst in ipairs(rawget(o, "list") or {}) do
            if which == nil or (which == "vanilla") == (inst.vanilla == true) then out[#out + 1] = inst.name end
        end
        return out
    end

    -- quantos anexos do mod (não vanilla) há em todo objeto carregado
    function G.ours()
        local n = 0
        for _, o in pairs(G.objs) do n = n + #G.attachedNames(o, "mod") end
        return n
    end

    -- o que o IsoChunk.Save gravaria agora: OnSave antes, depois a lista de cada objeto
    function G.saveSnapshot()
        G.fire("OnSave")
        local snap = { ours = 0, vanilla = 0, names = {} }
        for k, o in pairs(G.objs) do
            snap.names[k] = G.attachedNames(o)
            snap.ours = snap.ours + #G.attachedNames(o, "mod")
            snap.vanilla = snap.vanilla + #G.attachedNames(o, "vanilla")
        end
        return snap
    end

    -- chunk carregado do disco: objetos novos com o que veio no arquivo; spec.F/N/W = nomes
    -- vazados (anexos que um save levou, não-vanilla), spec.vanillaF/N/W = do mapa ou erosão.
    -- O save guarda o ID: o vazado que não é do pack (runtime, ID 20000000) não está no intMap
    -- e é descartado (IsoObject.load 221–251, 508–510); conta em G.discarded.
    G.discarded = 0
    function G.loadSquare(x, y, z, spec)
        for _, kind in ipairs({ "F", "N", "W" }) do
            local leaked, vanilla = spec[kind], spec["vanilla" .. kind]
            if leaked or vanilla or kind == "F" then
                local o = G.obj(x, y, z, kind, { attached = vanilla })
                for _, n in ipairs(leaked or {}) do
                    if KNOWN[n] then
                        o.list = rawget(o, "list") or {}
                        o.list[#o.list + 1] = newInst(n, false)
                    else
                        G.discarded = G.discarded + 1
                    end
                end
            end
        end
        G.fire("LoadGridsquare", G.square(x, y, z))
    end

    -- o servidor trocou o objeto (MP: pacote do objeto): novo, só com os anexos vanilla
    function G.replace(x, y, z, kind)
        local old = G.objs[key(x, y, z) .. kind]
        return G.obj(x, y, z, kind, { attached = old and G.attachedNames(old, "vanilla") or nil, class = old and old.class })
    end

    local function isSquare(o) return rawget(o, "kind") == "square" end
    local function isPlayer(o)
        for _, p in ipairs(G.players) do if p == o then return true end end
        return false
    end
    instanceof = function(o, cls)
        G.java = G.java + 1
        if type(o) ~= "table" then return false end
        local c = rawget(o, "class") or (isSquare(o) and "IsoGridSquare") or (isPlayer(o) and "IsoPlayer") or nil
        while c do
            if c == cls then return true end
            c = PARENT[c]
        end
        return false
    end

    ISTimedActionQueue = { queues = {} }
    -- a ação atual do jogador p (nil = fila vazia)
    function G.action(p, act)
        ISTimedActionQueue.queues[p] = act and { queue = { act } } or { queue = {} }
    end
    return G
end

return A
