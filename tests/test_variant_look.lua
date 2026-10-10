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
-- * Sprint 0016→0060b: só acessório de cabeça some; camisa/calça ficam. Sem setSkinTextureName
--   nas variantes de look (Body do mod lia como manequim P&B). Morte no solo: DoZombieInventory =
--   inventory.removeAllItems, WornItems.setFromItemVisuals (clear + CreateItem por
--   ItemVisual + setItem), addItemsToItemContainer, depois os itens presos; e o
--   OnZombieDead vem depois. Fogo (FireCheck): OnZombieDead sem DoZombieInventory e o
--   corpo direto (BurntToDeath). Cliente de MP (DeadZombiePacket → dieNetwork): os
--   vestidos e o inventário chegam do servidor, onKilled sem DoZombieInventory, e o
--   corpo copia pele e WornItems depois do OnZombieDead.
-- * Sprint 0018 (dissolve): alfa por jogador como o IsoObject (setAlpha(pn, a) com clamp,
--   getAlpha(pn)); o mundo anda o alfa 0,28 por tick pro alvo da visão (updateAlpha) antes
--   do OnTick; um tick = 16 ms de getTimestampMs. A opção do jogador (dissolve) vem de
--   opts.dissolve: desligada por padrão, que é o comportamento das sprints 0012–0017.
-- * Sprint 0022 (casca de brasa): a sub-opção vem de opts.body (desligada por padrão: a
--   sprint 0018 exata). O NOM_Embers é falso, com o teto do de verdade (NOM_EmberRules.CAP),
--   e anota cada brasa pedida em G.bursts.
-- * Rede: nada do visual viaja (ZombiePacket.set leva só outfitId e skinTextureIndex);
--   sendClientCommand/sendServerCommand aqui explodem.
local FILE_STATS = "mod/42/media/lua/shared/NOM_NightStats.lua"
local FILE_LOOK = "mod/42/media/lua/client/NOM_VariantLook.lua"

-- roupa vanilla que o outfit dá (dois itens): o que tem que sobrar intacto
local OUTFIT = { "Base.Tshirt_DefaultTEXTURE", "Base.Trousers_Denim" }
local PROOF = { "Base.Tshirt_Sport", "Base.Trousers_WhiteTEXTURE" }

