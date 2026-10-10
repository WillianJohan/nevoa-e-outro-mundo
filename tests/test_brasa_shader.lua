-- Shader NOM_Brasa (sprint 0067): mesma interface do item-model que NOM_Dissolve.
local DIR = "mod/42/media/shaders/"

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

local gl21 = dofile("tests/gl21.lua")

local function hasValidator()
    local r = os.execute("command -v glslangValidator >/dev/null 2>&1")
    return r == 0 or r == true
end

local function compile(src, stage, tag)
    local path = "/tmp/nom_brasa_" .. tag .. "." .. stage
    local f = assert(io.open(path, "w"))
    f:write(src)
    f:close()
    local ok = os.execute("glslangValidator -S " .. stage .. " " .. path .. " >/tmp/nom_brasa_glsl.txt 2>&1")
    assert(ok == 0 or ok == true, tag .. " não compila:\n" .. (read("/tmp/nom_brasa_glsl.txt") or ""))
end

return {
    brasa_shader_files_exist = function()
        assert(read(DIR .. "NOM_Brasa.vert"))
        assert(read(DIR .. "NOM_Brasa_static.vert"))
        assert(read(DIR .. "NOM_Brasa.frag"))
    end,

    brasa_shader_reads_alpha = function()
        local frag = assert(read(DIR .. "NOM_Brasa.frag"))
        assert(uniforms(frag).Alpha == "float")
        assert(frag:find("discard", 1, true))
        assert(frag:find("0.92", 1, true), "faixa Alpha alinhada às regras")
        local vert = assert(read(DIR .. "NOM_Brasa.vert"))
        assert(uniforms(vert).Alpha == "float", "vert usa Alpha na tremida")
        assert(vert:find("0.006", 1, true), "deslocamento ≤ 0,6%")
    end,

    brasa_shader_compiles = function()
        if not hasValidator() then return end
        for _, file in ipairs({ "NOM_Brasa.vert", "NOM_Brasa_static.vert" }) do
            local src = read(DIR .. file)
            compile(src, "vert", file .. "_330")
            compile(gl21(src, true), "vert", file .. "_120")
        end
        local frag = read(DIR .. "NOM_Brasa.frag")
        compile(frag, "frag", "frag_330")
        compile(gl21(frag, false), "frag", "frag_120")
    end,
}
