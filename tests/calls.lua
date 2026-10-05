-- Conta chamadas de método em objetos falsos: no jogo, cada uma é uma ida ao Java.
-- skip: métodos que o próprio jogo falso chama (ex.: o update do zumbi), fora da conta.
return function(objs, skip)
    local c = { n = 0 }
    for _, o in ipairs(objs) do
        for k, v in pairs(o) do
            if type(v) == "function" and not (skip and skip[k]) then
                o[k] = function(...) c.n = c.n + 1; return v(...) end
            end
        end
    end
    return c
end
