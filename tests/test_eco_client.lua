-- client/NOM_EcoClient.lua: no MP, o servidor tira o Eco do mundo mas não avisa
-- o cliente (removeFromWorld não manda ZombieDeleteOnClient). O cliente apaga o
-- fantasma local pelo onlineID. No cliente, removeFromWorld chama
-- GameClient.removeZombieFromCache e tira da lista da célula (bytecode).
local FILE = "mod/42/media/lua/client/NOM_EcoClient.lua"

local function setup(client)
    local zombies = {}
    local list = {
        size = function() return #zombies end,
        get = function(_, i) return zombies[i + 1] end,
    }
    local function zombie(id)
        local z = { id = id }
        function z:getOnlineID() return self.id end
        function z:removeFromWorld()
            for i, v in ipairs(zombies) do if v == self then table.remove(zombies, i) end end
            self.removed = true
        end
        function z:removeFromSquare() self.offSquare = true end
        zombies[#zombies + 1] = z
        return z
    end
    local handlers = {}
    isClient = function() return client end
    getDebug = function() return false end
    getCell = function() return { getZombieList = function() return list end } end
    Events = { OnServerCommand = { Add = function(f) handlers[#handlers + 1] = f end } }
    dofile(FILE)
    return {
        zombie = zombie,
        send = function(module, command, args) for _, h in ipairs(handlers) do h(module, command, args) end end,
        handlers = handlers,
    }
end

return {
    client_removes_ghosts_by_online_id = function()
        local C = setup(true)
        local a, b, c = C.zombie(4), C.zombie(7), C.zombie(9)
        C.send("NevoaEOutroMundo", "ecoGone", { ids = { 4, 9 } })
        assert(a.removed and a.offSquare and c.removed, "fantasma ficou")
        assert(not b.removed, "removeu zumbi que não era Eco")
    end,
    client_ignores_other_commands = function()
        local C = setup(true)
        local a = C.zombie(4)
        C.send("OutroMod", "ecoGone", { ids = { 4 } })
        C.send("NevoaEOutroMundo", "outra", { ids = { 4 } })
        assert(not a.removed)
    end,
    -- solo e servidor não registram nada: lá o zumbi já saiu de verdade
    client_file_inert_outside_mp_client = function()
        local C = setup(false)
        assert(#C.handlers == 0)
    end,
    -- -1 = zumbi ainda sem ID de rede: nunca casa com o comando
    client_skips_unassigned_online_id = function()
        local C = setup(true)
        local a = C.zombie(-1)
        C.send("NevoaEOutroMundo", "ecoGone", { ids = { -1, 4 } })
        assert(not a.removed, "removeu zumbi sem ID de rede")
    end,
    -- o substituto do Sem-rosto travado (fallback da ADR-007) usa a mesma limpeza
    client_removes_replaced_semrosto = function()
        local C = setup(true)
        local a, b = C.zombie(4), C.zombie(7)
        C.send("NevoaEOutroMundo", "semRostoGone", { ids = { 7 } })
        assert(b.removed and not a.removed)
    end,
}
