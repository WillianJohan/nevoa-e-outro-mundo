-- Regras puras dos comandos de debug (client/NOM_Debug.lua, server/NOM_DebugServer.lua):
-- sem API do jogo, testável com ./run-tests.sh. O servidor não confia no que o
-- cliente manda: tudo passa por parse.
NOM_DebugRules = {}

NOM_DebugRules.KINDS = { estalador = true, corredor = true, semrosto = true, carpideira = true }
-- spawn do debug (sprint 0020): no máximo 50 por pedido, a até 10 tiles de quem pede
NOM_DebugRules.MAX_SPAWN = 50
NOM_DebugRules.SPAWN_REACH = 10
local MAX_OUTFIT = 64

-- Quantidade do spawn: inteiro entre 1 e MAX_SPAWN; não número (ou NaN) dá nil.
function NOM_DebugRules.clampSpawn(n)
    if type(n) ~= "number" or n ~= n then return nil end
    return math.max(1, math.min(NOM_DebugRules.MAX_SPAWN, math.floor(n)))
end

-- args = { op = ..., ... } vindo do cliente. Devolve a tabela limpa ou nil.
-- value/kind ausentes (nil) devolvem o controle ao jogo.
function NOM_DebugRules.parse(args)
    if type(args) ~= "table" then return nil end
    local op, v = args.op, args.value
    if op == "night" then
        if v ~= nil and type(v) ~= "boolean" then return nil end
        return { op = op, value = v }
    elseif op == "fog" then
        -- evento de névoa (NOM_FogEvent): true começa (skip pula a espera da
        -- sirene), false ou nil termina
        if v ~= nil and type(v) ~= "boolean" then return nil end
        if args.skip ~= nil and type(args.skip) ~= "boolean" then return nil end
        -- toggle (NOM.fog sem argumento, sprint 0020): o servidor vê se há névoa ou sirene
        if args.toggle ~= nil and type(args.toggle) ~= "boolean" then return nil end
        return { op = op, value = v == true, skip = args.skip == true, toggle = args.toggle == true }
    elseif op == "redFog" then
        -- névoa vermelha (NOM_FogEvent.setRed): true força, false/nil desfaz; toggle
        -- (NOM.redFog sem argumento, sprint 0020): o servidor vê a vermelha aberta ou na sirene
        if v ~= nil and type(v) ~= "boolean" then return nil end
        if args.toggle ~= nil and type(args.toggle) ~= "boolean" then return nil end
        return { op = op, value = v == true, toggle = args.toggle == true }
    elseif op == "variant" then
        if type(args.id) ~= "number" or args.id ~= args.id or args.id == 0 then return nil end
        if args.kind ~= nil and not NOM_DebugRules.KINDS[args.kind] then return nil end
        return { op = op, id = args.id, kind = args.kind }
    elseif op == "time" then
        -- hora do relógio do jogo (NOM.time): 0 até antes de 24
        local h = args.hour
        if type(h) ~= "number" or h ~= h or h < 0 or h >= 24 then return nil end
        return { op = op, hour = h }
    elseif op == "spawn" then
        -- zumbis no tile x, y, z (o cliente mira na frente do jogador; o servidor confere a distância)
        local n = NOM_DebugRules.clampSpawn(args.n)
        if not n then return nil end
        if args.outfit ~= nil and (type(args.outfit) ~= "string" or #args.outfit > MAX_OUTFIT) then return nil end
        for _, k in ipairs({ "x", "y", "z" }) do
            if type(args[k]) ~= "number" or args[k] ~= args[k] then return nil end
        end
        return { op = op, n = n, outfit = args.outfit, x = args.x, y = args.y, z = args.z }
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
