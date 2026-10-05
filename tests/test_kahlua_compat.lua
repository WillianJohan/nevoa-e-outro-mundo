-- O jogo roda Lua no Kahlua, não no luajit dos testes. O que o luajit tem e o
-- Kahlua não tem passa nos testes e quebra no jogo: varre o código do mod.
local FORBIDDEN = {
    -- visto no console.txt: "Object tried to call nil in prune" (next é nil no Kahlua)
    { "[^%w_%.:]next%s*%(", "next() não existe no Kahlua; use um laço pairs" },
    { "^next%s*%(", "next() não existe no Kahlua; use um laço pairs" },
    { "table%.unpack", "table.unpack não existe no Lua 5.1; use unpack" },
    { "[^%w_]goto%s", "goto não existe no Lua 5.1" },
    { "[^/%-]//[^/]", "// (divisão inteira) não existe no Lua 5.1" },
}

local function luaFiles()
    local out = {}
    local p = io.popen("find mod mod2 -name '*.lua'")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

return {
    kahlua_no_missing_builtins = function()
        local bad = {}
        for _, path in ipairs(luaFiles()) do
            local n = 0
            for line in io.lines(path) do
                n = n + 1
                local code = line:gsub("%-%-.*$", "")
                for _, rule in ipairs(FORBIDDEN) do
                    if code:find(rule[1]) then
                        bad[#bad + 1] = path .. ":" .. n .. ": " .. rule[2]
                    end
                end
            end
        end
        assert(#bad == 0, "\n  " .. table.concat(bad, "\n  "))
    end,
}
