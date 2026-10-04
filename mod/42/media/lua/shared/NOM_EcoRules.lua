-- Regras puras do Eco: sem API do jogo, testável com ./run-tests.sh.
NOM_EcoRules = {}

-- persistentOutfitID (bytecode PersistentOutfits): bit 31 = feminino, bits 16-30 =
-- índice do outfit, bits 0-15 = semente. A chave tira a semente e fica com
-- outfit + sexo. 0 significa "sem outfit" e nunca vira chave.
function NOM_EcoRules.outfitKey(id)
    if not id or id == 0 then
        return nil
    end
    return math.floor(id / 65536)
end

function NOM_EcoRules.quota(cap, near)
    return math.max(0, cap - near)
end

-- cand = { dist2, animal, released, eco, ... }. Devolve os elegíveis, mais perto
-- primeiro, no máximo quota.
function NOM_EcoRules.pick(cands, radius, quota)
    local r2 = radius * radius
    local out = {}
    for _, c in ipairs(cands) do
        if not c.animal and not c.released and not c.eco and c.dist2 <= r2 then
            out[#out + 1] = c
        end
    end
    table.sort(out, function(a, b) return a.dist2 < b.dist2 end)
    for i = #out, quota + 1, -1 do
        out[i] = nil
    end
    return out
end

return NOM_EcoRules
