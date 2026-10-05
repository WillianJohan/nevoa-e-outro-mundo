-- Reescrita GL 2.1 do jogo, pros testes de shader (sprint 0018). O jogo, com
-- Core.getUseOpenGL21, passa cada linha (trim) do arquivo por
-- ShaderUnit.processShaderSyntax (bytecode 32–458, padrões do <clinit>). vert: true no .vert.
local function trim(l) return (l:gsub("^%s+", ""):gsub("%s+$", "")) end

local function gl21(src, vert)
    local out = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        local l = trim(line)
        if l:find("^#version") then
            l = "#version 120"
        elseif l:find("^out vec4 colour") then
            l = ""
        elseif vert and l:find("^layout") then
            local t, n = l:match("^layout%s*%(%s*location%s*=%s*[0-9]+%s*%)%s*in%s*([%w]+)%s*([%w]+)%s*;%s*$")
            if t then l = "attribute " .. t .. " " .. n .. ";" end
        elseif vert and l:find("^out") then
            local t, n = l:match("^out%s*(%S+)%s*(%S+)%s*;%s*$")
            if t then l = "varying " .. t .. " " .. n .. ";" end
        elseif not vert and l:find("^in") then
            local t, n = l:match("^in%s*(%S+)%s*(%S+)%s*;%s*$")
            if t then l = "varying " .. t .. " " .. n .. ";" end
        elseif not vert and l:find("^colour") then
            local x = l:match("^%s*colour%s*=%s*(.+);%s*$")
            if x then l = "gl_FragColor =  " .. x .. ";" end
        end
        out[#out + 1] = l
    end
    return table.concat(out, "\n")
end

return gl21
