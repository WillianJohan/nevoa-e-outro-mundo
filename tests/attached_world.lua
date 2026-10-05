-- Anexos de sprite nos objetos de piso e parede (sprint 0023), por cima do mundo falso de
-- tests/fog_world.lua. Imita o B42.21 onde importa (bytecode, pz-api-notes §16.6):
-- * obj:getAttachedAnimSprite(): a ArrayList do objeto, nil até o 1º anexo (o campo nasce nulo;
--   addAttachedAnimSpriteInstance cria). Viva: size()/get(i) leem a lista na hora.
-- * obj:addAttachedAnimSpriteByName(nome): nome vazio ou sem sprite (namedMap) não faz nada,
--   nem cria sprite vazio; com sprite, uma IsoSpriteInstance do POOL vai pro fim da lista e o
--   nível do chunk é invalidado (G.invalidations).
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
local A = {}

local PARENT = { IsoThumpable = "IsoObject", IsoDoor = "IsoObject", IsoWindow = "IsoObject",
    IsoMovingObject = "IsoObject", IsoPlayer = "IsoMovingObject", IsoZombie = "IsoMovingObject" }

function A.install(G)
    G.objs, G.unknown, G.invalidations, G.java = {}, {}, 0, G.java or 0
    G.blends = true -- todo piso nasce com um blend de grama anexado (vanilla)
    local pool = {}

    local function key(x, y, z) return x .. "," .. y .. "," .. (z or 0) end

    local instMeta = { __index = {
        getParentSprite = function(self)
            G.java = G.java + 1
            local me = self
            return { getName = function() G.java = G.java + 1; return me.name end }
        end,
        SetAlpha = function(self, v) G.java = G.java + 1; self.alpha = v end,
        SetTargetAlpha = function(self, v) G.java = G.java + 1; self.target = v end,
        getAlpha = function(self) return self.alpha end,
    } }

    -- uma instância do pool (reusa a tabela devolvida, como IsoSpriteInstance.get)
    local function newInst(name, vanilla)
        local inst = table.remove(pool) or setmetatable({}, instMeta)
        inst.name, inst.alpha, inst.target, inst.vanilla = name, 1, 1, vanilla
        return inst
    end

    local FORBIDDEN = { RemoveAttachedAnims = true, AttachExistingAnim = true, clearAttachedAnimSprite = true,
        setAttachedAnimSprite = true, transmitUpdatedSpriteToClients = true, transmitUpdatedSpriteToServer = true,
        transmitCompleteItemToServer = true, transmitCompleteItemToClients = true }

    function G.obj(x, y, z, kind, opts)
        opts = opts or {}
        -- list = false: o campo existe (nulo no Java), sem cair no __index que explode
        local o = { class = opts.class or "IsoObject", x = x, y = y, z = z or 0, kind = kind, list = false }
        local api = {
            getAttachedAnimSprite = function()
                if not o.list then return nil end
                return { size = function() return #o.list end, get = function(_, i) return o.list[i + 1] end }
            end,
            addAttachedAnimSpriteByName = function(_, name)
                if name == nil or name == "" or G.unknown[name] then return end
                o.list = o.list or {}
                o.list[#o.list + 1] = newInst(name, false)
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
    -- vazados (anexos que um save levou, não-vanilla), spec.vanillaF/N/W = do mapa ou erosão
    function G.loadSquare(x, y, z, spec)
        for _, kind in ipairs({ "F", "N", "W" }) do
            local leaked, vanilla = spec[kind], spec["vanilla" .. kind]
            if leaked or vanilla or kind == "F" then
                local o = G.obj(x, y, z, kind, { attached = vanilla })
                for _, n in ipairs(leaked or {}) do
                    o.list = rawget(o, "list") or {}
                    o.list[#o.list + 1] = newInst(n, false)
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
