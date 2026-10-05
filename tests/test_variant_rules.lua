require "NOM_VariantRules"

local R = NOM_VariantRules

-- Todas as variantes saem do MESMO sorteio por período de névoa (decisão do Johan,
-- 05/10): faixas contíguas na ordem de NOM_VariantRules.KINDS.
local function cfg(o)
    local c = { estaladorOn = true, corredorOn = true, semRostoOn = true, carpideiraOn = true,
        estaladorChance = 5, corredorChance = 10, semRostoChance = 5, carpideiraChance = 0 }
    for k, v in pairs(o or {}) do c[k] = v end
    return c
end

-- persistentOutfitID como o jogo monta (PersistentOutfits.pickOutfitMale):
-- bit 31 = feminino (int com sinal: negativo), índice << 16, semente 1..500
local function outfitID(index, seed, female)
    local id = index * 65536 + seed
    if female then id = id - 2147483648 end
    return id
end

local function realIDs()
    local out = {}
    for index = 1, 20 do
        for seed = 1, 500 do
            out[#out + 1] = outfitID(index, seed, false)
            out[#out + 1] = outfitID(index, seed, true)
        end
    end
    return out
end

local function count(ids, period, c)
    local n = { estalador = 0, corredor = 0, semrosto = 0, carpideira = 0 }
    for _, id in ipairs(ids) do
        local v = R.variant(id, period, c)
        if v then n[v] = n[v] + 1 end
    end
    return n
end

return {
    -- servidor e clientes calculam sozinhos: mesma entrada, mesma resposta
    variant_rules_deterministic = function()
        for _, id in ipairs({ outfitID(3, 17, false), outfitID(250, 499, true), 1 }) do
            for night = 1, 5 do
                assert(R.variant(id, night, cfg()) == R.variant(id, night, cfg()))
            end
        end
    end,
    -- antes da 1ª leitura do clima (ou do nightState no cliente) não há noite: sem variante
    variant_rules_needs_night_number = function()
        local c = cfg({ estaladorChance = 100 })
        assert(R.variant(outfitID(3, 17), nil, c) == nil)
        assert(R.variant(0, 3, c) == nil, "ID 0 (sem outfit) virou variante")
        assert(R.variant(nil, 3, c) == nil)
        assert(R.variant(outfitID(3, 17, true), 3, c) == "estalador", "ID feminino (negativo) falhou")
    end,
    -- "uma vez por noite": a noite seguinte é outro sorteio
    variant_rules_rerolls_each_night = function()
        local ids, kept, total = realIDs(), 0, 0
        for _, id in ipairs(ids) do
            if R.variant(id, 7, cfg()) == "estalador" then
                total = total + 1
                if R.variant(id, 8, cfg()) == "estalador" then kept = kept + 1 end
            end
        end
        assert(total > 0 and kept / total < 0.5, "Estaladores repetidos de uma noite pra outra: " .. kept .. "/" .. total)
    end,
    -- noites independentes: P(variante em N e em N+1) ≈ p², não mais
    variant_rules_nights_independent = function()
        local ids = realIDs()
        for _, night in ipairs({ 1, 7, 30 }) do
            local first, both = 0, 0
            for _, id in ipairs(ids) do
                if R.variant(id, night, cfg()) then
                    first = first + 1
                    if R.variant(id, night + 1, cfg()) then both = both + 1 end
                end
            end
            local p, joint = first / #ids, both / #ids
            assert(math.abs(joint - p * p) < 0.006, string.format("noite %d: P(as duas)=%.4f, p²=%.4f", night, joint, p * p))
        end
    end,
    variant_rules_scream_cooldown = function()
        assert(R.screamReady(nil, 10))
        assert(not R.screamReady(10, 10 + R.SCREAM_COOLDOWN_HOURS - 0.01))
        assert(R.screamReady(10, 10 + R.SCREAM_COOLDOWN_HOURS))
    end,
    variant_rules_chance_bounds_and_toggles = function()
        local ids = realIDs()
        local none = count(ids, 4, cfg({ estaladorChance = 0, corredorChance = 0, semRostoChance = 0 }))
        assert(none.estalador == 0 and none.corredor == 0 and none.semrosto == 0)
        local all = count(ids, 4, cfg({ estaladorChance = 100 }))
        assert(all.estalador == #ids)
        local on = count(ids, 4, cfg({ corredorChance = 50 }))
        local off = count(ids, 4, cfg({ estaladorOn = false, corredorChance = 50 }))
        assert(off.estalador == 0, "toggle desligado ainda sorteou")
        assert(off.corredor == on.corredor, "desligar o Estalador mudou o Corredor")
        local both = count(ids, 4, cfg({ estaladorChance = 70, corredorChance = 70 }))
        assert(both.estalador + both.corredor == #ids, "soma > 100 deixou zumbi comum")
        assert(both.semrosto == 0, "Sem-rosto passou do 100")
    end,
    -- a taxa bate com o sandbox nos IDs que o jogo gera de fato
    variant_rules_rate_matches_chance = function()
        local ids = realIDs()
        for period = 1, 3 do
            local n = count(ids, period, cfg())
            for kind, want in pairs({ estalador = 5, corredor = 10, semrosto = 5 }) do
                local got = n[kind] / #ids * 100
                assert(math.abs(got - want) < 1.5, kind .. " " .. got .. "%")
            end
        end
    end,
    -- um sorteio só, faixas sem sobreposição: o total é a soma, ninguém é duas coisas
    variant_rules_kinds_exclusive_and_add_up = function()
        local ids = realIDs()
        local n = count(ids, 3, cfg({ estaladorChance = 20, corredorChance = 20, semRostoChance = 20 }))
        local total = (n.estalador + n.corredor + n.semrosto) / #ids * 100
        assert(math.abs(total - 60) < 2, "total " .. total)
        for _, id in ipairs(ids) do
            local k = R.variant(id, 3, cfg())
            assert(R.semRosto(id, 3, cfg()) == (k == "semrosto"))
        end
    end,
    -- desligar um tipo não muda quem é o outro: as faixas ficam no lugar (a 4ª
    -- variante da sprint 0011 entra no fim da lista sem mexer nas de hoje)
    variant_rules_toggle_keeps_other_ranges = function()
        local ids = realIDs()
        for _, id in ipairs(ids) do
            if R.variant(id, 5, cfg()) == "semrosto" then
                assert(R.variant(id, 5, cfg({ estaladorOn = false, corredorOn = false })) == "semrosto")
            end
        end
        assert(R.KINDS[1] == "estalador" and R.KINDS[2] == "corredor" and R.KINDS[3] == "semrosto")
    end,
    -- padrão do Johan (05/10): Estalador 5, Corredor 2, Sem-rosto 5, por névoa
    variant_rules_default_chances = function()
        require "NOM_Config"
        SandboxVars = nil
        local ids = realIDs()
        local c = R.config(NOM_Config.get)
        for period = 1, 3 do
            local n = count(ids, period, c)
            for kind, want in pairs({ estalador = 5, corredor = 2, semrosto = 5, carpideira = 3 }) do
                local got = n[kind] / #ids * 100
                assert(math.abs(got - want) < 1.5, kind .. " " .. got .. "%")
            end
        end
    end,
    -- sprint 0011: 5 + 2 + 5 + 3 = 15%, a Carpideira na faixa [12, 15) depois das três
    -- de antes (quem era Estalador, Corredor ou Sem-rosto continua sendo)
    variant_rules_default_total_15 = function()
        require "NOM_Config"
        local c = R.config(function(k) return NOM_Config.DEFAULTS[k] end)
        local old = R.config(function(k) return NOM_Config.DEFAULTS[k] end)
        old.carpideiraChance = 0
        local ids, any = realIDs(), 0
        for period = 1, 3 do
            local n = count(ids, period, c)
            local total = (n.estalador + n.corredor + n.semrosto + n.carpideira) / #ids * 100
            assert(math.abs(total - 15) < 1.5, "total " .. total)
        end
        for _, id in ipairs(ids) do
            local k, before = R.variant(id, 2, c), R.variant(id, 2, old)
            if before then assert(k == before, "a Carpideira mexeu na faixa de " .. before) end
            if k == "carpideira" then any = any + 1; assert(before == nil) end
        end
        assert(any > 0)
        assert(R.KINDS[4] == "carpideira" and #R.KINDS == 4, "Carpideira fora do fim da lista")
    end,
    variant_rules_config_reads_sandbox = function()
        local vals = { EstaladorEnabled = false, CorredorEnabled = true, SemRostoEnabled = false,
            EstaladorChance = 7, CorredorChance = 9, SemRostoChance = 12, CarpideiraEnabled = true, CarpideiraChance = 4 }
        local c = R.config(function(k) return vals[k] end)
        assert(c.carpideiraOn == true and c.carpideiraChance == 4)
        assert(c.estaladorOn == false and c.corredorOn == true and c.semRostoOn == false)
        assert(c.estaladorChance == 7 and c.corredorChance == 9 and c.semRostoChance == 12)
    end,
    semrosto_rules_needs_period = function()
        local c = cfg({ estaladorChance = 0, corredorChance = 0, semRostoChance = 100 })
        assert(R.semRosto(outfitID(3, 17), 2, c) == true)
        assert(R.semRosto(outfitID(3, 17, true), 2, c) == true, "ID feminino (negativo) falhou")
        assert(R.semRosto(outfitID(3, 17), nil, c) == false, "sem período virou Sem-rosto")
        assert(R.semRosto(0, 2, c) == false, "ID 0 virou Sem-rosto")
        assert(R.semRosto(outfitID(3, 17), 2, cfg({ semRostoOn = false, semRostoChance = 100,
            estaladorChance = 0, corredorChance = 0 })) == false)
    end,
    -- forçado pelo NOM_Debug: vale contra chance e toggle, mas não sem período
    variant_rules_forced_wins = function()
        local off = cfg({ estaladorOn = false, corredorOn = false, semRostoOn = false })
        R.forced[123] = "corredor"
        assert(R.variant(123, 1, off) == "corredor")
        assert(R.variant(123, nil, off) == nil, "período desconhecido")
        R.forced[123] = "semrosto"
        assert(R.variant(123, 1, off) == "semrosto")
        assert(R.semRosto(123, 1, off) == true)
        R.forced[123] = nil
        assert(R.semRosto(123, 1, off) == false)
    end,
    -- Névoa vermelha (sprint 0010): sorteio por período, determinístico (recarregar
    -- não re-sorteia, servidor e cliente concordam), RedFogChance% dos períodos
    variant_rules_red_fog_deterministic_per_period = function()
        local c = cfg({ redFogOn = true, redFogChance = 10 })
        local n = 0
        for p = 1, 2000 do
            local a = R.redFog(p, c)
            assert(a == R.redFog(p, c), "mudou no mesmo período " .. p)
            if a then n = n + 1 end
        end
        assert(n > 150 and n < 250, "vermelhas em 2000 períodos: " .. n)
        assert(R.redFog(5, cfg({ redFogOn = false, redFogChance = 100 })) == false, "desligada")
        for p = 1, 50 do
            assert(R.redFog(p, cfg({ redFogOn = true, redFogChance = 100 })) == true, "100%")
            assert(R.redFog(p, cfg({ redFogOn = true, redFogChance = 0 })) == false, "0%")
        end
        assert(R.redFog(nil, c) == false, "sem período")
    end,
    -- na vermelha todo zumbi é variante, dividido por igual entre KINDS
    variant_rules_red_fog_splits_evenly = function()
        local count = {}
        for _, k in ipairs(R.KINDS) do count[k] = 0 end
        local ids = realIDs()
        for _, id in ipairs(ids) do
            local k = R.variant(id, 7, cfg(), true)
            assert(k, "zumbi comum na névoa vermelha: " .. id)
            count[k] = count[k] + 1
        end
        for k, v in pairs(count) do
            assert(math.abs(v / #ids - 1 / #R.KINDS) < 0.02, string.format("%s %.3f", k, v / #ids))
        end
        -- sprint 0011: os quatro tipos, 1/4 cada
        assert(#R.KINDS == 4 and count.carpideira and count.carpideira > 0, "Carpideira fora da vermelha")
        -- mesmo zumbi, mesmo período: mesma resposta (recarga); período novo re-divide
        local same, diff = 0, 0
        for i = 1, 3000 do
            local id = ids[i]
            assert(R.variant(id, 7, cfg(), true) == R.variant(id, 7, cfg(), true))
            if R.variant(id, 7, cfg(), true) == R.variant(id, 8, cfg(), true) then same = same + 1 else diff = diff + 1 end
        end
        assert(same / 3000 < 0.45, "períodos seguidos correlacionados: " .. same / 3000)
    end,
    -- tipo desligado: a fatia dele fica comum, as outras não mudam
    variant_rules_red_fog_disabled_kind_stays_normal = function()
        local off = cfg({ estaladorOn = false })
        local none = 0
        for _, id in ipairs(realIDs()) do
            local on, k = R.variant(id, 3, cfg(), true), R.variant(id, 3, off, true)
            if on == "estalador" then assert(k == nil) else assert(k == on) end
            if k == nil then none = none + 1 end
        end
        assert(none > 0)
    end,
    -- forçado pelo debug vence; ID 0 (sem outfit) e período desconhecido nunca
    variant_rules_red_fog_keeps_forced_and_id0 = function()
        R.forced[4242] = "semrosto"
        assert(R.variant(4242, 1, cfg(), true) == "semrosto")
        R.forced[4242] = nil
        assert(R.variant(0, 1, cfg(), true) == nil)
        assert(R.variant(4242, nil, cfg(), true) == nil)
        assert(R.semRosto(4242, 1, cfg(), true) == (R.variant(4242, 1, cfg(), true) == "semrosto"))
    end,
    -- red falso/ausente: o sorteio normal não muda (as faixas de antes valem)
    variant_rules_red_flag_off_is_normal_roll = function()
        local n = 0
        for _, id in ipairs(realIDs()) do
            local k = R.variant(id, 9, cfg())
            assert(R.variant(id, 9, cfg(), false) == k)
            if k then n = n + 1 end
        end
        assert(n > 0 and n < #realIDs() / 4, "normal: " .. n)
    end,
    variant_rules_config_reads_red_fog = function()
        local c = R.config(function(k) return ({ RedFogEnabled = false, RedFogChance = 33 })[k] end)
        assert(c.redFogOn == false and c.redFogChance == 33)
    end,
    -- review: sem semente do mundo todo save tinha a mesma agenda de vermelhas (#11,
    -- #14, #21...). Com a semente: mundos diferentes, agendas diferentes; a taxa
    -- de longo prazo continua RedFogChance
    variant_rules_red_fog_seed_changes_schedule = function()
        local c = cfg({ redFogOn = true, redFogChance = 10 })
        local function schedule(seed)
            local out = {}
            for p = 1, 200 do out[#out + 1] = R.redFog(p, c, seed) and "1" or "0" end
            return table.concat(out)
        end
        assert(schedule(12345) == schedule(12345), "mesma semente, agenda diferente")
        local seen, firsts = {}, {}
        local n, total = 0, 0
        for seed = 1, 50 do
            local s = schedule(seed * 1000003 % 67108859)
            seen[s] = true
            firsts[s:find("1", 1, true) or 0] = true
            for i = 1, #s do
                total = total + 1
                if s:sub(i, i) == "1" then n = n + 1 end
            end
        end
        local distinct, firstDistinct = 0, 0
        for _ in pairs(seen) do distinct = distinct + 1 end
        for _ in pairs(firsts) do firstDistinct = firstDistinct + 1 end
        assert(distinct == 50, "agendas repetidas: " .. distinct)
        assert(firstDistinct >= 10, "primeira vermelha quase sempre no mesmo período: " .. firstDistinct)
        assert(math.abs(n / total - 0.1) < 0.015, "taxa: " .. n / total)
    end,

    -- sprint 0017: setFallenHat liga o bit 0x8000 do ID (PersistentOutfits.setFallenHat
    -- 0–36). baseId tira só esse bit, exato também no ID feminino (negativo)
    variant_rules_base_id_exact = function()
        local H = R.HAT_FALLEN
        assert(H == 32768)
        assert(R.baseId(nil) == nil and R.baseId(0) == 0)
        assert(R.baseId(outfitID(3, 77, false)) == outfitID(3, 77, false))
        assert(R.baseId(outfitID(3, 77, false) + H) == outfitID(3, 77, false))
        assert(R.baseId(outfitID(3, 77, true)) == outfitID(3, 77, true))
        assert(R.baseId(outfitID(3, 77, true) + H) == outfitID(3, 77, true), "feminino com o bit")
        assert(R.baseId(-2147483648) == -2147483648, "limite negativo")
        assert(R.baseId(-2147483648 + H) == -2147483648)
        assert(R.baseId(2147483647) == 2147483647 - H, "limite positivo (todos os bits)")
        assert(R.baseId(-1) == -1 - H, "-1: todos os bits ligados")
        for _, id in ipairs(realIDs()) do
            local b = R.baseId(id + H)
            assert(b == id and R.baseId(b) == b, "id " .. id)
        end
    end,
    -- o chapéu caído não muda o tipo (nem o forçado do debug), na névoa normal e na vermelha
    variant_rules_fallen_hat_same_kind = function()
        local c = cfg({ carpideiraChance = 5 })
        local changed = 0
        for _, id in ipairs(realIDs()) do
            for period = 1, 5 do
                local a, b = R.variant(id, period, c), R.variant(id + R.HAT_FALLEN, period, c)
                assert(a == b, "id " .. id .. " período " .. period .. ": " .. tostring(a) .. " ≠ " .. tostring(b))
                assert(R.variant(id, period, c, true) == R.variant(id + R.HAT_FALLEN, period, c, true), "vermelha")
            end
        end
        local id = outfitID(5, 9, true)
        R.forced[id] = "carpideira"
        local ok = R.variant(id + R.HAT_FALLEN, 1, cfg({ estaladorChance = 0, corredorChance = 0, semRostoChance = 0 })) == "carpideira"
        R.forced[id] = nil
        assert(ok, "forçado perdeu o chapéu e deixou de ser forçado")
    end,
}
