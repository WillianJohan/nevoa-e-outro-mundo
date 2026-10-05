-- NOM_VariantAI contra um jogo falso que imita a ORDEM do B42.20 (bytecode) num frame:
-- 1. IsoPlayer.TestZombieSpotPlayer → IsoZombie.spotted → spottedNew: o zumbi vê
--    o jogador e faz setTarget(jogador). A visão do zumbi é presa em 10–20 tiles
--    (updateVisionRadius): até a visão "ruim" vê a 10, então o fake vê a ≤ 10.
-- 2. IsoZombie.updateInternal dispara OnZombieUpdate (offset 696)...
-- 3. ...antes de IsoGameCharacter.update (1029), a máquina de estados: com alvo
--    a ≤ 1 tile ataca (AttackState), com alvo anda até ele; sem alvo, nada.
-- * Som (addSound/WorldSoundManager) faz o zumbi ir até o ponto, sem alvo.
-- * OnHitZombie(zombie, wielder, bodyPart, weapon): shared/Definitions/DamageModelDefinitions.lua:24,69.
-- * Zumbi remoto (MP, não dono) não roda a IA: a posição vem do pacote.
-- * EveryOneMinute; ZombRand(n) global (server/ClientCommands.lua:120).
require "NOM_VariantRules"

local FILE = "mod/42/media/lua/shared/NOM_VariantAI.lua"

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
        local z = { class = "IsoZombie", x = o.x, y = o.y, md = {}, remote = o.remote or false,
            variant = o.variant, onlineID = o.onlineID or -1, sounds = {}, dead = false }
        if o.variant then z.md.NOM_variant = o.variant end
        function z:hasModData() return next(self.md) ~= nil end
        function z:getModData() return self.md end
        function z:isRemoteZombie() return self.remote end
        function z:isDead() return self.dead end
        function z:getTarget() return self.target end
        function z:setTarget(t) self.target = t end
        function z:getOnlineID() return self.onlineID end
        function z:getEmitter()
            return { playSound = function(_, name) z.sounds[#z.sounds + 1] = name; return 1 end }
        end
        G.zombies[#G.zombies + 1] = z
        return z
    end
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
                        if dist(z, p) <= 10 then z.target = p end -- spottedNew → setTarget
                    end
                end
            end
            for _, z in ipairs(G.zombies) do
                fire("OnZombieUpdate", z)
                if not z.remote then
                    local t = z.target
                    if t and dist(z, t) <= 1 then
                        t.bitten = t.bitten + 1
                    elseif t then
                        step(z, t.x, t.y)
                    elseif z.sound then
                        step(z, z.sound.x, z.sound.y)
                    end
                end
            end
        end
    end
    function G.sound(x, y) for _, z in ipairs(G.zombies) do z.sound = { x = x, y = y } end end
    function G.hit(z, p) fire("OnHitZombie", z, p, nil, nil) end
    function G.minutes(n) for _ = 1, n do fire("EveryOneMinute") end end

    instanceof = function(o, cls) return o.class == cls end
    ZombRand = function(n) return G.rand % n end
    isClient = function() return false end
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
    for _, m in ipairs({ "NOM_NightStats", "NOM_VariantAI" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_NightStats"
    NOM_NightStats.setNight(opts.night ~= false, 1)
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
        G.frame(30)
        assert(p.bitten == 0, "mordeu jogador agachado: " .. p.bitten)
        assert(z.target == nil and z.x == 0 and z.y == 0, "foi atrás de quem não fez barulho")
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
    -- amanhecer (flag já virou, o lote ainda não limpou a marca): nada de cego nem estalo
    ai_day_does_nothing = function()
        local G = setup({ night = false })
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
}
