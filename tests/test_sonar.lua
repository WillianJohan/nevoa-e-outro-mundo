-- Sonar do Estalador (sprint 0037): server/NOM_SonarServer.lua (quem decide) e
-- shared/NOM_Sonar.lua (quem toca, desenha e aplica) contra um jogo falso.
-- * EveryOneMinute; OnTick; ZombRand(n) (server/ClientCommands.lua:120); getTimestampMs()
--   (server/ISObjectClickHandler.lua:352); isGamePaused() (pz-api-notes, resumo).
-- * Jogadores do servidor: getOnlinePlayers() no dedicado, getSpecificPlayer(i) no solo
--   (NOM_Players, server/XpSystem/XpUpdate.lua:294-297).
-- * player:isSneaking() = campo sneaking (IsoGameCharacter.isSneaking 0–4). No dedicado ele
--   chega no pacote do jogador (NetworkPlayerVariables.getBooleanVariables 5–12 no cliente,
--   setBooleanVariables 2–8 no servidor, via NetworkPlayerAI.parse(PlayerPacket) 221–224).
-- * A posição do jogador remoto chega no pacote (Prediction.position, NetworkPlayerAI.parse).
-- * Zumbi: getPersistentOutfitID (o sorteio da variante, ADR-006), isLocal (dono, §24),
--   spotted(p, forçado) (IsoZombie, §13.2), setUseless/isUseless, getOnlineID (-1 no solo).
-- * Som no ponto: getWorld():getFreeEmitter(x, y, z):playSoundImpl(nome, false, nil),
--   local, sem pacote (pz-api-notes §22).
-- * getPlayerByOnlineID(id) no cliente (client/ServerCommands.lua:10).
-- * Interior: getCurrentSquare() (IsoMovingObject; server/NOM_Night.lua já usa no servidor),
--   sq:isOutside() = flag "exterior" do square (IsoGridSquare.isOutside 0–10) e
--   sq:getBuilding() = getRoom() e o prédio da sala, ou nil (IsoGridSquare.getBuilding 0–15).
--   No fake: o.building (o prédio) ou o.roof (coberto sem prédio) põe dentro.
-- Toda chamada de método em jogador, zumbi, lista e relógio conta em G.calls.
require "NOM_VariantRules"
require "NOM_Config"

local FILE = "mod/42/media/lua/server/NOM_SonarServer.lua"
local PERIOD = 3

local function idFor(want)
    -- sprint 0049: branca 100%; comum = ID 0 (sem outfit, ADR-006)
    if not want then return 0 end
    local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
    for seed = 1, 5000 do
        local id = 13 * 65536 + seed
        if NOM_VariantRules.variant(id, PERIOD, c) == want then return id end
    end
    error("nenhum ID")
end

