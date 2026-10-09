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
        local c = cfg({ estaladorChance = 100, corredorChance = 0, semRostoChance = 0, carpideiraChance = 0 })
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
        -- sprint 0049: na vermelha o cooldown é mais curto (identidade / agitação)
        local redCd = NOM_ColorIdentityRules.SCREAM_RED
        assert(R.screamReady(10, 10 + redCd, "red"))
        assert(not R.screamReady(10, 10 + redCd - 0.01, "red"))
        assert(not R.screamReady(10, 10 + redCd, "white"), "branco ainda espera 0,5 h")
    end,
    variant_rules_chance_bounds_and_toggles = function()
        local ids = realIDs()
        local none = count(ids, 4, cfg({ estaladorChance = 0, corredorChance = 0, semRostoChance = 0, carpideiraChance = 0 }))
        assert(none.estalador == 0 and none.corredor == 0 and none.semrosto == 0)
        local all = count(ids, 4, cfg({ estaladorChance = 100, corredorChance = 0, semRostoChance = 0, carpideiraChance = 0 }))
        assert(all.estalador == #ids)
        local on = count(ids, 4, cfg({ corredorChance = 50 }))
        local off = count(ids, 4, cfg({ estaladorOn = false, corredorChance = 50 }))
        assert(off.estalador == 0, "toggle desligado ainda sorteou")
        assert(off.corredor == on.corredor, "desligar o Estalador mudou o Corredor")
        local both = count(ids, 4, cfg({ estaladorChance = 70, corredorChance = 70, semRostoChance = 0, carpideiraChance = 0 }))
        assert(both.estalador + both.corredor == #ids, "pesos renormalizados deixaram zumbi comum")
        assert(both.semrosto == 0, "Sem-rosto com peso 0")
    end,
    -- a taxa bate com os pesos renormalizados nos IDs que o jogo gera de fato
    -- (cfg do helper: 5+10+5+0 = 20 → 25% / 50% / 25%)
    variant_rules_rate_matches_chance = function()
        local ids = realIDs()
        for period = 1, 3 do
            local n = count(ids, period, cfg())
            for kind, want in pairs({ estalador = 25, corredor = 50, semrosto = 25 }) do
                local got = n[kind] / #ids * 100
                assert(math.abs(got - want) < 1.5, kind .. " " .. got .. "%")
            end
        end
    end,
    -- um sorteio só, faixas sem sobreposição: na branca o total é 100%, ninguém é duas coisas
    variant_rules_kinds_exclusive_and_add_up = function()
        local ids = realIDs()
        local c = cfg({ estaladorChance = 20, corredorChance = 20, semRostoChance = 20, carpideiraChance = 0 })
        local n = count(ids, 3, c)
        local total = (n.estalador + n.corredor + n.semrosto) / #ids * 100
        assert(math.abs(total - 100) < 2, "total " .. total)
        for _, id in ipairs(ids) do
            local k = R.variant(id, 3, c)
            assert(R.semRosto(id, 3, c) == (k == "semrosto"))
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
    -- sprint 0049: defaults 5:3:3:3 renormalizados pra 100% (~35,7 / 21,4 / 21,4 / 21,4)
    variant_rules_default_chances = function()
        require "NOM_Config"
        SandboxVars = nil
        local ids = realIDs()
        local c = R.config(NOM_Config.get)
        local want = { estalador = 5 / 14 * 100, corredor = 3 / 14 * 100, semrosto = 3 / 14 * 100, carpideira = 3 / 14 * 100 }
        for period = 1, 3 do
            local n = count(ids, period, c)
            for kind, w in pairs(want) do
                local got = n[kind] / #ids * 100
                assert(math.abs(got - w) < 1.5, kind .. " " .. got .. "%")
            end
        end
    end,
    -- sprint 0049: branca 100%; Carpideira no fim de KINDS; com peso 0 a faixa some do total
    -- (quem tinha peso nas três primeiras continua nas mesmas razões entre si)
    variant_rules_default_total_100 = function()
        require "NOM_Config"
        local c = R.config(function(k) return NOM_Config.DEFAULTS[k] end)
        local old = R.config(function(k) return NOM_Config.DEFAULTS[k] end)
        old.carpideiraChance = 0
        local ids, any = realIDs(), 0
        for period = 1, 3 do
            local n = count(ids, period, c)
            local total = (n.estalador + n.corredor + n.semrosto + n.carpideira) / #ids * 100
            assert(math.abs(total - 100) < 1.5, "total " .. total)
        end
        -- sem Carpideira no peso: 100% nas três; a ordem KINDS não muda
        local n0 = count(ids, 2, old)
        assert(n0.carpideira == 0)
        assert(math.abs((n0.estalador + n0.corredor + n0.semrosto) / #ids * 100 - 100) < 1.5)
        for _, id in ipairs(ids) do
            if R.variant(id, 2, c) == "carpideira" then any = any + 1 end
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
    -- red falso/ausente: o sorteio da branca (100% pesos); red=false == omitido
    variant_rules_red_flag_off_is_normal_roll = function()
        local n = 0
        local ids = realIDs()
        for _, id in ipairs(ids) do
            local k = R.variant(id, 9, cfg())
            assert(R.variant(id, 9, cfg(), false) == k)
            if k then n = n + 1 end
        end
        assert(n == #ids, "branca 100%: " .. n .. "/" .. #ids)
    end,
    -- sprint 0049: branca cobre todos; pesos 2:1 → ~2/3 e ~1/3
    variant_rules_white_full_coverage = function()
        local c = cfg({ estaladorChance = 2, corredorChance = 1, semRostoChance = 0, carpideiraChance = 0 })
        local ids = realIDs()
        local n = count(ids, 11, c)
        assert(n.estalador + n.corredor == #ids, "sobraram comuns")
        assert(math.abs(n.estalador / #ids - 2 / 3) < 0.02, "estalador " .. n.estalador / #ids)
        assert(math.abs(n.corredor / #ids - 1 / 3) < 0.02, "corredor " .. n.corredor / #ids)
    end,
    variant_rules_white_disabled_kind_stays_normal = function()
        local off = cfg({ estaladorOn = false, estaladorChance = 50, corredorChance = 50, semRostoChance = 0, carpideiraChance = 0 })
        local none = 0
        for _, id in ipairs(realIDs()) do
            local on = R.variant(id, 3, cfg({ estaladorChance = 50, corredorChance = 50, semRostoChance = 0, carpideiraChance = 0 }))
            local k = R.variant(id, 3, off)
            if on == "estalador" then assert(k == nil) else assert(k == on) end
            if k == nil then none = none + 1 end
        end
        assert(none > 0)
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
    -- preta (sprint 0038): todo zumbi com ID é Tição, contra chance, toggle e forçado; sem ID ou
    -- sem período, nada
    variant_rules_black_is_always_ticao = function()
        local c = cfg({ estaladorOn = false, corredorOn = false, semRostoOn = false, carpideiraOn = false })
        R.forced[outfitID(2, 7)] = "estalador"
        for _, id in ipairs(realIDs()) do
            assert(R.variant(id, 5, c, false, true) == "ticao")
            assert(R.variant(id, 5, c, true, true) == "ticao", "a preta vale mais que a vermelha")
        end
        R.forced = {}
        assert(R.variant(0, 5, c, false, true) == nil and R.variant(outfitID(1, 1), nil, c, false, true) == nil)
        assert(not R.semRosto(outfitID(1, 1), 5, cfg({ semRostoChance = 100 }), false, true), "Sem-rosto na preta")
    end,
    -- LookForce do painel (0058): força o kind no assign; forçado por ID e preta ganham.
    variant_rules_look_force_from_panel = function()
        require "NOM_PanelParams"
        NOM_PanelParams.reset()
        local off = cfg({ estaladorOn = false, corredorOn = false, semRostoOn = false, carpideiraOn = false,
            estaladorChance = 0, corredorChance = 0, semRostoChance = 0, carpideiraChance = 0 })
        local id = outfitID(3, 17)
        assert(R.variant(id, 1, off) == nil, "sem force, sandbox off")
        NOM_PanelParams.set("LookForce", "pale")
        assert(R.variant(id, 1, off) == "estalador")
        NOM_PanelParams.set("LookForce", "wrong")
        assert(R.variant(id, 1, off) == "semrosto")
        R.forced[id] = "corredor"
        assert(R.variant(id, 1, off) == "corredor", "forced[id] ganha do LookForce")
        R.forced[id] = nil
        assert(R.variant(id, 1, off, false, true) == "ticao", "preta ganha do LookForce")
        NOM_PanelParams.reset()
        assert(R.variant(id, 1, off) == nil)
    end,
}
