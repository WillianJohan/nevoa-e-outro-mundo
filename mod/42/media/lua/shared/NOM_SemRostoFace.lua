-- Remendo 2D do Sem-rosto (0060f, opção A′ do revisor / bíblia §7.1): uma camada
-- base:zeddmg só no rosto, tingida no tom da bochecha da pele vanilla. Sem API do
-- jogo. Números de cheek_rgb: medição P3 nas Body/?_ZedBody0N_levelN (bluefin).
-- Lote 2: rostos F1–F4 (textureChoice 0..3) + todos os 24 tons em CHEEK.
require "NOM_Math"

NOM_SemRostoFace = {}
local F = NOM_SemRostoFace

F.ITEM = "Base.NOM_SemRostoRosto"
F.FACES = { "F1", "F2", "F3", "F4" }
-- 1º tom de prova (LookForce + lookInspect): masculino tom 2, podridão 1.
F.PROOF_SKIN = "M_ZedBody02_level1"
-- Média 8×8 na bochecha (u≈0,42 v≈0,15), 0–255 → tint /255. +0 na textura cinza.
F.CHEEK = {
    F_ZedBody01_level1 = { 182, 161, 139 },
    F_ZedBody01_level2 = { 140, 125, 101 },
    F_ZedBody01_level3 = { 104, 85, 56 },
    F_ZedBody02_level1 = { 203, 172, 137 },
    F_ZedBody02_level2 = { 175, 155, 130 },
    F_ZedBody02_level3 = { 143, 119, 96 },
    F_ZedBody03_level1 = { 169, 154, 111 },
    F_ZedBody03_level2 = { 160, 146, 103 },
    F_ZedBody03_level3 = { 98, 88, 60 },
    F_ZedBody04_level1 = { 75, 60, 49 },
    F_ZedBody04_level2 = { 67, 60, 51 },
    F_ZedBody04_level3 = { 67, 63, 56 },
    M_ZedBody01_level1 = { 166, 141, 120 },
    M_ZedBody01_level2 = { 124, 102, 82 },
    M_ZedBody01_level3 = { 84, 62, 40 },
    M_ZedBody02_level1 = { 213, 190, 152 },
    M_ZedBody02_level2 = { 180, 164, 136 },
    M_ZedBody02_level3 = { 134, 111, 90 },
    M_ZedBody03_level1 = { 167, 152, 109 },
    M_ZedBody03_level2 = { 167, 152, 109 },
    M_ZedBody03_level3 = { 167, 152, 109 },
    M_ZedBody04_level1 = { 68, 53, 43 },
    M_ZedBody04_level2 = { 64, 56, 49 },
    M_ZedBody04_level3 = { 66, 60, 55 },
}
F.DEFAULT = F.CHEEK[F.PROOF_SKIN]
-- Caixa do remendo (UV 0..1): P3 union feat + ~8 px @256. Rampa de alfa ~6 px no gen.
F.PATCH = { u0 = 0.348, u1 = 0.645, v0 = 0.0, v1 = 0.266 }

-- Rosto F1–F4 por outfit id (independente da roupa S*). capped → F1.
function F.pick(id, capped)
    if capped then return "F1", 1 end
    local n = #F.FACES
    local idx = NOM_Math.mod(math.floor(tonumber(id) or 0), n) + 1
    return F.FACES[idx], idx
end

-- textureChoice 0-based pro ItemVisual (pz-api-notes §14.2).
function F.textureChoice(faceOrIdx)
    if type(faceOrIdx) == "number" then return faceOrIdx - 1 end
    for i = 1, #F.FACES do
        if F.FACES[i] == faceOrIdx then return i - 1 end
    end
    return 0
end

-- Nome base da pele (sem sufixo "a" de body hair). Nil se não casar.
function F.parseSkin(name)
    if type(name) ~= "string" then return nil end
    return name:match("^([MF]_ZedBody0%d_level%d)")
end

-- r,g,b em 0..1 pro ItemVisual:setTint.
-- waxBoost default 1.0 (0064: 1.08 + pele clara estourava ovo branco no print 15).
-- Teto 1.04 (bíblia §7 ainda permite leve cera, sem L>0,60).
function F.tintFor(skinName, waxBoost)
    local key = F.parseSkin(skinName)
    local rgb = (key and F.CHEEK[key]) or F.DEFAULT
    local w = tonumber(waxBoost) or 1.0
    if w < 1 then w = 1 end
    if w > 1.04 then w = 1.04 end
    local function ch(c)
        local v = (c / 255) * w
        if v > 1 then v = 1 end
        return v
    end
    return ch(rgb[1]), ch(rgb[2]), ch(rgb[3])
end

return NOM_SemRostoFace
