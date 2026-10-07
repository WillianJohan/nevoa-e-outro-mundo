-- Contrato do rosto censurado do Sem-rosto entre o Lua, o Java e o shader do mod3 (sprint 0044).
-- O comportamento do Java está em tests/java/CensorTest.java; a compilação do shader e o contrato
-- de uniforms, em tests/test_mod3_flow.sh e tests/test_mod3_depth.py.
local function read(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local JAVA = "mod3/java/nom/render/"
local SH = "mod3/42/media/shaders/"

return {
    -- o Java acha o Sem-rosto pela peça que o NOM_VariantLook veste: os nomes têm de bater
    mod3_censor_items_match_look = function()
        local look = read("mod/42/media/lua/client/NOM_VariantLook.lua")
        local item, fx = look:match('semrosto = { item = "([%w%._]+)", fx = "([%w%._]+)" }')
        assert(item and fx, "LOOKS.semrosto não achado")
        local java = read(JAVA .. "Censor.java")
        assert(java:find('"' .. item .. '"', 1, true), "Censor.java sem " .. item)
        assert(java:find('"' .. fx .. '"', 1, true), "Censor.java sem " .. fx)
    end,

    -- o quadrado vem antes da névoa: a névoa cobre ele (senão o Sem-rosto acende no meio da névoa)
    mod3_censor_before_fog = function()
        local ctx = read(JAVA .. "RenderContext.java")
        local list = assert(ctx:match("PASSES = {([^}]*)}"), "PASSES")
        local a, b = list:find('"NOM_Censura"', 1, true), list:find('"NOM_VolFog"', 1, true)
        assert(a and b and a < b, "NOM_Censura tem de vir antes do NOM_VolFog: " .. list)
    end,

    -- param 13 liga e escala (padrão 1), o shader lê o mesmo componente, e o MAX do Java é o do GLSL
    mod3_censor_param_and_sizes = function()
        local ctx = read(JAVA .. "RenderContext.java")
        local p = tonumber(ctx:match("static final int PARAM_CENSOR = (%d+);"))
        assert(p and p < 16, "PARAM_CENSOR")
        assert(ctx:find("luaParams%[PARAM_CENSOR%] = 1f"), "o quadrado tem de vir ligado")
        local comp = ("uParams[%d].%s"):format(math.floor(p / 4), ({ "x", "y", "z", "w" })[p % 4 + 1])
        assert(read(SH .. "NOM_Censura.frag"):find(comp, 1, true), "NOM_Censura não lê " .. comp)
        local max = tonumber(read(JAVA .. "Censor.java"):match("MAX = (%d+);"))
        local glsl = tonumber(read(SH .. "NOM_RenderContext.glsl"):match("uniform vec4 uCensor%[(%d+)%]"))
        assert(max and max == glsl, "Censor.MAX " .. tostring(max) .. ", uCensor[" .. tostring(glsl) .. "]")
    end,

    -- erro na coleta só apaga o quadrado; a névoa segue. A cor da cena só é copiada com quadrado na tela.
    mod3_censor_errors_stay_local = function()
        local ctx = read(JAVA .. "RenderContext.java")
        local body = assert(ctx:match("private static void collectCensors%((.-)\n    }\n"), "collectCensors")
        assert(body:find("catch %(Throwable"), "collectCensors sem catch (Throwable)")
        assert(not body:find("fail(", 1, true), "erro do quadrado desliga o mod3 inteiro")
        assert(body:find("getAlpha(playerIndex)", 1, true), "sem o alfa do zumbi pro jogador (mostraria atrás da vista)")
        assert(ctx:find("if %(f%.censorCount > 0%)"), "cópia da cor sem a guarda do quadrado na tela")
        assert(read("tests/test_mod3_flow.sh"):find("CensorTest", 1, true), "teste Java fora do script")
    end,
}
