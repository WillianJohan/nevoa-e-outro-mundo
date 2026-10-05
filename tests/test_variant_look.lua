-- client/NOM_VariantLook.lua (sprint 0012) com o NOM_NightStats de verdade, num
-- jogo falso que IMITA o B42 (bytecode, pz-api-notes §14) no visual do zumbi:
-- * HumanVisual: getSkinTexture() devolve o skinTextureName se houver, senão a pele
--   calculada (0–11); setSkinTextureName só grava. Zumbi nasce com o nome nil.
-- * getItemVisuals(): ArrayList Java de ItemVisual (add, remove(Object) devolve
--   bool, size, get, contains). ItemVisual.new() + setItemType.
-- * Veste tarde: zumbi criado com isPersistentOutfitInit() false; o ModelManager
--   chama dressInPersistentOutfitID(id) na criação do modelo (G.render), que limpa
--   HumanVisual e itemVisuals e veste pelo ID (o mesmo ID).
-- * Reaproveitamento (createZombieOutsideWorld 177–230): HumanVisual.clear(),
--   setPersistentOutfitID (init false), modData zerado, OnZombieCreate.
-- * Morte no solo (IsoZombie.onKilled 45–52): DoZombieInventory (item vestido e no
--   inventário pra todo ItemVisual cujo item de script existe) ANTES do OnZombieDead;
--   depois o corpo copia pele, WornItems e inventário (IsoDeadBody.<init>).
-- * WornItems.setItem (review da 0012): lugar que não é multi-item expulsa quem já
--   está nele; o DoZombieInventory veste na ordem da lista e o inventário recebe só os
--   vestidos (addItemsToItemContainer). zeddmg, bandage e wound são multi-item
--   (shared/NPCs/BodyLocations.lua:857-859). O lugar dos itens do mod sai do script de verdade.
-- * Sprint 0016: a roupa vanilla some enquanto a variante dura. ItemVisual não tem flag
--   de esconder: o mod tira da lista e devolve. Morte no solo: DoZombieInventory =
--   inventory.removeAllItems, WornItems.setFromItemVisuals (clear + CreateItem por
--   ItemVisual + setItem), addItemsToItemContainer, depois os itens presos; e o
--   OnZombieDead vem depois. Fogo (FireCheck): OnZombieDead sem DoZombieInventory e o
--   corpo direto (BurntToDeath). Cliente de MP (DeadZombiePacket → dieNetwork): os
--   vestidos e o inventário chegam do servidor, onKilled sem DoZombieInventory, e o
--   corpo copia pele e WornItems depois do OnZombieDead.
-- * Rede: nada do visual viaja (ZombiePacket.set leva só outfitId e skinTextureIndex);
--   sendClientCommand/sendServerCommand aqui explodem.
local FILE_STATS = "mod/42/media/lua/shared/NOM_NightStats.lua"
local FILE_LOOK = "mod/42/media/lua/client/NOM_VariantLook.lua"

-- roupa vanilla que o outfit dá (dois itens): o que tem que sobrar intacto
local OUTFIT = { "Base.Tshirt_DefaultTEXTURE", "Base.Trousers_Denim" }

-- BodyLocation de cada item (vanilla: generated/items/clothing.txt; mod: NOM_clothing.txt)
local LOC = { ["Base.Tshirt_DefaultTEXTURE"] = "tshirt", ["Base.Trousers_Denim"] = "pants",
    ["Base.Hat_Army"] = "hat", ["Base.Glasses_SkiGoggles"] = "eyes", ["Base.Hat_SurgicalMask"] = "mask",
    ["Base.ZedDmg_BACK_Slash"] = "zeddmg", ["Base.Wound_Chest_Bite_Male"] = "wound",
    ["Base.Bandage_Chest"] = "bandage" }
do
    local f = assert(io.open("mod/42/media/scripts/NOM_clothing.txt"))
    for name, body in f:read("*a"):gmatch("item%s+([%w_]+)%s*(%b{})") do
        LOC["Base." .. name] = body:match("BodyLocation = base:(%w+)")
    end
    f:close()
end
local MULTI = { zeddmg = true, bandage = true, wound = true }
-- ChanceToFall (generated/items/clothing.txt): o que cai da cabeça
local FALL = { ["Base.Hat_Army"] = 10, ["Base.Hat_SurgicalMask"] = 10 }
LOC["Base.Tshirt_NOM_Fake"] = "tshirt" -- vanilla de mentira com "NOM_" no meio do nome
-- IsoZombie.cantBite 0–319: máscara/capacete de cabeça (mask, maskeyes, maskfull, fullhat,
-- fullsuithead) na lista de ItemVisual impede a mordida (BodyDamage.AddRandomDamageFromZombie
-- 1024–1041)
local NO_BITE = { mask = true, maskeyes = true, maskfull = true, fullhat = true, fullsuithead = true }
local function cantBite(z)
    for _, iv in ipairs(z.ivs.items) do
        if NO_BITE[LOC[iv.type]] then return true end
    end
    return false
