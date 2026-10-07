-- client/NOM_FogQualitySync.lua: manda a qualidade e a resolução escolhidas em Opções > Mods pro mod
-- Java opcional (mod3) com NOMRender_setParam(6, q) e (9, s). O global só existe com o mod3 carregado
-- (ZombieBuddy registra os @LuaMethod do RenderContext); sem ele, nada. Eventos falsos guardam os callbacks.
local FILE = "mod/42/media/lua/client/NOM_FogQualitySync.lua"

local function load(opt, withJava)
    local handlers = {}
    Events = setmetatable({}, { __index = function(t, name)
        local e = { Add = function(fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end }
        rawset(t, name, e)
        return e
    end })
    isServer = function() return false end
    NOM_ScreenFxOptions = {
        fogQuality = function() return opt.quality end,
        flowResolution = function() return opt.res end,
    }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    local calls = {}
    NOMRender_setParam = withJava and function(i, v) calls[#calls + 1] = { i, v } end or nil
    _G.NOM_FogQualitySync = nil
    _G.NOM_FogState, package.loaded.NOM_FogState = nil, nil -- sem ouvintes de carregamentos anteriores
    dofile(FILE)
    return NOM_FogQualitySync, handlers, calls
end

local function fire(handlers, name)
    for _, fn in ipairs(handlers[name] or {}) do fn() end
end

-- valor mandado pro parâmetro i (o último), ou nil
local function sent(calls, i)
    local v
    for _, c in ipairs(calls) do if c[1] == i then v = c[2] end end
    return v
end

local function count(calls, i)
    local k = 0
    for _, c in ipairs(calls) do if c[1] == i then k = k + 1 end end
    return k
end

return {
    fog_quality_sync_on_game_start = function()
        local o = { quality = 1, res = 3 }
        local S, h, calls = load(o, true)
        assert(S and S.PARAM == 6 and S.PARAM_RES == 9)
        fire(h, "OnGameStart")
        assert(sent(calls, 6) == 1, "não mandou a qualidade no início")
        assert(sent(calls, 9) == 3, "não mandou a resolução no início")
    end,

    fog_quality_sync_follows_option_once = function()
        local o = { quality = 2, res = 2 }
        local _, h, calls = load(o, true)
        fire(h, "OnGameStart")
        fire(h, "EveryOneMinute")
        assert(#calls == 3, "mandou de novo sem mudar")
        o.quality = 0
        fire(h, "EveryOneMinute")
        assert(count(calls, 6) == 2 and sent(calls, 6) == 0, "não seguiu a qualidade")
        assert(count(calls, 9) == 1, "mandou a resolução sem ela mudar")
        o.res = 1
        fire(h, "EveryOneMinute")
        assert(count(calls, 9) == 2 and sent(calls, 9) == 1, "não seguiu a resolução")
        assert(count(calls, 6) == 2, "mandou a qualidade sem ela mudar")
    end,

    -- sprint 0039: a névoa preta liga o empurrão da luz no mod3 (param 12) na borda, sem esperar o
    -- minuto; desliga quando acaba; não repete sem mudar
    fog_quality_sync_black_fog = function()
        local o = { quality = 2, res = 2 }
        local S, h, calls = load(o, true)
        assert(S.PARAM_BLACK == 12)
        fire(h, "OnGameStart")
        assert(sent(calls, 12) == 0, "não mandou a preta desligada no início")
        NOM_FogState.set(true, 3, false, true)
        assert(sent(calls, 12) == 1, "a borda da preta não ligou o param 12")
        fire(h, "EveryOneMinute")
        assert(count(calls, 12) == 2, "mandou de novo sem mudar")
        NOM_FogState.set(false, 3)
        assert(sent(calls, 12) == 0 and count(calls, 12) == 3, "o fim da preta não desligou")
    end,

    fog_quality_sync_without_java_mod = function()
        local o = { quality = 2, res = 2 }
        local S, h = load(o, false)
        fire(h, "OnGameStart")
        fire(h, "EveryOneMinute")
        assert(S.push() == false)
    end,
}
