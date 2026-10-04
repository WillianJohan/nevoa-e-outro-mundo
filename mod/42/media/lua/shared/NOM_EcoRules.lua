-- Regras puras do Eco: sem API do jogo, testável com ./run-tests.sh.
NOM_EcoRules = {}

-- Por quantas noites o ID de um Eco fica guardado. Eco descarregado que volta
-- depois disso é zumbi comum com a roupa do Eco.
NOM_EcoRules.KEEP_NIGHTS = 7

function NOM_EcoRules.quota(cap, near)
    return math.max(0, cap - near)
end

-- cand = { x, y, z, released, ... } (posição do square do corpo). Devolve os
-- não liberados no andar pz a até radius de (px, py), mais perto primeiro, no
-- máximo quota.
function NOM_EcoRules.pick(cands, px, py, pz, radius, quota)
    local r2 = radius * radius
    local function dist2(c)
        local dx, dy = c.x - px, c.y - py
        return dx * dx + dy * dy
    end
    local out = {}
    for _, c in ipairs(cands) do
        if not c.released and c.z == pz and dist2(c) <= r2 then
            out[#out + 1] = c
        end
    end
    table.sort(out, function(a, b) return dist2(a) < dist2(b) end)
    for i = #out, quota + 1, -1 do
        out[i] = nil
    end
    return out
end

-- state = { night = número da noite, inNight = bool } salvo no ModData global.
-- Conta pelo estado, não pela borda: servidor que reinicia no meio da noite
-- continua na mesma noite.
function NOM_EcoRules.syncNight(state, isNight)
    if isNight and not state.inNight then
        state.night = (state.night or 0) + 1
    end
    state.inNight = isNight
    return state.night or 0
end

-- ids = { [persistentOutfitID] = { [noite] = true } }. Conjunto de noites porque
-- a semente é Rand.Next(500)+1: dois Ecos do mesmo sexo dividem o ID em ~19%
-- das noites, e um não pode apagar o outro.
function NOM_EcoRules.prune(ids, night)
    local oldest = night - NOM_EcoRules.KEEP_NIGHTS
    for id, nights in pairs(ids) do
        for n in pairs(nights) do
            if n <= oldest then nights[n] = nil end
        end
        if next(nights) == nil then ids[id] = nil end
    end
end

-- Regra do GDD: ao amanhecer todos os Ecos somem, onde quer que estejam.
function NOM_EcoRules.keepReloaded(nights, night, isNight)
    return isNight and nights ~= nil and nights[night] == true
end

return NOM_EcoRules
