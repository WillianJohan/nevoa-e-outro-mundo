-- Visual das variantes e do Eco (sprint 0012): os dados que o jogo junta sozinho.
-- * Item de script `ClothingItem = X` → OutfitManager acha `X` pela fileGuidTable
--   (ZomboidFileSystem.loadFileGuidTable junta a do mod, mergeFrom) → o XML em
--   media/clothing/clothingItems/X.xml.
-- * textureChoices/m_BaseTextures `A\B` → media/textures/A/B.png
--   (ModelInstanceTextureCreator: 'media/textures/\1.png'); pele → media/textures/Body/<nome>.png.
-- * Item que cai da cabeça só com ChanceToFall > 0 (IsoZombie.helmetFallFromVisuals):
--   item do mod não pode cair no chão.
-- * Tamanho da textura = o da textura vanilla que o modelo usa (só o tamanho é lido).
local MEDIA = "mod/42/media/"

local function read(path)
    local f = assert(io.open(path, "rb"), "não abriu " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- largura e altura do PNG pelo cabeçalho IHDR (bytes 17–24, big endian)
local function pngSize(path)
    local s = read(path)
    assert(s:sub(2, 4) == "PNG", path .. " não é PNG")
    local function u32(i)
        local a, b, c, d = s:byte(i, i + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    return u32(17), u32(21)
end

local function items()
    local out = {}
    for name, body in read(MEDIA .. "scripts/NOM_clothing.txt"):gmatch("item%s+([%w_]+)%s*(%b{})") do
        out[name] = body
    end
    return out
end

local function guidTable()
    local out = {}
    for path, guid in read(MEDIA .. "fileGuidTable.xml"):gmatch("<path>([^<]+)</path>%s*<guid>([^<]+)</guid>") do
        out[guid] = path
    end
    return out
end

-- tamanho da textura vanilla que cada modelo usa (file(1) na textura do jogo)
local SIZE = {
    ["static\\clothes\\m_glasses_skigoggles"] = 128, -- SkiGoggles_White.png
    ["static\\clothes\\m_surgicalmask"] = 128,       -- Clothes/Hat/SurgicalMaskBlue.png
    ["skinned\\hair\\m_balaclavafull"] = 128,        -- Clothes/Hat/Balaclava_Full2.png
    ["skinned\\clothes\\m_weddingveil"] = 128,       -- Clothes/Hat/WeddingVeil.png
    [""] = 256,                                       -- camada no corpo: Dress_Textures/HospitalGown.png
    ["media\\models_X\\Skinned\\Clothes\\Bob_Hazmat.X"] = 256, -- Clothes/Hazmat/Hazmat_Yellow.png
    -- modelos nossos (scripts/gen_models.py, sprint 0041): textura nossa, 128 como as outras peças
    ["static\\clothes\\NOM_M_EstaladorVenda"] = 128,
}

-- Modelo nosso → arquivo no mod. O jogo monta media/models_x/<nome>.x e acha pelo
-- activeFileMap em minúsculas (FileTask_AbstractLoadModel + ZomboidFileSystem.getString,
-- pz-api-notes §32): o caminho tem que bater ignorando caixa.
local OWN_MODELS = {
    ["static\\clothes\\NOM_M_EstaladorVenda"] = "models_X/Static/Clothes/NOM_M_EstaladorVenda.x",
    ["static\\clothes\\NOM_F_EstaladorVenda"] = "models_X/Static/Clothes/NOM_F_EstaladorVenda.x",
}

-- Sprint 0018: gêmeo *Fx de cada peça com o shader do dissolve (a original fica sem,
-- pra opção desligada e pro shader que não compila) e a casca do Eco.
local FX = { "NOM_EstaladorVenda", "NOM_CorredorBoca", "NOM_SemRostoEstatica", "NOM_CarpideiraCabelo", "NOM_EcoVeu" }
local HAZMAT = "/mnt/stuff/steam/steamapps/common/ProjectZomboid/projectzomboid/media/clothing/clothingItems/HazmatSuit.xml"

local function xmlOf(name) return read(MEDIA .. "clothing/clothingItems/" .. name .. ".xml") end
local function tag(xml, t) return xml:match("<" .. t .. ">([^<]*)</" .. t .. ">") end

return {
    look_assets_items_resolve = function()
        local guids = guidTable()
        local n = 0
        for name, body in pairs(items()) do
            n = n + 1
            assert(body:find("ItemType = base:clothing", 1, true), name .. " não é roupa")
            assert(not body:find("ChanceToFall", 1, true), name .. " pode cair da cabeça")
            local ci = body:match("ClothingItem = ([%w_]+)")
            assert(ci == name, name .. ": ClothingItem " .. tostring(ci))
            local xml = read(MEDIA .. "clothing/clothingItems/" .. ci .. ".xml")
            local guid = xml:match("<m_GUID>([^<]+)</m_GUID>")
            assert(guids[guid] == "media/clothing/clothingItems/" .. ci .. ".xml", ci .. ": GUID fora da fileGuidTable")
            local model = xml:match("<m_MaleModel>([^<]*)</m_MaleModel>")
            local tex = xml:match("<textureChoices>([^<]+)</textureChoices>") or xml:match("<m_BaseTextures>([^<]+)</m_BaseTextures>")
            assert(SIZE[model], ci .. ": modelo sem tamanho conhecido " .. tostring(model))
            local w, h = pngSize(MEDIA .. "textures/" .. tex:gsub("\\", "/") .. ".png")
            assert(w == SIZE[model] and h == SIZE[model], ci .. ": textura " .. w .. "x" .. h)
        end
        assert(n == 13, "esperava 13 itens, achou " .. n)
    end,

    -- sprint 0041: modelo do mod (NOM_ no nome) existe no mod no caminho que o jogo monta
    look_assets_own_models_resolve = function()
        local n = 0
        for name in pairs(items()) do
            local xml = xmlOf(name)
            for _, t in ipairs({ "m_MaleModel", "m_FemaleModel" }) do
                local model = tag(xml, t)
                if model:find("NOM_", 1, true) then
                    n = n + 1
                    local file = OWN_MODELS[model]
                    assert(file, name .. ": modelo próprio sem arquivo conhecido " .. model)
                    local want = ("media/models_x/" .. model:gsub("\\", "/") .. ".x"):lower()
                    assert(("media/" .. file):lower() == want, name .. ": " .. file .. " não bate com " .. want)
                    assert(read(MEDIA .. file):sub(1, 16) == "xof 0303txt 0032", file .. " não é .x texto")
                end
            end
        end
        assert(n == 4, "esperava a venda e o gêmeo Fx nos dois sexos, achou " .. n)
    end,

    look_assets_guids_unique = function()
        local seen = {}
        for guid in read(MEDIA .. "fileGuidTable.xml"):gmatch("<guid>([^<]+)</guid>") do
            assert(not seen[guid], "GUID repetido " .. guid)
            seen[guid] = true
        end
    end,

    -- pele: mesmo tamanho da pele de zumbi vanilla (Body/M_ZedBody01_level1.png, 256)
    look_assets_skins = function()
        for _, skin in ipairs({ "NOM_Estalador", "NOM_Corredor", "NOM_Carpideira", "NOM_Ticao" }) do
            local w, h = pngSize(MEDIA .. "textures/Body/" .. skin .. ".png")
            assert(w == 256 and h == 256, skin .. " " .. w .. "x" .. h)
        end
    end,

    look_assets_item_names = function()
        for _, lang in ipairs({ "EN", "PTBR" }) do
            local names = read(MEDIA .. "lua/shared/Translate/" .. lang .. "/ItemName.json")
            for name in pairs(items()) do
                assert(names:find('"Base.' .. name .. '"', 1, true), lang .. ": sem nome pra Base." .. name)
            end
        end
    end,

    -- rodar o gerador de novo não muda um byte das texturas do visual (semente fixa)
    look_assets_deterministic = function()
        local paths = {}
        for _, n in ipairs({ "Estalador", "Corredor", "Carpideira", "Ticao" }) do paths[#paths + 1] = "textures/Body/NOM_" .. n .. ".png" end
        for _, n in ipairs({ "EstaladorVenda", "CorredorBoca", "SemRostoEstatica", "CarpideiraCabelo", "EcoCinza", "EcoVeu", "Brasa" }) do
            paths[#paths + 1] = "textures/NOM/NOM_" .. n .. ".png"
        end
        local before = {}
        for _, p in ipairs(paths) do before[p] = read(MEDIA .. p) end
        local ok = os.execute("python3 scripts/gen_textures.py >/dev/null 2>&1")
        assert(ok == 0 or ok == true, "gen_textures.py falhou")
        for _, p in ipairs(paths) do assert(read(MEDIA .. p) == before[p], p .. " mudou ao regerar") end
    end,

    -- o Eco é spawnado com o outfit do mod: o visual dele é só dado (nada de Lua)
    look_assets_eco_outfit_uses_mod_items = function()
        local guids = guidTable()
        local n = 0
        for guid in read(MEDIA .. "clothing/clothing.xml"):gmatch("<itemGUID>([%x%-]+)</itemGUID>") do
            n = n + 1
            local path = guids[guid]
            assert(path and path:find("NOM_Eco", 1, true), "outfit NOM_Eco com item que não é do Eco: " .. guid)
        end
        assert(n == 4, "NOM_Eco feminino e masculino com 2 itens cada, achou " .. n)
    end,

    look_assets_fx_twins = function()
        local all = items()
        for _, name in ipairs(FX) do
            local a, b = xmlOf(name), xmlOf(name .. "Fx")
            assert(all[name .. "Fx"], name .. "Fx fora do script")
            assert(all[name .. "Fx"]:match("BodyLocation = ([%w:]+)") == all[name]:match("BodyLocation = ([%w:]+)"), name .. "Fx em outro lugar")
            assert(not tag(a, "m_Shader"), name .. " ganhou shader (a opção desligada perde o fallback)")
            assert(tag(b, "m_Shader") == "NOM_Dissolve", name .. "Fx sem o shader")
            for _, t in ipairs({ "m_MaleModel", "m_FemaleModel", "m_Static", "m_AttachBone", "textureChoices", "m_MasksFolder", "m_HatCategory" }) do
                assert(tag(a, t) == tag(b, t), name .. "Fx: " .. t .. " diferente")
            end
            assert(tag(a, "m_GUID") ~= tag(b, "m_GUID"))
        end
    end,

    -- a casca do Eco: a malha Hazmat vanilla com as mesmas máscaras do corpo do
    -- HazmatSuit.xml (o buraco da casca mostra o fundo, não a pele), cinza do mod, shader
    look_assets_eco_shell = function()
        local x = xmlOf("NOM_EcoCasca")
        assert(tag(x, "m_MaleModel") == "media\\models_X\\Skinned\\Clothes\\Bob_Hazmat.X")
        assert(tag(x, "m_FemaleModel") == "media\\models_X\\Skinned\\Clothes\\Kate_Hazmat.X")
        assert(tag(x, "m_Shader") == "NOM_Dissolve" and tag(x, "textureChoices") == "NOM\\NOM_EcoCinza")
        local masks = {}
        for m in x:gmatch("<m_Masks>(%d+)</m_Masks>") do masks[#masks + 1] = m end
        local f = io.open(HAZMAT, "rb")
        if f then
            local van = {}
            for m in f:read("*a"):gmatch("<m_Masks>(%d+)</m_Masks>") do van[#van + 1] = m end
            f:close()
            assert(table.concat(masks, ",") == table.concat(van, ","), "máscaras diferentes do HazmatSuit.xml")
        end
        assert(#masks == 14)
        assert(items().NOM_EcoCasca:find("BodyLocation = base:zeddmg", 1, true), "casca fora do zeddmg (expulsaria a cinza)")
    end,

    -- sprint 0022: a casca de brasa do corpo inteiro na mutação. A mesma malha Hazmat da casca do
    -- Eco, mas SEM máscara (o buraco da queima tem de mostrar o monstro embaixo, não o fundo),
    -- textura de carvão e brasa do mod, o shader do dissolve, no lugar multi-item (não expulsa
    -- nada no DoZombieInventory) e sem BloodLocation (getBodyPartClothingDefense e o som de
    -- armadura pulam o item: nenhum efeito de jogo enquanto queima).
    look_assets_ember_shell = function()
        local x = xmlOf("NOM_Brasa")
        assert(tag(x, "m_MaleModel") == "media\\models_X\\Skinned\\Clothes\\Bob_Hazmat.X")
        assert(tag(x, "m_FemaleModel") == "media\\models_X\\Skinned\\Clothes\\Kate_Hazmat.X")
        assert(tag(x, "m_Shader") == "NOM_Dissolve", "casca sem o shader")
        assert(tag(x, "textureChoices") == "NOM\\NOM_Brasa")
        assert(not x:find("<m_Masks>", 1, true), "máscara esconderia o monstro embaixo da casca")
        local body = items().NOM_Brasa
        assert(body, "NOM_Brasa fora do script")
        assert(body:find("BodyLocation = base:zeddmg", 1, true), "casca fora do zeddmg (expulsaria a peça)")
        assert(not body:find("BloodLocation", 1, true), "casca com BloodLocation viraria armadura")
        assert(not body:find("Defense", 1, true), "casca com defesa")
    end,
}
