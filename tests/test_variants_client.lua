-- client/NOM_VariantsClient.lua: no MP o dono avisa o servidor, que decide o grito.
-- sendClientCommand(module, command, args) sem jogador: pz-api-notes §7.
local FILE = "mod/42/media/lua/client/NOM_VariantsClient.lua"

local function setup(client)
    local C = { sent = {}, reporter = nil }
    isClient = function() return client end
    isServer = function() return false end
    sendClientCommand = function(module, command, args)
        C.sent[#C.sent + 1] = { module = module, command = command, args = args }
    end
    NOM_VariantAI = { install = function(fn) C.reporter = fn end }
    package.loaded["NOM_VariantAI"] = NOM_VariantAI
    dofile(FILE)
    return C
end

return {
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
}
