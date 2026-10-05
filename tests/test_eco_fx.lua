-- client/NOM_EcoFx.lua (sprint 0018): a morte do Eco queima. Jogo falso que imita o B42.21
-- (bytecode) onde importa:
-- * Solo (IsoZombie.onKilled 38–52): DoZombieInventory faz o WornItems da lista de
--   ItemVisual (setFromItemVisuals: item novo por visual, com o visual COPIADO) e o
--   OnZombieDead vem depois; IsoGameCharacter.Kill 35–50 só liga o onKillDone depois do
--   onKilled. Com onKillDone, IsoZombie.getItemVisuals sai do WornItems (isUsingWornItems,
--   getItemVisuals 0–38): o modelo da animação de morte é feito do WornItems. O corpo
--   nasce no fim da animação (becomeCorpse) e o OnDeadBodySpawn dispara no construtor.
-- * Cliente de MP (DeadZombiePacket → dieNetwork 0–10): o WornItems vem do servidor,
--   Kill (OnZombieDead) e logo becomeCorpse: o corpo nasce no mesmo tick.
-- * resetModelNextFrame: o modelo é refeito no quadro seguinte, de getItemVisuals().
-- * IsoDeadBody.getOutfitName (HumanVisual.getOutfit().name), setDoRender(Z), isAnimal.
-- * instanceItem(tipo) cria o InventoryItem (getBodyLocation, getVisual, getFullType) sem
--   rede; WornItems.setItem(lugar, item), remove(item) e clear() são locais.
-- * Kill: setHealth(0) antes do onKilled (isDead já vale no OnZombieDead).
-- * Solo: o server/NOM_Eco.lua roda no mesmo processo; com opts.server o teste carrega os
--   dois na ordem do jogo (shared → client → server): o OnZombieDead do NOM_EcoFx roda
--   ANTES do do servidor, que limpa inventário e WornItems (0002/0012: sem loot, sem corpo).
-- * O corpo (IsoDeadBody.<init> 661–710) copia o inventário e o WornItems do zumbi e só
--   depois dispara o OnDeadBodySpawn.
local FILE = "mod/42/media/lua/client/NOM_EcoFx.lua"

-- BodyLocation de cada item (mod: o script de verdade; vanilla: generated/items/clothing.txt)
local LOC = { ["Base.Tshirt_DefaultTEXTURE"] = "tshirt" }
do
    local f = assert(io.open("mod/42/media/scripts/NOM_clothing.txt"))
    for name, body in f:read("*a"):gmatch("item%s+([%w_]+)%s*(%b{})") do
        LOC["Base." .. name] = body:match("BodyLocation = base:(%w+)")
    end
    f:close()
end

