-- Regras puras dos comandos de debug (client/NOM_Debug.lua, server/NOM_DebugServer.lua):
-- sem API do jogo, testável com ./run-tests.sh. O servidor não confia no que o
-- cliente manda: tudo passa por parse.
NOM_DebugRules = {}

NOM_DebugRules.KINDS = { estalador = true, corredor = true, semrosto = true }

-- args = { op = ..., ... } vindo do cliente. Devolve a tabela limpa ou nil.
-- value/kind ausentes (nil) devolvem o controle ao jogo.
function NOM_DebugRules.parse(args)
    if type(args) ~= "table" then return nil end
    local op, v = args.op, args.value
    if op == "night" then
        if v ~= nil and type(v) ~= "boolean" then return nil end
        return { op = op, value = v }
    elseif op == "fog" then
        if v ~= nil and type(v) ~= "number" then return nil end
        if v then v = math.max(0, math.min(1, v)) end
        return { op = op, value = v }
    elseif op == "variant" then
        if type(args.id) ~= "number" or args.id == 0 then return nil end
        if args.kind ~= nil and not NOM_DebugRules.KINDS[args.kind] then return nil end
        return { op = op, id = args.id, kind = args.kind }
    elseif op == "spawnEco" or op == "status" then
        return { op = op }
    end
    return nil
end

-- "prefixo a=1 b=2", chaves em ordem alfabética: linha de console estável.
function NOM_DebugRules.line(prefix, t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = { prefix }
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(t[k]) end
    return table.concat(parts, " ")
end

return NOM_DebugRules