local function setup(opts)
    opts = opts or {}
    local G = { players = {}, zombies = {}, sent = {}, sounds = {}, calls = 0, now = 1000, rand = opts.rand or 0 }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    local function def(o, name, fn)
        o[name] = function(...) G.calls = G.calls + 1; return fn(...) end
    end
    -- square do objeto o (building ou roof: dentro), lido na hora
    local function square(o)
        local sq = {}
        def(sq, "isOutside", function() return o.building == nil and not o.roof end)
        def(sq, "getBuilding", function() return o.building end)
        def(o, "getCurrentSquare", function() return sq end)
    end
    function G.player(o)
        local p = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, sneaking = o.sneaking == true, dead = false,
            onlineID = o.onlineID or (#G.players + 1), class = "IsoPlayer", building = o.building, roof = o.roof }
        square(p)
        def(p, "getX", function(self) return self.x end)
        def(p, "getY", function(self) return self.y end)
        def(p, "getZ", function(self) return self.z end)
        def(p, "isSneaking", function(self) return self.sneaking end)
        def(p, "isRunning", function() return false end)
        def(p, "isSprinting", function() return false end)
        def(p, "isDead", function(self) return self.dead end)
        def(p, "getOnlineID", function(self) return self.onlineID end)
        G.players[#G.players + 1] = p
        return p
    end
    function G.zombie(o)
        local z = { x = o.x + 0.5, y = o.y + 0.5, z = o.z or 0, id = o.id or 0, onlineID = o.onlineID or -1,
            remote = o.remote == true, dead = false, md = {}, outfit = o.outfit or "Generic01",
            building = o.building, roof = o.roof }
        square(z)
        if o.eco then z.md.NOM_eco = true end
        def(z, "getX", function(self) return self.x end)
        def(z, "getY", function(self) return self.y end)
        def(z, "getZ", function(self) return self.z end)
        def(z, "getPersistentOutfitID", function(self) return self.id end)
        def(z, "getOnlineID", function(self) return self.onlineID end)
        def(z, "isDead", function(self) return self.dead end)
        def(z, "getModData", function(self) return self.md end)
        def(z, "getOutfitName", function(self) return self.outfit end)
        def(z, "isLocal", function(self) return (not isClient() and not isServer()) or not self.remote end)
        def(z, "isUseless", function(self) return self.useless == true end)
        def(z, "setUseless", function(self, b) self.useless = b end)
        def(z, "setTarget", function(self, t) self.target = t end)
        def(z, "getTarget", function(self) return self.target end)
        -- spottedNew: useless volta com alvo nulo (191–208)
        def(z, "spotted", function(self, p, forced)
            if self.useless then self.target = nil return end
            self.target, self.forcedSpot = p, forced
        end)
        G.zombies[#G.zombies + 1] = z
        return z
    end
    isClient = function() return opts.client == true end
    instanceof = function(o, cls) return type(o) == "table" and o.class == cls end
    isServer = function() return opts.server == true end
    getDebug = function() return opts.debug == true end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    -- G.rolls: sorteios em ordem (um por chamada); acabou, G.rand
    ZombRand = function(n)
        if G.rolls and #G.rolls > 0 then return table.remove(G.rolls, 1) % n end
        return G.rand % n
    end
    getTimestampMs = function() G.calls = G.calls + 1; return G.now end
    isGamePaused = function() G.calls = G.calls + 1; return G.paused == true end
    getNumActivePlayers = function() G.calls = G.calls + 1; return opts.server and 0 or #G.players end
    getSpecificPlayer = function(i) G.calls = G.calls + 1; return G.players[i + 1] end
    getOnlinePlayers = function()
        G.calls = G.calls + 1
        local all = (opts.server or opts.client) and G.players or {}
        return { size = function() G.calls = G.calls + 1; return #all end,
            get = function(_, i) G.calls = G.calls + 1; return all[i + 1] end }
    end
    getPlayerByOnlineID = function(id)
        for _, p in ipairs(G.players) do if p.onlineID == id then return p end end
        return nil
    end
    getCell = function()
        return { getZombieList = function()
            return { size = function() G.calls = G.calls + 1; return #G.zombies end,
                get = function(_, i) G.calls = G.calls + 1; return G.zombies[i + 1] end }
        end }
    end
    getWorld = function()
        return { getFreeEmitter = function(_, x, y, z)
            return { playSoundImpl = function(_, name, flag, obj)
                assert(type(flag) == "boolean" and obj == nil, "playSoundImpl(nome, false, nil)")
                G.sounds[#G.sounds + 1] = { name = name, x = x, y = y, z = z }
                return #G.sounds
            end }
        end }
    end
    sendServerCommand = function(a, b, c, d)
        if d == nil then G.sent[#G.sent + 1] = { module = a, command = b, args = c }
        else G.sent[#G.sent + 1] = { player = a, module = b, command = c, args = d } end
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_World", "NOM_Players", "NOM_Sonar", "NOM_SonarServer", "NOM_FogState", "NOM_NightStats",
        "NOM_VariantAI", "NOM_Carpideira", "NOM_SirenFreeze" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    NOM_Fog = { period = function() return PERIOD end } -- server/NOM_Fog.lua: o período da névoa
    package.loaded.NOM_Fog = NOM_Fog
    require "NOM_World"
    NOM_World.setFog(opts.fog ~= false, opts.red)
    require "NOM_FogState"
    NOM_FogState.set(opts.fog ~= false, PERIOD)
    if not opts.client then dofile(FILE) end
    require "NOM_Sonar"
    G.rings = {}
    NOM_Sonar.onRing(function(x, y, z) G.rings[#G.rings + 1] = { x = x, y = y, z = z } end)
    function G.tick(n)
        for _ = 1, n or 1 do
            G.now = G.now + 16
            G.fire("OnTick")
        end
    end
    function G.minute() G.fire("EveryOneMinute") end
    -- anda ms reais em ticks de 16 ms
    function G.wait(ms) G.tick(math.ceil(ms / 16)) end
    -- anda até o próximo estalo (no máximo max ms); devolve os ms que levou ou nil
    function G.untilRing(max)
        local before = NOM_SonarServer.emitted
        for k = 1, math.ceil((max or 32000) / 16) do
            G.tick(1)
            if NOM_SonarServer.emitted > before then return k * 16 end
        end
        return nil
    end
    function G.commands(name)
        local out = {}
        for _, c in ipairs(G.sent) do if c.command == name then out[#out + 1] = c end end
        return out
    end
    return G
end

local EST = idFor("estalador")
local COMMON = idFor(false)

return {
    -- estalo com jogador perto: toca no ponto (solo) e o anel nasce
    sonar_click_emits_for_estalador = function()
        local G = setup()
        local e = G.zombie({ x = 100, y = 100, id = EST })
        G.zombie({ x = 101, y = 100, id = COMMON })
        G.player({ x = 105, y = 100 })
        assert(G.untilRing(), "não estalou")
        assert(#G.sounds == 1 and G.sounds[1].name == NOM_Sonar.CLICK_SOUND, "estalo: " .. #G.sounds)
        assert(G.sounds[1].x == e.x and G.sounds[1].y == e.y)
        assert(#G.rings == 1 and #NOM_SonarServer.rings == 1)
        assert(#G.sent == 0, "solo não manda comando")
    end,

    -- jogador longe, Eco, morto e fim da névoa: nada
    sonar_click_skips = function()
        local G2 = setup()
        G2.zombie({ x = 100, y = 100, id = EST })
        G2.player({ x = 100 + NOM_SonarRules.SEND_RANGE + 2, y = 100 })
        assert(not G2.untilRing(40000), "estalou sem ninguém perto")
        local G3 = setup()
        G3.zombie({ x = 100, y = 100, id = EST, eco = true })
        local dead = G3.zombie({ x = 100, y = 102, id = EST })
        dead.dead = true
        G3.player({ x = 105, y = 100 })
        assert(not G3.untilRing(40000), "Eco ou morto estalou")
        local G4 = setup({ fog = false })
        G4.zombie({ x = 100, y = 100, id = EST })
        G4.player({ x = 105, y = 100 })
        assert(not G4.untilRing(40000), "estalou sem névoa")
    end,

    -- ritmo (decisão do Johan, 2026-10-06): cada Estalador estala num intervalo aleatório de
    -- GAP_MIN_MS a GAP_MAX_MS reais, sorteado de novo a cada estalo. Não depende do minuto de
    -- jogo (tamanho do dia): o EveryOneMinute não estala nada.
    sonar_click_rhythm_real_time = function()
        local R = require "NOM_SonarRules"
        local G = setup() -- ZombRand 0: o intervalo mínimo
        G.zombie({ x = 100, y = 100, id = EST })
        G.player({ x = 105, y = 100 })
        for _ = 1, 30 do G.minute() end
        assert(NOM_SonarServer.emitted == 0, "o minuto de jogo estalou")
        local first = G.untilRing()
        assert(first and first >= R.GAP_MIN_MS and first <= R.GAP_MIN_MS + R.SCAN_MS + 300, "primeiro: " .. tostring(first))
        local second = G.untilRing()
        assert(second and math.abs(second - R.GAP_MIN_MS) <= 300, "segundo: " .. tostring(second))
        local G2 = setup({ rand = R.GAP_ROLL - 1 }) -- o máximo
        G2.zombie({ x = 100, y = 100, id = EST })
        G2.player({ x = 105, y = 100 })
        assert(not G2.untilRing(R.GAP_MAX_MS - 500), "estalou antes do intervalo")
        assert(G2.untilRing(R.SCAN_MS + 1000), "não estalou no fim do intervalo")
    end,

    -- cada Estalador sorteia o seu: dois no mesmo lugar não estalam juntos
    sonar_click_rhythm_per_estalador = function()
        local G = setup()
        G.rolls = { 0, 20000 } -- o primeiro sorteado: 5 s; o segundo: 25 s
        G.rand = 25000 -- daqui pra frente, 30 s
        local a = G.zombie({ x = 100, y = 100, id = EST })
        local b = G.zombie({ x = 100, y = 104, id = EST })
        G.player({ x = 105, y = 100 })
        assert(G.untilRing())
        assert(#G.sounds == 1 and G.sounds[1].y == a.y, "o primeiro não foi o de 5 s")
        local t = G.untilRing()
        assert(#G.sounds == 2 and G.sounds[2].y == b.y, "o segundo não foi o de 25 s")
        assert(t and t >= 19000 and t <= 21000, "o de 25 s veio em " .. tostring(t))
    end,

    -- pausa não conta: o intervalo espera o jogo voltar
    sonar_click_rhythm_pause = function()
        local R = require "NOM_SonarRules"
        local G = setup()
        G.zombie({ x = 100, y = 100, id = EST })
        G.player({ x = 105, y = 100 })
        G.untilRing()
        G.wait(2000)
        G.paused = true
        G.wait(20000)
        assert(NOM_SonarServer.emitted == 1, "estalou com o jogo pausado")
        G.paused = false
        local t = G.untilRing()
        -- a pausa é conferida na amostra (SAMPLE_MS) e a agenda também: ~2 amostras de folga
        assert(t and t >= R.GAP_MIN_MS - 2000 - 2 * R.SAMPLE_MS and t <= R.GAP_MIN_MS - 2000 + 2 * R.SAMPLE_MS,
            "depois da pausa: " .. tostring(t))
    end,

    -- a regra: em pé é achado quando o anel chega; agachado e parado, passa
    sonar_finds_standing_not_crouched_still = function()
        local G = setup()
        local e = G.zombie({ x = 100, y = 100, id = EST })
        local stand = G.player({ x = 105, y = 100 })
        assert(G.untilRing(), "não estalou")
        G.tick(10) -- 160 ms: o anel está em ~0,85 tile
        assert(e.target == nil, "achou antes do anel chegar")
        G.tick(120)
        assert(e.target == stand and e.forcedSpot == true, "em pé não foi achado")
        assert(NOM_VariantAI.found[e] ~= nil, "sem janela anti-recegueira")
        assert(#NOM_SonarServer.rings == 0, "o anel não acabou")
        local G2 = setup()
        local e2 = G2.zombie({ x = 100, y = 100, id = EST })
        G2.player({ x = 105, y = 100, sneaking = true })
        G2.tick(40) -- amostras de posição antes do estalo
        assert(G2.untilRing(), "não estalou")
        G2.tick(120)
        assert(e2.target == nil, "agachado e parado foi achado")
        assert(NOM_SonarServer.passed == 1)
    end,

    -- solo (review, item 10): a janela anti-recegueira do achado não vence com o jogo pausado
    -- (o NOM_VariantAI instalado, como o server/NOM_Variants.lua faz no solo)
    sonar_found_window_pauses_solo = function()
        local G = setup()
        NOM_VariantAI.install(function() end)
        G.rolls, G.rand = { 0 }, NOM_SonarRules.GAP_ROLL - 1 -- o segundo estalo só em 30 s
        local e = G.zombie({ x = 100, y = 100, id = EST })
        G.player({ x = 104, y = 100 })
        assert(G.untilRing())
        G.wait(NOM_SonarRules.DURATION_MS)
        assert(NOM_VariantAI.found[e] ~= nil, "não achou")
        G.paused = true
        G.wait(30000)
        G.paused = false
        G.tick(1)
        assert(NOM_VariantAI.found[e].left > 0, "a janela venceu com o jogo pausado")
        G.wait(NOM_SonarRules.FOUND_MS)
        assert(NOM_VariantAI.found[e].left <= 0, "a janela não venceu depois da pausa")
    end,

    -- agachado andando é achado; o "andando" vem da posição amostrada
    sonar_finds_crouched_moving = function()
        local G = setup()
        local e = G.zombie({ x = 100, y = 100, id = EST })
        local p = G.player({ x = 106, y = 100, sneaking = true })
        assert(G.untilRing(), "não estalou")
        for _ = 1, 120 do
            p.x = p.x - 0.02 -- ~1,2 tile/s, agachado andando na direção do anel
            G.tick(1)
        end
        assert(e.target == p, "agachado andando passou")
    end,

    -- objeto reaproveitado no meio do anel (review, item 6): o anel guarda o persistentOutfitID
    -- do Estalador e confere antes de aplicar; no dedicado o achado leva o ID e o dono confere
    sonar_reused_zombie_not_applied = function()
        for _, server in ipairs({ false, true }) do
            local G = setup({ server = server })
            local e = G.zombie({ x = 100, y = 100, id = EST, onlineID = 77 })
            G.player({ x = 106, y = 100, onlineID = 5 })
            assert(G.untilRing(), "não estalou")
            e.id = COMMON -- resetForReuse: outro zumbi no mesmo objeto
            G.wait(NOM_SonarRules.DURATION_MS + 100)
            assert(e.target == nil and NOM_SonarServer.found == 0, "aplicou no zumbi reaproveitado")
            assert(#G.commands("sonarFound") == 0, "mandou o achado do zumbi reaproveitado")
        end
        local G = setup({ server = true })
        G.zombie({ x = 100, y = 100, id = EST, onlineID = 77 })
        G.player({ x = 104, y = 100, onlineID = 5 })
        assert(G.untilRing())
        G.wait(NOM_SonarRules.DURATION_MS + 100)
        local f = G.commands("sonarFound")
        assert(#f == 1 and f[1].args.pid == EST, "o achado não leva o persistentOutfitID")
        local C = setup({ client = true })
        local mine = C.zombie({ x = 100, y = 100, id = COMMON, onlineID = 77 }) -- o onlineID 77 é outro agora
        C.player({ x = 104, y = 100, onlineID = 5 })
        NOM_Sonar.command("sonarFound", { id = 77, pl = 5, pid = EST })
        assert(mine.target == nil, "o dono aplicou num zumbi com outro persistentOutfitID")
        mine.id = EST
        NOM_Sonar.command("sonarFound", { id = 77, pl = 5, pid = EST })
        assert(mine.target ~= nil, "com o mesmo ID, o dono não aplicou")
    end,

    -- casa protege (decisão do Johan, 2026-10-06): em pé dentro de casa com o Estalador na rua
    -- (ou o contrário), o anel não acha; na mesma casa, acha; casas diferentes, não
    sonar_house_shelters = function()
        local HOUSE, OTHER = { name = "casa" }, { name = "vizinha" }
        local cases = {
            { p = HOUSE, z = nil, found = false, why = "jogador dentro, Estalador fora" },
            { p = nil, z = HOUSE, found = false, why = "jogador fora, Estalador dentro" },
            { p = HOUSE, z = HOUSE, found = true, why = "os dois na mesma casa" },
            { p = HOUSE, z = OTHER, found = false, why = "casas diferentes" },
            { p = nil, z = nil, found = true, why = "os dois na rua" },
        }
        for _, c in ipairs(cases) do
            local G = setup()
            local e = G.zombie({ x = 100, y = 100, id = EST, building = c.z })
            local p = G.player({ x = 104, y = 100, building = c.p })
            assert(G.untilRing(), "não estalou")
            G.wait(NOM_SonarRules.DURATION_MS + 100)
            assert((e.target == p) == c.found, c.why .. ": achou=" .. tostring(e.target == p))
            assert(NOM_SonarServer.sheltered == (c.found and 0 or 1), c.why .. ": contagem")
        end
    end,

    -- correndo na direção do anel, em qualquer fase do tick, ninguém pula a frente (a posição
    -- do tick anterior conta); e o mesmo anel acha cada jogador uma vez só
    sonar_runner_never_jumps_front = function()
        for k = 0, 9 do
            local G = setup()
            local e = G.zombie({ x = 100, y = 100, id = EST })
            local p = G.player({ x = 106, y = 100 })
            p.x = p.x + k * 0.013
            assert(G.untilRing(), "não estalou")
            for _ = 1, 100 do
                p.x = p.x - 0.1 -- ~6 tiles/s, mais que o anel anda num tick
                G.tick(1)
            end
            assert(e.target == p, "pulou a frente na fase " .. k)
            assert(NOM_SonarServer.found == 1, "achado " .. NOM_SonarServer.found .. " vezes na fase " .. k)
        end
    end,

    -- teto de anéis (review, item 1): com mais de MAX_RINGS estalando juntos perto do jogador,
    -- o que não cabe não é anunciado (nem som, nem anel, nem comando); todo anel anunciado é
    -- simulado até o fim e acha o jogador
    sonar_cap_never_announces_dropped = function()
        local R = require "NOM_SonarRules"
        for _, server in ipairs({ false, true }) do
            local G = setup({ server = server })
            for i = 1, R.MAX_RINGS + 2 do G.zombie({ x = 100 + (i % 3), y = 100 + i * 0.3, id = EST, onlineID = 50 + i }) end
            G.player({ x = 104, y = 102, onlineID = 5 })
            assert(G.untilRing(), "não estalou")
            assert(#NOM_SonarServer.rings == R.MAX_RINGS, "anéis vivos: " .. #NOM_SonarServer.rings)
            local announced = server and #G.commands("sonar") or #G.rings
            assert(announced == R.MAX_RINGS, "anunciados: " .. announced)
            assert(NOM_SonarServer.dropped == 2, "descartados: " .. tostring(NOM_SonarServer.dropped))
            G.wait(R.DURATION_MS + 100)
            local found = server and #G.commands("sonarFound") or NOM_SonarServer.found
            assert(found == R.MAX_RINGS, "anel anunciado que não achou ninguém: " .. found)
        end
    end,

    -- lotado com anéis que já não alcançam ninguém (longe de todo jogador): o mais longe sai
    -- pro anel perto, que acha o jogador
    sonar_cap_evicts_farthest_unreachable = function()
        local R = require "NOM_SonarRules"
        local G = setup()
        G.rolls = {}
        for i = 1, R.MAX_RINGS do
            G.zombie({ x = 100 + R.REACH + i, y = 100, id = EST })
            G.rolls[i] = 0
        end
        local near = G.zombie({ x = 100, y = 104, id = EST })
        G.rolls[R.MAX_RINGS + 1] = 600 -- estala logo depois dos longes
        G.rand = R.GAP_ROLL - 1
        local p = G.player({ x = 100, y = 100 })
        assert(G.untilRing())
        G.wait(300)
        assert(#NOM_SonarServer.rings == R.MAX_RINGS)
        local far = 0
        for _, ring in ipairs(NOM_SonarServer.rings) do far = math.max(far, ring.x) end
        assert(G.untilRing(1500), "o perto não estalou")
        assert(#G.rings == R.MAX_RINGS + 1 and NOM_SonarServer.dropped == 0)
        for _, ring in ipairs(NOM_SonarServer.rings) do assert(ring.x ~= far, "o mais longe ficou") end
        G.wait(R.DURATION_MS)
        assert(near.target == p, "o anel perto não achou")
    end,

    -- fora dos 8 tiles e em outro andar: o anel não chega
    sonar_range_and_floor = function()
        local G = setup()
        local e = G.zombie({ x = 100, y = 100, id = EST })
        G.player({ x = 109, y = 100 })
        G.player({ x = 103, y = 100, z = 1 })
        assert(G.untilRing(), "não estalou")
        G.tick(150)
        assert(e.target == nil, "achou fora do alcance ou em outro andar")
    end,

    -- dedicado: o servidor manda o anel a todos e o achado pro dono aplicar
    sonar_dedicated_sends_commands = function()
        local G = setup({ server = true })
        local e = G.zombie({ x = 100, y = 100, id = EST, onlineID = 77 })
        local p = G.player({ x = 104, y = 100, onlineID = 5 })
        local up = G.player({ x = 102, y = 100, z = 1, onlineID = 6 }) -- outro andar: ouve o estalo
        G.player({ x = 100 + NOM_SonarRules.SEND_RANGE + 5, y = 100, onlineID = 7 }) -- longe
        assert(G.untilRing(), "não estalou")
        -- só pra quem está a até SEND_RANGE (review, item 2): sendServerCommand(jogador, ...)
        local s = G.commands("sonar")
        assert(#s == 2 and s[1].player == p and s[2].player == up, "sonar: " .. #s)
        assert(s[1].args.x == e.x and s[1].args.y == e.y and s[1].args.z == 0 and s[1].args.id == 77)
        assert(#G.sounds == 0 and #G.rings == 0, "o dedicado tocou ou desenhou")
        G.tick(150)
        local f = G.commands("sonarFound")
        assert(#f == 1 and f[1].args.id == 77 and f[1].args.pl == p.onlineID, "sonarFound: " .. #f)
        assert(e.target == nil, "o servidor aplicou (quem aplica é o dono)")
    end,

    -- cliente de MP: confere a mensagem, toca, desenha e o dono aplica
    sonar_client_commands = function()
        local G = setup({ client = true })
        local mine = G.zombie({ x = 100, y = 100, id = EST, onlineID = 77 })
        local other = G.zombie({ x = 120, y = 100, id = EST, onlineID = 78, remote = true })
        local p = G.player({ x = 104, y = 100, onlineID = 5 })
        NOM_Sonar.command("sonar", { x = 100.5, y = 100.5, z = 0, id = 77 })
        assert(#G.rings == 1 and #G.sounds == 1, "anel/estalo no cliente")
        NOM_Sonar.command("sonar", { x = "a", y = 1, z = 0 })
        NOM_Sonar.command("sonar", { x = 1, y = 1, z = 0.5 })
        assert(#G.rings == 1, "mensagem inválida desenhou")
        -- anel do outro lado do mapa (review, item 2): nem som, nem desenho, nem mod3
        NOM_Sonar.command("sonar", { x = 104.5 + NOM_SonarRules.SEND_RANGE + 1, y = 100.5, z = 0, id = 77 })
        assert(#G.rings == 1 and #G.sounds == 1, "anel longe de todo jogador local tocou ou desenhou")
        NOM_Sonar.command("sonarFound", { id = 77, pl = 5 })
        assert(mine.target == p, "o dono não aplicou")
        NOM_Sonar.command("sonarFound", { id = 78, pl = 5 })
        assert(other.target == nil, "cópia remota aplicou")
        NOM_Sonar.command("sonarFound", { id = 77, pl = 0 / 0 })
        NOM_Sonar.command("sonarFound", { id = 77, pl = 999 }) -- jogador que este cliente não conhece
    end,

    -- quem desenha com erro não para o estalo nem o anel do servidor
    sonar_listener_error_isolated = function()
        local G = setup()
        NOM_Sonar.onRing(function() error("bum") end)
        G.zombie({ x = 100, y = 100, id = EST })
        G.player({ x = 104, y = 100 })
        assert(G.untilRing(), "não estalou")
        assert(#G.sounds == 1 and #NOM_SonarServer.rings == 1)
    end,

    -- debug: Estalador mais perto estala; sem Estalador, anel no jogador (só visual)
    sonar_debug_force = function()
        local G = setup()
        G.zombie({ x = 130, y = 100, id = EST })
        local near = G.zombie({ x = 110, y = 100, id = EST })
        G.zombie({ x = 101, y = 100, id = COMMON })
        local p = G.player({ x = 100, y = 100 })
        local msg = NOM_SonarServer.force(p)
        assert(msg:find("estalador", 1, true), msg)
        assert(#G.rings == 1 and G.rings[1].x == near.x, "não foi o mais perto")
        local G2 = setup({ fog = false })
        local p2 = G2.player({ x = 100, y = 100 })
        local msg2 = NOM_SonarServer.force(p2)
        assert(msg2:find("jogador", 1, true), msg2)
        assert(#G2.rings == 1 and G2.rings[1].x == p2.x)
        G2.tick(150)
        assert(NOM_SonarServer.found == 0, "anel sem Estalador achou alguém")
    end,

    -- custo: sem névoa nem anel, nada por tick; com névoa, o relógio e a amostra a cada 250 ms;
    -- com MAX_RINGS anéis e 4 jogadores, o tick fica pequeno; o minuto com 300 zumbis
    sonar_budget = function()
        local G = setup({ fog = false })
        G.player({ x = 100, y = 100 })
        G.calls = 0
        G.tick(100)
        assert(G.calls == 0, "sem névoa e sem anel: " .. G.calls)
        local G2 = setup()
        for i = 1, 4 do G2.player({ x = 100 + i, y = 100 }) end
        G2.tick(5)
        G2.calls = 0
        G2.tick(600)
        local idle = G2.calls / 600
        assert(idle <= 3, "névoa sem anel: " .. idle .. " por tick")
        for i = 1, NOM_SonarRules.MAX_RINGS do
            local e = G2.zombie({ x = 100 + i, y = 101, id = EST })
            NOM_SonarServer.emit(e, e.x, e.y, 0, "teste")
        end
        G2.calls = 0
        local worst = 0
        for _ = 1, 100 do
            local before = G2.calls
            G2.tick(1)
            worst = math.max(worst, G2.calls - before)
        end
        assert(NOM_SonarServer.found > 0, "o teste de custo não achou ninguém")
        -- +3 por cruzamento (casa: getCurrentSquare, isOutside, getBuilding) e +1 por achado
        -- (getPersistentOutfitID, objeto reaproveitado)
        assert(worst <= 90, "com anéis: pior tick " .. worst)
        local G3 = setup()
        for i = 1, 300 do G3.zombie({ x = 100 + i, y = 100, id = COMMON }) end
        for i = 1, 3 do G3.zombie({ x = 100, y = 100 + i, id = EST }) end
        G3.player({ x = 100, y = 100 })
        G3.calls = 0
        local scan = 0
        for _ = 1, 250 do -- 4 s: 4 passadas na lista (SCAN_MS), nenhum estalo ainda
            local before = G3.calls
            G3.tick(1)
            scan = math.max(scan, G3.calls - before)
        end
        local avg = G3.calls / 250
        assert(NOM_SonarServer.emitted == 0, "estalou antes do intervalo")
        assert(scan <= 303 * 2 + 3 * 8 + 10, "passada com 303 zumbis: " .. scan)
        assert(avg <= 303 * 2 / (NOM_SonarRules.SCAN_MS / 16) + 4, "média com 303 zumbis: " .. avg)
        print(string.format("[budget] sonar: névoa sem anel %.2f chamadas/tick; %d anéis e 4 jogadores pior tick %d; passada com 303 zumbis %d (média %.1f/tick)",
            idle, NOM_SonarRules.MAX_RINGS, worst, scan, avg))
    end,
}
