-- Contrato do sonar do Estalador entre o Lua e o mod3 (sprint 0037): os números do
-- mod3/java/nom/render/Sonar.java são os do shared/NOM_SonarRules.lua, e o NOMRender_sonar
-- (RenderContext.java) nunca deixa erro do Java subir pro Lua. O comportamento do Java está em
-- tests/java/FlowSonarTest.java; o do Lua que chama, em tests/test_sonar_fx.lua.
local function read(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local JAVA = "mod3/java/nom/render/"

local function const(src, name)
    local v = src:match("static final %a+ " .. name .. " = ([%d%.]+)f?;")
    return assert(tonumber(v), "Sonar.java sem " .. name)
end

return {
    mod3_sonar_constants_match_lua = function()
        local R = dofile("mod/42/media/lua/shared/NOM_SonarRules.lua")
        local s = read(JAVA .. "Sonar.java")
        assert(const(s, "RANGE") == R.RANGE, "RANGE")
        assert(math.abs(const(s, "DURATION") * 1000 - R.DURATION_MS) < 1e-6, "DURATION")
        assert(const(s, "MAX_RINGS") == R.MAX_RINGS, "MAX_RINGS")
    end,

    -- a curva (raio em t) é a mesma: os pontos de tests/sonar_curve.csv valem no Lua aqui e no
    -- Java no FlowSonarTest, que lê o mesmo arquivo
    mod3_sonar_curve_matches_java = function()
        local R = dofile("mod/42/media/lua/shared/NOM_SonarRules.lua")
        local n = 0
        for line in read("tests/sonar_curve.csv"):gmatch("[^\n]+") do
            local ms, r = line:match("^(%d+),([%d%.]+)$")
            if ms then
                n = n + 1
                assert(math.abs(R.radius(tonumber(ms)) - tonumber(r)) < 1e-6, "raio em " .. ms .. " ms")
            end
        end
        assert(n >= 4, "poucos pontos na curva: " .. n)
        assert(read("tests/java/FlowSonarTest.java"):find("tests/sonar_curve.csv", 1, true), "o Java não confere a curva")
    end,

    mod3_sonar_never_throws_to_lua = function()
        local s = read(JAVA .. "RenderContext.java")
        local body = s:match('@LuaMethod%(name = "NOMRender_sonar", global = true%)(.-)\n    }\n')
        assert(body, "RenderContext sem NOMRender_sonar")
        assert(body:find("catch %(Throwable"), "NOMRender_sonar sem catch (Throwable)")
        assert(body:find("return false", 1, true), "erro tem que mandar o anel pra tela")
        assert(read(JAVA .. "Main.java"):find("NOMRender_sonar", 1, true), "Main não loga o registro")
    end,

    -- a simulação aplica a frente em todo passo (não só no primeiro, como o blast)
    mod3_sonar_applied_every_step = function()
        local s = read(JAVA .. "Flow.java")
        local apply = assert(s:match("private static void apply%(Input in%)(.-)\n    }\n"), "Flow.apply")
        local loop = assert(apply:match("for %(int s = 0; s < in%.steps; s%+%+%)(.-)grid%.step%(STEP%)"), "laço dos passos")
        assert(loop:find("grid.sonar(", 1, true), "grid.sonar fora do laço dos passos")
        assert(s:find("sonar.clear()", 1, true), "anéis não somem com a grade nova")
        assert(read("tests/test_mod3_flow.sh"):find("FlowSonarTest", 1, true), "teste Java fora do script")
    end,
}
