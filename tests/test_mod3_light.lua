-- Contrato da luz que empurra a névoa preta entre o Lua e o mod3 (sprint 0039): o número do
-- param é o mesmo dos dois lados, o empurrão vai em todo passo e erro nele nunca derruba o fluido.
-- O comportamento do Java está em tests/java/FlowLightWindTest.java; o do Lua que manda o param,
-- em tests/test_fog_quality_sync.lua.
local function read(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local JAVA = "mod3/java/nom/render/"

return {
    mod3_light_param_matches_lua = function()
        local s = read(JAVA .. "RenderContext.java")
        local v = tonumber(s:match("static final int PARAM_BLACK = (%d+);"))
        local lua = read("mod/42/media/lua/client/NOM_FogQualitySync.lua")
        local w = tonumber(lua:match("PARAM_BLACK = (%d+)"))
        assert(v and v == w, "PARAM_BLACK: Java " .. tostring(v) .. ", Lua " .. tostring(w))
        assert(v < 16, "luaParams tem 16")
    end,

    mod3_light_applied_every_step = function()
        local s = read(JAVA .. "Flow.java")
        local apply = assert(s:match("private static void apply%(Input in%)(.-)\n    }\n"), "Flow.apply")
        local loop = assert(apply:match("for %(int s = 0; s < in%.steps; s%+%+%)(.-)grid%.step%(STEP%)"), "laço dos passos")
        assert(loop:find("in.lights[", 1, true), "impulsos da luz fora do laço dos passos")
        assert(read("tests/test_mod3_flow.sh"):find("FlowLightWindTest", 1, true), "teste Java fora do script")
    end,

    -- a leitura dos postes (lista do jogo) e das lanternas fica num catch próprio: o fluido segue
    mod3_light_errors_stay_local = function()
        local s = read(JAVA .. "Flow.java")
        local body = assert(s:match("private static int lightImpulses%((.-)\n    }\n"), "Flow.lightImpulses")
        assert(body:find("catch %(Throwable"), "lightImpulses sem catch (Throwable)")
        assert(not body:find("die(", 1, true), "erro da luz mata o fluido")
        local ctx = read(JAVA .. "RenderContext.java")
        assert(ctx:find("Flow.setTorches(", 1, true), "o RenderContext não passa as lanternas")
    end,
}
