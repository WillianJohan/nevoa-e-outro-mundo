-- client/NOM_ScreenFxOptions.lua contra um PZAPI.ModOptions falso que imita o
-- vanilla (client/PZAPI/ModOptions.lua): create(id, name) guarda em Dict;
-- addTickBox(id, name, value, tooltip) / addSlider(id, name, min, max, step, value,
-- tooltip) devolvem a opção com getValue; o load() (MainOptions.lua:2796, ao montar
-- a tela de opções, também no OnGameStart) troca option.value depois, e o "Aplicar"
-- da tela também. Por isso o mod lê getValue() toda vez, não guarda na carga.
local FILE = "mod/42/media/lua/client/NOM_ScreenFxOptions.lua"

local function fakeModOptions()
    local M = { Dict = {}, Data = {} }
    function M:create(id, name)
        local o = { id = id, name = name, dict = {}, data = {} }
        local function add(opt)
            opt.getValue = function(self) return self.value end
            o.dict[opt.id] = opt
            o.data[#o.data + 1] = opt
            return opt
        end
        function o:addTickBox(oid, n, value, tip) return add({ type = "tickbox", id = oid, name = n, value = value, tooltip = tip }) end
        function o:addSlider(oid, n, min, max, step, value, tip)
            return add({ type = "slider", id = oid, name = n, min = min, max = max, step = step, value = value, tooltip = tip })
        end
        -- addKeyBind(id, nome, tecla, dica) (ModOptions.lua:182-204): getValue devolve
        -- option.key; o load() e a tela de opções trocam option.key (:326-327, :276-280)
        function o:addKeyBind(oid, n, key, tip)
            local opt = add({ type = "keybind", id = oid, name = n, key = key, defaultkey = key, tooltip = tip })
            opt.getValue = function(self) return self.key end
            return opt
        end
        function o:getOption(oid) return self.dict[oid] end
        self.Dict[id] = o
        self.Data[#self.Data + 1] = o
        return o
    end
    function M:getOptions(id) return self.Dict[id] end
    return M
end

local function load(withApi, debug)
    _G.NOM_ScreenFxOptions = nil
    package.loaded.NOM_ScreenFxOptions = nil
    PZAPI = withApi and { ModOptions = fakeModOptions() } or nil
    isServer = function() return false end
    getDebug = function() return debug == true end
    -- org/lwjglx/input/Keyboard. F7 (65) abre o editor de veículos do vanilla em -debug
    -- (IngameState.updateInternal 547–606): o mod usa Insert (210)
    Keyboard = { KEY_F7 = 65, KEY_INSERT = 210 }
    dofile(FILE)
    return NOM_ScreenFxOptions
end

return {
    screenfx_options_registered_with_defaults = function()
        local O = load(true)
        local opts = PZAPI.ModOptions:getOptions("NevoaEOutroMundo")
        assert(opts, "sem página de opções do mod")
        local on, int = opts:getOption("ScreenFx"), opts:getOption("ScreenFxIntensity")
        assert(on.type == "tickbox" and on.value == true)
        assert(int.type == "slider" and int.min == 0 and int.max == 2 and int.value == 1)
        assert(opts.name:find("^UI_NOM_") and on.name:find("^UI_NOM_") and int.tooltip:find("^UI_NOM_"))
        assert(O.enabled() == true and O.intensity() == 1)
    end,

    -- o load() do ModOptions.ini e o "Aplicar" trocam o valor depois da carga
    screenfx_options_follow_changes = function()
        local O = load(true)
        local opts = PZAPI.ModOptions:getOptions("NevoaEOutroMundo")
        opts:getOption("ScreenFxIntensity").value = 1.5
        assert(O.intensity() == 1.5)
        opts:getOption("ScreenFx").value = false
        assert(O.enabled() == false and O.intensity() == 0, "desligado ainda tem intensidade")
        opts:getOption("ScreenFx").value = true
        opts:getOption("ScreenFxIntensity").value = 7
        assert(O.intensity() == 2, "fora da faixa")
    end,

    screenfx_options_without_api_use_defaults = function()
        local O = load(false)
        assert(O.enabled() == true and O.intensity() == 1)
        assert(O.overlayDensity() == 1)
    end,

    -- sprint 0015: densidade do sangue e da erosão, do jogador, na mesma página
    overlay_density_option = function()
        local O = load(true)
        local opt = PZAPI.ModOptions:getOptions("NevoaEOutroMundo"):getOption("FogOverlayDensity")
        assert(opt and opt.type == "slider" and opt.min == 0 and opt.max == 2 and opt.value == 1)
        assert(opt.name:find("^UI_NOM_") and opt.tooltip:find("^UI_NOM_"))
        assert(O.overlayDensity() == 1)
        opt.value = 1.7
        assert(O.overlayDensity() == 1.7)
        opt.value = -1
        assert(O.overlayDensity() == 0)
        opt.value = 5
        assert(O.overlayDensity() == 2)
    end,

    -- sprint 0018: dissolve (liga/desliga) e bloom do shader (0..2), do jogador
    dissolve_and_bloom_options = function()
        local O = load(true)
        local opts = PZAPI.ModOptions:getOptions("NevoaEOutroMundo")
        local d, b = opts:getOption("Dissolve"), opts:getOption("Bloom")
        assert(d and d.type == "tickbox" and d.value == true and d.name:find("^UI_NOM_") and d.tooltip:find("^UI_NOM_"))
        assert(b and b.type == "slider" and b.min == 0 and b.max == 2 and b.value == 1 and b.tooltip:find("^UI_NOM_"))
        assert(O.dissolve() == true and O.bloom() == 1)
        d.value = false
        b.value = 1.4
        assert(O.dissolve() == false and O.bloom() == 1.4)
        b.value = 9
        assert(O.bloom() == 2)
        local O2 = load(false)
        assert(O2.dissolve() == true and O2.bloom() == 1, "sem a API: padrão")
    end,

    -- sprint 0022: "Brasa no corpo inteiro", sub-opção do dissolve (ligada)
    body_embers_option = function()
        local O = load(true)
        local opts = PZAPI.ModOptions:getOptions("NevoaEOutroMundo")
        local e = opts:getOption("BodyEmbers")
        assert(e and e.type == "tickbox" and e.value == true and e.name:find("^UI_NOM_") and e.tooltip:find("^UI_NOM_"))
        assert(O.bodyEmbers() == true)
        e.value = false
        assert(O.bodyEmbers() == false)
        e.value = true
        opts:getOption("Dissolve").value = false
        assert(O.bodyEmbers() == false, "sem o dissolve não há casca")
        assert(load(false).bodyEmbers() == true, "sem a API: padrão")
    end,
    -- sprint 0020: tecla do painel de debug na mesma página, só com -debug
    screenfx_options_debug_key_only_in_debug = function()
        local O = load(true, true)
        local k = PZAPI.ModOptions:getOptions("NevoaEOutroMundo"):getOption("DebugPanel")
        assert(k and k.type == "keybind" and k.key == 210 and k.name:find("^UI_NOM_") and k.tooltip:find("^UI_NOM_"))
        assert(O.debugPanelKey() == 210)
        O = load(true, false)
        assert(PZAPI.ModOptions:getOptions("NevoaEOutroMundo"):getOption("DebugPanel") == nil, "tecla sem -debug")
        assert(O.debugPanelKey() == nil)
    end,
    screenfx_options_debug_key_follows_rebind = function()
        local O = load(true, true)
        PZAPI.ModOptions:getOptions("NevoaEOutroMundo"):getOption("DebugPanel").key = 88
        assert(O.debugPanelKey() == 88, "não seguiu a tecla trocada")
        O = load(false, true)
        assert(O.debugPanelKey() == 210, "sem a API: Insert")
    end,
}