-- BodyLocation de cada item (vanilla: generated/items/clothing.txt; mod: NOM_clothing.txt)
local LOC = { ["Base.Tshirt_DefaultTEXTURE"] = "tshirt", ["Base.Trousers_Denim"] = "pants",
    ["Base.Tshirt_Sport"] = "tshirt", ["Base.Trousers_WhiteTEXTURE"] = "pants",
    ["Base.Hat_Army"] = "hat", ["Base.Glasses_SkiGoggles"] = "eyes", ["Base.Hat_SurgicalMask"] = "mask",
    ["Base.ZedDmg_BACK_Slash"] = "zeddmg", ["Base.Wound_Chest_Bite_Male"] = "wound",
    ["Base.Bandage_Chest"] = "bandage",
    -- guarda-roupa lote A/2 (clothing.txt B42)
    ["Base.HospitalGown"] = "longdress", ["Base.Shirt_FormalWhite"] = "shirt",
    ["Base.Shirt_FormalTINT"] = "shirt", ["Base.Trousers_SuitWhite"] = "pants",
    ["Base.Apron_White"] = "torsoextra",
    ["Base.Tshirt_WhiteTINT"] = "tshirt", ["Base.Vest_DefaultTEXTURE_TINT"] = "sweater",
    ["Base.Skirt_Long"] = "longskirt", ["Base.Dress_Long"] = "dress",
    ["Base.Dress_SatinNegligee"] = "dress", ["Base.Dress_Normal"] = "longdress",
    ["Base.PonchoGarbageBag"] = "jacket", ["Base.LongCoat_Bathrobe"] = "bathrobe",
    ["Base.Boilersuit"] = "boilersuit", ["Base.HoodieDOWN_WhiteTINT"] = "sweater",
    ["Base.Jacket_Black"] = "jacket", ["Base.Jacket_Shellsuit_TINT"] = "jacket_bulky",
    ["Base.Shirt_Lumberjack_TINT"] = "shirt", ["Base.Jumper_RoundNeck"] = "sweater",
    ["Base.Shirt_Workman"] = "shirt", ["Base.Tie_Full"] = "neck",
    ["Base.Jacket_Fireman"] = "jacket", ["Base.Shoes_Random"] = "shoes" }
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
        local iv = { type = t, tint = nil, dirt = {}, blood = {}, holes = {} }
        function iv:setItemType(x) vc(); self.type = x end
        function iv:getItemType() vc(); return self.type end
        function iv:setTint(c) vc(); self.tint = c end
        function iv:getTint() vc(); return self.tint end
        function iv:setDirt(part, a) vc(); self.dirt[part] = a end
        function iv:setBlood(part, a) vc(); self.blood[part] = a end
        function iv:setHole(part) vc(); self.holes[part] = true end
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
    ImmutableColor = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end }
    BloodBodyPartType = {
        Torso_Upper = "Torso_Upper", Torso_Lower = "Torso_Lower",
        UpperArm_L = "UpperArm_L", UpperArm_R = "UpperArm_R",
        UpperLeg_L = "UpperLeg_L", UpperLeg_R = "UpperLeg_R",
        LowerLeg_L = "LowerLeg_L", LowerLeg_R = "LowerLeg_R", Groin = "Groin",
    }
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
        function z:isLocal() return (not isClient() and not isServer()) or not self.remote end
        function z:getOutfitName() return self.outfit end
        function z:isCanCrawlUnderVehicle() return true end
        function z:setCanCrawlUnderVehicle() end
        function z:getSpeedType() return self.speedType end
        function z:doZombieSpeed(t) if t and t > 0 then self.speedType = t end end
        function z:DoZombieStats() end
        function z:isReanimatedPlayer() vc(); return self.reanimated end
        z.alpha, z.seen = 1, true
        function z:setAlpha(pn, a) vc(); assert(pn == 0); self.alpha = math.max(0, math.min(1, a)) end
        function z:getAlpha(pn) vc(); assert(pn == 0); if self.alphaThrows then error("getAlpha falhou") end; return self.alpha end
        -- IsoObject.getTargetAlpha(I) 0–14: o alvo da visão do jogador (1 à vista, 0 não)
        function z:getTargetAlpha(pn) vc(); assert(pn == 0); return self.seen and 1 or 0 end
        function z:getCurrentSquare() vc(); return self.dead and nil or {} end
        z.x, z.y, z.z = o.x or 10.5, o.y or 20.5, 0
        function z:getX() vc(); return self.x end
        function z:getY() vc(); return self.y end
        function z:getZ() vc(); return self.z end
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
    G.now = 1759999999000
    G.minAlpha = {} -- [z] = menor alfa desenhado desde a última limpeza
    function G.tick(n)
        for _ = 1, n or 1 do
            for _, z in ipairs(G.zombies) do -- IsoObject.updateAlpha, no update do mundo
                local t = z.seen and 1 or 0
                z.alpha = z.alpha < t and math.min(t, z.alpha + 0.28) or math.max(t, z.alpha - 0.28)
            end
            fire("OnTick", 0)
            for _, z in ipairs(G.zombies) do
                G.minAlpha[z] = math.min(G.minAlpha[z] or 1, z.alpha)
            end
            G.now = G.now + 16
        end
    end
    function G.ms(ms) G.tick(math.ceil(ms / 16)) end
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
    getTimestampMs = function() return G.now end
    getNumActivePlayers = function() return 1 end
    G.dissolve = opts.dissolve == true
    G.body = opts.body == true
    NOM_ScreenFxOptions = { dissolve = function() return G.dissolve end,
        bodyEmbers = function() return G.dissolve and G.body end }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    require "NOM_EmberRules"
    G.bursts = {}
    NOM_Embers = { burst = function(x, y, z)
        local live = 0
        for _, b in ipairs(G.bursts) do if G.now - b.at < NOM_EmberRules.LIFE_MS then live = live + 1 end end
        if live >= NOM_EmberRules.CAP then return false end
        G.bursts[#G.bursts + 1] = { x = x, y = y, z = z, at = G.now }
        return true
    end }
    package.loaded.NOM_Embers = NOM_Embers
    sendClientCommand = function() error("visual não vai pela rede", 2) end
    sendServerCommand = function() error("visual não vai pela rede", 2) end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_NightStats", "NOM_FogState", "NOM_VariantLook", "NOM_VariantWardrobe",
        "NOM_Dissolve", "NOM_EmberShell" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    NOM_PanelParams = nil
    require "NOM_ScreenFxRules"
    NOM_ScreenFxRules.setLookClean(false)
    require "NOM_Config"
    require "NOM_VariantRules"
    NOM_VariantRules.forced = {}
    dofile(FILE_STATS)
    NOM_NightStats.install()
    dofile(FILE_LOOK)
    return G
end

-- ID no formato do jogo que dá a variante pedida no período (nil = zumbi comum).
-- Sprint 0049: branca 100%; ID 0 nunca é variante (ADR-006).
local function idFor(want, period, red, female)
    if want == nil and not red then return 0 end
    local c = NOM_VariantRules.config(NOM_Config.get)
    for seed = 1, 500 do
        local id = 9 * 65536 + seed
        if female then id = id - 2147483648 end -- bit 31 (PersistentOutfits.pickOutfitFemale)
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
local SHELL = "Base.NOM_Brasa" -- casca de brasa (sprint 0022)

return {
    look_applied_when_variant_starts = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 3) })
        G.converge()
        assert(z.hv.name == nil and types(z) == table.concat(OUTFIT, ","), "visual sem névoa")
        fogOn(3)
        G.converge()
        local look = NOM_VariantLook.LOOKS.estalador
        assert(z.hv.name == nil, "0060b: sem Body custom: " .. tostring(z.hv.name))
        assert(hasItem(z, look.item), "sem a peça: " .. types(z))
        -- lote A: slot-assinatura vanilla (E1–E5) + peça de cabeça
        local ward = hasItem(z, "Base.HospitalGown") or hasItem(z, "Base.Shirt_FormalWhite")
            or hasItem(z, "Base.Apron_White") or hasItem(z, "Base.Tshirt_WhiteTINT")
            or hasItem(z, "Base.Vest_DefaultTEXTURE_TINT")
        assert(ward, "sem wardrobe: " .. types(z))
        assert(z.outfitID == idFor("estalador", 3), "o ID do outfit mudou")
        assert(z.resets >= 1, "sem resetModelNextFrame")
        assert(NOM_VariantLook.count() == 1)
    end,

    -- 0060e: flag lookClean → prova; LookForce sozinho NÃO é clean
    look_clean_proof_colored_body = function()
        local G = setup()
        NOM_PanelParams = { lookForce = function() return "misaligned" end, lookKind = function() return nil end }
        assert(NOM_ScreenFxRules.lookForceOn() and not NOM_ScreenFxRules.lookClean())
        local z = G.spawn({ id = idFor("estalador", 3) })
        fogOn(3)
        G.converge()
        local look = NOM_VariantLook.LOOKS.estalador
        assert(hasItem(z, look.item), "Force não deve ser clean: " .. types(z))
        assert(not hasItem(z, PROOF[1]), "prova com LookForce só: " .. types(z))
        NOM_ScreenFxRules.setLookClean(true)
        NOM_VariantLook.refreshClean()
        assert(hasItem(z, PROOF[1]) and hasItem(z, PROOF[2]), "sem prova: " .. types(z))
        NOM_ScreenFxRules.setLookClean(false)
        NOM_VariantLook.refreshClean()
        assert(not hasItem(z, PROOF[1]), "não saiu do clean: " .. types(z))
        assert(hasItem(z, look.item), "peça sumiu ao sair do clean: " .. types(z))
        fogOff()
        G.converge()
        NOM_PanelParams = nil
        NOM_ScreenFxRules.setLookClean(false)
    end,

    look_each_kind_distinct = function()
        local G = setup()
        local seen, zs = {}, {}
        for _, k in ipairs(KINDS) do zs[k] = G.spawn({ id = idFor(k, 4) }) end
        fogOn(4)
        G.converge()
        for _, k in ipairs(KINDS) do
            local look = NOM_VariantLook.LOOKS[k]
            assert(look, "sem LOOKS pra " .. k)
            assert(look.item, "sem visual pra " .. k)
            assert(not seen[look.item], "peça repetida " .. look.item)
            seen[look.item] = true
            assert(hasItem(zs[k], look.item), k .. " sem a peça: " .. types(zs[k]))
            if k == "semrosto" then
                -- 0060f A′: remendo 2D; ModData pro censor; sem casca-ovo
                assert(look.item == "Base.NOM_SemRostoRosto", "A′ remendo Sem-rosto")
                assert(zs[k].md.NOM_semrosto == true, "Sem-rosto sem ModData NOM_semrosto")
                assert(not hasItem(zs[k], "Base.NOM_SemRostoEstatica"), "casca-ovo ainda vestida")
            end
            if k == "ticao" then
                assert(zs[k].hv.name == look.skin, k .. " com a pele errada")
            else
                assert(zs[k].hv.name == nil, k .. " ainda troca Body: " .. tostring(zs[k].hv.name))
            end
        end
        assert(NOM_VariantLook.LOOKS.semrosto.skin == nil, "0060b: Sem-rosto sem Body")
        assert(not NOM_VariantLook.LOOKS.estalador.body and not NOM_VariantLook.LOOKS.corredor.body,
            "0060b: sem NOM_*Roupa no look")
    end,

    look_items_exist_in_script = function()
        local f = assert(io.open("mod/42/media/scripts/NOM_clothing.txt"))
        local s = f:read("*a")
        f:close()
        for _, k in ipairs(KINDS) do
            setup()
            local look = NOM_VariantLook.LOOKS[k]
            if look.item then
                local name = look.item:match("^Base%.(.+)$")
                assert(name and s:find("item " .. name .. "\n", 1, true), k .. ": item fora do script")
            end
            if look.body then
                local body = look.body:match("^Base%.(.+)$")
                assert(body and s:find("item " .. body .. "\n", 1, true), k .. ": manto fora do script")
            end
        end
    end,

    -- 0060f: Carpideira — mechas + (K1 manto+saia | K2–K5 roupa longa vanilla)
    look_carpideira_wears_manto = function()
        local G = setup()
        local z = G.spawn({ id = idFor("carpideira", 52) })
        fogOn(52)
        G.converge()
        local look = NOM_VariantLook.LOOKS.carpideira
        assert(hasItem(z, look.item), "sem mechas: " .. types(z))
        local long = hasItem(z, look.body) or hasItem(z, "Base.Dress_Long")
            or hasItem(z, "Base.Dress_SatinNegligee") or hasItem(z, "Base.PonchoGarbageBag")
            or hasItem(z, "Base.LongCoat_Bathrobe") or hasItem(z, "Base.Skirt_Long")
        assert(long, "sem coluna longa: " .. types(z))
        assert(z.hv.name == nil, "0060b: Carpideira sem Body")
        fogOff()
        G.converge()
        assert(not hasItem(z, look.body) and not hasItem(z, look.item), "manto ficou: " .. types(z))
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
        local z = G.spawn({ id = idFor("semrosto", 6), extra = { "Base.Hat_Army" } })
        fogOn(6)
        G.converge()
        assert(NOM_VariantLook.count() == 1, "Sem-rosto não entrou na tabela")
        assert(not hasItem(z, "Base.Hat_Army"), "chapéu deveria sumir na variante")
        assert(z.md.NOM_semrosto == true, "Sem-rosto sem ModData pro censor")
        assert(hasItem(z, "Base.NOM_SemRostoRosto"), "A′ remendo na cara")
        assert(not hasItem(z, "Base.NOM_SemRostoEstatica"), "casca-ovo aposentada ainda vestida")
        fogOff()
        G.converge()
        assert(NOM_VariantLook.count() == 0, "Sem-rosto ficou marcado")
        assert(hasItem(z, "Base.Hat_Army"), "chapéu não voltou: " .. types(z))
        assert(z.md.NOM_semrosto == nil, "ModData NOM_semrosto ficou")
        assert(not hasItem(z, "Base.NOM_SemRostoRosto"), "remendo ficou")
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
        assert(hasItem(z, NOM_VariantLook.LOOKS.corredor.item) and z.hv.name == nil,
            "não pintou depois de vestido")
        -- lote 2: C* pode trocar o torso (Boilersuit/Hoodie/…); calça vanilla fica
        assert(hasItem(z, OUTFIT[2]) or hasItem(z, "Base.Boilersuit")
            or hasItem(z, "Base.HoodieDOWN_WhiteTINT") or hasItem(z, "Base.Jacket_Black")
            or hasItem(z, "Base.Jacket_Shellsuit_TINT") or hasItem(z, "Base.Shirt_Lumberjack_TINT"),
            "corpo sem roupa após wardrobe: " .. types(z))
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
        local z = G.spawn({ id = idFor("estalador", 11), remote = true })
        fogOn(11)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.item), "cópia remota sem visual")
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
        for _, z in ipairs(G.zombies) do
            -- vermelha: todo mundo vira variante; Sem-rosto usa sentinela (I2)
            assert(z.hv.name == nil or z.hv.name == "NOM_Ticao", "vermelha Body: " .. tostring(z.hv.name))
        end
        assert(NOM_VariantLook.count() == 40)
    end,

    look_debug_forced_and_undone = function()
        -- sprint 0049: ID 0 nunca é variante (nem forçado); usa um Corredor e força por cima
        local G = setup()
        local id = idFor("corredor", 13)
        local z = G.spawn({ id = id, extra = { "Base.Hat_Army" } })
        fogOn(13)
        G.converge()
        NOM_VariantRules.forced[id] = "semrosto"
        G.converge()
        assert(not hasItem(z, "Base.Hat_Army"), "chapéu no Sem-rosto: " .. types(z))
        assert(z.md.NOM_semrosto == true, "forçado Sem-rosto sem ModData")
        assert(hasItem(z, "Base.NOM_SemRostoRosto"), "A′ remendo: " .. types(z))
        assert(not hasItem(z, "Base.NOM_SemRostoEstatica"), "casca-ovo ainda vestida")
        assert(hasItem(z, OUTFIT[1]), "roupa someu no Sem-rosto: " .. types(z))
        NOM_VariantRules.forced[id] = "estalador"
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.item),
            "trocou de tipo: " .. types(z))
        NOM_VariantRules.forced[id] = nil
        G.converge()
        -- desfeito: volta ao sorteio (Corredor), não a Knox
        assert(hasItem(z, NOM_VariantLook.LOOKS.corredor.item), "desfeito e ficou: " .. types(z))
    end,

    look_period_change_without_edge = function()
        -- sprint 0049: branca 100% — não há período "comum"; o visual acompanha a troca de tipo
        local G = setup()
        local id = idFor("corredor", 14)
        local z = G.spawn({ id = id })
        fogOn(14)
        G.converge()
        local c = NOM_VariantRules.config(NOM_Config.get)
        local p = 15
        while NOM_VariantRules.variant(id, p, c) == "corredor" do p = p + 1 end
        local k = NOM_VariantRules.variant(id, p, c)
        assert(k and k ~= "corredor", "não achou período com outro tipo")
        fogOn(p)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS[k].item), "período novo, visual velho: " .. types(z))
        assert(not hasItem(z, NOM_VariantLook.LOOKS.corredor.item), "ficou Corredor: " .. types(z))
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
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.item) and z.hv.name == nil,
            "re-vestido ficou sem visual: " .. types(z))
    end,

    -- orçamento: 0060f +guarda-roupa (1–2 ItemVisual + treat). pôr ≤ 30 + 3·N; tirar ≤ 12 + 2·N.
    look_budget = function()
        local G = setup()
        local z = G.spawn({ id = idFor("estalador", 16), extra = { "Base.Hat_Army" } })
        local n = #OUTFIT + 1
        fogOn(16)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls <= 30 + 3 * n, "pôr custou " .. G.vcalls)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls == 0, "passada sem troca custou " .. G.vcalls)
        fogOff()
        G.vcalls = 0
        G.converge()
        assert(G.vcalls <= 12 + 2 * n, "tirar custou " .. G.vcalls)
        assert(z.hv.name == nil)
    end,

    -- sprint 0016/0060f: feridas + peça + wardrobe; chapéu some
    nude_hidden_on_variant_start = function()
        local G = setup()
        local extra = { "Base.Hat_Army", "Base.ZedDmg_BACK_Slash", "Base.Wound_Chest_Bite_Male", "Base.Bandage_Chest" }
        local id = idFor("estalador", 21)
        local z = G.spawn({ id = id, extra = extra })
        fogOn(21)
        G.converge()
        assert(hasItem(z, "Base.ZedDmg_BACK_Slash") and hasItem(z, "Base.Wound_Chest_Bite_Male"), types(z))
        assert(hasItem(z, "Base.NOM_EstaladorVenda"), types(z))
        local ward = hasItem(z, "Base.HospitalGown") or hasItem(z, "Base.Shirt_FormalWhite")
            or hasItem(z, "Base.Apron_White") or hasItem(z, "Base.Tshirt_WhiteTINT")
            or hasItem(z, "Base.Vest_DefaultTEXTURE_TINT")
        assert(ward, "sem wardrobe: " .. types(z))
        assert(not hasItem(z, "Base.Hat_Army"), "chapéu deveria sumir: " .. types(z))
        assert(z.hv.name == nil)
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
        assert(hasItem(z, "Base.NOM_EstaladorVenda"), "re-vestido sem peça: " .. types(z))
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
        -- feminino (ID negativo, bit 31): o % do Kahlua daria -1 na paridade (review da 0017)
        local G2 = setup({ client = true })
        local fid = idFor("estalador", 30, nil, true)
        assert(fid < 0)
        local f = G2.spawn({ id = fid, remote = true, extra = { "Base.Hat_Army" } })
        fogOn(30)
        G2.converge()
        f.outfitID = f.outfitID + HAT_FALLEN
        f.ivs.items = { unpack(f.ivs.items) }
        G2.converge()
        fogOff()
        G2.converge()
        assert(types(f) == table.concat(OUTFIT, ","), "chapéu caído voltou (feminino): " .. types(f))
    end,

    -- só "NOM_" depois do módulo é item do mod; vanilla com NOM_ no nome some
    nude_keep_only_mod_module_prefix = function()
        local G = setup()
        local z = G.spawn({ id = idFor("corredor", 31), extra = { "Base.Tshirt_NOM_Fake" } })
        fogOn(31)
        G.converge()
        assert(hasItem(z, "Base.NOM_CorredorBoca") and hasItem(z, OUTFIT[1]), "sobrou: " .. types(z))
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
        assert(hasItem(a, "Base.NOM_EstaladorVenda"), "visual do que saiu da célula: " .. types(a))
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

    -- Sprint 0018 (dissolve ligado) ------------------------------------------------

    look_fx_items_exist_in_script = function()
        local f = assert(io.open("mod/42/media/scripts/NOM_clothing.txt"))
        local src = f:read("*a")
        f:close()
        setup()
        for _, k in ipairs(KINDS) do
            local look = NOM_VariantLook.LOOKS[k]
            -- A′ Sem-rosto: remendo 2D sem gêmeo Fx (I7 / dissolve só em peça com modelo)
            if look.item and look.fx then
                assert(look.fx == look.item .. "Fx", k .. ": gêmeo " .. tostring(look.fx))
                assert(src:find("item " .. look.fx:match("^Base%.(.+)$") .. "\n", 1, true), k .. ": gêmeo fora do script")
            end
        end
    end,

    -- mutação: o gêmeo com shader entra e se forma (o alfa na faixa do shader), roupa já some
    dissolve_look_in_on_mutation = function()
        local G = setup({ dissolve = true })
        local z = G.spawn({ id = idFor("estalador", 40) })
        fogOn(40)
        G.converge()
        local look = NOM_VariantLook.LOOKS.estalador
        assert(hasItem(z, look.fx) and not hasItem(z, look.item), "sem o gêmeo: " .. types(z))
        assert(z.hv.name == nil, "0060b Body: " .. types(z))
        assert(NOM_Dissolve.busy(z), "sem efeito na mutação")
        G.minAlpha = {}
        G.ms(NOM_DissolveRules.MS + 100)
        assert(G.minAlpha[z] >= NOM_DissolveRules.BAND - 1e-9, "corpo abaixo da faixa: " .. G.minAlpha[z])
        assert(not NOM_Dissolve.busy(z) and z.alpha == 1)
    end,

    -- fim da variante: a peça se desfaz e só então a roupa volta, igualzinha
    dissolve_look_out_before_strip = function()
        local G = setup({ dissolve = true })
        local z = G.spawn({ id = idFor("corredor", 41), extra = { "Base.Hat_Army" } })
        fogOn(41)
        G.converge()
        G.ms(1200)
        fogOff()
        G.converge()
        local look = NOM_VariantLook.LOOKS.corredor
        assert(hasItem(z, look.fx) and NOM_Dissolve.busy(z), "tirou antes de desfazer")
        assert(NOM_VariantLook.count() == 1)
        G.ms(NOM_DissolveRules.MS + 50)
        assert(types(z) == table.concat(OUTFIT, ",") .. ",Base.Hat_Army", "roupa: " .. types(z))
        assert(z.hv.name == nil and NOM_VariantLook.count() == 0 and not NOM_Dissolve.busy(z))
    end,

    -- a névoa volta (ou a passada pede a mesma variante) no meio: a peça se forma de novo
    dissolve_look_leave_cancelled_by_same_look = function()
        local G = setup({ dissolve = true })
        local z = G.spawn({ id = idFor("carpideira", 42) })
        fogOn(42)
        G.converge()
        G.ms(1200)
        fogOff()
        G.converge()
        G.ms(200)
        fogOn(42)
        G.converge()
        G.ms(NOM_DissolveRules.MS * 2)
        local look = NOM_VariantLook.LOOKS.carpideira
        assert(hasItem(z, look.fx) and z.hv.name == nil, "a peça sumiu: " .. types(z))
        assert(z.alpha == 1 and not NOM_Dissolve.busy(z))
        fogOff()
        G.converge()
        G.ms(NOM_DissolveRules.MS + 50)
        assert(types(z) == table.concat(OUTFIT, ","), "depois do cancelamento não sai mais: " .. types(z))
    end,

    -- troca de tipo (debug, período novo) no meio do efeito: na hora, sem resto
    dissolve_look_kind_change_immediate = function()
        local G = setup({ dissolve = true })
        local id = idFor("estalador", 43)
        local z = G.spawn({ id = id })
        fogOn(43)
        G.converge()
        NOM_VariantRules.forced[NOM_VariantRules.baseId(id)] = "corredor"
        G.converge()
        local L = NOM_VariantLook.LOOKS
        assert(hasItem(z, L.corredor.fx) and not hasItem(z, L.estalador.fx), types(z))
        NOM_VariantRules.forced = {}
    end,

    -- morte no meio do "desfazer": loot exato, sem gêmeo, e o efeito sai
    dissolve_look_dead_mid_leave_loot_exact = function()
        local extra = { "Base.Hat_Army", "Base.ZedDmg_BACK_Slash" }
        local G = setup({ dissolve = true })
        local id = idFor("estalador", 44)
        local want = G.kill(G.spawn({ id = id, extra = extra }))
        local z = G.spawn({ id = id, extra = extra })
        fogOn(44)
        G.converge()
        fogOff()
        G.converge()
        assert(NOM_Dissolve.busy(z))
        local c = G.kill(z)
        assert(table.concat(c.inv, ",") == table.concat(want.inv, ","), "loot " .. table.concat(c.inv, ","))
        assert(table.concat(c.worn, ",") == table.concat(want.worn, ","))
        assert(not NOM_Dissolve.busy(z) and NOM_VariantLook.count() == 0)
        G.ms(NOM_DissolveRules.MS + 50) -- o fim do efeito que saiu não roda nada
    end,

    -- objeto reaproveitado no meio: outro zumbi, limpo
    dissolve_look_reuse_mid_effect = function()
        local G = setup({ dissolve = true })
        local z = G.spawn({ id = idFor("estalador", 45) })
        fogOn(45)
        G.converge()
        assert(NOM_Dissolve.busy(z))
        G.reuse(z, idFor(nil, 45))
        assert(not NOM_Dissolve.busy(z))
        G.render(z)
        G.converge()
        G.ms(NOM_DissolveRules.MS + 50)
        assert(types(z) == table.concat(OUTFIT, ",") and z.hv.name == nil)
    end,

    -- vermelha com horda: o teto vale (o resto troca na hora) e o fim continua espalhado
    dissolve_look_red_fog_cap = function()
        local G = setup({ dissolve = true })
        for seed = 1, 40 do G.spawn({ id = 9 * 65536 + seed }) end
        fogOn(46, true)
        G.converge()
        assert(NOM_VariantLook.count() == 40 and NOM_Dissolve.count() <= NOM_DissolveRules.CAP)
        G.ms(NOM_DissolveRules.MS + 50)
        fogOff()
        local restoredPerTick, before = 0, 40
        for _ = 1, 200 do
            G.tick(1)
            local left = NOM_VariantLook.count()
            restoredPerTick = math.max(restoredPerTick, before - left)
            before = left
            assert(NOM_Dissolve.count() <= NOM_DissolveRules.CAP)
        end
        assert(before == 0, "sobraram " .. before)
        assert(restoredPerTick <= NOM_NightStats.BATCH, "um tick devolveu " .. restoredPerTick)
        for _, z in ipairs(G.zombies) do assert(types(z) == table.concat(OUTFIT, ",")) end
    end,

    -- desligado: a peça sem shader e nada de alfa (as sprints 0012–0017)
    dissolve_look_off_plain = function()
        local G = setup({ dissolve = false })
        local z = G.spawn({ id = idFor("estalador", 47) })
        fogOn(47)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.item) and not hasItem(z, NOM_VariantLook.LOOKS.estalador.fx))
        G.minAlpha = {}
        G.ms(500)
        assert(G.minAlpha[z] == 1 and NOM_Dissolve.count() == 0)
    end,

    -- Sprint 0022 (brasa no corpo inteiro) ----------------------------------------

    -- mutação: o corpo já é o monstro (pele, peça SEM shader, roupa escondida) e a casca de
    -- brasa entra inteira por cima e se desfaz ("out"); no fim sai e o monstro fica
    ember_mutation_shell_burns_off = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 60) })
        fogOn(60)
        G.converge()
        local look = NOM_VariantLook.LOOKS.estalador
        assert(hasItem(z, SHELL), "sem a casca: " .. types(z))
        assert(hasItem(z, look.item) and not hasItem(z, look.fx), "com casca a peça é a sem shader: " .. types(z))
        assert(z.hv.name == nil, "0060b Body: " .. types(z))
        assert(NOM_Dissolve.busy(z) and NOM_EmberShell.count() == 1)
        assert(z.alpha > 0.97, "a casca começa inteira (desfaz): alfa " .. z.alpha)
        G.minAlpha = {}
        G.ms(NOM_DissolveRules.MS + 100)
        assert(G.minAlpha[z] >= NOM_DissolveRules.BAND - 1e-9, "corpo abaixo da faixa: " .. G.minAlpha[z])
        assert(not hasItem(z, SHELL), "a casca ficou: " .. types(z))
        assert(hasItem(z, look.item) and z.hv.name == nil, "o monstro sumiu")
        assert(not NOM_Dissolve.busy(z) and z.alpha == 1 and NOM_EmberShell.count() == 0)
    end,

    -- volta: a casca se forma por cima do monstro, a troca acontece embaixo dela no fim e
    -- ela se desfaz revelando o zumbi comum, com a roupa de antes, igualzinha
    ember_revert_cover_swap_reveal = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("corredor", 61), extra = { "Base.Hat_Army" } })
        local before = { unpack(z.ivs.items) }
        fogOn(61)
        G.converge()
        G.ms(1200)
        fogOff()
        G.converge()
        local look = NOM_VariantLook.LOOKS.corredor
        assert(hasItem(z, SHELL) and hasItem(z, look.item) and z.hv.name == nil, "cobrir: " .. types(z))
        assert(NOM_Dissolve.busy(z) and z.alpha < 0.9, "a casca não começa sumida (forma): " .. z.alpha)
        G.ms(NOM_DissolveRules.MS / 2)
        assert(hasItem(z, look.item), "trocou antes da casca cobrir")
        G.ms(NOM_DissolveRules.MS / 2 + 50)
        assert(not hasItem(z, look.item) and z.hv.name == nil and hasItem(z, "Base.Hat_Army"), "sem troca: " .. types(z))
        assert(hasItem(z, SHELL) and NOM_Dissolve.busy(z), "a casca saiu junto com a troca")
        assert(NOM_VariantLook.count() == 0)
        G.ms(NOM_DissolveRules.MS + 50)
        assert(#z.ivs.items == #before, types(z))
        for i, iv in ipairs(before) do assert(z.ivs.items[i] == iv, "ordem/objeto " .. i .. ": " .. types(z)) end
        assert(not NOM_Dissolve.busy(z) and z.alpha == 1 and NOM_EmberShell.count() == 0)
    end,

    -- a névoa volta no meio da volta: a casca que se formava se desfaz de novo e o monstro fica
    ember_leave_cancelled_by_same_look = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("carpideira", 62) })
        fogOn(62)
        G.converge()
        G.ms(1200)
        fogOff()
        G.converge()
        G.ms(200)
        fogOn(62)
        G.converge()
        G.ms(NOM_DissolveRules.MS * 2)
        local look = NOM_VariantLook.LOOKS.carpideira
        assert(hasItem(z, look.item) and z.hv.name == nil, "o monstro sumiu: " .. types(z))
        assert(not hasItem(z, SHELL) and hasItem(z, OUTFIT[1]), types(z))
        assert(z.alpha == 1 and not NOM_Dissolve.busy(z) and NOM_EmberShell.count() == 0)
        fogOff()
        G.converge()
        G.ms(NOM_DissolveRules.MS * 2 + 100)
        assert(types(z) == table.concat(OUTFIT, ","), "não sai mais: " .. types(z))
    end,

    -- morte com a casca na lista (solo: o DoZombieInventory faz item e loot de toda a lista)
    ember_dead_mid_mutation_loot_exact = function()
        local extra = { "Base.Hat_Army", "Base.ZedDmg_BACK_Slash" }
        local G = setup({ dissolve = true, body = true })
        local id = idFor("estalador", 63)
        local want = G.kill(G.spawn({ id = id, extra = extra }))
        local z = G.spawn({ id = id, extra = extra })
        fogOn(63)
        G.converge()
        assert(hasItem(z, SHELL))
        local c = G.kill(z)
        assert(table.concat(c.inv, ",") == table.concat(want.inv, ","), "loot " .. table.concat(c.inv, ","))
        assert(table.concat(c.worn, ",") == table.concat(want.worn, ","), "vestidos " .. table.concat(c.worn, ","))
        assert(c.ivs == want.ivs and c.skin == nil, "lista " .. c.ivs)
        assert(not NOM_Dissolve.busy(z) and NOM_EmberShell.count() == 0)
        G.ms(NOM_DissolveRules.MS + 50)
    end,

    -- morte depois da troca, com só a casca queimando: o visual não guarda mais o zumbi,
    -- quem limpa é a casca
    ember_dead_after_swap_no_loot = function()
        local extra = { "Base.Hat_Army" }
        local G = setup({ dissolve = true, body = true })
        local id = idFor("estalador", 64)
        local want = G.kill(G.spawn({ id = id, extra = extra }))
        local z = G.spawn({ id = id, extra = extra })
        fogOn(64)
        G.converge()
        G.ms(1200)
        fogOff()
        G.converge()
        G.ms(NOM_DissolveRules.MS + 50)
        assert(hasItem(z, SHELL) and NOM_VariantLook.count() == 0, "não está na fase da casca: " .. types(z))
        local c = G.kill(z)
        assert(table.concat(c.inv, ",") == table.concat(want.inv, ","), "loot " .. table.concat(c.inv, ","))
        assert(table.concat(c.worn, ",") == table.concat(want.worn, ","), "vestidos " .. table.concat(c.worn, ","))
        assert(c.ivs == want.ivs, "lista " .. c.ivs)
        assert(not NOM_Dissolve.busy(z) and NOM_EmberShell.count() == 0)
    end,

    -- fogo (sem DoZombieInventory) e cliente de MP (vestidos do servidor): a casca só sai da lista
    ember_dead_fire_and_mp_client = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("corredor", 65), extra = { "Base.Hat_Army" } })
        fogOn(65)
        G.converge()
        local c = G.kill(z, "fire")
        assert(#c.worn == 0 and #c.inv == 0, "loot inventado: " .. table.concat(c.inv, ","))
        assert(c.ivs == table.concat(OUTFIT, ",") .. ",Base.Hat_Army", "lista: " .. c.ivs)
        local G2 = setup({ client = true, dissolve = true, body = true })
        local y = G2.spawn({ id = idFor("estalador", 65), remote = true })
        fogOn(65)
        G2.converge()
        assert(hasItem(y, SHELL))
        local server = { OUTFIT[1], OUTFIT[2] }
        local d = G2.kill(y, "client", server)
        table.sort(server)
        assert(table.concat(d.worn, ",") == table.concat(server, ","), "vestidos: " .. table.concat(d.worn, ","))
        assert(table.concat(d.inv, ",") == table.concat(server, ","), "loot: " .. table.concat(d.inv, ","))
        assert(not d.ivs:find("NOM_", 1, true), "lista: " .. d.ivs)
    end,

    ember_reuse_mid_effect_clean = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 66) })
        fogOn(66)
        G.converge()
        assert(hasItem(z, SHELL))
        G.reuse(z, idFor(nil, 66))
        assert(not hasItem(z, SHELL) and NOM_EmberShell.count() == 0 and not NOM_Dissolve.busy(z), types(z))
        G.render(z)
        G.converge()
        G.ms(NOM_DissolveRules.MS + 50)
        assert(types(z) == table.concat(OUTFIT, ",") and z.hv.name == nil)
    end,

    -- vermelha com horda: no máximo SHELL_CAP cascas, depois o dissolve da peça até o teto,
    -- depois instantâneo; o fim continua em lotes e nada sobra
    ember_red_fog_cap = function()
        local G = setup({ dissolve = true, body = true })
        for seed = 1, 40 do G.spawn({ id = 9 * 65536 + seed }) end
        fogOn(67, true)
        G.converge()
        local shells = 0
        for _, z in ipairs(G.zombies) do
            if hasItem(z, SHELL) then shells = shells + 1 end
            -- peça base (com gêmeo Fx) só aparece sob a casca na mutação; Sem-rosto A′
            -- não tem Fx e não entra nesta checagem
            for _, k in ipairs(KINDS) do
                local look = NOM_VariantLook.LOOKS[k]
                if look.fx and hasItem(z, look.item) then
                    assert(hasItem(z, SHELL), "peça sem shader sem casca: " .. k .. " " .. types(z))
                end
            end
        end
        assert(shells == NOM_DissolveRules.SHELL_CAP and NOM_EmberShell.count() == shells, "cascas: " .. shells)
        assert(NOM_Dissolve.count() == NOM_DissolveRules.CAP, "dissolve: " .. NOM_Dissolve.count())
        G.ms(NOM_DissolveRules.MS + 50)
        assert(NOM_EmberShell.count() == 0)
        fogOff()
        local restoredPerTick, before = 0, 40
        for _ = 1, 300 do
            G.tick(1)
            local left = NOM_VariantLook.count()
            restoredPerTick = math.max(restoredPerTick, before - left)
            before = left
            assert(NOM_EmberShell.count() <= NOM_DissolveRules.SHELL_CAP and NOM_Dissolve.count() <= NOM_DissolveRules.CAP)
        end
        assert(before == 0, "sobraram " .. before)
        assert(restoredPerTick <= NOM_NightStats.BATCH, "um tick devolveu " .. restoredPerTick)
        for _, z in ipairs(G.zombies) do assert(types(z) == table.concat(OUTFIT, ","), types(z)) end
        assert(NOM_EmberShell.count() == 0 and NOM_Dissolve.count() == 0)
    end,

    -- a variante volta enquanto a casca da volta ainda queima: a casca não pode entrar na
    -- lista guardada da 0016 como roupa e voltar no fim
    ember_shell_not_kept_as_hidden_clothes = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("corredor", 68) })
        fogOn(68)
        G.converge()
        G.ms(1200)
        fogOff()
        G.converge()
        G.ms(NOM_DissolveRules.MS + 50)
        assert(hasItem(z, SHELL) and NOM_VariantLook.count() == 0)
        fogOn(68)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.corredor.item) and hasItem(z, SHELL), types(z))
        G.ms(NOM_DissolveRules.MS + 100)
        assert(not hasItem(z, SHELL), types(z))
        fogOff()
        G.converge()
        G.ms(NOM_DissolveRules.MS * 2 + 200)
        assert(types(z) == table.concat(OUTFIT, ","), "a casca voltou como roupa: " .. types(z))
    end,

    -- a sub-opção desligada no meio: a casca que queima termina e sai; nenhuma nova
    ember_option_off_mid_effect = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 69) })
        fogOn(69)
        G.converge()
        G.ms(300)
        G.body = false
        G.ms(NOM_DissolveRules.MS)
        assert(not hasItem(z, SHELL) and not NOM_Dissolve.busy(z) and NOM_EmberShell.count() == 0, types(z))
        fogOff()
        G.converge()
        assert(types(z) == table.concat(OUTFIT, ","), "peça sem shader e sem casca troca na hora: " .. types(z))
        assert(#G.bursts == 1, "brasa sem casca")
    end,

    -- sub-opção desligada: a sprint 0018 exata (gêmeo com shader, sem casca, sem brasa)
    ember_off_is_sprint_0018 = function()
        local G = setup({ dissolve = true, body = false })
        local z = G.spawn({ id = idFor("estalador", 70) })
        fogOn(70)
        G.converge()
        assert(hasItem(z, NOM_VariantLook.LOOKS.estalador.fx) and not hasItem(z, SHELL), types(z))
        fogOff()
        G.converge()
        G.ms(NOM_DissolveRules.MS + 50)
        assert(#G.bursts == 0 and NOM_EmberShell.count() == 0)
    end,

    -- brasas do overlay no pé do zumbi, uma no começo de cada transição
    ember_bursts_at_each_transition = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 71), x = 33.5, y = 44.5 })
        fogOn(71)
        G.converge()
        assert(#G.bursts == 1 and G.bursts[1].x == 33.5 and G.bursts[1].y == 44.5 and G.bursts[1].z == 0)
        G.ms(1200)
        assert(#G.bursts == 1)
        fogOff()
        G.converge()
        assert(#G.bursts == 2, "sem brasa na volta")
        G.ms(NOM_DissolveRules.MS * 2 + 100)
        assert(#G.bursts == 2, "brasa no meio da volta")
        assert(types(z) == table.concat(OUTFIT, ","))
    end,

    ember_skips_reanimated_player = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 72), reanimated = true })
        fogOn(72)
        G.converge()
        assert(not hasItem(z, SHELL) and NOM_EmberShell.count() == 0 and #G.bursts == 0)
    end,

    -- orçamento: 0060f +wardrobe. pôr com casca ≤ 45 + 3·N + alfa.
    ember_budget = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 73), extra = { "Base.Hat_Army" } })
        local n = #OUTFIT + 1
        local per = 3
        fogOn(73)
        G.vcalls = 0
        G.converge()
        local ticks = math.ceil(1 / NOM_NightStats.BATCH) + 2
        assert(G.vcalls <= 45 + 3 * n + per * ticks, "pôr com casca custou " .. G.vcalls)
        G.vcalls = 0
        local ms = NOM_DissolveRules.MS + 50
        G.ms(ms)
        assert(G.vcalls <= per * math.ceil(ms / 16) + 6, "desfazer a casca custou " .. G.vcalls)
        G.vcalls = 0
        G.converge()
        assert(G.vcalls == 0, "passada sem troca custou " .. G.vcalls)
        fogOff()
        G.vcalls = 0
        G.converge()
        assert(G.vcalls <= 12 + per * ticks, "cobrir custou " .. G.vcalls)
        G.vcalls = 0
        G.ms(ms)
        assert(G.vcalls <= per * math.ceil(ms / 16) + 14 + 2 * n, "trocar embaixo custou " .. G.vcalls)
        assert(z.hv.name == nil)
    end,

    -- review da 0022: zumbi fora da vista (alvo de alfa 0) não ganha brasa (o overlay desenha
    -- na tela sem ver parede nem visão: revelaria o zumbi) nem casca (não prende vaga); vai
    -- pelo caminho da 0018, na mutação e na volta
    ember_unseen_zombie_no_shell_no_burst = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 74) })
        z.seen = false
        fogOn(74)
        G.converge()
        local look = NOM_VariantLook.LOOKS.estalador
        assert(not hasItem(z, SHELL) and hasItem(z, look.fx), "fora da vista: " .. types(z))
        assert(#G.bursts == 0 and NOM_EmberShell.count() == 0, "brasa ou casca fora da vista")
        -- visto na mutação (casca, peça sem shader), fora da vista na volta: na hora, sem brasa
        local y = G.spawn({ id = idFor("corredor", 74) })
        G.converge()
        G.ms(1200)
        assert(hasItem(y, NOM_VariantLook.LOOKS.corredor.item) and #G.bursts == 1)
        y.seen = false
        fogOff()
        G.converge()
        assert(not hasItem(y, SHELL) and #G.bursts == 1, "volta fora da vista: " .. types(y))
        assert(types(y) == table.concat(OUTFIT, ","), types(y))
    end,

    -- review da 0022: erro da API no driver do alfa no meio da casca: a casca sai
    ember_shell_removed_on_dissolve_error = function()
        local G = setup({ dissolve = true, body = true })
        local z = G.spawn({ id = idFor("estalador", 75) })
        fogOn(75)
        G.converge()
        assert(hasItem(z, SHELL))
        z.alphaThrows = true
        G.tick(1)
        z.alphaThrows = false
        assert(not hasItem(z, SHELL) and NOM_EmberShell.count() == 0, "a casca ficou: " .. types(z))
    end,
    -- preta (sprint 0038): todo zumbi vira Tição (pele de carvão e, desde a 0043, a crosta 3D com
    -- olhos de brasa e fumaça); no fim volta o zumbi de sempre
    look_black_fog_ticao_and_back = function()
        local G = setup()
        for seed = 1, 20 do G.spawn({ id = 9 * 65536 + seed }) end
        NOM_FogState.set(true, 12, false, true)
        G.converge()
        local look = NOM_VariantLook.LOOKS.ticao
        assert(look.skin == "NOM_Ticao" and look.item == "Base.NOM_TicaoCrosta" and look.fx == "Base.NOM_TicaoCrostaFx")
        for _, z in ipairs(G.zombies) do
            assert(z.hv.name == look.skin and hasItem(z, look.item), "preta: zumbi sem o Tição: " .. types(z))
        end
        assert(NOM_VariantLook.count() == 20)
        fogOff()
        G.converge()
        for _, z in ipairs(G.zombies) do
            assert(z.hv.name == nil and types(z) == table.concat(OUTFIT, ","), "Tição ficou: " .. types(z))
        end
    end,
}
