-- Shader de peça NOM_Dissolve (sprint 0018, ADR-016): media/shaders/NOM_Dissolve.vert
-- (peça com esqueleto), NOM_Dissolve_static.vert (peça presa a osso, m_Static) e
-- NOM_Dissolve.frag (os dois). Código original com a interface do item-model do jogo
-- (bytecode B42.21):
-- * uniforms: skinnedmodel.Shader.onProgramCompiled (MatrixPalette, transform, HueChange,
--   LightingAmount, Light0..4Colour/Direction, TintColour, Alpha, Texture), setScale →
--   FinalScale, setTargetDepth → targetDepth, setDepthBias → DepthBias,
--   VertexBufferObject.setModelViewProjection → ModelViewProjection, UVScale,
--   HighResDepthMultiplier (ItemModelRenderer, AnimatedModel). Uniform fora da lista não
--   recebe valor;
-- * atributos por índice do elemento (VertexBufferObject.BeginDraw): layout (location = N);
-- * GL 2.1 (Core.getUseOpenGL21): ShaderUnit.processShaderSyntax reescreve linha a linha
--   (trim): #version → 120, layout … in → attribute, out → varying (vert), in → varying
--   (frag), "out vec4 colour" some, "colour = X;" → gl_FragColor. O teste faz a mesma
--   reescrita e compila o resultado.
require "NOM_DissolveRules"

local DIR = "mod/42/media/shaders/"
local VANILLA = "/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid/media/shaders/"

local COMMON = { ModelViewProjection = "mat4", UVScale = "vec2", FinalScale = "float", targetDepth = "float",
    HighResDepthMultiplier = "float", DepthBias = "float" }
local VERT = {
    ["NOM_Dissolve.vert"] = { uniforms = { MatrixPalette = "mat4" },
        attribs = { "vec4 vertex", "vec4 normal", "vec4 boneWeights", "vec4 boneIndices", "vec2 uv" } },
    ["NOM_Dissolve_static.vert"] = { uniforms = { transform = "mat4" }, attribs = { "vec4 vertex", "vec4 normal", "vec2 uv" } },
}
local FRAG = { Texture = "sampler2D", Alpha = "float", TintColour = "vec3", AmbientColour = "vec3", HueChange = "float",
    LightingAmount = "float" }
for i = 0, 4 do
    FRAG["Light" .. i .. "Direction"] = "vec3"
    FRAG["Light" .. i .. "Colour"] = "vec3"
end
local FRAG_REQUIRED = { "Texture", "Alpha", "TintColour", "AmbientColour", "Light0Direction", "Light0Colour",
    "Light4Direction", "Light4Colour" }

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function uniforms(src)
    local out = {}
    for t, n in src:gmatch("\nuniform%s+([%w_]+)%s+([%w_]+)[^;\n]*;") do out[n] = t end
    return out
end

local function varyings(src, kw)
    local out = {}
    for t, n in src:gmatch("\n" .. kw .. "%s+([%w_]+)%s+([%w_]+)%s*;") do out[n] = t end
    return out
end

local function trim(l) return (l:gsub("^%s+", ""):gsub("%s+$", "")) end

local gl21 = dofile("tests/gl21.lua")

local function hasValidator()
    local r = os.execute("command -v glslangValidator >/dev/null 2>&1")
    return r == 0 or r == true
end

local function compile(src, stage, tag)
    local path = "/tmp/nom_dissolve_" .. tag .. "." .. stage
    local f = assert(io.open(path, "w"))
    f:write(src)
    f:close()
    local ok = os.execute("glslangValidator -S " .. stage .. " " .. path .. " >/tmp/nom_dissolve_glsl.txt 2>&1")
    assert(ok == 0 or ok == true, tag .. " não compila:\n" .. (read("/tmp/nom_dissolve_glsl.txt") or ""))
end

