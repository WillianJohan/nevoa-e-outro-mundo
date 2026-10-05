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
        function o:getOption(oid) return self.dict[oid] end
        self.Dict[id] = o
        self.Data[#self.Data + 1] = o
        return o
    end
    function M:getOptions(id) return self.Dict[id] end
    return M
end

local function load(withApi)
    _G.NOM_ScreenFxOptions = nil
    package.loaded.NOM_ScreenFxOptions = nil
    PZAPI = withApi and { ModOptions = fakeModOptions() } or nil
    isServer = function() return false end
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
    end,
}
