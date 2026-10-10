-- shared/NOM_SemRostoFace.lua: tint A′ a partir da pele vanilla (números P3).
require "NOM_SemRostoFace"

local F = NOM_SemRostoFace

return {
    semrosto_face_parses_vanilla_skin_name = function()
        assert(F.parseSkin("M_ZedBody02_level1") == "M_ZedBody02_level1")
        assert(F.parseSkin("F_ZedBody04_level3a") == "F_ZedBody04_level3") -- sufixo body hair
        assert(F.parseSkin("NOM_Ticao") == nil)
        assert(F.parseSkin(nil) == nil)
    end,

    semrosto_face_tint_proof_tone_m02_l1 = function()
        local r, g, b = F.tintFor(F.PROOF_SKIN, 1.0)
        local c = F.CHEEK[F.PROOF_SKIN]
        assert(math.abs(r - c[1] / 255) < 1e-6 and math.abs(g - c[2] / 255) < 1e-6)
        assert(math.abs(b - c[3] / 255) < 1e-6)
        local rw, gw, bw = F.tintFor(F.PROOF_SKIN, 1.08)
        assert(rw > r and rw <= 1 and gw > g and bw > b, "cera +8%")
        local r2 = select(1, F.tintFor(nil, 1.0))
        assert(math.abs(r2 - c[1] / 255) < 1e-6, "fallback = tom de prova")
        local r3 = select(1, F.tintFor("lixo", 1.0))
        assert(math.abs(r3 - c[1] / 255) < 1e-6, "nome estranho → default")
    end,

    semrosto_face_has_all_24_cheeks = function()
        local n = 0
        for k, rgb in pairs(F.CHEEK) do
            n = n + 1
            assert(type(k) == "string" and k:match("^[MF]_ZedBody0%d_level%d$"), k)
            assert(#rgb == 3 and rgb[1] >= 0 and rgb[1] <= 255)
        end
        assert(n == 24, "tabela P3 incompleta: " .. n)
        assert(F.ITEM == "Base.NOM_SemRostoRosto")
        assert(F.PATCH.u0 < F.PATCH.u1 and F.PATCH.v0 < F.PATCH.v1)
    end,

    -- lote 2: F1–F4 estáveis por outfit id; capped → F1
    semrosto_face_pick_f1_to_f4 = function()
        assert(#F.FACES == 4)
        assert(F.FACES[1] == "F1" and F.FACES[4] == "F4")
        local a, i = F.pick(42)
        local b, j = F.pick(42)
        assert(a == b and i == j and a:match("^F%d$"))
        assert(F.pick(42, true) == "F1", "capped força F1")
        local seen = {}
        for id = 0, 40 do
            local face, idx = F.pick(id)
            seen[idx] = true
            assert(face == ("F" .. idx))
        end
        for n = 1, 4 do assert(seen[n], "rosto " .. n .. " nunca saiu") end
    end,
}
