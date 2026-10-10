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
-- lightMass: massa clara (ajuste 6 — ≥1/4 no grupo vermelho). weight sobe a chance.
W.CATALOG = {
    estalador = {
        { id = "E1", name = "paciente", lightMass = true, weight = 2,
            pieces = { { type = "Base.HospitalGown" } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.35 },
        },
        { id = "E2", name = "missa", lightMass = true, weight = 2,
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
    -- Screamer (kind carpideira). 0064/0065: K1 + K2 (K3 Rastejante removida no playtest).
    -- Pesos live: ScreamerK1Weight / ScreamerK2Weight no NOM_PanelParams.
    carpideira = {
        -- K1 Que Nunca Cresceu: laço + pinafore (alças) + gola branca + meias + cabelo escuro longo.
        { id = "K1", name = "nunca_cresceu", lightMass = true, weight = 1,
            headItem = "Base.NOM_CarpideiraLaco",
            headFx = "Base.NOM_CarpideiraLacoFx",
            hairModel = "Long",
            hairColor = rgb("1A1512"),  -- #2B2420–#14110F
            pieces = {
                { type = "Base.Shirt_FormalTINT", tint = rgb("F0EBE0") },  -- gola/blusa clara
                { type = "Base.Dress_Straps", tint = rgb("2E3442") },      -- pinafore alças
                { type = "Base.Socks_Long", tint = rgb("C8C2B4") },        -- meias ≠ pele
                { type = "Base.Shoes_Black" },
            },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.55 },
            holes = { "Torso_Upper", "UpperArm_L" },
            keepBody = false,
        },
        -- K2 Embrulhada caminho A (diretor v3): balaclava vanilla + lençol; sem capuz 3D.
        -- Scarf nó #5A4A38; casca BoilerSuit + máscaras Hazmat (sem gola/estampa).
        { id = "K2", name = "embrulhada", lightMass = true, weight = 1,
            headItem = "Base.NOM_CarpideiraCapuz",
            headFx = "Base.NOM_CarpideiraCapuzFx",
            skinColor = rgb("8A8680"),
            pieces = {
                { type = "Base.NOM_EmbrulhadaCasca" },
                { type = "Base.Scarf_White", tint = rgb("5A4A38") },
            },
            strip = {
                "Dress_", "LongCoat_", "Poncho", "Boilersuit", "HospitalGown",
                "Tshirt_", "Shirt_", "Sweater", "Hoodie", "Vest_", "Jumper_",
                "Trousers_", "Skirt_", "Shorts_", "Jacket_", "Apron_", "Scarf",
                "Socks_", "Shoes_", "Underpants", "Briefs", "Boxers", "Bra_", "Frilly",
            },
            keepBody = false,
            dirt = { parts = TORSO, amount = 0.55 },
        },
    },
    -- Corredor C1–C5: tronco escuro N3 + risco claro N4 (LOOKS.corredor.body).
    corredor = {
        { id = "C1", name = "mecanico", keepBody = true,
            -- sem Boilersuit N3: o risco N4 ocupa base:boilersuit (como o manto)
            pieces = {
                { type = "Base.Shirt_Lumberjack_TINT", tint = rgb("2E2C2A") },
                { type = "Base.Trousers_SuitWhite", tint = rgb("2E2C2A") },
            },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.55 },
            holes = { "Torso_Upper" },
        },
        { id = "C2", name = "moletom", keepBody = true,
            pieces = { { type = "Base.HoodieDOWN_WhiteTINT", tint = rgb("2E2C2A") } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0.4 },
            holes = { "UpperArm_L", "UpperArm_R" },
        },
        { id = "C3", name = "jaqueta", keepBody = true,
            pieces = {
                { type = "Base.Jacket_Black" },
                { type = "Base.Tshirt_WhiteTINT", tint = rgb("2E2C2A") },
            },
            strip = { "Jacket_", "Hoodie", "LongCoat_", "Tshirt_", "Shirt_" },
            dirt = { parts = TORSO, amount = 0.35 },
        },
        { id = "C4", name = "agasalho", keepBody = true,
            pieces = { { type = "Base.Jacket_Shellsuit_TINT", tint = rgb("2E2C2A") } },
            strip = { "Jacket_", "Hoodie", "Track" },
            dirt = { parts = TORSO, amount = 0.5 },
        },
        { id = "C5", name = "lumberjack", keepBody = true,
            pieces = { { type = "Base.Shirt_Lumberjack_TINT", tint = rgb("2E2C2A") } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0.45 },
        },
    },
    -- Sem-rosto S1–S5 (bíblia §7.3). S5 = roupa própria lavada (keepOwn).
    semrosto = {
        { id = "S1", name = "escritorio", lightMass = true, weight = 2,
            pieces = {
                { type = "Base.Shirt_FormalTINT", tint = rgb("A89A84") },
                { type = "Base.Tie_Full" },
            },
            strip = { "Tshirt_", "Shirt_", "Sweater", "Hoodie", "Vest_", "Jumper_", "Tie_" },
            dirt = { parts = TORSO, amount = 0 },
        },
        { id = "S2", name = "cardiga",
            pieces = { { type = "Base.Jumper_RoundNeck", tint = rgb("7D7A74") } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0 },
        },
        { id = "S3", name = "igreja", lightMass = true, weight = 2,
            pieces = { { type = "Base.Dress_Normal", tint = rgb("B7A6A0") } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0 },
        },
        { id = "S4", name = "servidor",
            pieces = { { type = "Base.Shirt_Workman" } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0 },
        },
        { id = "S5", name = "proprio",
            pieces = {},
            strip = {},
            keepOwn = true,
            wash = true,
        },
    },
    -- Tição T1–T5: N2 setTint falha em TEXTURE (AllowRandomTint=false) → N3 peças *TINT
    -- carvão. Nenhum Tição com roupa clara intacta. T5 = pijama 70% carbonizado.
    ticao = {
        { id = "T1", name = "brasa_viva",
            pieces = {
                { type = "Base.Tshirt_WhiteTINT", tint = rgb("1A1817") },
                { type = "Base.Trousers_SuitWhite", tint = rgb("1A1817") },
            },
            strip = FULL,
            holes = { "Torso_Upper", "Torso_Lower", "UpperArm_L", "UpperArm_R" },
            dirt = { parts = TORSO, amount = 0.85 },
        },
        { id = "T2", name = "apagando",
            pieces = {
                { type = "Base.Tshirt_WhiteTINT", tint = rgb("5C5853") },
                { type = "Base.Trousers_SuitWhite", tint = rgb("3A3734") },
            },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.7 },
            holes = { "Torso_Upper" },
        },
        { id = "T3", name = "cinza_fria",
            pieces = {
                { type = "Base.HoodieDOWN_WhiteTINT", tint = rgb("5C5853") },
                { type = "Base.Trousers_SuitWhite", tint = rgb("2E2C2A") },
            },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.55 },
        },
        { id = "T4", name = "bombeiro",
            pieces = {
                { type = "Base.Jacket_Fireman" },
                { type = "Base.Tshirt_WhiteTINT", tint = rgb("1A1817") },
            },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.75 },
            holes = { "Torso_Upper", "UpperArm_L" },
        },
        { id = "T5", name = "pijama",
            -- 70% carbonizado: resto claro sob carvão #3D3835 (não A8B0B8 intacto)
            pieces = { { type = "Base.Tshirt_WhiteTINT", tint = rgb("3D3835") } },
            strip = TOP,
            dirt = { parts = TORSO, amount = 0.65 },
            holes = { "Torso_Upper", "Torso_Lower" },
        },
    },
    -- Almas A1–A5. A1 nua ≤20% (weight); A2/A3 padrão (esqueleto não aceita tinta de osso).
    alma = {
        { id = "A1", name = "nua", weight = 1, pieces = nil, strip = {} },
        { id = "A2", name = "farrapo", weight = 3,
            pieces = { { type = "Base.HospitalGown" } },
            strip = FULL,
            dirt = { parts = TORSO, amount = 0.75 },
            holes = { "Torso_Upper", "Torso_Lower" },
        },
        { id = "A3", name = "veu", weight = 3,
            pieces = { { type = "Base.NOM_EcoVeu" } },
            strip = { "Hat_", "Scar" },
            dirt = { parts = TORSO, amount = 0.55 },
        },
        { id = "A4", name = "sapato", weight = 1,
            pieces = { { type = "Base.Shoes_Random" } },
            strip = { "Shoes_" },
        },
        { id = "A5", name = "rastro", weight = 1,
            pieces = nil,
            strip = {},
            trail = true,
        },
    },
}

