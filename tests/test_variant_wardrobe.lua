-- shared/NOM_VariantWardrobe.lua: catálogo E1–E5 / K1–K5 e sorteio estável.
require "NOM_VariantWardrobe"

local W = NOM_VariantWardrobe

return {
    wardrobe_catalog_five_each = function()
        assert(W.count("estalador") == 5)
        assert(W.count("carpideira") == 5)
        assert(W.count("corredor") == 0)
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
        local k = W.CATALOG.carpideira
        assert(k[1].keepBody == true and k[1].pieces[1].type == "Base.Skirt_Long")
        assert(k[2].keepBody == false and k[2].pieces[1].type == "Base.Dress_Long")
        assert(k[5].pieces[1].type == "Base.LongCoat_Bathrobe")
    end,

    wardrobe_pick_stable_by_id = function()
        local a, i = W.pick("estalador", 10)
        local b, j = W.pick("estalador", 10)
        assert(a == b and i == j)
        local seen = {}
        for id = 0, 49 do
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
        assert(W.CATALOG.carpideira[2].pieces[1].tint ~= nil)
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
        assert(W.isStrip("Base.Dress_Long", W.CATALOG.carpideira[2].strip))
        assert(not W.isStrip("Base.NOM_EstaladorVenda"))
        assert(not W.isStrip("Base.Hat_Army"))
    end,
}
