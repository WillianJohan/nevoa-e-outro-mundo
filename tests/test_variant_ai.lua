-- NOM_VariantAI contra um jogo falso que imita a ORDEM do B42.20 (bytecode) num frame:
-- 1. IsoPlayer.TestZombieSpotPlayer → IsoZombie.spotted(p, false) → spottedNew. A visão
--    do zumbi é presa em 10–20 tiles (updateVisionRadius): até a "ruim" vê a 10, então o
--    fake vê a ≤ 10. spottedNew: zumbi useless → setTarget(null) + spottedLast = null e
--    volta (191–208); senão setTarget(p), spottedLast = p, guarda a última posição vista
--    (lastTargetSeenX/Y) e, no spot não forçado, bonusSpotTime = 720 (1909–1917).
-- 2. IsoZombie.updateInternal: OnZombieUpdate (696); depois, ainda antes da máquina de
--    estados, se bonusSpotTime > 0 e spottedLast vivo → spotted(spottedLast, true)
--    (956–991): o spot forçado refaz setTarget e pathToCharacter (2263–2447).
-- 3. IsoGameCharacter.update (1029), a máquina de estados: com alvo a ≤ 1 tile ataca
--    (AttackState), com alvo anda até ele; sem alvo, WalkTowardState segue até a
--    última posição vista (execute 169–213); sem isso, vai atrás do som ouvido.
-- * Som: RespondToSound volta cedo com o zumbi useless (8–15).
-- * OnHitZombie(zombie, wielder, bodyPart, weapon): shared/Definitions/DamageModelDefinitions.lua:24,69.
-- * setUseless/isUseless: client/DebugUIs/DebugContextMenu.lua:566,673; client/Tutorial/Steps.lua:1107.
-- * Zumbi remoto (MP, não dono) não roda a IA: a posição vem do pacote, e o useless
--   também (NetworkZombieAI.set → NetworkZombieVariables.getBooleanVariables 86–89;
--   NetworkZombieAI.parse 204–252). Quando a posse troca, o novo dono herda o useless.
-- * Outfit de debug com "Useless" no nome liga o useless (updateInternal 47–58).
-- * EveryOneMinute; ZombRand(n) global (server/ClientCommands.lua:120).
-- * Toda chamada de método no zumbi conta em z.calls (custo Java por frame).
require "NOM_VariantRules"

local FILE = "mod/42/media/lua/shared/NOM_VariantAI.lua"

-- persistentOutfitID (formato do jogo) que, com o sandbox padrão, é `want` no período
-- (sorteio normal); want nil = nada que o mod deixa useless (nem Carpideira nem
-- Estalador) nos períodos dados, normal ou vermelha
local function idFor(want, period, avoid)
    require "NOM_Config"
    local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
    local still = { carpideira = true, estalador = true }
    for seed = 1, 3000 do
        local id = 11 * 65536 + seed
        if want then
            if NOM_VariantRules.variant(id, period, c) == want then return id end
        else
            local ok = true
            for _, n in ipairs(avoid) do
                for _, red in ipairs({ false, true }) do
                    if still[NOM_VariantRules.variant(id, n, c, red) or ""] then ok = false end
                end
            end
            if ok then return id end
        end
    end
    error("nenhum ID")
end

