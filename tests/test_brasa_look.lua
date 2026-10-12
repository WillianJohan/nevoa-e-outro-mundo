-- Cliente NOM_BrasaLook: pulso fora do setAlpha; ModelInstance não é usável no Lua.
local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

return {
    brasa_look_no_set_alpha = function()
        local src = assert(read("mod/42/media/lua/client/NOM_BrasaLook.lua"))
        assert(not src:find("setAlpha", 1, true),
            "pulso não pode passar por z:setAlpha (cede Alpha ao NOM_Dissolve)")
        assert(src:find("setTint", 1, true), "TintColour via ItemVisual:setTint no vestir")
        assert(src:find("Dissolve.busy", 1, true), "cede o Alpha quando dissolve está ativo")
    end,

    -- console 2026-10-10: ModelInstance fora do Exposer → index of non-table.
    brasa_look_no_model_instance_api = function()
        local src = assert(read("mod/42/media/lua/client/NOM_BrasaLook.lua"))
        assert(not src:find("getReadyModelData", 1, true),
            "getReadyModelData devolve ModelInstance inacessível")
        assert(not src:find(":getItemVisual(", 1, true),
            "mi:getItemVisual quebra o OnTick")
        assert(not src:find("tintR", 1, true), "campos de ModelInstance não são Lua")
    end,

    -- playtest 01/03: resetModel a cada degrau do pulso = monstro sem andar.
    brasa_look_no_per_tick_pulse_reset = function()
        local src = assert(read("mod/42/media/lua/client/NOM_BrasaLook.lua"))
        assert(not src:find("applyPulseChannel", 1, true),
            "canal de pulso por tick removido")
        assert(not src:find("quantizeChannel", 1, true),
            "quantize+reset no tick removido")
        assert(src:find("syncLightHold", 1, true),
            "só reset na transição lanterna/escuro")
    end,
}
