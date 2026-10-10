-- Contrato do rosto censurado do Sem-rosto entre o Lua, o Java e o shader do mod3
-- (sprint 0044; 0060f: ModData + osso/estimativa, sem casca-ovo).
local function read(path)
    local f = assert(io.open(path, "rb"), "falta " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

local JAVA = "mod3/java/nom/render/"
local SH = "mod3/42/media/shaders/"

return {
    -- 0060f: Sem-rosto sem peça 3D; Censor marca via ModData NOM_semrosto (VariantLook).
    mod3_censor_moddata_matches_look = function()
        local look = read("mod/42/media/lua/client/NOM_VariantLook.lua")
        local block = look:match("semrosto = %b{}")
        assert(block, "LOOKS.semrosto não achado")
        assert(not block:find("SemRostoEstatica", 1, true), "casca-ovo ainda no LOOKS.semrosto")
        assert(block:find("SemRostoRosto", 1, true) or look:find("NOM_SemRostoFace.ITEM", 1, true),
            "A′ remendo fora do LOOKS.semrosto")
        assert(look:find('NOM_semrosto = true', 1, true), "VariantLook não marca ModData")
        assert(look:find('NOM_semrosto = nil', 1, true), "VariantLook não limpa ModData")
        local java = read(JAVA .. "Censor.java")
        assert(java:find('MODDATA_KEY = "NOM_semrosto"', 1, true), "Censor.MODDATA_KEY")
        assert(java:find("estimateHead", 1, true), "falta estimateHead (fallback prone)")
        assert(java:find("offerHead", 1, true), "falta offerHead")
        local ctx = read(JAVA .. "RenderContext.java")
        assert(ctx:find("Bip01_Head", 1, true), "RenderContext sem osso da cabeça")
        assert(ctx:find("isSemRostoMarked", 1, true), "sem leitura do ModData")
        assert(ctx:find("offerHead", 1, true), "collectCensors ainda usa offer(pés)")
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
        local copy = assert(ctx:match("private static void copyScene%((.-)\n    }\n"), "copyScene")
        assert(copy:find("catch %(Throwable"), "cópia da cor sem catch (Throwable): FBO incompleto desligaria a névoa")
        assert(not copy:find("fail(", 1, true), "erro na cópia da cor desliga o mod3 inteiro")
        assert(copy:find("f.censorCount = 0", 1, true), "erro na cópia da cor não pula o passe do quadrado")
        assert(read("tests/test_mod3_flow.sh"):find("CensorTest", 1, true), "teste Java fora do script")
    end,
}