local function setup(opts)
    opts = opts or {}
    local G = { zombies = {}, players = {}, reports = {}, rand = opts.rand or 0 }
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    function G.player(o)
        local p = { class = "IsoPlayer", x = o.x, y = o.y, sneaking = o.sneaking or false,
            running = o.running or false, sprinting = o.sprinting or false, bitten = 0 }
        function p:isSneaking() return self.sneaking end
        function p:isRunning() return self.running end
        function p:isSprinting() return self.sprinting end
        G.players[#G.players + 1] = p
        return p
    end
    function G.zombie(o)
        local z = { class = "IsoZombie", x = o.x, y = o.y, md = {}, remote = o.remote or false, id = o.id or 4242,
            onlineID = o.onlineID or -1, sounds = {}, netSounds = {}, dead = false, useless = o.useless or false,
            bonusSpotTime = 0, calls = 0, outfitName = o.outfit }
        local function def(name, fn)
            z[name] = function(...) z.calls = z.calls + 1; return fn(...) end
        end
        if o.variant then
            z.md.NOM_variant = o.variant
            NOM_NightStats.variants[z] = o.variant -- o que o NOM_NightStats faz no apply
        end
        def("hasModData", function(self) return next(self.md) ~= nil end)
        def("getModData", function(self) return self.md end)
        def("isRemoteZombie", function(self) return self.remote end)
        def("isDead", function(self) return self.dead end)
        def("getTarget", function(self) return self.target end)
        def("setTarget", function(self, t) self.target = t end)
        def("isUseless", function(self) return self.useless end)
        def("setUseless", function(self, b) self.useless = b end)
        def("getOnlineID", function(self) return self.onlineID end)
        def("getOutfitName", function(self) return self.outfitName end)
        def("getPersistentOutfitID", function(self) return self.id end)
        -- IsoZombie.spotted(obj, forçado) público → spottedNew (sprint 0011)
        def("spotted", function(self, p, forced) G.spot(self, p, forced) end)
        -- emitter:playSound manda PacketType.PlaySound no cliente de MP
        -- (FMODSoundEmitter.playSound 0–104); playSoundLocal = playSoundImpl(nome, nil), sem pacote
        def("getEmitter", function()
            return { playSound = function(_, name) z.netSounds[#z.netSounds + 1] = name; return 1 end }
        end)
        def("playSoundLocal", function(_, name) z.sounds[#z.sounds + 1] = name; return 1 end)
        G.zombies[#G.zombies + 1] = z
        return z
    end
    -- spottedNew, como no bytecode
    local function spotted(z, p, forced)
        if z.useless then
            z.target, z.spottedLast = nil, nil
            return
        end
        z.target, z.spottedLast = p, p
        z.lastSeen = { x = p.x, y = p.y }
        if not forced then z.bonusSpotTime = 720 end
    end
    G.spot = spotted
    local function dist(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end
    local function step(a, tx, ty)
        if a.x < tx then a.x = a.x + 1 elseif a.x > tx then a.x = a.x - 1 end
        if a.y < ty then a.y = a.y + 1 elseif a.y > ty then a.y = a.y - 1 end
    end
    -- um frame do jogo, na ordem do bytecode
    function G.frame(n)
        for _ = 1, n or 1 do
            for _, z in ipairs(G.zombies) do
                if not z.remote then
                    for _, p in ipairs(G.players) do
                        if dist(z, p) <= 10 then spotted(z, p, false) end
                    end
                end
            end
            for _, z in ipairs(G.zombies) do
                fire("OnZombieUpdate", z)
                if not z.remote then
                    if z.bonusSpotTime > 0 and z.spottedLast then spotted(z, z.spottedLast, true) end
                    z.bonusSpotTime = math.max(0, z.bonusSpotTime - 1)
                    local t = z.target
                    if t and dist(z, t) <= 1 then
                        t.bitten = t.bitten + 1
                    elseif t then
                        step(z, t.x, t.y)
                    elseif z.lastSeen then -- WalkTowardState até chegar, depois acaba
                        step(z, z.lastSeen.x, z.lastSeen.y)
                        if z.x == z.lastSeen.x and z.y == z.lastSeen.y then z.lastSeen = nil end
                    elseif z.sound then
                        step(z, z.sound.x, z.sound.y)
                    end
                end
            end
        end
    end
    -- RespondToSound volta cedo com o zumbi useless
    function G.sound(x, y)
        for _, z in ipairs(G.zombies) do
            if not z.useless then z.sound = { x = x, y = y } end
        end
    end
    function G.hit(z, p) fire("OnHitZombie", z, p, nil, nil) end
    function G.minutes(n) for _ = 1, n do fire("EveryOneMinute") end end
    -- objeto reaproveitado (resetForReuse) passa pelo OnZombieCreate
    function G.reuse(z) z.md = {}; fire("OnZombieCreate", z) end

    instanceof = function(o, cls) return o.class == cls end
    ZombRand = function(n) return G.rand % n end
    isClient = function() return opts.client == true end
    -- getCore():getGameMode() == "Tutorial": shared/TimedActions/ISGrabCorpseAction.lua:140
    getCore = function() return { getGameMode = function() return opts.gameMode or "Sandbox" end } end
    isServer = function() return false end
    getDebug = function() return false end
    SandboxVars = {}
    getCell = function()
        return {
            getZombieList = function()
                return { size = function() return #G.zombies end, get = function(_, i) return G.zombies[i + 1] end }
            end,
        }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_FogState", "NOM_NightStats", "NOM_VariantAI", "NOM_Carpideira" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_NightStats"
    -- variantes só existem na névoa (Johan, 05/10), de dia ou de noite
    NOM_FogState.set(opts.fog ~= false, 1)
    NOM_NightStats.setNight(opts.night == true, 1)
    dofile(FILE)
    NOM_VariantAI.install(function(z) G.reports[#G.reports + 1] = z end)
    G.handlers = handlers
    return G
end

return {
    -- critério: agachado e em silêncio, o jogador passa do lado do Estalador
    ai_estalador_ignores_silent_crouched = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        -- tempo de sobra pra várias janelas de cegueira abrirem e fecharem
        G.frame(5 * NOM_VariantAI.BLIND_FRAMES)
        assert(p.bitten == 0, "mordeu jogador agachado: " .. p.bitten)
        assert(z.target == nil, "ficou com o jogador de alvo")
        -- zumbi comum do lado, mesma situação: morde (o fake não é bonzinho)
        local G2 = setup()
        G2.zombie({ x = 0, y = 0 })
        local p2 = G2.player({ x = 1, y = 0, sneaking = true })
        G2.frame(30)
        assert(p2.bitten > 0, "o fake não ataca: teste não prova nada")
    end,
    -- andar em pé, correr ou disparar: faz barulho
    ai_estalador_hears_walking_player = function()
        for _, o in ipairs({ {}, { sneaking = true, running = true }, { sneaking = true, sprinting = true } }) do
            local G = setup()
            G.zombie({ x = 0, y = 0, variant = "estalador" })
            o.x, o.y = 5, 0
            local p = G.player(o)
            G.frame(30)
            assert(p.bitten > 0, "Estalador ignorou jogador barulhento")
        end
    end,
    -- som no mundo: o Estalador vai até o ponto (reage a som), mesmo cego
    ai_estalador_follows_sound = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        G.sound(20, 0)
        G.frame(20)
        assert(z.x == 20, "Estalador não foi até o som")
    end,
    -- golpe é barulho: Estalador acertado acha o agressor, mesmo agachado
    ai_estalador_hit_wakes_it = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        G.frame(5)
        G.hit(z, p)
        G.frame(5)
        assert(p.bitten > 0, "golpe não acordou o Estalador")
        assert(z.md.NOM_alert == true)
    end,
    -- o servidor decide o grito: o dono só avisa na borda "pegou um jogador de alvo"
    ai_corredor_reports_once_per_acquire = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "corredor" })
        local p = G.player({ x = 30, y = 0 })
        G.frame(5)
        assert(#G.reports == 0, "gritou sem ver ninguém")
        p.x = 8
        G.frame(10)
        assert(#G.reports == 1 and G.reports[1] == z, "avisos: " .. #G.reports)
        z.target = nil -- perdeu o alvo (memória acabou)
        p.x, z.x = 50, 0
        G.frame(3)
        p.x = 5
        G.frame(3)
        assert(#G.reports == 2, "não avisou o novo alvo")
    end,
    ai_common_zombie_untouched = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0 })
        G.player({ x = 5, y = 0, sneaking = true })
        G.frame(5)
        assert(#G.reports == 0 and z.target ~= nil and next(z.md) == nil, "mexeu em zumbi comum")
    end,
    -- MP: só o dono roda a IA; cópia remota não decide nada
    ai_remote_untouched = function()
        local G = setup()
        local e = G.zombie({ x = 0, y = 0, variant = "estalador", remote = true })
        local c = G.zombie({ x = 0, y = 2, variant = "corredor", remote = true })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        e.target, c.target = p, p
        G.frame(3)
        assert(e.target == p and #G.reports == 0)
    end,
    -- fim da névoa (flag já virou, o lote ainda não limpou a marca): nada de cego nem estalo
    ai_night_without_fog_does_nothing = function()
        local G = setup({ fog = false, night = true })
        local e = G.zombie({ x = 0, y = 0, variant = "estalador" })
        G.zombie({ x = 0, y = 5, variant = "corredor" })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        G.frame(10)
        G.minutes(10)
        assert(p.bitten > 0 and #G.reports == 0 and #e.sounds == 0)
    end,
    -- estalo de aviso: só Estalador, vivo, em toda cópia local (inclusive remota)
    ai_click_only_estalador = function()
        local G = setup()
        local e = G.zombie({ x = 0, y = 0, variant = "estalador", remote = true })
        local c = G.zombie({ x = 0, y = 5, variant = "corredor" })
        local n = G.zombie({ x = 0, y = 9 })
        local dead = G.zombie({ x = 0, y = 7, variant = "estalador" })
        dead.dead = true
        G.minutes(4)
        assert(#e.sounds == 4 and e.sounds[1] == NOM_VariantAI.CLICK_SOUND)
        assert(#c.sounds == 0 and #n.sounds == 0 and #dead.sounds == 0)
    end,
    -- o sorteio por minuto separa os estalos (senão todos estalam juntos, metrônomo)
    ai_click_is_spread = function()
        local G = setup({ rand = 1 })
        local e = G.zombie({ x = 0, y = 0, variant = "estalador" })
        G.minutes(4)
        assert(#e.sounds == 0)
    end,
    -- a cegueira é uma janela curta: levantou, ele acha; foi embora, ele volta a ouvir
    ai_estalador_releases_when_player_makes_noise = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        assert(z.useless, "não cegou")
        p.sneaking = false
        G.frame(5)
        assert(not z.useless and p.bitten > 0, "não soltou quando o jogador levantou")
    end,
    ai_estalador_window_is_short = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        p.x = 40 -- saiu de perto agachado
        G.frame(NOM_VariantAI.BLIND_FRAMES + 2)
        assert(not z.useless, "ficou useless depois que o jogador sumiu")
        G.sound(0, 20)
        G.frame(25)
        assert(z.y == 20, "Estalador surdo depois da janela: " .. z.x .. "," .. z.y)
    end,
    -- nunca useless depois do fim da névoa, da troca de variante ou do golpe
    ai_estalador_useless_never_outlives_night = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        assert(z.useless)
        NOM_FogState.set(false, 1)
        G.frame(1)
        assert(not z.useless, "useless passou do fim da névoa")
        -- variante saiu (o lote tirou do conjunto)
        local G2 = setup()
        local z2 = G2.zombie({ x = 0, y = 0, variant = "estalador" })
        G2.player({ x = 1, y = 0, sneaking = true })
        G2.frame(3)
        NOM_NightStats.variants[z2] = nil
        z2.md.NOM_variant = nil
        G2.frame(1)
        assert(not z2.useless, "useless sobrou sem variante")
    end,
    ai_estalador_hit_releases_now = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        G.hit(z, p)
        assert(not z.useless and z.md.NOM_alert == true, "golpe não soltou")
    end,
    -- objeto reaproveitado pra outro zumbi não pode nascer useless
    ai_reuse_releases = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador" })
        G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        G.reuse(z)
        assert(not z.useless, "reaproveitado nasceu useless")
    end,
    -- useless de outro (tutorial, debug, outro mod): o mod não liga nem desliga
    -- MP: o dono cegou, a posse troca no meio da janela; o novo dono recebeu o
    -- useless pelo pacote sem a entrada local. Não pode ficar inerte pra sempre.
    ai_ownership_transfer_mid_window = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador", remote = true, useless = true })
        local p = G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        assert(z.useless, "mexeu no useless de zumbi remoto")
        z.remote = false -- virou dono
        G.frame(2)
        assert(#G.zombies == 1 and p.bitten == 0)
        p.sneaking = false
        G.frame(5)
        assert(p.bitten > 0, "Estalador herdado ficou inerte: useless=" .. tostring(z.useless))
    end,
    -- useless do próprio jogo (outfit de debug "…Useless…"): o mod não liga nem desliga
    ai_foreign_useless_untouched = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "estalador", useless = true, outfit = "DebugUseless" })
        G.player({ x = 1, y = 0, sneaking = true })
        G.frame(3)
        NOM_FogState.set(false, 1)
        G.frame(3)
        G.hit(z, {})
        assert(z.useless, "desligou um useless que não era do mod")
    end,
    -- custo por frame: zumbi comum sai com uma consulta de tabela, sem chamar Java
    ai_common_zombie_no_java_calls = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0 })
        z.target = G.player({ x = 1, y = 0 })
        local before = z.calls
        for _ = 1, 50 do
            for _, h in ipairs(G.handlers.OnZombieUpdate) do h(z) end
        end
        assert(z.calls == before, "chamadas Java no zumbi comum: " .. (z.calls - before))
    end,
    -- o estalo é tocado em toda cópia de todo cliente: tem que ser local, senão
    -- cada cliente manda PlaySound e os outros ouvem o estalo N vezes
    ai_click_is_local_on_mp_client = function()
        local G = setup({ client = true })
        local e = G.zombie({ x = 0, y = 0, variant = "estalador", remote = true })
        G.minutes(3)
        assert(#e.netSounds == 0, "estalo foi pra rede")
        assert(#e.sounds == 3 and e.sounds[1] == NOM_VariantAI.CLICK_SOUND)
    end,

    -- orçamento: o estalo (1/min à noite) não chama nada no zumbi comum
    ai_click_touches_only_estaladores = function()
        local G = setup()
        local zs = {}
        for i = 1, 300 do zs[i] = G.zombie({ x = i, y = 0 }) end
        local e = G.zombie({ x = 0, y = 0, variant = "estalador" })
        G.minutes(10)
        local n = 0
        for _, z in ipairs(zs) do n = n + z.calls end
        assert(n == 0, "estalo chamou zumbi comum: " .. n)
        assert(#e.sounds == 10, "Estalador não estalou")
    end,
    -- orçamento da névoa vermelha (review): ninguém é comum. Por frame, sem alvo:
    -- Estalador 4 chamadas (getModData, isRemoteZombie, isUseless, getTarget), Corredor
    -- 3 (getModData, isRemoteZombie, getTarget); o Sem-rosto não tem IA aqui (0)
    ai_red_fog_budget_per_frame = function()
        local G = setup()
        NOM_FogState.set(true, 1, true)
        local kinds = { "estalador", "corredor", false, "carpideira" }
        local by = { estalador = {}, corredor = {}, none = {}, carpideira = {} }
        for i = 1, 400 do
            local k = kinds[i % 4 + 1]
            local z = G.zombie({ x = 100 + i, y = 100, variant = k or nil })
            table.insert(by[k or "none"], z)
        end
        G.frame(10)
        local function sum(list) local n = 0 for _, z in ipairs(list) do n = n + z.calls end return n end
        assert(sum(by.estalador) <= 100 * 10 * 4, "Estalador: " .. sum(by.estalador))
        assert(sum(by.corredor) <= 100 * 10 * 3, "Corredor: " .. sum(by.corredor))
        assert(sum(by.none) == 0, "Sem-rosto/comum: " .. sum(by.none))
        -- Carpideira calma (sprint 0011): 2 por frame (getModData, isRemoteZombie) e, no
        -- primeiro, 3 a mais (getPersistentOutfitID, setUseless, setTarget)
        assert(sum(by.carpideira) <= 100 * (10 * 2 + 3), "Carpideira: " .. sum(by.carpideira))
        -- estalo: 1/min, só nos Estaladores, ≤ 3 chamadas cada (getModData, isDead, playSoundLocal)
        for _, z in ipairs(G.zombies) do z.calls = 0 end
        G.minutes(1)
        assert(sum(by.estalador) <= 100 * 3 and sum(by.corredor) == 0 and sum(by.none) == 0 and sum(by.carpideira) == 0)
    end,

    -- Carpideira (sprint 0011): calma, fica parada; jogador em pé à vista (fora do raio
    -- que a acorda, que é da varredura) não é perseguido. Controle: o Corredor vem.
    ai_carpideira_still_while_calm = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "carpideira" })
        local p = G.player({ x = 30, y = 0 })
        G.frame(2)
        assert(z.useless, "não ficou parada (useless)")
        p.x = 6
        G.frame(60)
        assert(z.x == 0 and z.y == 0 and p.bitten == 0, "andou ou mordeu: " .. z.x .. "," .. z.y)
        G.sound(0, 20)
        G.frame(25)
        assert(z.x == 0 and z.y == 0, "foi atrás de som calma")
        local G2 = setup()
        local c = G2.zombie({ x = 0, y = 0, variant = "corredor" })
        local p2 = G2.player({ x = 6, y = 0 })
        G2.frame(30)
        assert(p2.bitten > 0 and c.x ~= 0, "o fake não persegue: teste não prova nada")
    end,
    -- o grito (decidido pelo servidor) solta e manda caçar quem a acordou
    ai_carpideira_scream_hunts_trigger_player = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "carpideira" })
        local p = G.player({ x = 30, y = 0 })
        G.frame(2)
        NOM_Carpideira.scream(z, p)
        assert(not z.useless and z.target == p, "não soltou ou não pegou o alvo")
        assert(z.sounds[1] == NOM_Carpideira.SCREAM and #z.netSounds == 0, "grito não tocou local")
        G.frame(40)
        assert(p.bitten > 0, "não caçou quem a acordou")
        assert(z.useless == false, "voltou a ficar parada depois do grito")
    end,
    -- fim da névoa: solta (não fica parada pro resto do jogo)
    ai_carpideira_released_when_fog_ends = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "carpideira" })
        G.frame(2)
        assert(z.useless)
        NOM_FogState.set(false, 1)
        G.frame(1)
        assert(not z.useless, "parada depois da névoa")
        -- objeto reaproveitado também
        local G2 = setup()
        local z2 = G2.zombie({ x = 0, y = 0, variant = "carpideira" })
        G2.frame(2)
        G2.reuse(z2)
        assert(not z2.useless, "reaproveitado nasceu parado")
    end,
    -- MP: só o dono mexe; a cópia remota segue o pacote (o useless viaja nele:
    -- NetworkZombieAI.set/parse), então nasce parada como a do dono
    ai_carpideira_remote_untouched = function()
        local G = setup()
        local z = G.zombie({ x = 0, y = 0, variant = "carpideira", remote = true, useless = true })
        G.frame(5)
        assert(z.useless, "cópia remota mexeu no useless")
        z.remote = false -- virou dono, com o useless herdado
        G.frame(1)
        assert(z.useless and NOM_Carpideira.still[z], "novo dono não a assumiu parada")
    end,
    -- review (Critical A): calma e parada pelo dono antigo; a névoa acaba e a posse vem
    -- pra cá com o useless herdado. Nada aqui a parou (kind, blind, still: nil): o
    -- onUpdate sai cedo. A passada do NightStats (unstick) solta.
    ai_carpideira_inherited_after_fog_is_released = function()
        local G = setup({ fog = false })
        -- foi Carpideira na névoa que acabou (período 1); comum de novo, herdada parada
        local z = G.zombie({ x = 0, y = 0, useless = true, id = idFor("carpideira", 1) })
        local p = G.player({ x = 6, y = 0 })
        G.frame(5)
        assert(z.useless, "o fake não modela o useless herdado")
        NOM_NightStats.unstick(z)
        G.frame(30)
        assert(not z.useless and p.bitten > 0, "ficou parada pra sempre depois da névoa")
        -- reaproveitado com o useless herdado (resetForReuse não limpa)
        local G2 = setup({ fog = false })
        local z2 = G2.zombie({ x = 0, y = 0, useless = true, id = idFor("carpideira", 1) })
        G2.reuse(z2)
        assert(not z2.useless, "reaproveitado nasceu parado")
        -- remoto, Useless do jogo (outfit de debug) e parada pelo próprio mod: não mexe
        local G3 = setup()
        local r = G3.zombie({ x = 0, y = 0, useless = true, remote = true, id = idFor("carpideira", 1) })
        local dbg = G3.zombie({ x = 0, y = 5, useless = true, outfit = "DebugUseless", id = idFor("carpideira", 1) })
        local mine = G3.zombie({ x = 0, y = 9, variant = "carpideira" })
        G3.frame(2)
        for _, z3 in ipairs({ r, dbg, mine }) do NOM_NightStats.unstick(z3) end
        assert(r.useless and dbg.useless and mine.useless, "soltou o que não era herdado")
        -- Estalador cego por este processo também fica
        local G4 = setup()
        local e = G4.zombie({ x = 0, y = 0, variant = "estalador" })
        G4.player({ x = 1, y = 0, sneaking = true })
        G4.frame(3)
        assert(e.useless)
        NOM_NightStats.unstick(e)
        assert(e.useless, "soltou o Estalador no meio da janela")
    end,
    -- review (Critical B): ela já gritou e a posse muda; o novo dono herda o useless
    -- do pacote antigo. Furiosa: solta.
    ai_carpideira_inherited_after_scream_is_released = function()
        local G = setup()
        NOM_Carpideira.screamed[778] = true
        local z = G.zombie({ x = 0, y = 0, variant = "carpideira", id = 778, useless = true })
        local p = G.player({ x = 6, y = 0 })
        G.frame(30)
        assert(not z.useless and p.bitten > 0, "furiosa herdada ficou parada")
    end,
    -- quem já gritou nesta névoa (servidor avisou) volta do virtual como objeto novo:
    -- não fica parada de novo
    ai_carpideira_reloaded_after_scream_stays_furious = function()
        local G = setup()
        NOM_Carpideira.screamed[777] = true
        local z = G.zombie({ x = 0, y = 0, variant = "carpideira", id = 777 })
        local p = G.player({ x = 6, y = 0 })
        G.frame(30)
        assert(not z.useless and p.bitten > 0, "furiosa recarregada ficou parada")
    end,
    -- verificação da review: o unstick só solta quem o mod pode ter deixado useless
    -- (Carpideira ou Estalador no período atual ou no anterior, normal ou vermelha).
    -- Zumbi do tutorial (client/Tutorial/Steps.lua:847, 1107) e de outro mod fica.
    ai_unstick_leaves_foreign_useless = function()
        local G = setup({ fog = false })
        NOM_FogState.set(false, 3)
        local z = G.zombie({ x = 0, y = 0, useless = true, id = idFor(nil, nil, { 2, 3 }) })
        NOM_NightStats.unstick(z)
        G.reuse(z)
        assert(z.useless, "soltou useless de quem nunca foi Carpideira nem Estalador")
    end,
    -- ex-Carpideira da névoa anterior (o período avançou com a nova névoa), herdada parada
    ai_unstick_releases_previous_period_carpideira = function()
        local id = idFor("carpideira", 2)
        local G = setup()
        NOM_FogState.set(true, 3)
        require "NOM_Config"
        local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
        assert(NOM_VariantRules.variant(id, 3, c) ~= "carpideira", "escolher outro ID: Carpideira de novo")
        local z = G.zombie({ x = 0, y = 0, useless = true, id = id })
        NOM_NightStats.unstick(z)
        assert(not z.useless, "não soltou a Carpideira da névoa anterior")
        -- e uma de dois períodos atrás não
        local G2 = setup()
        NOM_FogState.set(true, 4)
        local old = G2.zombie({ x = 0, y = 0, useless = true, id = idFor(nil, nil, { 3, 4 }) })
        NOM_NightStats.unstick(old)
        assert(old.useless)
    end,
    -- tutorial: o mod não mexe em useless nenhum
    ai_unstick_does_nothing_in_tutorial = function()
        local G = setup({ fog = false, gameMode = "Tutorial" })
        local z = G.zombie({ x = 0, y = 0, useless = true, id = idFor("carpideira", 1) })
        NOM_NightStats.unstick(z)
        G.reuse(z)
        assert(z.useless, "mexeu no zumbi do tutorial")
    end,
}
