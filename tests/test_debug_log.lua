-- shared/NOM_DebugLog.lua (sprint 0046): o que o debug escreve vai pro console e fica nas últimas
-- linhas pro painel.
local function setup()
    package.loaded["NOM_DebugLog"] = nil
    NOM_DebugLog = nil
    local printed = {}
    local savedPrint = print
    print = function(s) printed[#printed + 1] = s end
    require "NOM_DebugLog"
    return printed, function() print = savedPrint end
end

return {
    debug_log_prints_and_keeps = function()
        local printed, restore = setup()
        local ok, err = pcall(function()
            NOM_DebugLog.say("[NOM] debug relâmpago em x=1 y=2")
            assert(printed[1] == "[NOM] debug relâmpago em x=1 y=2", "não imprimiu")
            local l = NOM_DebugLog.lines()
            assert(#l == 1 and l[1].text == "relâmpago em x=1 y=2", "linha: " .. tostring(l[1] and l[1].text))
            assert(l[1].kind == "reply")
            NOM_DebugLog.echo("Relâmpago agora")
            l = NOM_DebugLog.lines()
            assert(#l == 2 and l[2].text == "Relâmpago agora" and l[2].kind == "echo", "eco")
            assert(#printed == 1, "o eco não vai pro console")
        end)
        restore()
        assert(ok, err)
    end,
    debug_log_keeps_last_max = function()
        local _, restore = setup()
        local ok, err = pcall(function()
            for i = 1, NOM_DebugLog.MAX + 15 do NOM_DebugLog.say("[NOM] debug linha " .. i) end
            local l = NOM_DebugLog.lines()
            assert(#l == NOM_DebugLog.MAX, "guardou " .. #l)
            assert(l[1].text == "linha 16" and l[#l].text == "linha " .. (NOM_DebugLog.MAX + 15), l[1].text)
            local seq = NOM_DebugLog.seq()
            NOM_DebugLog.clear()
            assert(#NOM_DebugLog.lines() == 0)
            assert(NOM_DebugLog.seq() > seq, "limpar não avisa o painel")
        end)
        restore()
        assert(ok, err)
    end,
    -- texto sem o prefixo fica como veio; linha de várias partes (status) também
    debug_log_strips_only_debug_prefix = function()
        local _, restore = setup()
        local ok, err = pcall(function()
            NOM_DebugLog.say("[NOM] debug local noite=true")
            NOM_DebugLog.say("outra coisa")
            local l = NOM_DebugLog.lines()
            assert(l[1].text == "local noite=true" and l[2].text == "outra coisa")
        end)
        restore()
        assert(ok, err)
    end,
}