function W.count(kind)
    local cat = W.CATALOG[kind]
    return cat and #cat or 0
end

-- Peso efetivo: Screamer K1–K3 leem ScreamerK*Weight do painel (live); senão .weight.
function W.weightOf(kind, entry)
    if not entry then return 0 end
    if kind == "carpideira" and entry.id and NOM_PanelParams and NOM_PanelParams.SCHEMA then
        local key = "Screamer" .. entry.id .. "Weight"
        if NOM_PanelParams.SCHEMA[key] then
            return NOM_PanelParams.get(key)
        end
    end
    return entry.weight or 1
end

-- Sorteio estável: mesmo id → mesma variante (ADR-006).
-- Se alguma entrada tem .weight, usa faixas ponderadas (A1≤20%, massa clara).
function W.pick(kind, id)
    local cat = W.CATALOG[kind]
    if not cat or #cat == 0 then return nil, 0 end
    local total = 0
    for i = 1, #cat do
        total = total + W.weightOf(kind, cat[i])
    end
    if total <= 0 then return nil, 0 end
    local r = NOM_Math.mod(math.floor(tonumber(id) or 0), total)
    local acc = 0
    for i = 1, #cat do
        acc = acc + W.weightOf(kind, cat[i])
        if r < acc then return cat[i], i end
    end
    return cat[#cat], #cat
end

function W.isLightMass(variant)
    return variant ~= nil and variant.lightMass == true
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