local function norm(line)
    return (line:gsub("//.*$", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function isInterface(l)
    return l:find("^uniform ") or l:find("^in ") or l:find("^out ") or l:find("^#version") or l:find("^layout")
        or l:find("^varying ") or l:find("^attribute ")
end

return {
    dissolve_shader_vert_interface = function()
        for file, want in pairs(VERT) do
            local src = assert(read(DIR .. file), "falta " .. file)
            assert(src:match("^%s*#version 330\n"), file .. ": primeira linha não é #version 330")
            for n, t in pairs(uniforms(src)) do
                local w = want.uniforms[n] or COMMON[n]
                assert(w, file .. ": uniform " .. n .. " o jogo não manda")
                assert(w == t, file .. ": uniform " .. n .. " é " .. t)
            end
            for n in pairs(want.uniforms) do assert(uniforms(src)[n], file .. ": falta " .. n) end
            assert(uniforms(src).ModelViewProjection, file .. ": falta ModelViewProjection")
            for i, a in ipairs(want.attribs) do
                local line = "\nlayout (location = " .. (i - 1) .. ") in " .. a .. ";"
                assert(src:find(line, 1, true), file .. ": falta" .. line)
            end
            assert(src:find("gl_Position", 1, true) and not src:find("#include", 1, true), file)
        end
        assert(uniforms(read(DIR .. "NOM_Dissolve.vert")).MatrixPalette and
            read(DIR .. "NOM_Dissolve.vert"):find("MatrixPalette%[60%]"), "a paleta do jogo tem 60 ossos")
    end,

    dissolve_shader_frag_interface = function()
        local src = assert(read(DIR .. "NOM_Dissolve.frag"), "falta NOM_Dissolve.frag")
        assert(src:match("^%s*#version 330\n"))
        local u = uniforms(src)
        for n, t in pairs(u) do
            assert(FRAG[n], "frag: uniform " .. n .. " o jogo não manda")
            assert(FRAG[n] == t, "frag: uniform " .. n .. " é " .. t)
        end
        for _, n in ipairs(FRAG_REQUIRED) do assert(u[n], "frag: falta " .. n) end
        assert(src:find("discard", 1, true) and src:find("gl_FragColor", 1, true) and not src:find("#include", 1, true))
        -- o que o vert entrega é o que o frag lê
        local ins = varyings(src, "in")
        for file in pairs(VERT) do
            local outs = varyings(read(DIR .. file), "out")
            for n, t in pairs(ins) do assert(outs[n] == t, file .. " não entrega " .. t .. " " .. n) end
        end
        -- a reescrita do GL 2.1 troca linha que começa com "in" ou "colour": nada disso fora da interface
        for line in src:gmatch("[^\n]+") do
            local l = trim(line)
            if l:find("^in") and not l:find("^in ") then error("linha começa com 'in' (o GL 2.1 vira varying): " .. l) end
            if l:find("^colour") then error("linha começa com 'colour' (o GL 2.1 vira gl_FragColor): " .. l) end
        end
    end,

    dissolve_shader_band_matches_lua = function()
        local m = read(DIR .. "NOM_Dissolve.frag"):match("const float NOM_BAND = ([%d%.]+);")
        assert(m and tonumber(m) == NOM_DissolveRules.BAND, "NOM_BAND ~= NOM_DissolveRules.BAND")
    end,

    -- licença: nenhuma linha do basicEffect da The Indie Stone (pula sem o jogo)
    dissolve_shader_has_no_vanilla_text = function()
        local seen = {}
        local any = false
        for _, f in ipairs({ "basicEffect.vert", "basicEffect_static.vert", "basicEffect.frag" }) do
            local van = read(VANILLA .. f)
            if van then
                any = true
                for line in van:gmatch("[^\n]+") do
                    local l = norm(line)
                    if #l >= 16 and not isInterface(l) then seen[l] = true end
                end
            end
        end
        if not any then return end
        local bad = {}
        for _, f in ipairs({ "NOM_Dissolve.vert", "NOM_Dissolve_static.vert", "NOM_Dissolve.frag" }) do
            local n = 0
            for line in assert(read(DIR .. f)):gmatch("[^\n]+") do
                n = n + 1
                if seen[norm(line)] then bad[#bad + 1] = f .. ":" .. n .. ": " .. norm(line) end
            end
        end
        assert(#bad == 0, "linhas iguais ao vanilla:\n  " .. table.concat(bad, "\n  "))
    end,

    -- compila em 330 e na reescrita do GL 2.1 (pula sem o glslangValidator)
    dissolve_shader_compiles = function()
        if not hasValidator() then return end
        for file in pairs(VERT) do
            local src = read(DIR .. file)
            compile(src, "vert", file .. "_330")
            compile(gl21(src, true), "vert", file .. "_120")
        end
        local frag = read(DIR .. "NOM_Dissolve.frag")
        compile(frag, "frag", "frag_330")
        compile(gl21(frag, false), "frag", "frag_120")
    end,

    -- o próprio teste: a reescrita imita o jogo (o vanilla passa por ela)
    dissolve_shader_gl21_rewrite_like_game = function()
        local v = gl21("#version 330\nlayout (location = 4) in vec2 uv;\nout vec2 nomUv;\n", true)
        assert(v:find("#version 120\nattribute vec2 uv;\nvarying vec2 nomUv;", 1, true), v)
        local f = gl21("#version 330\nin vec2 nomUv;\n    int k;\n", false)
        assert(f:find("varying vec2 nomUv;", 1, true) and f:find("varying t k;", 1, true), "a armadilha do 'in' sumiu: " .. f)
    end,
}
