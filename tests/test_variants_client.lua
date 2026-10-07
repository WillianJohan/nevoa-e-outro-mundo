-- client/NOM_VariantsClient.lua: no MP o dono avisa o servidor, que decide o grito.
-- sendClientCommand(module, command, args) sem jogador: pz-api-notes §7; com o jogador
-- na frente (sendClientCommand(player, ...), client/NOM_Debug.lua) o servidor recebe
-- esse jogador, o certo na tela dividida.
-- OnServerCommand(module, command, args) (client/ServerCommands.lua:218);
-- getPlayerByOnlineID(id) (client/ServerCommands.lua:10).
local FILE = "mod/42/media/lua/client/NOM_VariantsClient.lua"

local function setup(client)
    local C = { sent = {}, reporter = nil, zombies = {}, screams = {}, handlers = {} }
    isClient = function() return client end
    isServer = function() return false end
    sendClientCommand = function(a, b, c, d)
        if d == nil then
            C.sent[#C.sent + 1] = { module = a, command = b, args = c }
        else
            C.sent[#C.sent + 1] = { player = a, module = b, command = c, args = d }
        end
    end
    NOM_VariantAI = { install = function(fn) C.reporter = fn end }
    package.loaded["NOM_VariantAI"] = NOM_VariantAI
    NOM_Carpideira = { screamed = {}, install = function(fn) C.carpReport = fn end,
        scream = function(z, p) C.screams[#C.screams + 1] = { z = z, p = p } end }
    package.loaded["NOM_Carpideira"] = NOM_Carpideira
    C.waves = {}
    NOM_Wander = { wave = function(seed) C.waves[#C.waves + 1] = seed end }
    package.loaded["NOM_Wander"] = NOM_Wander
    C.players = {}
    getPlayerByOnlineID = function(id) return C.players[id] end
    getCell = function()
        return { getZombieList = function()
            return { size = function() return #C.zombies end, get = function(_, i) return C.zombies[i + 1] end }
        end }
    end
    Events = { OnServerCommand = { Add = function(f) C.handlers[#C.handlers + 1] = f end } }
    function C.server(command, args)
        for _, h in ipairs(C.handlers) do h("NevoaEOutroMundo", command, args) end
    end
    function C.zombie(pid, onlineID)
        local z = { pid = pid, onlineID = onlineID }
        function z:getPersistentOutfitID() return self.pid end
        function z:getOnlineID() return self.onlineID end
        C.zombies[#C.zombies + 1] = z
        return z
    end
    dofile(FILE)
    return C
end

return {
    -- perambular (sprint 0036): o servidor manda a semente, o cliente aplica nos zumbis dele
    variants_client_applies_wander_wave = function()
        local C = setup(true)
        C.server("wander", { seed = 77 })
        C.server("wander", { seed = "x" })
        assert(#C.waves == 1 and C.waves[1] == 77, "ondas: " .. #C.waves)
    end,
    variants_client_inert_outside_mp = function()
        local C = setup(false)
        assert(C.reporter == nil, "solo/servidor instalou o cliente")
    end,
    variants_client_reports_by_online_id = function()
        local C = setup(true)
        C.reporter({ getOnlineID = function() return 42 end })
        assert(#C.sent == 1 and C.sent[1].module == "NevoaEOutroMundo" and C.sent[1].command == "corredorSaw")
        assert(C.sent[1].args.id == 42)
    end,
    -- -1 = zumbi sem ID de rede: o servidor não acharia, não manda
    variants_client_skips_unassigned_id = function()
        local C = setup(true)
        C.reporter({ getOnlineID = function() return -1 end })
        assert(#C.sent == 0)
    end,
    -- Carpideira (sprint 0011): o jogador local que a acordou vai junto (tela dividida)
    variants_client_reports_carpideira = function()
        local C = setup(true)
        local p = {}
        C.carpReport({ getOnlineID = function() return 42 end }, p, "light")
        assert(#C.sent == 1 and C.sent[1].player == p and C.sent[1].command == "carpideiraWoke")
        assert(C.sent[1].args.id == 42 and C.sent[1].args.why == "light")
        C.carpReport({ getOnlineID = function() return -1 end }, p, "near")
        assert(#C.sent == 1, "mandou zumbi sem ID de rede")
    end,
    -- o servidor decidiu: marca o ID e aplica o grito no zumbi certo (o onlineID),
    -- com quem a acordou; outro zumbi com o mesmo ID fica furioso pela marca
    variants_client_scream_applies_to_the_zombie = function()
        local C = setup(true)
        local p = { name = "quem acordou" }
        C.players[9] = p
        C.zombie(7, 3)
        local z = C.zombie(7, 4)
        C.zombie(8, 5)
        C.server("carpideiraScream", { pid = 7, id = 4, pl = 9 })
        assert(NOM_Carpideira.screamed[7] == true and not NOM_Carpideira.screamed[8])
        assert(#C.screams == 1 and C.screams[1].z == z and C.screams[1].p == p)
        -- quem acordou não está carregado aqui: grita do mesmo jeito, sem alvo
        C.server("carpideiraScream", { pid = 8, id = 5, pl = 99 })
        assert(#C.screams == 2 and C.screams[2].p == nil)
        C.server("carpideiraScream", { pid = "x" })
        assert(#C.screams == 2)
    end,
    -- entrou no meio da névoa: recebe quem já gritou
    variants_client_takes_carpideira_list = function()
        local C = setup(true)
        C.server("carpideiraList", { pids = { 11, 12 } })
        assert(NOM_Carpideira.screamed[11] and NOM_Carpideira.screamed[12])
    end,

    -- sprint 0017: o pid do servidor vem sem o bit do chapéu; a cópia daqui com o bit grita
    variants_client_scream_with_fallen_hat = function()
        local C = setup(true)
        local z = C.zombie(7 + 32768, 4)
        C.server("carpideiraScream", { pid = 7, id = 4 })
        assert(#C.screams == 1 and C.screams[1].z == z, "não achou a Carpideira de chapéu caído")
    end,
}
