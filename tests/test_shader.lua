-- Mod do shader (mod2/, id NevoaEOutroMundo_Shader, sprint 0013): screen.frag original
-- com a interface que o jogo espera, sem texto do vanilla, e o mod.info.
--
-- Interface (bytecode WeatherShader do 42.21): onCompileSuccess busca a posição destes
-- uniforms por nome (glGetUniformLocation); startRenderThread manda os valores
-- (glUniform1f / 2f / 3f / 4f, daí o tipo). Uniform fora da lista nunca recebe valor.
-- O vértice continua o screen.vert vanilla: saídas vColor e vUV.
require "NOM_ScreenFxRules"

local SHADER = "mod2/42/media/shaders/screen.frag"
local VANILLA = "/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid/media/shaders/screen.frag"

local BOUND = {
    TimeOfDay = "float", BloomVal = "float", PixelOffset = "float", PixelSize = "float",
    BlurStrength = "float", bgl_RenderedTextureWidth = "float", bgl_RenderedTextureHeight = "float",
    timer = "float", timerWrap = "float", TextureSize = "vec2", Zoom = "float", Light = "vec3",
    LightIntensity = "float", NightValue = "float", Exterior = "float", NightVisionGoggles = "float",
    DesaturationVal = "float", FogMod = "float", SearchMode = "vec4", ScreenInfo = "vec4",
    ParamInfo = "vec4", VarInfo = "vec4", DrunkFactor = "float", BlurFactor = "float",
    DIFFUSE = "sampler2D", -- a cena; sampler sem valor = unidade 0, onde o jogo põe a textura
}

-- o que o comportamento vanilla que importa usa (dessaturação do clima, busca,
-- visão noturna, bêbado, óculos, grão) e o canal do mod
local REQUIRED = { "DIFFUSE", "DesaturationVal", "SearchMode", "ScreenInfo", "ParamInfo", "VarInfo",
    "NightVisionGoggles", "NightValue", "DrunkFactor", "BlurFactor", "timer", "timerWrap",
    "bgl_RenderedTextureWidth", "bgl_RenderedTextureHeight" }

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function uniforms(src)
    local out = {}
    for t, n in src:gmatch("\nuniform%s+([%w_]+)%s+([%w_]+)%s*;") do out[n] = t end
    return out
end

local function norm(line)
    return (line:gsub("//.*$", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- linha de declaração da interface: igual por necessidade
local function isInterface(l)
    return l:find("^uniform ") or l:find("^in ") or l:find("^out ") or l:find("^#version")
end

return {
    shader_declares_game_interface = function()
        local src = assert(read(SHADER), "falta " .. SHADER)
        assert(src:match("^%s*#version 330\n"), "primeira linha não é #version 330 (a do vanilla)")
        local u = uniforms(src)
        for n, t in pairs(u) do
            assert(BOUND[n], "uniform " .. n .. " o jogo não manda")
            assert(BOUND[n] == t, "uniform " .. n .. " é " .. t .. ", o jogo manda " .. BOUND[n])
        end
        for _, n in ipairs(REQUIRED) do assert(u[n], "falta o uniform " .. n) end
        assert(src:find("\nin vec2 vUV;", 1, true), "falta in vec2 vUV (saída do screen.vert)")
        assert(src:find("gl_FragColor", 1, true) and src:find("void main()", 1, true))
        assert(not src:find("#include", 1, true), "depende de arquivo do jogo")
    end,

    shader_marker_matches_lua = function()
        local src = assert(read(SHADER))
        local m = src:match("const float NOM_MARKER = ([%d%.]+);")
        assert(m and tonumber(m) == NOM_ScreenFxRules.MARKER, "marcador do shader ~= NOM_ScreenFxRules.MARKER")
    end,

    -- licença: nenhuma linha do screen.frag da The Indie Stone (pula sem o jogo)
    shader_has_no_vanilla_text = function()
        local van = read(VANILLA)
        if not van then return end
        local seen = {}
        for line in van:gmatch("[^\n]+") do
            local l = norm(line)
            if #l >= 16 and not isInterface(l) then seen[l] = true end
        end
        local bad = {}
        local n = 0
        for line in assert(read(SHADER)):gmatch("[^\n]+") do
            n = n + 1
            local l = norm(line)
            if seen[l] then bad[#bad + 1] = n .. ": " .. l end
        end
        assert(#bad == 0, "linhas iguais ao vanilla:\n  " .. table.concat(bad, "\n  "))
    end,

    -- compila com o validador do Khronos, se instalado (o vanilla passa nele)
    shader_compiles = function()
        if os.execute("command -v glslangValidator >/dev/null 2>&1") ~= 0 and
            os.execute("command -v glslangValidator >/dev/null 2>&1") ~= true then return end
        local ok = os.execute("glslangValidator -S frag " .. SHADER .. " >/tmp/nom_glsl.txt 2>&1")
        assert(ok == 0 or ok == true, "não compila: " .. (read("/tmp/nom_glsl.txt") or ""))
    end,

    shader_modinfo = function()
        local info = assert(read("mod2/42/mod.info"), "falta mod2/42/mod.info")
        assert(info:find("\nid=NevoaEOutroMundo_Shader\n", 1, true))
        assert(info:find("\nrequire=NevoaEOutroMundo\n", 1, true), "sem require do mod principal")
        assert(info:find("\nversionMin=42.20\n", 1, true))
        assert(info:find("^name=[^\n]*ShadowZ"), "o nome não avisa do ShadowZ")
        assert(io.open("mod2/common/.gitkeep", "r"), "falta mod2/common/")
        -- readModInfoAux casa por contains numa ordem fixa (bytecode 152–1325)
        local ORDER = { "name=", "poster=", "description=", "require=", "incompatible=", "loadModAfter=",
            "loadModBefore=", "id=", "author=", "modversion=", "icon=", "category=", "url=", "pack=",
            "type=", "tiledef=", "versionMax=", "versionMin=" }
        for line in info:gmatch("[^\n]+") do
            local own = assert(line:match("^(%w+=)"), "linha sem chave: " .. line)
            for _, key in ipairs(ORDER) do
                if line:find(key, 1, true) then
                    assert(key == own, "o jogo lê '" .. line .. "' como " .. key)
                    break
                end
            end
        end
    end,

    -- a flag que o NOM_FogVignette e o NOM_ScreenFx leem (shared carrega antes do client)
    shader_flag_file = function()
        NOM_ShaderMod = nil
        dofile("mod2/42/media/lua/shared/NOM_ShaderFlag.lua")
        assert(NOM_ShaderMod == true)
        NOM_ShaderMod = nil
    end,

    shader_mod_translations = function()
        for _, lang in ipairs({ "EN", "PTBR" }) do
            local s = assert(read("mod2/42/media/lua/shared/Translate/" .. lang .. "/Mod.json"), lang)
            assert(s:find('"name"', 1, true) and s:find('"description"', 1, true), lang)
            assert(s:find("ShadowZ", 1, true), lang .. ": não avisa do ShadowZ")
            local ok = os.execute("python3 -c 'import json,sys; json.load(open(sys.argv[1]))' mod2/42/media/lua/shared/Translate/"
                .. lang .. "/Mod.json")
            assert(ok == 0 or ok == true, lang .. ": JSON inválido")
        end
    end,
}
