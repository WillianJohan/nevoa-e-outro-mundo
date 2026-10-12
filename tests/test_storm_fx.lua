-- client/NOM_StormFx.lua (sprint 0053): tint vermelho na preta + overlay de fallback.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_StormFx.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_StormRules", "NOM_ScreenFxRules", "NOM_StormFx", "NOM_ScreenFx" })
    NOM_ScreenFx = { extra = {} }
    package.loaded.NOM_ScreenFx = NOM_ScreenFx
    NOMRender_setLightningColor = opts.mod3
    G.ticksBefore = #(G.handlers.OnTick or {})
    dofile(FILE)
    require "NOM_FogState"
    require "NOM_StormRules"
    return G
end

return {
    storm_fx_inert_on_dedicated = function()
        local G = setup({ server = true })
        assert(#(G.handlers.OnTick or {}) == G.ticksBefore, "servidor dedicado registrou StormFx")
    end,

    storm_fx_tints_via_mod3_on_black = function()
        local calls = {}
        local G = setup({
            mod3 = function(r, g, b) calls[#calls + 1] = { r, g, b }; return true end,
        })
        NOM_FogState.set(true, 1, false, true)
        G.tick(1)
        assert(#calls == 1, "não pintou na preta")
        local c = NOM_StormRules.LIGHTNING_BLACK
        assert(calls[1][1] == c.r and calls[1][2] == c.g and calls[1][3] == c.b)
        G.tick(1)
        assert(#calls == 1, "repintou sem mudar")
        NOM_FogState.set(true, 1, true, false) -- vermelha
        G.tick(1)
        assert(#calls == 2 and calls[2][1] == 1 and calls[2][2] == 1 and calls[2][3] == 1,
            "vermelha volta a branco")
    end,

    storm_fx_flash_overlay_only_black = function()
        local G = setup()
        NOM_FogState.set(true, 1, true, false)
        NOM_StormFx.flash()
        assert(NOM_StormFx.flashAt == nil, "flash na vermelha")
        NOM_FogState.set(true, 1, false, true)
        G.now = 5000
        NOM_StormFx.flash()
        assert(NOM_StormFx.flashAt == 5000)
        assert(NOM_StormRules.stormFlash(5000, NOM_StormFx.flashAt) == 1)
    end,

    storm_fx_server_command_triggers_flash = function()
        local G = setup()
        NOM_FogState.set(true, 1, false, true)
        G.now = 100
        G.fire("OnServerCommand", "NevoaEOutroMundo", "thunderFlash", {})
        assert(NOM_StormFx.flashAt == 100, "comando não acendeu o overlay")
    end,

    storm_fx_mod3_contract = function()
        local f = assert(io.open("mod3/java/nom/render/RenderContext.java"))
        local s = f:read("*a")
        f:close()
        assert(s:find("NOMRender_setLightningColor", 1, true), "sem LuaMethod")
        assert(s:find("lightningInfos", 1, true), "sem reflexão do array")
        assert(s:find("catch (Throwable", 1, true), "sem catch Throwable")
        local m = assert(io.open("mod3/java/nom/render/Main.java"))
        local ms = m:read("*a")
        m:close()
        assert(ms:find("NOMRender_setLightningColor", 1, true), "Main não loga o registro")
    end,
}
