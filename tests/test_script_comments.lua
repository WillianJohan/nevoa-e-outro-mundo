-- O leitor de script do jogo conta comentário aninhado: um "/*" dentro de /* ... */
-- abre outro nível e o resto do arquivo vira comentário (visto no jogo: "Couldn't find
-- item Base.NOM_EstaladorVendaFx" porque "clothingItems/*Fx.xml" num comentário apagou
-- todos os itens da sprint 0018). Varre media/scripts atrás de "/*" dentro de comentário.
local function files()
    local out = {}
    local p = io.popen("find mod mod2 -path '*media/scripts/*' -name '*.txt' 2>/dev/null")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

return {
    scripts_no_nested_comment_open = function()
        local bad = {}
        for _, path in ipairs(files()) do
            local h = io.open(path); local s = h:read("*a"); h:close()
            local depth, i, line = 0, 1, 1
            while i <= #s do
                local two = s:sub(i, i + 1)
                if s:sub(i, i) == "\n" then line = line + 1 end
                if two == "/*" then
                    if depth > 0 then bad[#bad + 1] = path .. ":" .. line end
                    depth = depth + 1; i = i + 2
                elseif two == "*/" and depth > 0 then
                    depth = depth - 1; i = i + 2
                else
                    i = i + 1
                end
            end
            if depth ~= 0 then bad[#bad + 1] = path .. ": comentário sem fechar" end
        end
        assert(#bad == 0, "\n  " .. table.concat(bad, "\n  "))
    end,
}
