-- client/NOM_FogClient.lua: no MP a flag de névoa vem do servidor.
local W = dofile("tests/fog_world.lua")
require "NOM_FogEventRules"
local FILE = "mod/42/media/lua/client/NOM_FogClient.lua"


-- sirenes tocadas de uma névoa: as 5 do coro de cada jogador (shared/NOM_SirenSpotsRules.lua)
local function played(G, kind)
    local n = 0
    for _, name in ipairs(NOM_SirenSpotsRules.SOUNDS[kind]) do n = n + G.played(name) end
    return n
end

local function playing(G, kind)
    local out = {}
    for _, name in ipairs(NOM_SirenSpotsRules.SOUNDS[kind]) do
        for _, s in ipairs(G.playing(name)) do out[#out + 1] = s end
    end
    return out
end

local function setup(opts)
    opts = opts or {}
    if opts.client == nil then opts.client = true end
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SemRosto", "NOM_Siren", "NOM_SirenFreeze", "NOM_TicaoFreeze", "NOM_LampFlickerFx",
        "NOM_FlickerRules" })
    dofile(FILE)
    function G.server(command, args) G.fire("OnServerCommand", "NevoaEOutroMundo", command, args) end
    return G
end

return {
    fog_client_inert_outside_mp = function()
        local G = setup({ client = false })
        assert(next(G.handlers) == nil, "solo/servidor registrou o cliente")
    end,
    fog_client_follows_server = function()
        local G = setup()
        G.server("fog", { on = true, period = 3 })
        assert(NOM_FogState.on == true and NOM_FogState.period == 3)
        G.fire("OnServerCommand", "OutroMod", "fog", { on = false })
        assert(NOM_FogState.on == true)
        G.server("fog", { on = false, period = 3 })
        assert(NOM_FogState.on == false)
    end,
    -- sirene do evento de névoa (comando do servidor): toca local, volume cheio, sem pacote
    fog_client_plays_siren = function()
        local G = setup()
        G.server("siren", {})
        assert(played(G, "white") == 0, "tocou sem jogador")
        G.player({ x = 0, y = 0 })
        G.server("siren", {})
        assert(played(G, "white") == 1 and playing(G, "white")[1].volume == 1)
        G.fire("OnServerCommand", "OutroMod", "siren", {})
        assert(played(G, "white") == 1)
    end,
    -- sprint 0033: a sirene congela os zumbis que este cliente simula (dono), virados pro
    -- jogador mais perto (sprint 0034), e o sirenStop solta e cala as sirenes
    fog_client_siren_freezes_owned_zombies = function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        local mine = G.zombie({ x = 10, y = 10, onlineID = 5 })
        local remote = G.zombie({ x = 20, y = 20, onlineID = 6, remote = true })
        G.server("siren", { red = false })
        G.tick(1)
        assert(NOM_SirenFreeze.active and mine.useless == true, "dono não congelou")
        assert(mine.faced.x == p.x and mine.faced.y == p.y, "não virou pro jogador")
        assert(not remote.useless, "cópia remota é do outro cliente")
        G.fire("OnServerCommand", "OutroMod", "sirenStop", {})
        assert(mine.useless == true, "comando de outro módulo soltou")
        G.server("sirenStop", {})
        assert(mine.useless == false and not NOM_SirenFreeze.active, "sirenStop não soltou")
        assert(#playing(G, "white") == 0, "sirenStop deixou a sirene tocando")
        G.seconds(NOM_SirenSpotsRules.DELAY_MAX_MS / 1000 + 0.1)
        assert(played(G, "white") == 1, "a sirene atrasada entrou depois do sirenStop")
    end,
    -- sprint 0034: 5 sirenes por jogador, nas posições, longe do jogador local
    fog_client_plays_five_positioned_sirens = function()
        local G = setup()
        G.player({ x = 500, y = 500 })
        G.server("siren", { red = true })
        G.seconds(NOM_SirenSpotsRules.DELAY_MAX_MS / 1000 + 0.1)
        assert(played(G, "red") == NOM_SirenSpotsRules.COUNT and played(G, "white") == 0)
        for _, s in ipairs(playing(G, "red")) do assert(s.emitter, "sirene fora de emitter do mundo") end
    end,
    fog_client_fog_on_releases_freeze = function()
        local G = setup()
        local mine = G.zombie({ x = 10, y = 10, onlineID = 5 })
        G.server("siren", { red = true })
        G.tick(1)
        assert(mine.useless == true)
        G.server("fog", { on = false, period = 1 })
        assert(mine.useless == true, "fog off não devia soltar")
        G.server("fog", { on = true, period = 2 })
        assert(mine.useless == false and not NOM_SirenFreeze.active, "a névoa não soltou")
    end,
    -- sirene sem argumentos (servidor antigo): congela e tem a mesma segurança de fim
    fog_client_siren_without_args_and_safety = function()
        local G = setup()
        local mine = G.zombie({ x = 10, y = 10, onlineID = 5 })
        G.server("siren", nil)
        G.tick(1)
        assert(mine.useless == true)
        G.now = G.now + NOM_FogEventRules.GRACE_MS + NOM_SirenFreeze.SAFETY_MS + 1000
        G.tick(1)
        assert(mine.useless == false, "sem sirenStop nem fog, ficou congelado")
    end,
    -- sprint 0034: a sirene sobe a névoa de quem vê (com a cor dela); a névoa aberta e o
    -- cancelamento descem a subida. A névoa de jogo (on) só vem no fog.
    fog_client_siren_raises_fog = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.server("siren", { red = true })
        assert(NOM_FogState.rising == true and NOM_FogState.risingRed == true, "a sirene não subiu a névoa")
        assert(NOM_FogState.on == false, "a sirene abriu a névoa de jogo")
        G.server("fog", { on = true, period = 2, red = true })
        assert(NOM_FogState.rising == false and NOM_FogState.on == true and NOM_FogState.visibleRed() == true)
        G.server("siren", { red = false })
        assert(NOM_FogState.rising == true and NOM_FogState.risingRed == false)
        G.server("sirenStop", {})
        assert(NOM_FogState.rising == false, "sirenStop não desceu a subida")
        G.server("siren", nil)
        assert(NOM_FogState.rising == true and NOM_FogState.risingRed == false, "sirene sem argumentos")
    end,
    -- quem entra na fuga recebe fog (off) e depois siren (server/NOM_Fog.lua, fogState): sobe
    fog_client_join_during_grace_rises = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.server("fog", { on = false, period = 1, red = false })
        G.server("siren", { red = true })
        assert(NOM_FogState.rising == true and NOM_FogState.risingRed == true, "entrou na fuga sem a subida")
        G.server("fog", { on = false, period = 1, red = false })
        assert(NOM_FogState.rising == true, "fog off desceu a subida")
    end,
    -- sprint 0034, estática: o presságio liga o presságio de quem vê (com a cor), sem subir a
    -- névoa nem tocar a sirene; a sirene depois marca a hora dela
    fog_client_presage_sets_omen = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.server("presage", { red = true })
        assert(NOM_FogState.omenAt == G.now and NOM_FogState.omenRed == true, "o presságio não ligou")
        assert(NOM_FogState.rising == false and played(G, "red") == 0 and not NOM_SirenFreeze.active)
        G.fire("OnServerCommand", "OutroMod", "presage", { red = false })
        assert(NOM_FogState.omenRed == true, "comando de outro módulo")
        G.seconds(3)
        G.server("siren", { red = true })
        assert(NOM_FogState.sirenAt == G.now and NOM_FogState.omenAt ~= nil)
        G.server("sirenStop", {})
        assert(NOM_FogState.omenAt == nil and NOM_FogState.sirenAt == nil, "sirenStop não limpou")
        G.server("presage", nil) -- servidor antigo / sem argumentos: branca
        assert(NOM_FogState.omenAt ~= nil and NOM_FogState.omenRed == false)
    end,
    -- review final da 0034: o debug trocou a cor no meio do presságio ou da fuga (sirenColor):
    -- a cor muda sem recomeçar nada, sem tocar a sirene de novo e sem ligar o que não corre
    fog_client_siren_color_recolors = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.server("sirenColor", { red = true })
        assert(NOM_FogState.rising == false and NOM_FogState.omenAt == nil, "a cor ligou alguma coisa")
        G.server("presage", { red = false })
        local omenAt = NOM_FogState.omenAt
        G.tick(5)
        G.server("sirenColor", { red = true })
        assert(NOM_FogState.omenRed == true and NOM_FogState.omenAt == omenAt, "o presságio não trocou de cor")
        G.seconds(3)
        G.server("siren", { red = true })
        local sirenAt = NOM_FogState.sirenAt
        G.tick(5)
        G.server("sirenColor", { red = false })
        assert(NOM_FogState.rising == true and NOM_FogState.risingRed == false, "a subida não trocou de cor")
        assert(NOM_FogState.sirenAt == sirenAt, "a subida recomeçou")
        assert(played(G, "red") == 1 and played(G, "white") == 0, "tocou a sirene de novo")
    end,
    -- EXTRA da 0034: se o fog (on) ou o sirenStop se perder, a subida e o presságio não ficam
    -- pra sempre: depois de PRESAGE_MS + GRACE_MS + 15 s sem confirmação, desligam sozinhos
    fog_client_rising_safety_timeout = function()
        local G = setup()
        local R = NOM_FogEventRules
        local limit = R.PRESAGE_MS + R.GRACE_MS + NOM_SirenFreeze.SAFETY_MS
        G.player({ x = 0, y = 0 })
        G.server("presage", { red = true })
        G.seconds(3)
        G.server("siren", { red = true })
        G.seconds((limit - 1000) / 1000)
        assert(NOM_FogState.rising == true, "desligou antes do prazo")
        G.seconds(1.1)
        assert(NOM_FogState.rising == false and NOM_FogState.omenAt == nil, "a subida ficou sem confirmação")
        -- presságio sozinho (a sirene se perdeu também)
        G.server("presage", { red = false })
        G.seconds(limit / 1000 + 0.1)
        assert(NOM_FogState.omenAt == nil, "o presságio ficou sem confirmação")
        -- confirmado (fog on): o prazo não derruba a névoa aberta nem uma subida nova depois
        G.server("siren", { red = false })
        G.seconds(10)
        G.server("fog", { on = true, period = 1 })
        G.seconds(limit / 1000 + 1)
        assert(NOM_FogState.on == true and NOM_FogState.visible() == true)
        G.server("fog", { on = false, period = 1 })
        G.server("siren", { red = false })
        G.seconds(limit / 1000 - 5)
        assert(NOM_FogState.rising == true, "prazo velho derrubou a subida nova")
    end,
    fog_client_asks_state_on_join = function()
        local G = setup()
        local p = {}
        G.fire("OnCreatePlayer", 0, p)
        assert(#G.sentClient == 1 and G.sentClient[1].player == p)
        assert(G.sentClient[1].module == "NevoaEOutroMundo" and G.sentClient[1].command == "fogState")
    end,
    -- o cliente que vê avisa o servidor pelo ID de rede, com o destino
    fog_client_reports_by_online_id = function()
        local G = setup()
        G.server("fog", { on = true, period = 1 })
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 42, remote = true })
        G.zombie({ x = 100, y = 112, id = W.semRostoID(1, true), onlineID = -1 }) -- sem ID de rede
        G.players[1].face = 0.6
        G.tick(NOM_SemRosto.SCAN_TICKS)
        local seen = G.commands(G.sentClient, "semRostoSeen")
        assert(#seen == 1, "avisos: " .. #seen)
        assert(seen[1].module == "NevoaEOutroMundo" and seen[1].args.id == 42)
        assert(type(seen[1].args.x) == "number" and seen[1].args.z == 0)
        -- a cópia remota de quem viu vai junto pro destino (ADR-007): sem deslize
        assert(G.zombies[1].x == seen[1].args.x + 0.5, "cópia remota de quem viu não foi pro destino")
    end,
    -- critério (MP): só o dono move; a cópia remota recebe a posição do dono
    fog_client_only_owner_moves = function()
        local G = setup()
        local mine = G.zombie({ x = 112, y = 100, id = 1, onlineID = 5 })
        local remote = G.zombie({ x = 50, y = 50, id = 2, onlineID = 6, remote = true })
        G.server("semRostoMove", { id = 5, x = 95, y = 100, z = 0 })
        G.server("semRostoMove", { id = 6, x = 40, y = 50, z = 0 })
        G.server("semRostoMove", { id = -1, x = 1, y = 1, z = 0 })
        assert(mine.teleports == 1 and mine.x == 95.5 and mine.y == 100.5)
        assert(remote.teleports == nil, "cópia remota teleportou (o pacote do dono a puxa de volta)")
    end,
    -- quem viu não é o dono: a cópia dele (remota) vai direto pro destino; o dono
    -- (outro cliente) move quando o servidor manda, e os pacotes dele convergem ali
    fog_client_reporter_not_owner = function()
        local G = setup()
        G.server("fog", { on = true, period = 1 })
        G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 42, remote = true })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        local seen = G.commands(G.sentClient, "semRostoSeen")
        assert(#seen == 1)
        local a = seen[1].args
        assert(z.x == a.x + 0.5 and z.y == a.y + 0.5, "a cópia de quem viu ficou pra deslizar")
        assert(not z:getCurrentSquare():isCanSee(0), "continua à vista de quem viu")
        -- o eco do servidor não move de novo a cópia remota
        G.server("semRostoMove", { id = 42, x = a.x, y = a.y, z = a.z })
        assert(z.teleports == 1)
    end,
    -- o dono confere a vista dos próprios jogadores antes de mover (o servidor não sabe)
    fog_client_owner_skips_visible_destination = function()
        local G = setup()
        G.player({ x = 90, y = 100, face = 0 }) -- olhando pro destino
        local z = G.zombie({ x = 130, y = 100, id = 1, onlineID = 5 })
        G.server("semRostoMove", { id = 5, x = 95, y = 100, z = 0 })
        assert(z.teleports == nil, "dono moveu pra frente do próprio jogador")
        G.server("semRostoMove", { id = 5, x = 80, y = 100, z = 0 }) -- atrás dele
        assert(z.teleports == 1 and z.x == 80.5)
    end,
    -- névoa vermelha: a sirene própria, uma vez por comando; o red chega no FogState
    fog_client_plays_red_siren_once = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        G.server("siren", { red = true })
        assert(played(G, "red") == 1 and played(G, "white") == 0)
        assert(playing(G, "red")[1].volume == 1)
        G.server("fog", { on = true, period = 4, red = true })
        assert(NOM_FogState.on and NOM_FogState.red == true and played(G, "red") == 1)
        G.server("fog", { on = false, period = 4, red = true })
        assert(NOM_FogState.red == false, "vermelho sem névoa")
    end,

    -- sprint 0017: o destino que o servidor espalha (semRostoMove, de qualquer cliente)
    -- fica reservado aqui também: dois clientes vendo a mesma horda não a juntam
    fog_client_move_reserves_tile = function()
        local function scanOnce(move)
            local G = setup()
            G.server("fog", { on = true, period = 1 })
            G.player({ x = 100, y = 100, face = 0 })
            G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 42, remote = true })
            if move then G.server("semRostoMove", move) end
            G.tick(NOM_SemRosto.SCAN_TICKS)
            return G.commands(G.sentClient, "semRostoSeen")[1].args
        end
        local free = scanOnce()
        local got = scanOnce({ id = 77, x = free.x, y = free.y, z = 0 }) -- outro zumbi, de outro cliente
        assert(got.x ~= free.x or got.y ~= free.y, "escolheu o tile que o servidor acabou de usar")
    end,

    -- sprint 0045: o poste que o servidor sorteou pisca aqui pela cor
    fog_client_lamp_flicker = function()
        local G = setup()
        local lamp = G.lamp({ x = 5, y = 7, hydro = true })
        G.server("lampFlicker", { x = 5, y = 7, z = 0, segs = { 100, 50, 100 } })
        G.tick(1)
        assert(lamp.r == 0, "o poste não apagou")
        G.tick(20)
        assert(lamp.r == 1, "a cor não voltou")
    end,
    -- sprint 0045: a lanterna deste jogador toca o padrão que veio do servidor
    fog_client_torch_flicker_pattern = function()
        local G = setup()
        local p = G.player({ x = 0, y = 0, light = true })
        G.server("torchFlicker", { segs = { 50, 50, 50 } })
        assert(p.item.on == false, "não apagou")
        G.tick(4)
        assert(p.item.on == true, "não acendeu no meio")
        G.tick(4)
        assert(p.item.on == false, "não apagou de novo")
        G.tick(4)
        assert(p.item.on == true, "não voltou no fim")
    end,
}
