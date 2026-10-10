-- Guarda-roupa por variante (bíblia look + lote A/1): slot-assinatura vanilla (N3)
-- + tratamento tint/dirt/blood/hole no ItemVisual (N2). Sem API do jogo.
--
-- Evidência ItemVisual (javap B42 / pz-api-notes §14.4 + U1):
-- * setTint(ImmutableColor) — getTint(ClothingItem) só devolve a tinta se
--   ClothingItem.allowRandomTint; senão força white. Só itens *TINT / AllowRandomTint=true.
-- * setDirt/setBlood(BloodBodyPartType, f) / setHole(BloodBodyPartType) — EXISTS.
-- Itens confirmados em media/scripts/generated/items/clothing.txt do B42 (2026-10-09).
require "NOM_Math"

NOM_VariantWardrobe = {}
local W = NOM_VariantWardrobe

-- Hex da bíblia → RGB 0..1
local function rgb(hex)
    local n = tonumber(hex, 16)
    return {
        NOM_Math.mod(math.floor(n / 65536), 256) / 255,
        NOM_Math.mod(math.floor(n / 256), 256) / 255,
        NOM_Math.mod(n, 256) / 255,
    }
end

-- Partes comuns pra sujeira/sangue/buraco (BloodBodyPartType.* no jogo).
local TORSO = { "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R" }
local LEGS = { "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R" }
local APRON = { "Torso_Upper", "Torso_Lower", "Groin" }

-- Padrões de strip por família (só o slot-assinatura; o resto do zumbi fica — híbrido §2).
local TOP = { "Tshirt_", "Shirt_", "Sweater", "Hoodie", "Vest_", "Jumper_" }
local BOTTOM = { "Trousers_", "Skirt_", "Shorts_" }
local FULL = { "Dress_", "LongCoat_", "Poncho", "Boilersuit", "HospitalGown",
    "Tshirt_", "Shirt_", "Sweater", "Hoodie", "Vest_", "Jumper_",
    "Trousers_", "Skirt_", "Shorts_", "Jacket_", "Apron_" }
local APRON_ONLY = { "Apron_" }
local SKIRT_LEG = { "Trousers_", "Skirt_", "Shorts_", "Dress_" }

-- Estalador E1–E5 (clothing.txt B42 confirmado).
-- E4: Shirt/Trousers_Pyjama MISS → Tshirt_WhiteTINT (AllowRandomTint=true).
-- E5: Vest_DefaultTEXTURE tint=false → Vest_DefaultTEXTURE_TINT.
W.CATALOG = {
    estalador = {
        { id = "E1", name = "paciente",
            pieces = { { type = "Base.HospitalGown" } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.35 },
        },
        { id = "E2", name = "missa",
            pieces = {
                { type = "Base.Shirt_FormalWhite" },
                { type = "Base.Trousers_SuitWhite", tint = rgb("3A3734") },
            },
            strip = { "Tshirt_", "Shirt_", "Sweater", "Hoodie", "Vest_", "Jumper_",
                "Trousers_", "Skirt_", "Shorts_" },
            dirt = { parts = TORSO, amount = 0.55 },
        },
        { id = "E3", name = "acougueiro",
            pieces = { { type = "Base.Apron_White" } },
            strip = APRON_ONLY,
            blood = { parts = APRON, amount = 0.45 },
            dirt = { parts = TORSO, amount = 0.25 },
        },
        { id = "E4", name = "pijama",
            pieces = { { type = "Base.Tshirt_WhiteTINT", tint = rgb("A8B0B8") } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0.2 },
        },
        { id = "E5", name = "regata",
            pieces = { { type = "Base.Vest_DefaultTEXTURE_TINT", tint = rgb("D9D2C3") } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0.3 },
        },
    },
    -- Carpideira K1–K5. Skirt_Long OK; Bathrobe → LongCoat_Bathrobe; Nightdress MISS → Dress_SatinNegligee.
    carpideira = {
        { id = "K1", name = "paciente",
            pieces = { { type = "Base.Skirt_Long", tint = rgb("1E1C1B") } },
            strip = SKIRT_LEG,
            dirt = { parts = LEGS, amount = 0.4 },
            keepBody = true, -- manto + saia
        },
        { id = "K2", name = "velorio",
            pieces = { { type = "Base.Dress_Long", tint = rgb("1E1C1B") } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.5 },
            keepBody = false,
        },
        { id = "K3", name = "camisola",
            pieces = {
                { type = "Base.Dress_SatinNegligee", tint = rgb("D9D2C3") },
                { type = "Base.Skirt_Long", tint = rgb("C9C1B0") },
            },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.65 },
            keepBody = false,
        },
        { id = "K4", name = "capa",
            pieces = { { type = "Base.PonchoGarbageBag" } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.4 },
            keepBody = false,
        },
        { id = "K5", name = "roupao",
            pieces = { { type = "Base.LongCoat_Bathrobe", tint = rgb("2B2926") } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.35 },
            keepBody = false,
        },
    },
}

function W.count(kind)
    local cat = W.CATALOG[kind]
    return cat and #cat or 0
end

-- Sorteio estável: mesmo id → mesma variante (ADR-006).
function W.pick(kind, id)
    local cat = W.CATALOG[kind]
    if not cat or #cat == 0 then return nil, 0 end
    local n = #cat
    local idx = NOM_Math.mod(math.floor(tonumber(id) or 0), n) + 1
    return cat[idx], idx
end

function W.isStrip(t, patterns)
    if t == nil or t:find("%.NOM_", 1, true) then return false end
    patterns = patterns or FULL
    for i = 1, #patterns do
        if t:find(patterns[i], 1, true) then return true end
    end
    return false
end

-- Aplica tinta/sujeira/sangue/buraco num ItemVisual (API do jogo no cliente).
function W.treat(iv, piece, variant)
    if piece.tint and ImmutableColor and ImmutableColor.new then
        local t = piece.tint
        iv:setTint(ImmutableColor.new(t[1], t[2], t[3], 1))
    end
    local function smear(spec, setter)
        if not spec or not BloodBodyPartType then return end
        for i = 1, #spec.parts do
            local part = BloodBodyPartType[spec.parts[i]]
            if part then setter(iv, part, spec.amount) end
        end
    end
    if variant.dirt then
        smear(variant.dirt, function(v, p, a) v:setDirt(p, a) end)
    end
    if variant.blood then
        smear(variant.blood, function(v, p, a) v:setBlood(p, a) end)
    end
    if variant.holes and BloodBodyPartType then
        for i = 1, #variant.holes do
            local part = BloodBodyPartType[variant.holes[i]]
            if part then iv:setHole(part) end
        end
    end
end

return NOM_VariantWardrobe
