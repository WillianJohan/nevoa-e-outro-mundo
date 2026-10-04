-- client/NOM_NightClient.lua: no MP o cliente dono simula o zumbi
-- (NetworkZombieManager.updateAuth); o servidor só manda a flag "night".
-- sendClientCommand(player, module, command, args): client/PZAPI/ui/organisms/PrintMedia.lua:307.
local FILE = "mod/42/media/lua/client/NOM_NightClient.lua"

local function setup(client)
    local C = { installed = 0, asked = {} }
    local handlers = {}
    isClient = function() return client end
    isServer = function() return false end
    getDebug = function() return false end
    SandboxVars = {}
    sendClientCommand = function(player, module, command, args)
        C.asked[#C.asked + 1] = { player = player, module = module, command = command, args = args }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    NOM_NightStats = nil
    package.loaded["NOM_NightStats"] = nil
    require "NOM_NightStats"
    NOM_NightStats.install = function() C.installed = C.installed + 1 end
    dofile(FILE)
    function C.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    C.handlers = handlers
    return C
end

return {
    -- solo e servidor: quem aplica é server/NOM_Night.lua
    night_client_inert_outside_mp = function()
        local C = setup(false)
        assert(C.installed == 0 and next(C.handlers) == nil)
    end,
    night_client_follows_server = function()
        local C = setup(true)
        assert(C.installed == 1)
        C.fire("OnServerCommand", "NevoaEOutroMundo", "night", { on = true })
        assert(NOM_NightStats.night == true)
        C.fire("OnServerCommand", "NevoaEOutroMundo", "night", { on = false })
        assert(NOM_NightStats.night == false)
    end,
    night_client_asks_state_on_join = function()
        local C = setup(true)
        local p = {}
        C.fire("OnCreatePlayer", 0, p)
        assert(#C.asked == 1 and C.asked[1].player == p)
        assert(C.asked[1].module == "NevoaEOutroMundo" and C.asked[1].command == "nightState")
    end,
    night_client_ignores_other_commands = function()
        local C = setup(true)
        C.fire("OnServerCommand", "OutroMod", "night", { on = true })
        C.fire("OnServerCommand", "NevoaEOutroMundo", "ecoGone", { ids = {} })
        assert(NOM_NightStats.night == false)
    end,
}
