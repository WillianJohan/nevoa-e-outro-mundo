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
-- * Rede: nada do visual viaja (ZombiePacket.set leva só outfitId e skinTextureIndex);
--   sendClientCommand/sendServerCommand aqui explodem.
local FILE_STATS = "mod/42/media/lua/shared/NOM_NightStats.lua"
local FILE_LOOK = "mod/42/media/lua/client/NOM_VariantLook.lua"

-- roupa vanilla que o outfit dá (dois itens): o que tem que sobrar intacto
local OUTFIT = { "Base.Tshirt_DefaultTEXTURE", "Base.Trousers_Denim" }

-- BodyLocation de cada item (vanilla: generated/items/clothing.txt; mod: NOM_clothing.txt)
local LOC = { ["Base.Tshirt_DefaultTEXTURE"] = "tshirt", ["Base.Trousers_Denim"] = "pants",
    ["Base.Hat_Army"] = "hat", ["Base.Glasses_SkiGoggles"] = "eyes", ["Base.Hat_SurgicalMask"] = "mask" }
do
    local f = assert(io.open("mod/42/media/scripts/NOM_clothing.txt"))
    for name, body in f:read("*a"):gmatch("item%s+([%w_]+)%s*(%b{})") do
        LOC["Base." .. name] = body:match("BodyLocation = base:(%w+)")
    end
    f:close()
end
local MULTI = { zeddmg = true, bandage = true, wound = true }

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

    ItemVisual = { new = function()
        vc()
        if G.throwNew then error("ItemVisual.new falhou") end
        local iv = {}
        function iv:setItemType(t) vc(); self.type = t end
        function iv:getItemType() vc(); return self.type end
        return iv
    end }

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
            for _, t in ipairs(OUTFIT) do self.ivs.items[#self.ivs.items + 1] = { type = t } end
            for _, t in ipairs(self.extra) do self.ivs.items[#self.ivs.items + 1] = { type = t } end
            self.outfitID, self.init = id, true
        end
        if z.init then z:dressInPersistentOutfitID(z.outfitID) end
        function z:getInventory()
            local me = self
            return {
                FindAndReturn = function(_, t)
                    for _, it in ipairs(me.inv) do if it.type == t then return it end end
                    return nil
                end,
                Remove = function(_, it)
                    for i, v in ipairs(me.inv) do if v == it then table.remove(me.inv, i) return end end
                end,
            }
        end
        function z:getWornItems()
            local me = self
            return { remove = function(_, it)
                for i, v in ipairs(me.worn) do if v == it then table.remove(me.worn, i) return end end
            end }
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
    function G.kill(z)
        if not z.init then z:dressInPersistentOutfitID(z.outfitID) end
        z.inv, z.worn = {}, {}
        for _, iv in ipairs(z.ivs.items) do -- WornItems.setFromItemVisuals → setItem
            local it = { type = iv.type, loc = assert(LOC[iv.type], "sem lugar: " .. iv.type) }
            if not MULTI[it.loc] then
                for i = #z.worn, 1, -1 do
                    if z.worn[i].loc == it.loc then table.remove(z.worn, i) end
                end
            end
            z.worn[#z.worn + 1] = it
        end
        for _, it in ipairs(z.worn) do z.inv[#z.inv + 1] = it end
        z.dead = true
        fire("OnZombieDead", z)
        local corpse = { skin = z.hv.name, worn = {}, inv = {}, ivs = types(z) }
        for _, it in ipairs(z.worn) do corpse.worn[#corpse.worn + 1] = it.type end
        for _, it in ipairs(z.inv) do corpse.inv[#corpse.inv + 1] = it.type end
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
        assert(hasItem(z, OUTFIT[1]) and hasItem(z, OUTFIT[2]), "tirou a roupa do zumbi")
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
        assert(hasItem(z, OUTFIT[1]), "roupa do zumbi sumiu")
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
        for _, z in ipairs(G.zombies) do assert(#z.ivs.items == #OUTFIT + 1, "vermelha: zumbi sem visual") end
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

    -- orçamento (docs/architecture/README.md): por zumbi, pôr ≤ 9 chamadas, tirar ≤ 5,
    -- passada sem troca 0
    look_budget = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 16) })
        fogOn(16)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls <= 9, "pôr custou " .. G.vcalls)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls == 0, "passada sem troca custou " .. G.vcalls)
        G.vcalls = 0
        fogOff()
        assert(G.vcalls <= 5, "tirar custou " .. G.vcalls)
        assert(z.hv.name == nil)
    end,
}
