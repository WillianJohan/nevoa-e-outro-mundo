-- shared/NOM_VariantWardrobe.lua: catálogo E/C/T/S/K/A e sorteio estável ponderado.
require "NOM_VariantWardrobe"

local W = NOM_VariantWardrobe

return {
    wardrobe_catalog_five_each = function()
        assert(W.count("estalador") == 5)
        assert(W.count("carpideira") >= 2, "Screamer: K1 + K2 Embrulhada")
        assert(W.count("corredor") == 5)
        assert(W.count("ticao") == 5)
        assert(W.count("semrosto") == 5)
        assert(W.count("alma") == 5)
        local ids = {}
        for i = 1, 5 do
            local v = W.CATALOG.estalador[i]
            assert(v.id == ("E" .. i), v.id)
            assert(v.pieces and #v.pieces >= 1)
            ids[v.pieces[1].type] = true
        end
        assert(ids["Base.HospitalGown"] and ids["Base.Apron_White"])
        assert(ids["Base.Tshirt_WhiteTINT"], "E4 fallback pijama")
        assert(ids["Base.Vest_DefaultTEXTURE_TINT"], "E5 TINT")
        -- 0064: K1 Que Nunca Cresceu (vanilla+tint); manto/viúva fora
        local k1 = W.CATALOG.carpideira[1]
        assert(k1.id == "K1" and k1.name == "nunca_cresceu")
        assert(k1.keepBody == false, "sem manto")
        local types = {}
        for i = 1, #k1.pieces do types[k1.pieces[i].type] = k1.pieces[i] end
        assert(types["Base.Dress_Knees"] and types["Base.Dress_Knees"].tint, "vestido marinho tintável")
        assert(types["Base.Shirt_FormalTINT"] and types["Base.Shirt_FormalTINT"].tint, "blusa")
        assert(types["Base.Socks_Long_White"], "meias brancas")
        assert(types["Base.Shoes_Black"], "sapato")
        assert(not types["Base.Dress_Long"] and not types["Base.Skirt_Long"], "viúva fora")
        assert(W.CATALOG.corredor[1].id == "C1")
        assert(W.CATALOG.corredor[1].pieces[1].type == "Base.Shirt_Lumberjack_TINT")
        assert(W.CATALOG.corredor[1].keepBody == true, "risco N4 fica")
        assert(W.CATALOG.semrosto[5].id == "S5" and W.CATALOG.semrosto[5].keepOwn == true)
        assert(W.CATALOG.ticao[1].id == "T1")
        assert(W.CATALOG.alma[1].id == "A1" and W.CATALOG.alma[1].pieces == nil)
    end,

    -- ajuste 5: T1–T3 trocam slot (N3 *TINT carvão); sem keepOwn / sem roupa clara intacta
    wardrobe_ticao_carbonized_tintable = function()
        for i = 1, 3 do
            local t = W.CATALOG.ticao[i]
            assert(not t.keepOwn, t.id .. " não pode keepOwn (setTint falha em TEXTURE)")
            assert(t.pieces and #t.pieces >= 1, t.id)
            local top = t.pieces[1]
            assert(top.tint, t.id .. " precisa tint")
            assert(top.type:find("TINT", 1, true) or top.type:find("SuitWhite", 1, true)
                or top.type:find("Hoodie", 1, true), t.id .. " peça tintável: " .. top.type)
            -- carvão / cinza fria — luminância baixa no canal R do tint
            assert(top.tint[1] < 0.45, t.id .. " ainda claro: " .. tostring(top.tint[1]))
        end
        local t5 = W.CATALOG.ticao[5]
        assert(t5.pieces[1].tint[1] < 0.35, "T5 70% carbonizado, não pijama claro")
        assert(not t5.keepOwn)
    end,

    -- A1 ≤ 20% via weight; A2/A3 dominam
    wardrobe_alma_a1_at_most_20pct = function()
        local cat = W.CATALOG.alma
        local total, a1w = 0, 0
        for i = 1, #cat do
            local w = cat[i].weight or 1
            total = total + w
            if cat[i].id == "A1" then a1w = w end
        end
        assert(a1w / total <= 0.20 + 1e-9, "A1 weight " .. a1w .. "/" .. total)
        local counts = { A1 = 0, A2 = 0, A3 = 0 }
        for id = 0, total * 20 - 1 do
            local v = W.pick("alma", id)
            if counts[v.id] then counts[v.id] = counts[v.id] + 1 end
        end
        local n = total * 20
        assert(counts.A1 / n <= 0.22, "A1 saiu demais: " .. counts.A1 / n)
        assert(counts.A2 > counts.A1 and counts.A3 > counts.A1, "A2/A3 devem dominar")
    end,

    wardrobe_light_mass_flags = function()
        assert(W.isLightMass(W.CATALOG.estalador[1]))
        assert(W.isLightMass(W.CATALOG.estalador[2]))
        assert(W.isLightMass(W.CATALOG.semrosto[1]))
        assert(W.isLightMass(W.CATALOG.semrosto[3]))
        assert(W.isLightMass(W.CATALOG.carpideira[1]), "K1 meias/blusa claras")
        assert(not W.isLightMass(W.CATALOG.corredor[1]))
    end,

    wardrobe_pick_stable_by_id = function()
        local a, i = W.pick("estalador", 10)
        local b, j = W.pick("estalador", 10)
        assert(a == b and i == j)
        local seen = {}
        for id = 0, 199 do
            local v, idx = W.pick("estalador", id)
            seen[idx] = true
            assert(v.id == ("E" .. idx))
        end
        for n = 1, 5 do assert(seen[n], "variante " .. n .. " nunca saiu") end
    end,

    wardrobe_tint_only_on_tintable_pieces = function()
        -- E2 calça SuitWhite tem tint; HospitalGown (E1) não (AllowRandomTint=false).
        assert(W.CATALOG.estalador[1].pieces[1].tint == nil)
        assert(W.CATALOG.estalador[2].pieces[2].tint ~= nil)
        assert(W.CATALOG.estalador[4].pieces[1].tint ~= nil)
        assert(W.CATALOG.carpideira[1].pieces[1].tint ~= nil, "Dress_Knees tint")
    end,

    wardrobe_treat_sets_dirt_blood_tint = function()
        ImmutableColor = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
        BloodBodyPartType = { Torso_Upper = "Torso_Upper", Torso_Lower = "Torso_Lower",
            UpperArm_L = "UpperArm_L", UpperArm_R = "UpperArm_R", Groin = "Groin" }
        local iv = { dirt = {}, blood = {} }
        function iv:setTint(c) self.tint = c end
        function iv:setDirt(p, a) self.dirt[p] = a end
        function iv:setBlood(p, a) self.blood[p] = a end
        function iv:setHole() end
        local v = W.CATALOG.estalador[3] -- açougueiro: blood no avental
        W.treat(iv, v.pieces[1], v)
        assert(iv.blood.Torso_Upper and iv.blood.Torso_Upper > 0)
        local e4 = W.CATALOG.estalador[4]
        local iv2 = { dirt = {}, blood = {} }
        function iv2:setTint(c) self.tint = c end
        function iv2:setDirt(p, a) self.dirt[p] = a end
        function iv2:setBlood() end
        function iv2:setHole() end
        W.treat(iv2, e4.pieces[1], e4)
        assert(iv2.tint and iv2.tint.r > 0)
    end,

    wardrobe_strip_patterns = function()
        local e3 = W.CATALOG.estalador[3].strip
        assert(W.isStrip("Base.Apron_White", e3))
        assert(not W.isStrip("Base.Tshirt_DefaultTEXTURE", e3), "avental não tira camisa")
        assert(W.isStrip("Base.Dress_Knees", W.CATALOG.carpideira[1].strip))
        assert(not W.isStrip("Base.NOM_EstaladorVenda"))
        assert(not W.isStrip("Base.Hat_Army"))
    end,

    -- 0064: Screamer K1 não é mais manto/viúva
    wardrobe_carpideira_nunca_cresceu = function()
        local k1 = W.CATALOG.carpideira[1]
        assert(k1.name == "nunca_cresceu")
        assert(k1.keepBody == false)
        local navy = k1.pieces[1].tint
        assert(navy and navy[1] < 0.25 and navy[3] > navy[1], "marinho apagado")
        for i = 1, #W.CATALOG.carpideira do
            local v = W.CATALOG.carpideira[i]
            for j = 1, #(v.pieces or {}) do
                local t = v.pieces[j].type
                assert(t ~= "Base.Dress_Long" and t ~= "Base.LongCoat_Bathrobe"
                    and t ~= "Base.PonchoGarbageBag" and t ~= "Base.Dress_SatinNegligee",
                    "viúva ainda no catálogo: " .. t)
            end
        end
    end,

    -- 0064: K2 Embrulhada — prova do capuz (headItem) antes do corpo
    wardrobe_carpideira_embrulhada_capuz = function()
        local k2 = W.CATALOG.carpideira[2]
        assert(k2 and k2.id == "K2" and k2.name == "embrulhada")
        assert(k2.headItem == "Base.NOM_CarpideiraCapuz")
        assert(k2.headFx == "Base.NOM_CarpideiraCapuzFx")
        assert(k2.keepBody == false)
        assert(k2.pieces and #k2.pieces == 1 and k2.pieces[1].type == "Base.HospitalGown",
            "prova: bata clara até o Hazmat")
        assert(W.isLightMass(k2))
        assert((k2.weight or 1) == 0, "prova: fora do sorteio até o corpo")
        for id = 0, 39 do
            local v = W.pick("carpideira", id)
            assert(v.id == "K1", "sorteio ainda pega K2: " .. v.id)
        end
    end,
}
