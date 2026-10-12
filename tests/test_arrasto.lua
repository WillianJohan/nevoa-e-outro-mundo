-- Arrasto / Rastejante (sprint 0059): apply no IsoZombie + force no servidor.
local function setup(opts)
    opts = opts or {}
    package.loaded["NOM_ArrastoRules"] = nil
    package.loaded["NOM_Arrasto"] = nil
    package.loaded["NOM_ArrastoServer"] = nil
    package.loaded["NOM_World"] = nil
    _G.NOM_ArrastoRules, _G.NOM_Arrasto, _G.NOM_ArrastoServer = nil, nil, nil

    isClient = function() return opts.client == true end
    isServer = function() return opts.server == true end

    NOM_World = { fog = opts.fog == true, red = opts.red == true, black = opts.black == true }
    package.loaded["NOM_World"] = NOM_World

    dofile("mod/42/media/lua/shared/NOM_ArrastoRules.lua")
    dofile("mod/42/media/lua/shared/NOM_Arrasto.lua")
    if not opts.client then
        dofile("mod/42/media/lua/server/NOM_ArrastoServer.lua")
    end

    local function zombie(o)
        o = o or {}
        local z = {
            dead = o.dead == true,
            md = o.md or {},
            crawler = false,
            speed = nil,
            online = o.online or 7,
        }
        function z:isDead() return self.dead end
        function z:getModData() return self.md end
        function z:setCrawler(v) self.crawler = v == true end
        function z:doZombieSpeed(t) self.speed = t end
        function z:getOnlineID() return self.online end
        return z
    end

    return { zombie = zombie }
end

return {
    arrasto_apply_marks_crawler_and_slow = function()
        local G = setup({ client = true }) -- só shared
        local z = G.zombie()
        assert(NOM_Arrasto.apply(z) == true)
        assert(z.md.NOM_arrasto == true)
        assert(z.crawler == true)
        assert(z.speed == 3)
        assert(NOM_Arrasto.is(z) == true)
        NOM_Arrasto.clear(z)
        assert(z.md.NOM_arrasto == nil)
        assert(NOM_Arrasto.is(z) == false)
    end,

    arrasto_apply_refuses_dead = function()
        local G = setup({ client = true })
        assert(NOM_Arrasto.apply(nil) == false)
        assert(NOM_Arrasto.apply(G.zombie({ dead = true })) == false)
    end,

    arrasto_force_only_red_or_black = function()
        local G = setup({ fog = true, red = true })
        local z = G.zombie()
        local ok, why = NOM_ArrastoServer.force(z)
        assert(ok == true, tostring(why))
        assert(z.crawler == true and z.speed == 3)

        G = setup({ fog = true, red = false, black = false })
        z = G.zombie()
        ok, why = NOM_ArrastoServer.force(z)
        assert(ok == nil and why:find("vermelha"), tostring(why))
        assert(z.crawler == false)

        G = setup({ fog = false })
        z = G.zombie()
        ok, why = NOM_ArrastoServer.force(z)
        assert(ok == nil, "fora da névoa não força")

        G = setup({ fog = true, black = true })
        z = G.zombie()
        ok, why = NOM_ArrastoServer.force(z)
        assert(ok == true, tostring(why))
    end,

    arrasto_force_skip_color = function()
        local G = setup({ fog = false })
        local z = G.zombie()
        local ok, why = NOM_ArrastoServer.force(z, true)
        assert(ok == true, tostring(why))
        assert(z.md.NOM_arrasto == true)
    end,
}
