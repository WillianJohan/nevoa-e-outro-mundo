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
-- * Canal do shader (sprint 0013, bytecode SearchMode/PlayerSearchMode):
--   setOverride(pn, b) só grava o flag; com override, PlayerSearchMode.update sai na
--   1ª linha (nem o fade anda); setEnabled(pn, false) com enabled ligado começa o
--   fade de saída (FadeOut), e isShaderEnabled() = enabled ou fade em andamento;
--   SearchModeFloat.setAll(v) grava atual e alvo. O fake roda o update todo tick.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogVignette.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_FogVignette", "NOM_ScreenFx", "NOM_ScreenFxOptions", "NOM_ScreenFxRules",
        "NOM_SemRosto", "NOM_Carpideira", "NOM_NightStats" })
    PZAPI = nil
    NOM_ShaderMod = opts.shader
    require "NOM_FogState"
    -- bloom do jogador (sprint 0018): 0 nos testes da 0013, que são o canal só da névoa
    require "NOM_ScreenFxOptions"
    G.bloom = opts.bloom or 0
    if NOM_ScreenFxOptions then NOM_ScreenFxOptions.bloom = function() return G.bloom end end
    G.enabled, G.targets, G.managers, G.override, G.fading, G.all = {}, {}, {}, {}, {}, {}
    G.FADE_TICKS = 30
    local function float(pn, name)
        return { setAll = function(_, v)
            G.all[pn] = G.all[pn] or {}
            G.all[pn][name] = v
        end, setTargets = function(_, ext, int)
            G.targets[pn] = G.targets[pn] or {}
            G.targets[pn][name] = { ext, int }
        end }
    end
    getSearchMode = function()
        return {
            setEnabled = function(_, pn, b)
                -- FadeOut: o fade anda por SearchMode.fadeTime, aqui ~FADE_TICKS ticks
                if not b and G.enabled[pn] then G.fading[pn] = G.FADE_TICKS end
                G.enabled[pn] = b
            end,
            setOverride = function(_, pn, b) G.override[pn] = b end,
            isOverride = function(_, pn) return G.override[pn] == true end,
            isEnabled = function(_, pn) return G.enabled[pn] == true end,
            getSearchModeForPlayer = function(_, pn)
                return {
                    isShaderEnabled = function() return G.enabled[pn] == true or G.fading[pn] ~= nil end,
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
        -- SearchMode.update (IngameState.UpdateStuff): com override não anda
        for pn in pairs(G.fading) do
            if not G.override[pn] then
                G.fading[pn] = G.fading[pn] - 1
                if G.fading[pn] <= 0 then G.fading[pn] = nil end
            end
        end
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
    -- sprint 0034: a vinheta escurece já na subida da sirene e sai se ela for cancelada
    vignette_on_while_rising = function()
        local G = setup()
        NOM_FogState.setRising(true)
        G.seconds(2)
        assert(G.enabled[0] == true and G.managers[G.p].isOverride == true, "vinheta sem a subida")
        NOM_FogState.setRising(false)
        G.seconds(1)
        assert(G.managers[G.p].isOverride == false and G.enabled[0] == false, "vinheta ficou depois da subida")
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
    -- o override de antes mudou no meio (handleOverride): não escreve o velho de volta
    vignette_release_does_not_restore_stale_override = function()
        local G = setup()
        local m = ISSearchManager.getManager(G.p)
        m.isOverride = true -- de outro
        NOM_FogState.set(true, 1)
        G.seconds(2)
        m.isOverride = false -- o outro soltou (ISSearchManager.handleOverride, :1449-1456)
        NOM_FogState.set(false, 1)
        G.seconds(1)
        assert(m.isOverride == false, "escreveu de volta o override velho")
    end,
    vignette_intensity_change_mid_fog = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(2)
        SandboxVars.NevoaEOutroMundo.FogVignetteIntensity = 2
        G.seconds(2)
        assert(G.targets[0].darkness[1] == NOM_AtmosphereRules.vignette(2).darkness, "intensidade nova não aplicou")
    end,
    -- sem o mod do shader, nada de override do SearchMode (só a vinheta)
    vignette_no_channel_without_shader_mod = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(6)
        assert(G.override[0] ~= true and G.all[0] == nil)
    end,
    -- com o shader: enabled nunca liga (o ramo vanilla do círculo ficaria por cima),
    -- override ligado, o canal carrega a névoa e o marcador, todo tick
    vignette_channel_writes_floats = function()
        local G = setup({ shader = true })
        NOM_FogState.set(true, 1)
        G.seconds(1)
        assert(G.override[0] == true and G.managers[G.p].isOverride == true, "não tomou o SearchMode")
        local a = G.all[0].blur
        G.tick(1)
        assert(G.all[0].blur > a, "canal não anda todo tick")
        G.seconds(5)
        local c = G.all[0]
        assert(G.enabled[0] ~= true, "ligou o SearchMode com o shader")
        assert(c.blur == 1 and c.desat == 0 and c.radius == 0 and c.gradient == NOM_ScreenFxRules.MARKER, "canal errado")
        NOM_FogState.set(true, 1, true)
        G.seconds(5)
        assert(G.all[0].desat == 1, "vermelha não chegou ao canal")
    end,
    -- review final da 0034: com o shader a vinheta também sobe na fuga (visible), na cor da
    -- subida (visibleRed); as camadas do Outro Mundo (NOM_ScreenFx) seguem esperando a névoa
    vignette_channel_rises_with_siren = function()
        local G = setup({ shader = true })
        NOM_FogState.setRising(true, true)
        G.seconds(5)
        assert(G.override[0] == true and G.all[0] and G.all[0].blur == 1, "o canal não subiu na fuga")
        assert(G.all[0].desat == 1, "a subida vermelha não chegou ao canal")
        assert(NOM_ScreenFx.state.fog == 0 and NOM_ScreenFx.state.red == 0, "o Outro Mundo da tela abriu na fuga")
        NOM_FogState.setRising(false)
        G.seconds(NOM_ScreenFxRules.FADE_MS / 1000 + 1)
        assert(G.override[0] == false and G.all[0].blur == 0, "segurou o canal depois da sirene cancelada")
    end,
    -- override com fade do forrageamento em andamento congelaria o fade (isShaderEnabled
    -- preso em true): espera acabar
    vignette_channel_waits_for_search_fade = function()
        local G = setup({ shader = true })
        G.override[0] = true -- outro segurou o SearchMode no meio de um fade
        G.enabled[0] = true
        getSearchMode():setEnabled(0, false)
        NOM_FogState.set(true, 1)
        G.seconds(1)
        assert(G.all[0] == nil, "tomou no meio do fade")
        G.override[0] = false
        G.tick(G.FADE_TICKS - 12)
        assert(G.all[0] == nil, "tomou antes do fade acabar")
        G.seconds(1)
        assert(G.override[0] == true and G.all[0] and G.all[0].blur > 0, "não tomou depois do fade")
    end,
    -- Review Focus 4: forragear com o shader: o canal sai, zerado, e o jogo volta normal
    vignette_channel_releases_for_foraging = function()
        local G = setup({ shader = true })
        NOM_FogState.set(true, 1)
        G.seconds(5)
        local m = G.managers[G.p]
        m.isSearchMode = true
        G.seconds(1)
        assert(G.override[0] == false and m.isOverride == false, "segurou com o jogador forrageando")
        assert(G.all[0].blur == 0 and G.all[0].darkness == 0, "deixou o canal no círculo do forrageamento")
        assert(G.enabled[0] == true and G.targets[0].darkness[1] == 0.1, "o forrageamento não voltou")
        m.isSearchMode = false
        G.seconds(2)
        assert(G.override[0] == true and G.all[0].blur > 0, "não voltou depois do forrageamento")
    end,
    vignette_channel_restores_on_fog_end = function()
        local G = setup({ shader = true })
        NOM_FogState.set(true, 1)
        G.seconds(5)
        NOM_FogState.set(false, 1)
        G.seconds(1)
        assert(G.override[0] == true and G.all[0].blur > 0, "cortou sem o fade de saída")
        G.seconds(NOM_ScreenFxRules.FADE_MS / 1000 + 1)
        assert(G.override[0] == false and G.managers[G.p].isOverride == false, "segurou depois da névoa")
        assert(G.all[0].blur == 0)
    end,
    -- o sandbox do servidor ainda manda: FogVignette desligada = sem canal;
    -- FogVignetteIntensity escala o canal junto com a opção do jogador
    vignette_channel_follows_sandbox = function()
        local G = setup({ shader = true, sandbox = { FogVignette = false } })
        NOM_FogState.set(true, 1)
        G.seconds(6)
        assert(G.override[0] ~= true and G.all[0] == nil, "canal com a vinheta desligada no sandbox")
        local G2 = setup({ shader = true, sandbox = { FogVignetteIntensity = 0.5 } })
        NOM_FogState.set(true, 1)
        G2.seconds(6)
        assert(math.abs(G2.all[0].blur - 0.5) < 1e-9, "não escalou: " .. tostring(G2.all[0].blur))
        SandboxVars.NevoaEOutroMundo.FogVignetteIntensity = 0
        G2.seconds(1)
        assert(G2.override[0] == false, "segurou com intensidade 0 no sandbox")
    end,

    -- Sprint 0018: bloom do shader -------------------------------------------------------

    -- fora da névoa, só pelo bloom: canal tomado, sem efeito da névoa, bloom no marcador
    vignette_channel_bloom_outside_fog = function()
        local G = setup({ shader = true, bloom = 1.2 })
        G.seconds(2)
        assert(G.override[0] == true and G.enabled[0] ~= true, "não tomou o canal pro bloom")
        local c = G.all[0]
        assert(c.blur == 0 and c.darkness == 0 and c.desat == 0)
        assert(math.abs(c.gradient - (NOM_ScreenFxRules.MARKER + 1.2 * NOM_ScreenFxRules.BLOOM_SCALE)) < 1e-9, "marcador " .. c.gradient)
        G.bloom = 0.5 -- o jogador mexeu na opção
        G.tick(1)
        assert(math.abs(G.all[0].gradient - (NOM_ScreenFxRules.MARKER + 0.5 * NOM_ScreenFxRules.BLOOM_SCALE)) < 1e-9)
        G.bloom = 0
        G.seconds(1)
        assert(G.override[0] == false and G.all[0].gradient == 0, "segurou o canal sem bloom e sem névoa")
    end,

    vignette_channel_bloom_yields_to_foraging = function()
        local G = setup({ shader = true, bloom = 1 })
        G.seconds(1)
        local m = G.managers[G.p]
        m.isSearchMode = true
        G.seconds(1)
        assert(G.override[0] == false and m.isOverride == false, "segurou com o jogador forrageando")
        assert(G.enabled[0] == true, "o forrageamento não voltou")
        m.isSearchMode = false
        G.seconds(2)
        assert(G.override[0] == true, "não voltou depois do forrageamento")
    end,

    -- o sandbox desliga a vinheta da névoa, não o bloom do jogador
    vignette_channel_bloom_with_sandbox_vignette_off = function()
        local G = setup({ shader = true, bloom = 1, sandbox = { FogVignette = false } })
        NOM_FogState.set(true, 1)
        G.seconds(6)
        assert(G.override[0] == true and G.all[0].blur == 0, "a névoa voltou pelo bloom")
        assert(G.all[0].gradient > NOM_ScreenFxRules.MARKER)
    end,

    vignette_bloom_needs_shader_mod = function()
        local G = setup({ bloom = 2 })
        G.seconds(2)
        assert(G.override[0] ~= true and G.all[0] == nil)
    end,
}