end
local HAT_FALLEN = 32768 -- PersistentOutfits.setFallenHat: bit 0x8000 do persistentOutfitID

local function jlist(G)
    local l = { items = {} }
    local function c() G.vcalls = G.vcalls + 1 end
    function l:size() c(); return #self.items end
    function l:get(i) c(); return self.items[i + 1] end
    function l:add(o) c(); self.items[#self.items + 1] = o; return true end
    function l:remove(o)
        c()
        assert(type(o) == "table", "remove(int) não: o mod tira pelo objeto")
        for i, v in ipairs(self.items) do
            if v == o then table.remove(self.items, i); return true end
        end
        return false
    end
    function l:contains(o) c(); for _, v in ipairs(self.items) do if v == o then return true end end return false end
    function l:clear() c(); self.items = {} end
    return l
end

local function types(z)
    local out = {}
    for _, iv in ipairs(z.ivs.items) do out[#out + 1] = iv.type end
    return table.concat(out, ",")
end

local function setup(opts)
    opts = opts or {}
    local G = { zombies = {}, vcalls = 0, corpses = {} }
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    G.fire = fire
    local function vc() G.vcalls = G.vcalls + 1 end

    -- ItemVisual: o do mod (ItemVisual.new) e os do outfit, mesma classe
    local function mkiv(t)
        local iv = { type = t }
        function iv:setItemType(x) vc(); self.type = x end
        function iv:getItemType() vc(); return self.type end
        function iv:getScriptItem()
            vc()
            local t = self.type
            return { getChanceToFall = function() vc(); return FALL[t] or 0 end }
        end
        return iv
    end
    ItemVisual = { new = function()
        vc()
        if G.throwNew then error("ItemVisual.new falhou") end
        return mkiv(nil)
    end }
    -- WornItems.setItem: lugar comum expulsa quem já está nele
    local function setItem(list, it)
        if not MULTI[it.loc] then
            for i = #list, 1, -1 do
                if list[i].loc == it.loc then table.remove(list, i) end
            end
        end
        list[#list + 1] = it
    end
    local function item(t) return { type = t, loc = assert(LOC[t], "sem lugar: " .. t) } end

    function G.zombie(o)
        o = o or {}
        local z = { md = {}, outfitID = o.id or 0, init = o.dressed ~= false, remote = o.remote or false,
            dead = false, speedType = 2, resets = 0, outfit = o.outfit or "Generic01", extra = o.extra or {},
            reanimated = o.reanimated or false }
        z.hv = {}
        function z.hv:setSkinTextureName(n) vc(); self.name = n end
        function z.hv:getSkinTexture() vc(); return self.name or "M_ZedBody01_level1" end
        z.ivs = jlist(G)
        z.inv, z.worn = {}, {}
        function z:getHumanVisual() vc(); return self.hv end
        function z:getItemVisuals() vc(); return self.ivs end
        function z:isPersistentOutfitInit() vc(); return self.init end
        function z:resetModelNextFrame() vc(); self.resets = self.resets + 1 end
        function z:dressInPersistentOutfitID(id)
            self.hv.name = nil
            self.ivs.items = {}
            for _, t in ipairs(OUTFIT) do self.ivs.items[#self.ivs.items + 1] = mkiv(t) end
            for _, t in ipairs(self.extra) do self.ivs.items[#self.ivs.items + 1] = mkiv(t) end
            self.outfitID, self.init = id, true
        end
        if z.init then z:dressInPersistentOutfitID(z.outfitID) end
        z.attached = o.attached or {} -- item preso (faca nas costas): vai pro inventário na morte
        function z:getInventory()
            local me = self
            return {
                FindAndReturn = function(_, t)
                    vc()
                    for _, it in ipairs(me.inv) do if it.type == t then return it end end
                    return nil
                end,
                Remove = function(_, it)
                    vc()
                    for i, v in ipairs(me.inv) do if v == it then table.remove(me.inv, i) return end end
                end,
                AddItem = function(_, it) vc(); me.inv[#me.inv + 1] = it; return it end,
            }
        end
        function z:getWornItems()
            local me = self
            local wi = {}
            function wi:size() vc(); return #me.worn end
            function wi:get(i)
                vc()
                local it = me.worn[i + 1]
                return { getItem = function() vc(); return it end }
            end
            function wi:remove(it)
                vc()
                for i, v in ipairs(me.worn) do if v == it then table.remove(me.worn, i) return end end
            end
            function wi:setFromItemVisuals(ivs)
                vc()
                me.worn = {}
                for _, iv in ipairs(ivs.items) do setItem(me.worn, item(iv.type)) end
            end
            function wi:addItemsToItemContainer(inv)
                vc()
                for _, it in ipairs(me.worn) do inv:AddItem(it) end
            end
            return wi
        end
        -- o que o NOM_NightStats usa (stats fora do teste)
        function z:getPersistentOutfitID() return self.outfitID end
        function z:getModData() return self.md end
        function z:hasModData() return true end
        function z:isDead() return self.dead end
        function z:isCrawling() return false end
        function z:isRemoteZombie() return self.remote end
        function z:getOutfitName() return self.outfit end
        function z:isCanCrawlUnderVehicle() return true end
        function z:setCanCrawlUnderVehicle() end
        function z:getSpeedType() return self.speedType end
        function z:doZombieSpeed(t) if t and t > 0 then self.speedType = t end end
        function z:DoZombieStats() end
        function z:isReanimatedPlayer() vc(); return self.reanimated end
        return z
    end
    function G.spawn(o)
        local z = G.zombie(o)
        fire("OnZombieCreate", z)
        G.zombies[#G.zombies + 1] = z
        return z
    end
    -- ModelManager.dressInRandomOutfit: veste quem ainda não foi vestido
    function G.render(z) if not z.init then z:dressInPersistentOutfitID(z.outfitID) end end
    function G.reuse(z, id)
        z.hv.name = nil
        z.outfitID, z.init, z.md = id, false, {}
        fire("OnZombieCreate", z)
    end
    -- how: "solo" (IsoZombie.onKilled), "fire" (FireCheck + BurntToDeath) ou
    -- "client" (cliente de MP: server = tipos vestidos que o servidor manda)
    function G.kill(z, how, server)
        how = how or "solo"
        if not z.init then z:dressInPersistentOutfitID(z.outfitID) end
        if how == "solo" and not z.reanimated then -- DoZombieInventory
            z.inv, z.worn = {}, {}
            for _, iv in ipairs(z.ivs.items) do setItem(z.worn, item(iv.type)) end
            for _, it in ipairs(z.worn) do z.inv[#z.inv + 1] = it end
            for _, t in ipairs(z.attached) do z.inv[#z.inv + 1] = { type = t } end
        elseif how == "client" then -- DeadZombiePacket.parseCharacterInventory
            z.inv, z.worn = {}, {}
            for _, t in ipairs(server) do setItem(z.worn, item(t)) end
            for _, it in ipairs(z.worn) do z.inv[#z.inv + 1] = it end
        end
        z.dead = true
        fire("OnZombieDead", z)
        local corpse = { skin = z.hv.name, worn = {}, inv = {}, ivs = types(z) }
        for _, it in ipairs(z.worn) do corpse.worn[#corpse.worn + 1] = it.type end
        for _, it in ipairs(z.inv) do corpse.inv[#corpse.inv + 1] = it.type end
        table.sort(corpse.worn)
        table.sort(corpse.inv)
        G.corpses[#G.corpses + 1] = corpse
        for i, v in ipairs(G.zombies) do if v == z then table.remove(G.zombies, i) break end end
        return corpse
    end
    function G.tick(n) for _ = 1, n or 1 do fire("OnTick", 0) end end
    function G.converge() G.tick(math.ceil(#G.zombies / NOM_NightStats.BATCH) + 2) end

    local lore = { Speed = 2, Sight = 2, Hearing = 2, Cognition = 2, Memory = 2 }
    getSandboxOptions = function()
        return { getOptionByName = function(_, name)
            local short = name:match("^ZombieLore%.(%w+)$")
            return { getValue = function() return lore[short] end, setValue = function(_, v) lore[short] = v end }
        end }
    end
    isClient = function() return opts.client == true end
    isServer = function() return opts.server == true end
    getDebug = function() return false end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    getCell = function()
        return { getZombieList = function()
            return { size = function() return #G.zombies end, get = function(_, i) return G.zombies[i + 1] end }
        end }
    end
    getGameTime = function() return { isZombieInactivityPhase = function() return false end } end
    sendClientCommand = function() error("visual não vai pela rede", 2) end
    sendServerCommand = function() error("visual não vai pela rede", 2) end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_NightStats", "NOM_FogState", "NOM_VariantLook" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_Config"
    require "NOM_VariantRules"
    NOM_VariantRules.forced = {}
    dofile(FILE_STATS)
    NOM_NightStats.install()
    dofile(FILE_LOOK)
    return G
end

-- ID no formato do jogo que dá a variante pedida no período (nil = zumbi comum)
local function idFor(want, period, red)
    local c = NOM_VariantRules.config(NOM_Config.get)
    for seed = 1, 500 do
        local id = 9 * 65536 + seed
        if NOM_VariantRules.variant(id, period, c, red) == want then return id end
    end
    error("nenhum ID dá " .. tostring(want))
end

local function fogOn(period, red) NOM_FogState.set(true, period, red) end
local function fogOff() NOM_FogState.set(false, nil) end

local function hasItem(z, t)
    for _, iv in ipairs(z.ivs.items) do if iv.type == t then return true end end
    return false
end

local KINDS = { "estalador", "corredor", "semrosto", "carpideira" }

return {
    look_applied_when_variant_starts = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 3) })
        G.converge()
        assert(z.hv.name == nil and types(z) == table.concat(OUTFIT, ","), "visual sem névoa")
        fogOn(3)
        G.converge()
        local look = NOM_VariantLook.LOOKS.estalador
        assert(z.hv.name == look.skin, "pele: " .. tostring(z.hv.name))
        assert(hasItem(z, look.item), "sem a peça: " .. types(z))
        assert(not hasItem(z, OUTFIT[1]) and not hasItem(z, OUTFIT[2]), "roupa vanilla à mostra (0016)")
        assert(z.outfitID == idFor("estalador", 3), "o ID do outfit mudou")
        assert(z.resets >= 1, "sem resetModelNextFrame")
        assert(NOM_VariantLook.count() == 1)
    end,

    look_each_kind_distinct = function()
        local G = setup()
        local seen, zs = {}, {}
        for _, k in ipairs(KINDS) do zs[k] = G.spawn({ id = idFor(k, 4) }) end
        fogOn(4)
        G.converge()
        for _, k in ipairs(KINDS) do
            local look = NOM_VariantLook.LOOKS[k]
            assert(look and look.item, "sem visual pra " .. k)
            assert(not seen[look.item], "peça repetida " .. look.item)
            seen[look.item] = true
            assert(hasItem(zs[k], look.item), k .. " sem a peça")
            assert(zs[k].hv.name == look.skin, k .. " com a pele errada")
        end
        assert(NOM_VariantLook.LOOKS.semrosto.skin == nil, "o Sem-rosto é zumbi comum fora do rosto")
    end,

    look_items_exist_in_script = function()
        local f = assert(io.open("mod/42/media/scripts/NOM_clothing.txt"))
        local s = f:read("*a")
        f:close()
        for _, k in ipairs(KINDS) do
            setup()
            local name = NOM_VariantLook.LOOKS[k].item:match("^Base%.(.+)$")
            assert(name and s:find("item " .. name .. "\n", 1, true), k .. ": item fora do script")
        end
    end,

    look_removed_when_fog_ends = function()
        local G = setup()
        local zs = {}
        for _, k in ipairs(KINDS) do zs[k] = G.spawn({ id = idFor(k, 5) }) end
        fogOn(5)
        G.converge()
        fogOff()
        G.converge()
        for _, k in ipairs(KINDS) do
            local z = zs[k]
            assert(z.hv.name == nil, k .. ": pele ficou")
            assert(types(z) == table.concat(OUTFIT, ","), k .. ": sobrou " .. types(z))
            assert(z.outfitID == idFor(k, 5), k .. ": ID mudou")
        end
        assert(NOM_VariantLook.count() == 0)
    end,

    -- de dia, o Sem-rosto não tem stats: a passada do NightStats sai cedo nele
    look_semrosto_removed_at_day = function()
        local G = setup()
        local z = G.spawn({ id = idFor("semrosto", 6) })
        fogOn(6)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.semrosto.item))
        fogOff()
        G.converge()
        assert(not hasItem(z, NOM_VariantLook.LOOKS.semrosto.item), "Sem-rosto ficou com o rosto de chiado")
    end,

    look_common_zombie_untouched = function()
        local G = setup()
        for _ = 1, 30 do G.spawn({ id = idFor(nil, 7) }) end
        fogOn(7)
        G.vcalls = 0
        G.converge()
        G.converge()
        assert(G.vcalls == 0, "zumbi comum teve " .. G.vcalls .. " chamadas de visual")
        for _, z in ipairs(G.zombies) do assert(types(z) == table.concat(OUTFIT, ",") and z.hv.name == nil) end
    end,

    look_eco_untouched = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 7), outfit = "NOM_Eco" })
        fogOn(7)
        G.converge()
        assert(z.hv.name == nil and types(z) == table.concat(OUTFIT, ","), "Eco ganhou visual de variante")
    end,

    -- longe da tela o jogo só veste quando cria o modelo: pintar antes seria apagado
    look_waits_until_dressed = function()
        local G = setup()
        local z = G.spawn({ id = idFor("corredor", 8), dressed = false })
        fogOn(8)
        G.converge()
        assert(#z.ivs.items == 0 and z.hv.name == nil, "pintou zumbi ainda não vestido")
        G.render(z)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.corredor.item) and z.hv.name == NOM_VariantLook.LOOKS.corredor.skin,
            "não pintou depois de vestido")
        assert(not hasItem(z, OUTFIT[1]), "roupa vanilla à mostra (0016)")
    end,

    look_reused_object_clean = function()
        local G = setup()
        local z = G.spawn({ id = idFor("carpideira", 9) })
        fogOn(9)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.carpideira.item))
        G.reuse(z, idFor(nil, 9))
        G.render(z)
        G.converge()
        assert(not hasItem(z, NOM_VariantLook.LOOKS.carpideira.item) and z.hv.name == nil, "objeto reaproveitado com visual: " .. types(z))
        assert(NOM_VariantLook.count() == 0, "a tabela guardou o objeto reaproveitado")
        -- reaproveitado ainda não vestido: o item velho não pode ficar se o jogo demorar a vestir
        local y = G.spawn({ id = idFor("estalador", 9) })
        G.converge()
        G.reuse(y, idFor(nil, 9))
        assert(not hasItem(y, NOM_VariantLook.LOOKS.estalador.item), "item velho ficou até o jogo vestir")
    end,

    look_dead_leaves_no_loot = function()
        local G = setup()
        for _, k in ipairs(KINDS) do G.spawn({ id = idFor(k, 10) }) end
        fogOn(10)
        G.converge()
        for _, z in ipairs({ unpack(G.zombies) }) do
            local c = G.kill(z)
            assert(c.skin == nil, "corpo com a pele do mod")
            for _, list in ipairs({ c.worn, c.inv }) do
                for _, t in ipairs(list) do assert(not t:find("NOM_", 1, true), "corpo com " .. t) end
            end
            assert(not c.ivs:find("NOM_", 1, true), "corpo vestido com " .. c.ivs)
            assert(#c.inv == #OUTFIT, "loot vanilla sumiu")
        end
        assert(NOM_VariantLook.count() == 0)
    end,

    -- MP: cada cliente pinta a própria cópia, dona ou remota, sem rede
    look_remote_copy_gets_it_and_nothing_sent = function()
        local G = setup({ client = true })
        local z = G.spawn({ id = idFor("semrosto", 11), remote = true })
        fogOn(11)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.semrosto.item), "cópia remota sem visual")
    end,

    look_not_on_dedicated_server = function()
        setup({ server = true })
        assert(NOM_VariantLook == nil, "servidor dedicado carregou o visual")
        assert(NOM_NightStats.look == nil, "servidor dedicado com o gancho")
    end,

    look_red_fog_everyone = function()
        local G = setup()
        for seed = 1, 40 do G.spawn({ id = 9 * 65536 + seed }) end
        fogOn(12, true)
        G.converge()
        for _, z in ipairs(G.zombies) do assert(#z.ivs.items == 1 and z.ivs.items[1].type:find("NOM_", 1, true), "vermelha: zumbi sem visual: " .. types(z)) end
        assert(NOM_VariantLook.count() == 40)
    end,

    look_debug_forced_and_undone = function()
        local G = setup()
        local id = idFor(nil, 13)
        local z = G.spawn({ id = id })
        fogOn(13)
        G.converge()
        NOM_VariantRules.forced[id] = "semrosto"
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.semrosto.item), "forçado sem visual")
        NOM_VariantRules.forced[id] = "estalador"
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.item) and not hasItem(z, NOM_VariantLook.LOOKS.semrosto.item),
            "trocou de tipo e ficou com as duas: " .. types(z))
        NOM_VariantRules.forced[id] = nil
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ",") and z.hv.name == nil, "desfeito e ficou: " .. types(z))
    end,

    look_period_change_without_edge = function()
        local G = setup()
        local id = idFor("corredor", 14)
        local z = G.spawn({ id = id })
        fogOn(14)
        G.converge()
        local p = 15
        while NOM_VariantRules.variant(id, p, NOM_VariantRules.config(NOM_Config.get)) ~= nil do p = p + 1 end
        fogOn(p)
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ",") and z.hv.name == nil, "período novo, visual velho")
    end,

    -- review da 0012: a peça do mod num lugar comum expulsava o chapéu/máscara/óculos do
    -- zumbi no DoZombieInventory, e o corpo ficava sem nenhum dos dois
    look_dead_keeps_vanilla_headgear = function()
        local G = setup()
        local extra = { "Base.Hat_Army", "Base.Glasses_SkiGoggles", "Base.Hat_SurgicalMask" }
        for _, k in ipairs(KINDS) do G.spawn({ id = idFor(k, 17), extra = extra }) end
        fogOn(17)
        G.converge()
        assert(NOM_VariantLook.count() == 4)
        for _, z in ipairs({ unpack(G.zombies) }) do
            local c = G.kill(z)
            local inv = table.concat(c.inv, ",")
            for _, t in ipairs(extra) do assert(inv:find(t, 1, true), "o corpo perdeu " .. t .. ": " .. inv) end
            assert(not inv:find("NOM_", 1, true), "loot do mod: " .. inv)
        end
    end,

    -- ReanimatedPlayers salva o zumbi com IsoZombie.save → HumanVisual.save (com o
    -- skinTextureName): a pele do mod ficaria pra sempre
    look_skips_reanimated_player = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 18), reanimated = true })
        fogOn(18)
        G.converge()
        assert(z.hv.name == nil and types(z) == table.concat(OUTFIT, ","), "jogador reanimado pintado")
        assert(NOM_VariantLook.count() == 0)
    end,

    -- surpresa da API no jogo: a pele não vaza e a passada dos stats não para
    look_api_error_does_not_leak_or_stall = function()
        local G = setup()
        local a = G.spawn({ id = idFor("estalador", 19) })
        local b = G.spawn({ id = idFor("corredor", 19) })
        G.throwNew = true
        fogOn(19)
        G.converge()
        assert(a.md.NOM_variant == "estalador" and b.md.NOM_variant == "corredor", "os stats pararam no erro do visual")
        G.throwNew = false
        fogOff()
        G.converge()
        assert(a.hv.name == nil and b.hv.name == nil, "pele vazou depois do erro")
        assert(NOM_VariantLook.count() == 0)
    end,

    -- o jogo veste de novo com outro ID (a lista e a pele somem): pinta de novo
    look_redressed_zombie_repainted = function()
        local G = setup()
        local id1 = idFor("estalador", 20)
        local c = NOM_VariantRules.config(NOM_Config.get)
        local id2
        for seed = 1, 500 do
            local id = 11 * 65536 + seed
            if NOM_VariantRules.variant(id, 20, c) == "estalador" then id2 = id break end
        end
        local z = G.spawn({ id = id1 })
        fogOn(20)
        G.converge()
        z:dressInPersistentOutfitID(id2)
        assert(not hasItem(z, NOM_VariantLook.LOOKS.estalador.item))
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.item) and z.hv.name == NOM_VariantLook.LOOKS.estalador.skin,
            "re-vestido ficou sem visual: " .. types(z))
    end,

    -- orçamento (docs/architecture/README.md): por zumbi com N peças vanilla escondidas,
    -- pôr ≤ 11 + 3·N chamadas, tirar ≤ 5 + 2·N (na passada), passada sem troca 0.
    -- G.vcalls conta toda chamada de visual nos objetos falsos (zumbi, HumanVisual, lista,
    -- cada ItemVisual), inclusive os criados no meio da chamada.
    look_budget = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 16), extra = { "Base.Hat_Army" } })
        local n = #OUTFIT + 1
        fogOn(16)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls <= 11 + 3 * n, "pôr custou " .. G.vcalls)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls == 0, "passada sem troca custou " .. G.vcalls)
        fogOff()
        G.vcalls = 0
        G.converge()
        assert(G.vcalls <= 5 + 2 * n, "tirar custou " .. G.vcalls)
        assert(z.hv.name == nil)
    end,

    -- sprint 0016: só a pele e a peça do mod (e as feridas do corpo, KEEP) aparecem
    nude_hidden_on_variant_start = function()
        local G = setup()
        local extra = { "Base.Hat_Army", "Base.ZedDmg_BACK_Slash", "Base.Wound_Chest_Bite_Male", "Base.Bandage_Chest" }
        local id = idFor("estalador", 21)
        local z = G.spawn({ id = id, extra = extra })
        fogOn(21)
        G.converge()
        assert(types(z) == "Base.ZedDmg_BACK_Slash,Base.Wound_Chest_Bite_Male,Base.NOM_EstaladorVenda",
            "lista na variante: " .. types(z))
        assert(z.hv.name == NOM_VariantLook.LOOKS.estalador.skin)
        assert(z.outfitID == id and z.resets >= 1)
    end,

    nude_restored_on_fog_end = function()
        local G = setup()
        local zs, before = {}, {}
        for _, k in ipairs(KINDS) do
            local z = G.spawn({ id = idFor(k, 22), extra = { "Base.Hat_Army", "Base.ZedDmg_BACK_Slash" } })
            zs[k], before[k] = z, { unpack(z.ivs.items) }
        end
        fogOn(22)
        G.converge()
        fogOff()
        G.converge()
        for _, k in ipairs(KINDS) do
            local z, b = zs[k], before[k]
            assert(#z.ivs.items == #b, k .. ": " .. types(z))
            for i, iv in ipairs(b) do assert(z.ivs.items[i] == iv, k .. ": ordem/objeto " .. i .. ": " .. types(z)) end
            assert(z.hv.name == nil)
        end
        assert(NOM_VariantLook.count() == 0)
    end,

    -- o jogo veste de novo (lista nova): a guardada não volta por cima
    nude_redressed_does_not_restore_old_clothes = function()
        local G = setup()
        local c = NOM_VariantRules.config(NOM_Config.get)
        local id2
        for seed = 1, 500 do
            local id = 11 * 65536 + seed
            if NOM_VariantRules.variant(id, 23, c) == "estalador" then id2 = id break end
        end
        local z = G.spawn({ id = idFor("estalador", 23) })
        fogOn(23)
        G.converge()
        z:dressInPersistentOutfitID(id2)
        G.converge()
        assert(types(z) == "Base.NOM_EstaladorVenda", "re-vestido não escondeu: " .. types(z))
        fogOff()
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ","), "roupa duplicada ou velha: " .. types(z))
    end,

    nude_api_error_hides_nothing = function()
        local G = setup()
        local z = G.spawn({ id = idFor("corredor", 24) })
        G.throwNew = true
        fogOn(24)
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ","), "escondeu sem a peça: " .. types(z))
    end,

    nude_reuse_restores_nothing_stale = function()
        local G = setup()
        local z = G.spawn({ id = idFor("carpideira", 25), extra = { "Base.Hat_Army" } })
        fogOn(25)
        G.converge()
        G.reuse(z, idFor(nil, 25))
        z.extra = {}
        G.render(z)
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ","), "objeto reaproveitado: " .. types(z))
        assert(NOM_VariantLook.count() == 0)
    end,

    -- SP: o DoZombieInventory leu a lista escondida antes do OnZombieDead. O corpo e o
    -- loot têm que ser os de um gêmeo que nunca foi variante: sem perda, sem duplicata,
    -- sem item do mod, e o item preso (fora do WornItems) fica
    nude_dead_loot_exact = function()
        local extra = { "Base.Hat_Army", "Base.Glasses_SkiGoggles", "Base.ZedDmg_BACK_Slash", "Base.Bandage_Chest" }
        local attached = { "Base.HuntingKnife" }
        for _, k in ipairs(KINDS) do
            local G = setup()
            local id = idFor(k, 26)
            local twin = G.spawn({ id = id, extra = extra, attached = attached })
            local want = G.kill(twin)
            local z = G.spawn({ id = id, extra = extra, attached = attached })
            fogOn(26)
            G.converge()
            assert(NOM_VariantLook.count() == 1, k)
            local c = G.kill(z)
            assert(c.skin == nil, k .. ": pele do mod no corpo")
            assert(table.concat(c.worn, ",") == table.concat(want.worn, ","),
                k .. ": vestidos " .. table.concat(c.worn, ",") .. " ≠ " .. table.concat(want.worn, ","))
            assert(table.concat(c.inv, ",") == table.concat(want.inv, ","),
                k .. ": loot " .. table.concat(c.inv, ",") .. " ≠ " .. table.concat(want.inv, ","))
            assert(c.ivs == want.ivs, k .. ": lista " .. c.ivs)
            assert(NOM_VariantLook.count() == 0)
        end
    end,

    -- fogo: OnZombieDead sem DoZombieInventory (FireCheck) e o corpo direto
    -- (BurntToDeath). O mod devolve a lista e não inventa loot
    nude_burn_death_no_invented_loot = function()
        local G = setup()
        local z = G.spawn({ id = idFor("corredor", 27), extra = { "Base.Hat_Army" } })
        fogOn(27)
        G.converge()
        local c = G.kill(z, "fire")
        assert(#c.worn == 0 and #c.inv == 0, "loot inventado: " .. table.concat(c.inv, ","))
        assert(c.ivs == table.concat(OUTFIT, ",") .. ",Base.Hat_Army", "lista não voltou: " .. c.ivs)
        assert(c.skin == nil)
    end,

    -- cliente de MP: vestidos e inventário vêm do servidor (que nunca pinta); o mod
    -- não refaz nada, só tira a pele (o corpo local copia a HumanVisual)
    nude_mp_client_death_keeps_server_items = function()
        local G = setup({ client = true })
        local z = G.spawn({ id = idFor("estalador", 28), remote = true, extra = { "Base.Hat_Army" } })
        fogOn(28)
        G.converge()
        assert(not hasItem(z, "Base.Hat_Army"))
        local server = { OUTFIT[1], OUTFIT[2], "Base.Hat_Army" }
        local c = G.kill(z, "client", server)
        table.sort(server)
        assert(table.concat(c.worn, ",") == table.concat(server, ","), "vestidos do servidor mudaram: " .. table.concat(c.worn, ","))
        assert(table.concat(c.inv, ",") == table.concat(server, ","), "loot do servidor mudou")
        assert(c.skin == nil, "pele do mod no corpo do cliente")
    end,

    -- fim da névoa: nada de refazer o modelo de todo mundo no mesmo tick; a passada
    -- do NightStats devolve em lotes de BATCH
    nude_fog_end_spread_in_batches = function()
        local G = setup()
        for seed = 1, 40 do G.spawn({ id = 9 * 65536 + seed }) end
        fogOn(29, true)
        G.converge()
        assert(NOM_VariantLook.count() == 40)
        fogOff()
        assert(NOM_VariantLook.count() == 40, "a borda tirou todos de uma vez")
        G.tick(1)
        local left = NOM_VariantLook.count()
        assert(left >= 40 - NOM_NightStats.BATCH and left < 40, "um tick devolveu " .. (40 - left))
        G.converge()
        assert(NOM_VariantLook.count() == 0)
        for _, z in ipairs(G.zombies) do assert(types(z) == table.concat(OUTFIT, ",") and z.hv.name == nil) end
    end,

    -- cliente de MP: o servidor derruba o chapéu (ZombieHelmetFallingPacket.processClient
    -- 130–238: não acha o chapéu na lista, que está escondido, mas cria a roupa caindo e
    -- liga o bit do chapéu caído no ID). Ao devolver, o chapéu não pode voltar pra cabeça
    nude_fallen_hat_not_restored = function()
        local G = setup({ client = true })
        local z = G.spawn({ id = idFor("estalador", 30), remote = true, extra = { "Base.Hat_Army" } })
        fogOn(30)
        G.converge()
        assert(not hasItem(z, "Base.Hat_Army"))
        z.outfitID = z.outfitID + HAT_FALLEN -- setFallenHat → setPersistentOutfitID(id | 0x8000)
        z.ivs.items = { unpack(z.ivs.items) } -- clear + addAll da cópia (sem o chapéu)
        G.converge()
        fogOff()
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ","), "chapéu caído voltou: " .. types(z))
    end,

    -- só "NOM_" depois do módulo é item do mod; vanilla com NOM_ no nome some
    nude_keep_only_mod_module_prefix = function()
        local G = setup()
        local z = G.spawn({ id = idFor("corredor", 31), extra = { "Base.Tshirt_NOM_Fake" } })
        fogOn(31)
        G.converge()
        assert(types(z) == "Base.NOM_CorredorBoca", "sobrou: " .. types(z))
    end,

    -- status do debug: só quem está na lista da célula conta (step 4 do roteiro)
    nude_count_only_loaded_zombies = function()
        local G = setup()
        local a = G.spawn({ id = idFor("estalador", 32) })
        G.spawn({ id = idFor("corredor", 32) })
        fogOn(32)
        G.converge()
        assert(NOM_VariantLook.count() == 2)
        table.remove(G.zombies, 1) -- saiu do mundo sem evento (virou virtual)
        assert(NOM_VariantLook.count() == 1, "contou zumbi fora da célula")
        assert(a.hv.name ~= nil)
    end,

    -- decisão do Johan (05/10): "o monstro larga tudo". A máscara escondida não impede
    -- a mordida enquanto é variante, e volta a impedir no fim
    nude_monster_bites_through_hidden_mask = function()
        local G = setup()
        local z = G.spawn({ id = idFor("carpideira", 33), extra = { "Base.Hat_SurgicalMask" } })
        assert(cantBite(z), "fake: máscara deveria impedir")
        fogOn(33)
        G.converge()
        assert(not cantBite(z), "variante com a máscara ainda impede a mordida")
        fogOff()
        G.converge()
        assert(cantBite(z), "a máscara não voltou a valer")
    end,

    -- sprint 0017: o bit do chapéu caído não é identidade. O zumbi continua a mesma
    -- variante, e o visual não é refeito (a peça do mod é o mesmo objeto: o
    -- processClient refaz a lista com os objetos que estavam nela)
    look_fallen_hat_keeps_variant = function()
        local G = setup({ client = true })
        local z = G.spawn({ id = idFor("estalador", 34), remote = true, extra = { "Base.Hat_Army" } })
        fogOn(34)
        G.converge()
        local function piece()
            for _, iv in ipairs(z.ivs.items) do if iv.type == NOM_VariantLook.LOOKS.estalador.item then return iv end end
        end
        local before = piece()
        assert(before)
        z.outfitID = z.outfitID + HAT_FALLEN
        z.ivs.items = { unpack(z.ivs.items) }
        G.converge()
        assert(NOM_NightStats.variants[z] == "estalador", "perdeu a variante com o chapéu")
        assert(piece() == before, "repintou por causa do bit do chapéu")
    end,
}