local function setup(opts)
    opts = opts or {}
    local G = { now = 1759999999000, zombies = {}, bodies = {}, java = 0, on = opts.on ~= false, prints = {} }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    Events = setmetatable({}, { __index = function(t, name)
        local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
        rawset(t, name, e)
        return e
    end })
    isServer = function() return false end
    isClient = function() return opts.client == true end
    getDebug = function() return true end
    local rawPrint = print
    print = function(s) G.prints[#G.prints + 1] = s end
    G.restore = function() print = rawPrint end
    getTimestampMs = function() return G.now end
    getNumActivePlayers = function() return 1 end
    NOM_ScreenFxOptions = { dissolve = function() return G.on end }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    NOM_ScreenFx = { extra = {} } -- o overlay da 0013 (testado em test_screen_fx.lua)
    package.loaded.NOM_ScreenFx = NOM_ScreenFx
    for _, m in ipairs({ "NOM_Dissolve", "NOM_Embers", "NOM_EcoFx" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    local function vc() G.java = G.java + 1 end

    local function visual(t)
        local v = { type = t }
        function v:getItemType() vc(); return self.type end
        function v:setItemType(x) vc(); self.type = x end
        return v
    end
    local function item(t)
        local it = { type = t, visual = visual(t) }
        function it:getVisual() vc(); return self.visual end
        function it:getFullType() vc(); return self.type end
        function it:getBodyLocation() vc(); return { loc = assert(LOC[t], "sem lugar " .. t) } end
        return it
    end
    instanceItem = function(t) vc(); return item(t) end
    local function jlist(items)
        local l = { items = items }
        function l:size() vc(); return #self.items end
        function l:get(i) vc(); return self.items[i + 1] end
        function l:add(o) vc(); self.items[#self.items + 1] = o; return true end
        return l
    end

    function G.zombie(outfit)
        local z = { outfit = outfit or "NOM_Eco", killDone = false, resets = 0, model = nil, alpha = 1, onSquare = true,
            x = 10.5, y = 20.5, zz = 0 }
        local types = z.outfit == "NOM_Eco" and { "Base.NOM_EcoCinza", "Base.NOM_EcoVeu" } or { "Base.Tshirt_DefaultTEXTURE" }
        local ivs = {}
        for _, t in ipairs(types) do ivs[#ivs + 1] = visual(t) end
        z.ivs = jlist(ivs)
        z.worn = {}
        function z:getOutfitName() vc(); return self.outfit end
        z.md = { NOM_eco = z.outfit == "NOM_Eco" or nil }
        z.inv = {}
        function z:getModData() return self.md end
        function z:isDead() vc(); return self.dead == true end
        function z:getInventory()
            local me = self
            return { removeAllItems = function() vc(); me.inv = {} end }
        end
        function z:getItemVisuals()
            vc()
            if not self.killDone then return self.ivs end
            local out = {}
            for _, w in ipairs(self.worn) do out[#out + 1] = w.item.visual end
            return jlist(out)
        end
        function z:getWornItems()
            vc()
            local me = self
            local wi = {}
            function wi:size() vc(); return #me.worn end
            function wi:get(i) vc(); local w = me.worn[i + 1]; return { getItem = function() vc(); return w.item end } end
            function wi:setItem(loc, it)
                vc()
                assert(type(loc) == "table" and loc.loc, "setItem(ItemBodyLocation, item)")
                for i = #me.worn, 1, -1 do
                    if me.worn[i].loc == loc.loc and loc.loc ~= "zeddmg" then table.remove(me.worn, i) end
                end
                me.worn[#me.worn + 1] = { loc = loc.loc, item = it }
            end
            function wi:remove(it)
                vc()
                for i, w in ipairs(me.worn) do if w.item == it then table.remove(me.worn, i) return end end
            end
            function wi:clear() vc(); me.worn = {} end
            return wi
        end
        function z:resetModelNextFrame() vc(); self.resets = self.resets + 1; self.pendingReset = true end
        function z:getX() vc(); return self.x end
        function z:getY() vc(); return self.y end
        function z:getZ() vc(); return self.zz end
        function z:setAlpha(pn, a) vc(); self.alpha = math.max(0, math.min(1, a)) end
        function z:getAlpha(pn) vc(); return self.alpha end
        function z:getCurrentSquare() vc(); return self.onSquare and {} or nil end
        G.zombies[#G.zombies + 1] = z
        return z
    end

    local function modelOf(z)
        local out = {}
        local l = z:getItemVisuals()
        for i = 0, l:size() - 1 do out[#out + 1] = l:get(i).type end
        return table.concat(out, ",")
    end
    function G.frame(n)
        for _ = 1, n or 1 do
            for _, z in ipairs(G.zombies) do
                z.alpha = math.min(1, z.alpha + 0.28) -- à vista
            end
            G.fire("OnTick", 0)
            for _, z in ipairs(G.zombies) do
                if z.pendingReset and z.onSquare then z.model = modelOf(z); z.pendingReset = false end
                z.drawn = z.alpha
            end
            G.now = G.now + 16
        end
    end
    local function corpse(z)
        local b = { outfit = z.outfit, render = true, animal = false, inv = {}, worn = {} }
        for _, t in ipairs(z.inv) do b.inv[#b.inv + 1] = t end
        for _, w in ipairs(z.worn) do b.worn[#b.worn + 1] = w.item.visual.type end
        function b:getWornItems() vc(); return { clear = function() vc(); b.worn = {} end } end
        function b:getOutfitName() vc(); return self.outfit end
        function b:isAnimal() vc(); return self.animal end
        function b:setDoRender(v) vc(); self.render = v end
        function b:getX() vc(); return z.x end
        function b:getY() vc(); return z.y end
        function b:getZ() vc(); return z.zz end
        z.onSquare = false
        G.bodies[#G.bodies + 1] = b
        G.fire("OnDeadBodySpawn", b)
        return b
    end
    G.corpse = corpse
    -- how: "solo" (animação de animMs antes do corpo) ou "client" (corpo no mesmo tick)
    function G.kill(z, how, animMs)
        -- solo: DoZombieInventory (vestidos e inventário da lista); cliente de MP: o que o
        -- servidor mandou (opts.serverWorn, o servidor do Eco já limpou: vazio)
        z.worn, z.inv = {}, {}
        local from = z.ivs.items
        if how == "client" and opts.serverWorn then
            from = {}
            for _, t in ipairs(opts.serverWorn) do from[#from + 1] = visual(t) end
        end
        for _, v in ipairs(from) do
            z.worn[#z.worn + 1] = { loc = LOC[v.type], item = item(v.type) }
            z.inv[#z.inv + 1] = v.type
        end
        z.dead = true
        G.fire("OnZombieDead", z)
        z.killDone = true
        if how == "client" then return corpse(z) end
        G.frame(math.ceil((animMs or 1600) / 16))
        return corpse(z)
    end
    dofile(FILE)
    if opts.server then -- solo: o servidor no mesmo processo, carregado depois do client
        getCell = function() return { getGridSquare = function() return nil end, getZombieList = function()
            return { size = function() return 0 end }
        end } end
        ModData = { getOrCreate = function() return {} end }
        SandboxVars = { NevoaEOutroMundo = {} }
        for _, m in ipairs({ "NOM_Eco", "NOM_World", "NOM_NightCount", "NOM_Players" }) do
            _G[m] = nil
            package.loaded[m] = nil
        end
        dofile("mod/42/media/lua/server/NOM_Eco.lua")
    end
    return G
end

local function has(list, t)
    for _, x in ipairs(list) do if x == t then return true end end
    return false
end

local function split(s)
    local out = {}
    for x in (s or ""):gmatch("[^,]+") do out[#out + 1] = x end
    return out
end

return {
    -- solo: véu vira o gêmeo, casca vestida pelo WornItems (o modelo da morte), queima com
    -- brasas e o corpo nasce escondido
    ecofx_solo_death_burns = function()
        local G = setup()
        local z = G.zombie()
        local b = G.kill(z, "solo", 1600)
        G.restore()
        local model = split(z.model)
        assert(z.resets >= 1 and has(model, "Base.NOM_EcoVeuFx") and not has(model, "Base.NOM_EcoVeu"),
            "véu no modelo da morte: " .. tostring(z.model))
        assert(has(model, "Base.NOM_EcoCasca") and has(model, "Base.NOM_EcoCinza"), "casca: " .. tostring(z.model))
        assert(z.drawn < 0.05, "não queimou até sumir: " .. z.drawn)
        assert(b.render == false, "corpo do Eco à mostra")
        assert(NOM_Embers.count() == 1, "sem brasas")
        G.frame(1)
        assert(not NOM_Dissolve.busy(z), "o efeito sobrou depois do corpo")
    end,

    -- no meio da animação o alfa anda pela faixa e abaixo dela
    ecofx_solo_alpha_goes_down = function()
        local G = setup()
        local z = G.zombie()
        G.kill(z, "solo", NOM_DissolveRules.MS / 2)
        local d = z.drawn
        G.frame(1) -- o corpo nasceu: o zumbi saiu do square
        G.restore()
        assert(d < 1 and d >= NOM_DissolveRules.BAND, "meia queima: " .. d)
        assert(not NOM_Dissolve.busy(z), "o efeito sobrou depois do corpo")
    end,

    -- cliente de MP: sem janela, o corpo nasce no mesmo tick: escondido, com brasas
    ecofx_mp_client_no_window = function()
        local G = setup({ client = true })
        local z = G.zombie()
        local b = G.kill(z, "client")
        G.frame(2)
        G.restore()
        assert(b.render == false and NOM_Embers.count() == 1)
        assert(not NOM_Dissolve.busy(z))
        local logged = false
        for _, p in ipairs(G.prints) do if p:find("janela ms=0", 1, true) then logged = true end end
        assert(logged, "sem a linha da janela no console")
    end,

    ecofx_shell_constant_off = function()
        local G = setup()
        NOM_EcoFx.SHELL = false
        local z = G.zombie()
        G.kill(z, "solo", 1600)
        G.restore()
        assert(not has(split(z.model), "Base.NOM_EcoCasca") and has(split(z.model), "Base.NOM_EcoVeuFx"), tostring(z.model))
    end,

    -- desligado: nada muda (a morte da 0017: o servidor tira o corpo)
    ecofx_off_untouched = function()
        local G = setup({ on = false })
        local z = G.zombie()
        G.java = 0
        local b = G.kill(z, "solo", 1600)
        G.restore()
        assert(z.resets == 0 and b.render == true and NOM_Embers.count() == 0 and z.drawn == 1)
        assert(G.java <= 4, "desligado custou " .. G.java)
    end,

    ecofx_common_zombie_untouched = function()
        local G = setup()
        local z = G.zombie("Generic01")
        local b = G.kill(z, "solo", 1600)
        G.restore()
        assert(z.resets == 0 and b.render == true and NOM_Embers.count() == 0)
        local animal = { getOutfitName = function() error("corpo de animal sem HumanVisual") end, isAnimal = function() return true end }
        G.fire("OnDeadBodySpawn", animal) -- não pergunta o outfit de animal
    end,

    -- muitos Ecos de uma vez: o teto do dissolve vale e o corpo ainda some
    ecofx_cap = function()
        local G = setup()
        local zs = {}
        for i = 1, NOM_DissolveRules.CAP + 3 do zs[i] = G.zombie() end
        for _, z in ipairs(zs) do G.fire("OnZombieDead", z); z.killDone = true end
        assert(NOM_Dissolve.count() == NOM_DissolveRules.CAP)
        assert(NOM_Embers.count() <= NOM_EmberRules.CAP)
        G.restore()
    end,

    -- Review da 0018: no solo os dois OnZombieDead rodam no mesmo processo, o do servidor
    -- depois, e limpa o WornItems. A morte tem que queimar mesmo assim, e o corpo nasce sem
    -- loot e sem nada vestido (regra da 0002)
    ecofx_sp_with_server_handler = function()
        local G = setup({ server = true })
        local z = G.zombie()
        local b = G.kill(z, "solo", 1600)
        G.restore()
        local model = split(z.model)
        assert(has(model, "Base.NOM_EcoVeuFx") and has(model, "Base.NOM_EcoCasca") and has(model, "Base.NOM_EcoCinza"),
            "o Eco caiu sem nada pra queimar: " .. tostring(z.model))
        assert(not has(model, "Base.NOM_EcoVeu"), "véu sem shader")
        assert(#b.inv == 0, "loot no corpo: " .. table.concat(b.inv, ","))
        assert(#b.worn == 0, "corpo vestido: " .. table.concat(b.worn, ","))
        assert(b.render == false)
    end,

    -- cliente de MP com o que o servidor mandou (vazio: ele já limpou) e o corpo no mesmo tick
    ecofx_mp_client_empty_worn = function()
        local G = setup({ client = true, serverWorn = {} })
        local z = G.zombie()
        local b = G.kill(z, "client")
        G.frame(2)
        G.restore()
        assert(b.render == false and #b.worn == 0 and NOM_Embers.count() == 1)
    end,

    -- duas mortes ao mesmo tempo: cada corpo loga a janela do seu Eco
    ecofx_window_per_zombie = function()
        local G = setup()
        local a, c = G.zombie(), G.zombie()
        c.x, c.y = 30.5, 40.5
        a.dead = true
        G.fire("OnZombieDead", a)
        a.killDone = true
        G.frame(math.ceil(800 / 16))
        c.dead = true
        G.fire("OnZombieDead", c)
        c.killDone = true
        G.frame(math.ceil(400 / 16))
        G.prints = {}
        -- corpo do primeiro (morto há ~1200 ms)
        a.onSquare = false
        local b = { outfit = "NOM_Eco", x = 10, y = 20 }
        function b:getOutfitName() return self.outfit end
        function b:isAnimal() return false end
        function b:setDoRender() end
        function b:getWornItems() return { clear = function() end } end
        function b:getX() return 10.5 end
        function b:getY() return 20.5 end
        function b:getZ() return 0 end
        G.fire("OnDeadBodySpawn", b)
        G.restore()
        local ms
        for _, p in ipairs(G.prints) do ms = ms or tonumber(p:match("janela ms=(%d+)")) end
        assert(ms and ms >= 1100 and ms <= 1300, "janela do Eco errado: " .. tostring(ms))
    end,

    -- a opção desligada entre a morte e o corpo: o corpo de um Eco que a fila vestiu sai
    -- sem nada vestido mesmo assim (a casca não vai pro save se a remoção falhar)
    ecofx_option_off_before_corpse_still_clears = function()
        local G = setup({ server = true })
        local z = G.zombie()
        z.dead = true
        G.fire("OnZombieDead", z)
        z.killDone = true
        G.frame(5)
        assert(#z.worn > 0, "a fila não vestiu")
        G.on = false
        local b = G.corpse(z)
        G.restore()
        assert(#b.worn == 0, "corpo com a casca: " .. table.concat(b.worn, ","))
    end,
}
