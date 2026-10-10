-- Teto visual do Sem-rosto (bíblia §7.3): no máximo 1 em cada 6 num grupo
-- e 2 por tela. Excedentes continuam Sem-rosto no gameplay (som, sumir), mas
-- o look fica F1+S5. Sem API do jogo; ADR-006 (mesmo ID → mesma decisão).
NOM_SemRostoCap = {}
local C = NOM_SemRostoCap

C.MAX_SCREEN = 2
C.PER_GROUP = 6
C.CLUSTER_RADIUS = 8

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

-- Ordena cópia por id (estável entre clientes).
local function byId(entries)
    local out = {}
    for i = 1, #entries do out[i] = entries[i] end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Quantos zumbis do crowd estão no raio de p.
local function crowdNear(crowd, p, r2)
    local n = 0
    for i = 1, #crowd do
        if dist2(crowd[i], p) <= r2 then n = n + 1 end
    end
    return n
end

-- Devolve mapa [id]=true dos Sem-rosto que ganham look completo (variantes).
-- entries: { {id,x,y}, ... } só Sem-rosto; crowd: { {x,y}, ... } todos perto.
function C.fullLook(entries, crowd, opts)
    opts = opts or {}
    local maxScreen = opts.maxScreen or C.MAX_SCREEN
    local perGroup = opts.perGroup or C.PER_GROUP
    local radius = opts.radius or C.CLUSTER_RADIUS
    local r2 = radius * radius
    local full, accepted = {}, {}
    local sorted = byId(entries or {})
    for i = 1, #sorted do
        if #accepted >= maxScreen then break end
        local e = sorted[i]
        local nCrowd = crowdNear(crowd or {}, e, r2)
        local maxGroup = math.floor(nCrowd / perGroup)
        if maxGroup < 1 then
            -- grupo < PER_GROUP: ninguém full (só F1+S5)
        else
            local localFull = 0
            for j = 1, #accepted do
                if dist2(accepted[j], e) <= r2 then localFull = localFull + 1 end
            end
            if localFull < maxGroup then
                full[e.id] = true
                accepted[#accepted + 1] = e
            end
        end
    end
    return full
end

function C.isCapped(id, fullMap)
    return fullMap == nil or fullMap[id] ~= true
end

return NOM_SemRostoCap
