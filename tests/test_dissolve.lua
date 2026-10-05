-- client/NOM_Dissolve.lua (sprint 0018) contra um zumbi falso com o alfa do jogo
-- (bytecode B42.21):
-- * IsoObject.alpha[] e targetAlpha[] por jogador; setAlpha(pn, a) faz clamp 0..1 e sai
--   no servidor (setAlpha(IF) 0–39); getAlpha(pn) lê (0–14).
-- * O alvo vem da visão (IsoPlayer.updateLOS 1097–1110: 1 se vê, 0 se não) e
--   IsoObject.updateAlpha(IFF) 79–188 anda 0,28·multiplicador por update na direção
--   dele, no update do mundo; IsoGameCharacter.isUpdateAlphaDuringRender = false.
-- * Ordem do quadro: mundo (updateAlpha) → OnTick (IngameState.updateInternal 1067 →
--   1331) → render (ModelSlotRenderData.init 623–626 lê getAlpha(pn)).
-- * Zumbi que sai do mundo (corpo, removeFromSquare) fica sem square.
local FILE = "mod/42/media/lua/client/NOM_Dissolve.lua"

local function setup(opts)
    opts = opts or {}
    local G = { now = 1759999999000, calls = 0, zombies = {}, players = opts.players or 1, on = opts.on ~= false }
    local handlers = {}
    function G.fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    Events = setmetatable({}, { __index = function(t, name)
        local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
        rawset(t, name, e)
        return e
    end })
    isServer = function() return opts.server == true end
    isClient = function() return false end
    getDebug = function() return false end
    getTimestampMs = function() return G.now end
    getNumActivePlayers = function() G.calls = G.calls + 1; return G.players end
    NOM_ScreenFxOptions = { dissolve = function() return G.on end }
    package.loaded.NOM_ScreenFxOptions = NOM_ScreenFxOptions
    _G.NOM_Dissolve = nil
    package.loaded.NOM_Dissolve = nil
    require "NOM_DissolveRules"
    dofile(FILE)

    function G.zombie(o)
        o = o or {}
        local z = { alpha = {}, seen = {}, drawn = {}, sq = true, throw = false }
        for pn = 0, 3 do
            z.alpha[pn] = o.alpha or 1
            z.seen[pn] = o.seen ~= false
        end
        local function c()
            G.calls = G.calls + 1
            if z.throw then error("API falhou") end
        end
        function z:setAlpha(pn, a)
            c()
            assert(type(pn) == "number" and type(a) == "number", "setAlpha(IF)")
            if opts.server then return end
            self.alpha[pn] = math.max(0, math.min(1, a))
        end
        function z:getAlpha(pn) c(); return self.alpha[pn] end
        function z:getCurrentSquare() c(); return self.sq and {} or nil end
        function z:isDead() c(); return self.dead == true end
        G.zombies[#G.zombies + 1] = z
        return z
    end
    -- um quadro: mundo, OnTick, render; ~60 quadros por segundo
    function G.frame(n)
        for _ = 1, n or 1 do
            for _, z in ipairs(G.zombies) do
                for pn = 0, G.players - 1 do
                    local target = z.seen[pn] and 1 or 0
                    local a = z.alpha[pn]
                    if a < target then a = math.min(target, a + 0.28) else a = math.max(target, a - 0.28) end
                    z.alpha[pn] = a
                end
            end
            G.fire("OnTick", 0)
            for _, z in ipairs(G.zombies) do
                for pn = 0, G.players - 1 do z.drawn[pn] = z.alpha[pn] end
            end
            G.now = G.now + 16
        end
    end
    function G.ms(ms) G.frame(math.ceil(ms / 16)) end
    return G
end

local R

return {
    dissolve_inert_on_dedicated = function()
        local G = setup({ server = true })
        assert(NOM_Dissolve == nil, "carregou no dedicado")
        assert(G)
    end,

    -- "in": a peça se forma com o corpo sempre na faixa, e no fim o jogo volta a mandar
    dissolve_in_alpha_in_band_each_frame = function()
        local G = setup()
        R = NOM_DissolveRules
        local z = G.zombie()
        local ended = 0
        assert(NOM_Dissolve.run(z, "in", function(x) assert(x == z); ended = ended + 1 end))
        local last = 0
        local n = 0
        while NOM_Dissolve.busy(z) do
            G.frame(1)
            n = n + 1
            assert(z.drawn[0] >= R.BAND - 1e-9 and z.drawn[0] <= 1, "fora da faixa: " .. z.drawn[0])
            assert(z.drawn[0] >= last - 1e-9, "voltou")
            last = z.drawn[0]
            assert(n < 200, "não acaba")
        end
        assert(n >= 55 and n <= 70, "durou " .. n .. " quadros")
        assert(ended == 1 and last == 1)
        G.calls = 0
        G.frame(5)
        assert(G.calls == 0, "ainda mexe no alfa")
    end,

    -- quem não está à vista não aparece: nunca acima do que o jogo deixou
    dissolve_never_reveals_unseen_zombie = function()
        local G = setup()
        local z = G.zombie({ alpha = 0, seen = false })
        NOM_Dissolve.run(z, "in")
        G.ms(500)
        assert(z.drawn[0] == 0, "zumbi fora da vista apareceu: " .. z.drawn[0])
        local w = G.zombie()
        NOM_Dissolve.run(w, "out")
        G.ms(200)
        w.seen[0] = false -- saiu da vista no meio
        G.ms(200)
        assert(w.drawn[0] < NOM_DissolveRules.BAND - 0.2, "segurou o alfa de quem saiu da vista")
    end,

    dissolve_each_local_player = function()
        local G = setup({ players = 2 })
        local z = G.zombie()
        NOM_Dissolve.run(z, "out")
        G.ms(300)
        assert(z.drawn[0] < 1 and math.abs(z.drawn[0] - z.drawn[1]) < 1e-9, "tela dividida diferente")
    end,

    dissolve_cap = function()
        local G = setup()
        local R2 = NOM_DissolveRules
        local zs = {}
        for i = 1, R2.CAP do
            zs[i] = G.zombie()
            assert(NOM_Dissolve.run(zs[i], "in"), "negou antes do teto")
        end
        local extra = G.zombie()
        assert(not NOM_Dissolve.run(extra, "in"), "passou do teto")
        assert(NOM_Dissolve.run(zs[1], "out"), "trocar o efeito de quem já está não conta como novo")
        assert(NOM_Dissolve.count() == R2.CAP)
        G.ms(R2.MS + 100)
        assert(NOM_Dissolve.count() == 0 and NOM_Dissolve.run(extra, "in"), "não liberou o teto")
    end,

    -- troca no meio parte do limiar atual, e o callback do efeito velho não roda
    dissolve_replace_from_current = function()
        local G = setup()
        local z = G.zombie()
        local outEnded = false
        NOM_Dissolve.run(z, "out", function() outEnded = true end)
        G.ms(400)
        local a = z.drawn[0]
        NOM_Dissolve.run(z, "in")
        G.frame(1)
        assert(math.abs(z.drawn[0] - a) < 0.01, "pulou: " .. a .. " → " .. z.drawn[0])
        G.ms(1200)
        assert(not outEnded and not NOM_Dissolve.busy(z) and z.drawn[0] == 1)
    end,

    dissolve_death_reaches_zero = function()
        local G = setup()
        local z = G.zombie()
        local ended = false
        NOM_Dissolve.run(z, "death", function() ended = true end)
        G.ms(NOM_DissolveRules.MS + NOM_DissolveRules.FADE_MS - 100)
        assert(z.drawn[0] < 0.3)
        G.ms(1000)
        assert(z.drawn[0] == 0 and not ended, "o Eco ainda caindo voltou a aparecer")
        G.ms(NOM_DissolveRules.HOLD_MS)
        assert(ended, "segurou pra sempre")
    end,

    -- corpo nasceu (o zumbi sai do square): limpa e chama o fim
    dissolve_removed_zombie_cleaned = function()
        local G = setup()
        local z = G.zombie()
        local ended = false
        NOM_Dissolve.run(z, "death", function() ended = true end)
        G.ms(100)
        z.sq = false
        G.frame(1)
        assert(ended and not NOM_Dissolve.busy(z))
    end,

    -- reaproveitamento e menu principal: some sem chamar o fim
    dissolve_reuse_and_menu_clean = function()
        local G = setup()
        local z, w = G.zombie(), G.zombie()
        local ended = false
        NOM_Dissolve.run(z, "out", function() ended = true end)
        NOM_Dissolve.run(w, "out", function() ended = true end)
        G.fire("OnZombieCreate", z)
        assert(not NOM_Dissolve.busy(z) and NOM_Dissolve.busy(w))
        G.fire("OnMainMenuEnter")
        assert(NOM_Dissolve.count() == 0 and not ended)
        NOM_Dissolve.stop(z) -- parar o que não tem efeito: nada
    end,

    dissolve_disabled = function()
        local G = setup({ on = false })
        local z = G.zombie()
        assert(not NOM_Dissolve.enabled() and not NOM_Dissolve.run(z, "in"))
        G.calls = 0
        G.frame(3)
        assert(G.calls == 0)
    end,

    -- uma surpresa da API num zumbi tira só o efeito dele, e o resto segue
    dissolve_api_error_drops_effect = function()
        local G = setup()
        local z, w = G.zombie(), G.zombie()
        NOM_Dissolve.run(z, "out")
        NOM_Dissolve.run(w, "out")
        z.throw = true
        G.frame(1)
        assert(not NOM_Dissolve.busy(z) and NOM_Dissolve.busy(w))
        G.frame(2)
        assert(w.drawn[0] < 1)
    end,

    -- review da 0022: o erro também chama o fim, pra quem pôs alguma coisa no zumbi (a casca de
    -- brasa) tirar; o alfa fica com o jogo
    dissolve_api_error_still_calls_done = function()
        local G = setup()
        local z = G.zombie()
        local got
        NOM_Dissolve.run(z, "out", function(x) got = x end)
        z.throw = true
        G.frame(1)
        assert(got == z and not NOM_Dissolve.busy(z), "o fim não rodou no erro")
    end,

    -- orçamento: sem efeito, zero; com E efeitos e P jogadores, ≤ 1 + E·(1 + 2P) por tick
    dissolve_budget = function()
        local G = setup({ players = 2 })
        G.zombie()
        G.calls = 0
        G.frame(10)
        assert(G.calls == 0, "sem efeito custou " .. G.calls)
        local zs = {}
        for i = 1, 5 do
            zs[i] = G.zombie()
            NOM_Dissolve.run(zs[i], "in")
        end
        G.calls = 0
        G.frame(1)
        assert(G.calls <= 1 + 5 * (1 + 2 * 2), "custou " .. G.calls)
    end,

    -- review da 0018: morto e ainda no square (animação de morte longa), o teto não solta o
    -- alfa: soltar traria o Eco de volta na casca. Só sai quando deixa o square
    dissolve_death_holds_while_dead_on_square = function()
        local G = setup()
        local R2 = NOM_DissolveRules
        local z = G.zombie()
        z.dead = true
        local ended = false
        NOM_Dissolve.run(z, "death", function() ended = true end)
        G.ms(R2.MS + R2.FADE_MS + R2.HOLD_MS + 500)
        assert(not ended and NOM_Dissolve.busy(z) and z.drawn[0] == 0, "soltou o Eco morto ainda caindo")
        z.sq = false
        G.frame(1)
        assert(ended and not NOM_Dissolve.busy(z))
        -- vivo (não devia acontecer): o teto ainda solta
        local w = G.zombie()
        NOM_Dissolve.run(w, "death")
        G.ms(R2.MS + R2.FADE_MS + R2.HOLD_MS + 100)
        assert(not NOM_Dissolve.busy(w), "o teto não soltou o vivo")
    end,

    -- morto que nunca vira corpo não segura uma vaga pra sempre: depois de BACKSTOP_MS solta
    dissolve_death_backstop = function()
        local G = setup()
        local R2 = NOM_DissolveRules
        assert(R2.BACKSTOP_MS == 30000)
        local z = G.zombie()
        z.dead = true
        NOM_Dissolve.run(z, "death")
        G.ms(R2.BACKSTOP_MS - 1000)
        assert(NOM_Dissolve.busy(z) and z.drawn[0] == 0)
        G.ms(2000)
        assert(not NOM_Dissolve.busy(z) and NOM_Dissolve.count() == 0, "segurou a vaga depois do teto longo")
    end,
}
