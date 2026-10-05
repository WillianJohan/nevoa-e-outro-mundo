-- client/NOM_FogQualitySync.lua: manda a qualidade escolhida em Opções > Mods pro mod Java opcional
-- (mod3) com NOMRender_setParam(6, q). O global só existe com o mod3 carregado (ZombieBuddy registra
-- os @LuaMethod do RenderContext); sem ele, nada. Eventos falsos guardam os callbacks.
local FILE = "mod/42/media/lua/client/NOM_FogQualitySync.lua"

local function load(quality, withJava)
    local handlers = {}
    Events = setmetatable({}, { __index = function(t, name)
        local e = { Add = function(fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end }
        rawset(t, name, e)
        return e
    end })
    isServer = function() return false end
    NOM_ScreenFxOptions = { fogQuality = function() return quality.value end }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    local calls = {}
    NOMRender_setParam = withJava and function(i, v) calls[#calls + 1] = { i, v } end or nil
    _G.NOM_FogQualitySync = nil
    dofile(FILE)
    return NOM_FogQualitySync, handlers, calls
end

local function fire(handlers, name)
    for _, fn in ipairs(handlers[name] or {}) do fn() end
end

return {
    fog_quality_sync_on_game_start = function()
        local q = { value = 1 }
        local S, h, calls = load(q, true)
        assert(S and S.PARAM == 6)
        fire(h, "OnGameStart")
        assert(#calls == 1 and calls[1][1] == 6 and calls[1][2] == 1, "não mandou a qualidade no início")
    end,

    fog_quality_sync_follows_option_once = function()
        local q = { value = 2 }
        local _, h, calls = load(q, true)
        fire(h, "OnGameStart")
        fire(h, "EveryOneMinute")
        assert(#calls == 1, "mandou de novo sem mudar")
        q.value = 0
        fire(h, "EveryOneMinute")
        assert(#calls == 2 and calls[2][2] == 0, "não seguiu a opção")
    end,

    fog_quality_sync_without_java_mod = function()
        local q = { value = 2 }
        local S, h = load(q, false)
        fire(h, "OnGameStart")
        fire(h, "EveryOneMinute")
        assert(S.push() == false)
    end,
}
