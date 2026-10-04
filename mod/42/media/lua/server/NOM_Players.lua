-- Jogadores do lado do servidor, em solo e no dedicado.
if isClient() then return end

NOM_Players = {}

-- Padrão de server/XpSystem/XpUpdate.lua:294-297.
function NOM_Players.all()
    local out = {}
    if isServer() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    else
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p then out[#out + 1] = p end
        end
    end
    return out
end

return NOM_Players
