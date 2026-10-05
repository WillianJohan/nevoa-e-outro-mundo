-- client/NOM_FogVignette.lua contra um SearchMode/ISSearchManager falso que imita
-- o jogo:
-- * getSearchMode():setEnabled(pn, b) / isEnabled(pn); getSearchModeForPlayer(pn)
--   com getBlur/getDesat/getRadius/getDarkness/getGradientWidth → SearchModeFloat
--   com setTargets(ext, int) (bytecode SearchMode; ISSearchMode.lua:38-42, 268-270).
-- * ISSearchManager.getManager(player) (client/Foraging/ISSearchManager.lua:68).
-- * manager:updateOverlay() (:1055-1090): volta cedo com isOverride; senão reescreve
--   os alvos com os do forrageamento e faz setEnabled(pn, isSearchMode or
--   isEffectOverlay) — é o que desligaria a vinheta. O fake roda a cada tick.
-- * manager.isSearchMode é o forrageamento (:1416-1428).
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogVignette.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_FogVignette" })
    require "NOM_FogState"
    G.enabled, G.targets, G.managers = {}, {}, {}
    local function float(pn, name)
        return { setTargets = function(_, ext, int)
            G.targets[pn] = G.targets[pn] or {}
            G.targets[pn][name] = { ext, int }
        end }
    end
    getSearchMode = function()
        return {
            setEnabled = function(_, pn, b) G.enabled[pn] = b end,
            isEnabled = function(_, pn) return G.enabled[pn] == true end,
            getSearchModeForPlayer = function(_, pn)
                return {
                    getBlur = function() return float(pn, "blur") end,
                    getDesat = function() return float(pn, "desat") end,
                    getRadius = function() return float(pn, "radius") end,
                    getDarkness = function() return float(pn, "darkness") end,
                    getGradientWidth = function() return float(pn, "gradient") end,
                }
            end,
        }
    end
    ISSearchManager = {
        getManager = function(p)
            if not G.managers[p] then
                local m = { isOverride = false, isSearchMode = false, isEffectOverlay = false, pn = p:getPlayerNum() }
                function m:updateOverlay()
                    if self.isOverride then return end
                    local f = getSearchMode():getSearchModeForPlayer(self.pn)
                    f:getDarkness():setTargets(0.1, 0.1)
                    getSearchMode():setEnabled(self.pn, self.isSearchMode or self.isEffectOverlay)
                end
                G.managers[p] = m
            end
            return G.managers[p]
        end,
    }
    dofile(FILE)
    -- o jogo roda o updateOverlay do vanilla depois do nosso tick
    Events.OnTick.Add(function()
        for _, m in pairs(G.managers) do m:updateOverlay() end
    end)
    G.p = G.player({ x = 100, y = 100 })
    return G
end

return {
    vignette_inert_on_dedicated = function()
        local G = setup({ server = true })
        G.seconds(2)
        assert(G.enabled[0] == nil and next(G.targets) == nil)
    end,
    -- critério do spike: liga na névoa e o updateOverlay do vanilla não desliga
    vignette_on_in_fog_survives_update_overlay = function()
        local G = setup()
        G.seconds(2)
        assert(G.enabled[0] ~= true, "vinheta sem névoa")
        NOM_FogState.set(true, 1)
        G.seconds(60)
        assert(G.enabled[0] == true, "vinheta desligada")
        local want = NOM_AtmosphereRules.vignette(1)
        assert(G.targets[0].darkness[1] == want.darkness and G.targets[0].radius[1] == want.radius)
        assert(G.managers[G.p].isOverride == true)
    end,
    -- forragear durante a névoa: a vinheta sai da frente, depois volta
    vignette_yields_to_foraging = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(2)
        local m = G.managers[G.p]
        m.isSearchMode = true
        G.seconds(2)
        assert(m.isOverride == false, "segurou o override com o jogador forrageando")
        assert(G.enabled[0] == true and G.targets[0].darkness[1] == 0.1, "forrageamento sem os valores do vanilla")
        m.isSearchMode = false
        G.seconds(2)
        assert(m.isOverride == true and G.enabled[0] == true and G.targets[0].darkness[1] == NOM_AtmosphereRules.vignette(1).darkness,
            "não voltou depois do forrageamento")
    end,
    -- névoa acaba: tudo como o vanilla deixaria
    vignette_restores_on_fog_end = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(2)
        NOM_FogState.set(false, 1)
        G.seconds(1)
        assert(G.managers[G.p].isOverride == false and G.enabled[0] == false, "vinheta ficou")
        -- mesmo se o vanilla não rodar o updateOverlay (painel invisível: UNKNOWN)
        local G2 = setup()
        NOM_FogState.set(true, 1)
        G2.seconds(2)
        G2.managers[G2.p].updateOverlay = function() end
        NOM_FogState.set(false, 1)
        G2.seconds(1)
        assert(G2.enabled[0] == false, "dependeu do vanilla pra desligar")
        -- forrageou depois que a névoa acabou: é do vanilla, não mexe
        G2.managers[G2.p].isSearchMode = true
        G2.enabled[0] = true
        G2.seconds(1)
        assert(G2.enabled[0] == true)
    end,
    vignette_off_toggle = function()
        for _, sb in ipairs({ { FogVignette = false }, { FogVignetteIntensity = 0 } }) do
            local G = setup({ sandbox = sb })
            NOM_FogState.set(true, 1)
            G.seconds(5)
            assert(G.enabled[0] ~= true and G.managers[G.p] == nil or G.managers[G.p].isOverride == false, "ligou desligada")
        end
    end,
    -- override de outro (OnOverrideSearchManager, outro mod) fica como estava
    vignette_keeps_foreign_override = function()
        local G = setup()
        local m = ISSearchManager.getManager(G.p)
        m.isOverride = true
        G.enabled[0] = false
        NOM_FogState.set(true, 1)
        G.seconds(2)
        assert(G.enabled[0] == true)
        NOM_FogState.set(false, 1)
        G.seconds(1)
        assert(m.isOverride == true, "apagou o override de outro")
        assert(G.enabled[0] == false, "não devolveu o enabled de antes")
    end,
}
