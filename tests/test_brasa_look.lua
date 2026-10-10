-- Cliente NOM_BrasaLook: pulso fora do setAlpha (dissolve / visibilidade intactos).
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
        assert(src:find("pulseChannel", 1, true), "usa canal de pulso das regras")
        assert(src:find("getReadyModelData", 1, true)
            or src:find("setTint", 1, true),
            "escreve TintColour via ModelInstance ou ItemVisual:setTint")
        assert(src:find("Dissolve.busy", 1, true), "cede o Alpha quando dissolve está ativo")
    end,
}
