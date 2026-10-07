-- Registro do debug (sprint 0046): tudo que o debug escreve ("[NOM] debug ...", do cliente e do
-- servidor) passa por say, que imprime no console como antes e guarda as últimas MAX linhas pro
-- painel (client/NOM_DebugPanel.lua). echo registra o clique de um botão, sem ir pro console.
-- No solo o servidor roda no mesmo processo e escreve aqui direto; no MP a resposta chega pelo
-- "debugReply" (client/NOM_Debug.lua).
NOM_DebugLog = { MAX = 60 }

local L = NOM_DebugLog
local PREFIX = "[NOM] debug "
local list, count = {}, 0

local function add(text, kind)
    list[#list + 1] = { text = text, kind = kind }
    if #list > L.MAX then table.remove(list, 1) end
    count = count + 1
end

function L.say(msg)
    msg = tostring(msg)
    print(msg)
    if msg:sub(1, #PREFIX) == PREFIX then msg = msg:sub(#PREFIX + 1) end
    add(msg, "reply")
end

function L.echo(text) add(tostring(text), "echo") end

function L.lines() return list end

-- Muda a cada linha nova e a cada limpeza: o painel só refaz o rodapé quando muda.
function L.seq() return count end

function L.clear()
    list = {}
    count = count + 1
end

return NOM_DebugLog
